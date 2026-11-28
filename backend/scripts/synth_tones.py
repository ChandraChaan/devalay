"""Synthesise Devalay's devotional ringtones, notification sounds and meditation loops.

Licensing
---------
Every sound made here is original synthesis written in this file (oscillators, FM,
Karplus-Strong strings, filtered noise, modal drums, a synthetic reverb).  No samples,
loops or presets from anywhere else are used, so those outputs are released as CC0.

The two exceptions are remixes of freely licensed chant recordings from Wikimedia
Commons, downloaded at build time through the Commons API:

* ``gayatri-lofi``          File:Gayatri_mantra.ogg, by Wilfredor, CC0.
* ``om-namah-shivaya-beat`` File:Om_Namah_Shivaya_Performance_at_Khajuraho_-_2026.ogg,
                            by Sachin Patel 78, CC BY-SA 4.0, so that remix is
                            CC BY-SA 4.0 and must be credited.

The licence and credit of every file are written to ``synth.json``.

Output
------
44.1 kHz / 16-bit / stereo WAV masters, a ``synth.json`` catalogue and a spectrogram
PNG per file (waveform strip on top, log-frequency spectrogram below and, on the right,
a close-up of the last and first two seconds so a loop seam would be visible).

Ringtones are built on a circular timeline: notes, echoes and reverb tails that run
past the end wrap round to the start, so every tone loops on whole bars without a
seam.  Meditation loops use the same idea for 120 s: sustained oscillators are tuned
to whole numbers of cycles per loop, noise beds are generated in the frequency domain
(periodic by construction) and all events wrap, so the end flows into the start.

Everything is deterministic (fixed random seeds per slug).

Usage
-----
    python -I backend/scripts/synth_tones.py OUT_DIR [--only slug,slug] [--chant-dir DIR]

Needs numpy, scipy and pillow, plus ffmpeg on PATH to decode the chant recordings.
Chants are cached in ``OUT_DIR/../chants`` (their own folder) unless --chant-dir is given.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.parse
import urllib.request
import wave
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import signal
from scipy.ndimage import minimum_filter1d, uniform_filter1d

SR = 44100
TAU = 2 * np.pi
USER_AGENT = "DevalayContentBuilder/1.0 (https://github.com/ChandraChaan/devalay)"
COMMONS_API = "https://commons.wikimedia.org/w/api.php"

# ---------------------------------------------------------------------------
# Small helpers: pitch, envelopes, filters, panning
# ---------------------------------------------------------------------------

SWARA = {"S": 0, "r": 1, "R": 2, "g": 3, "G": 4, "m": 5, "M": 6, "P": 7, "d": 8, "D": 9, "n": 10, "N": 11}
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def note_hz(name: str) -> float:
    """'C#3' -> Hz (A4 = 440)."""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTE[pitch] + 12 * (octave + 1) - 69) / 12)


def swara_semis(token: str) -> int:
    """Semitones above Sa for a sargam token: "S" madhya, "S'" tara (upper), ".N" mandra (lower)."""
    octave = token.count("'") - token.count(".")
    return SWARA[token.strip("'.")] + 12 * octave


def swara_hz(sa: float, token: str) -> float:
    return sa * 2 ** (swara_semis(token) / 12)


def parse_line(text: str) -> list[tuple[float, float, str, str]]:
    """Parse "S/.5 R/.5 G/1k -/1" into (beat, beats, swara, flags); '-' is a rest, '|' is ignored.

    Flags: k = kampita (oscillating gamaka), s = slide in from the note below, v = vibrato.
    """
    out, beat = [], 0.0
    for tok in text.split():
        if tok == "|":
            continue
        sw, rest = tok.split("/")
        num = rest.rstrip("ksv")
        flags = rest[len(num):]
        dur = float(num)
        if sw != "-":
            out.append((beat, dur, sw, flags))
        beat += dur
    return out


def ramp(n: int) -> np.ndarray:
    """Raised-cosine 0 -> 1 over n samples."""
    if n <= 0:
        return np.ones(0)
    return 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, n))


def fades(x: np.ndarray, attack: float = 0.002, release: float = 0.01) -> np.ndarray:
    """Short raised-cosine fade in/out so no event starts or stops with a click."""
    na, nr = int(attack * SR), int(release * SR)
    n = x.shape[-1]
    na, nr = min(na, n // 2), min(nr, n // 2)
    if na:
        x[..., :na] *= ramp(na)
    if nr:
        x[..., n - nr:] *= ramp(nr)[::-1]
    return x


def tsec(n: int) -> np.ndarray:
    return np.arange(n) / SR


def butter(kind: str, fc, order: int = 2):
    return signal.butter(order, fc, kind, fs=SR, output="sos")


def filt(x: np.ndarray, sos, circular: bool = False) -> np.ndarray:
    """sosfilt along the last axis; circular=True filters a periodic signal in steady state."""
    if not circular:
        return signal.sosfilt(sos, x, axis=-1)
    n = x.shape[-1]
    y = signal.sosfilt(sos, np.concatenate([x, x], axis=-1), axis=-1)
    return y[..., n:]


def peq(f0: float, gain_db: float, q: float) -> np.ndarray:
    """RBJ peaking-EQ biquad as one sos row."""
    a = 10 ** (gain_db / 40)
    w0 = TAU * f0 / SR
    al = np.sin(w0) / (2 * q)
    b = [1 + al * a, -2 * np.cos(w0), 1 - al * a]
    den = [1 + al / a, -2 * np.cos(w0), 1 - al / a]
    return np.array([[b[0] / den[0], b[1] / den[0], b[2] / den[0], 1, den[1] / den[0], den[2] / den[0]]])


def pan2(mono: np.ndarray, pan: float = 0.0) -> np.ndarray:
    """Equal-power pan, -1 (left) .. +1 (right); centre keeps unity per channel."""
    th = (pan + 1) * np.pi / 4
    return np.vstack([mono * np.cos(th), mono * np.sin(th)]) * np.sqrt(2)


def db(x: float) -> float:
    return 10 ** (x / 20)


# ---------------------------------------------------------------------------
# Circular timeline
# ---------------------------------------------------------------------------


class Loop:
    """Named stereo buses on a timeline of n samples.

    circular=True: anything placed past the end wraps to the start (seamless loops).
    circular=False: overflow is dropped (one-shot notification sounds).
    """

    def __init__(self, seconds: float, circular: bool = True):
        self.n = int(round(seconds * SR))
        self.circular = circular
        self.buses: dict[str, np.ndarray] = {}

    def bus(self, name: str) -> np.ndarray:
        if name not in self.buses:
            self.buses[name] = np.zeros((2, self.n))
        return self.buses[name]

    def add(self, name: str, sig: np.ndarray, at: float, gain: float = 1.0, pan: float = 0.0) -> None:
        s = pan2(sig, pan) if sig.ndim == 1 else sig
        s = s * gain
        b = self.bus(name)
        start = int(round(at * SR))
        if self.circular:
            start %= self.n
            i, total = 0, s.shape[1]
            while i < total:
                pos = (start + i) % self.n
                k = min(total - i, self.n - pos)
                b[:, pos:pos + k] += s[:, i:i + k]
                i += k
        else:
            if start >= self.n:
                return
            k = min(s.shape[1], self.n - max(start, 0))
            b[:, start:start + k] += s[:, :k]

    def fold(self, y: np.ndarray) -> np.ndarray:
        """Wrap (or drop) samples beyond n."""
        out = y[..., :self.n].copy()
        if self.circular:
            i = self.n
            while i < y.shape[-1]:
                k = min(self.n, y.shape[-1] - i)
                out[..., :k] += y[..., i:i + k]
                i += k
        return out


def circ_spectrum_noise(n: int, rng, mag_fn, channels: int = 1) -> np.ndarray:
    """Noise with magnitude response mag_fn(freqs), generated in the frequency domain so it is
    exactly periodic over n samples. Normalised to unit RMS."""
    f = np.fft.rfftfreq(n, 1 / SR)
    mag = mag_fn(f)
    out = []
    for _ in range(channels):
        spec = (rng.standard_normal(len(f)) + 1j * rng.standard_normal(len(f))) * mag
        spec[0] = 0
        y = np.fft.irfft(spec, n)
        out.append(y / (np.sqrt(np.mean(y ** 2)) + 1e-12))
    return np.array(out) if channels > 1 else out[0]


def circ_lfo(n: int, max_hz: float, rng) -> np.ndarray:
    """Smooth periodic random control signal, zero mean, unit standard deviation."""
    return circ_spectrum_noise(n, rng, lambda f: (f > 0) * np.exp(-(f / max_hz) ** 2))


def bandmag(lo: float, hi: float, order: int = 2):
    """Smooth band-pass magnitude for circ_spectrum_noise."""
    def mag(f):
        f = np.maximum(f, 1e-3)
        hp = 1 / np.sqrt(1 + (lo / f) ** (2 * order)) if lo > 0 else 1
        lp = 1 / np.sqrt(1 + (f / hi) ** (2 * order))
        return hp * lp
    return mag


# ---------------------------------------------------------------------------
# Reverb: synthetic decaying-noise impulse response, convolved (circularly for loops)
# ---------------------------------------------------------------------------


def reverb_ir(rt60: float, seed: int = 7, predelay: float = 0.015, hf_damp: float = 0.55,
              seconds: float | None = None) -> np.ndarray:
    """Stereo IR: independent noise per channel, frequency-dependent exponential decay
    (highs die faster), a few early reflections. Unit energy per channel."""
    rng = np.random.default_rng(seed)
    m = int((seconds or rt60 * 1.15) * SR)
    t = tsec(m)
    f = np.maximum(np.fft.rfftfreq(m, 1 / SR), 1e-3)
    cross = [250.0, 1500.0, 5000.0]
    lows = [np.zeros_like(f)] + [1 / (1 + (f / c) ** 4) for c in cross] + [np.ones_like(f)]
    rts = [rt60 * 1.15, rt60, rt60 * (1 - 0.45 * hf_damp), rt60 * (1 - 0.8 * hf_damp)]
    ir = np.zeros((2, m))
    for ch in range(2):
        spec = np.fft.rfft(rng.standard_normal(m))
        for i, rt in enumerate(rts):
            band = np.fft.irfft(spec * (lows[i + 1] - lows[i]), m)
            ir[ch] += band * np.exp(-6.91 * t / rt)
        nd = int(0.01 * SR)
        ir[ch, :nd] *= ramp(nd)
        for _ in range(6):  # early reflections
            k = int(rng.uniform(0.004, 0.045) * SR)
            ir[ch, k] += rng.uniform(0.15, 0.35) * np.sqrt(SR) * 0.02 * rng.choice([-1, 1])
    pd = int(predelay * SR)
    ir = np.concatenate([np.zeros((2, pd)), ir], axis=1)
    ir /= np.sqrt(np.sum(ir ** 2, axis=1, keepdims=True))
    return ir


def convolve(loop: Loop, x: np.ndarray, ir: np.ndarray) -> np.ndarray:
    y = np.vstack([signal.fftconvolve(x[c], ir[c]) for c in range(2)])
    return loop.fold(y)


def echo(loop: Loop, x: np.ndarray, delay_l: float, delay_r: float, feedback: float = 0.35,
         repeats: int = 4, lp: float = 3500) -> np.ndarray:
    """Ping-pong-ish tape echo (each repeat darker), wrapped on the loop."""
    out = np.zeros((2, loop.n + int(SR * (max(delay_l, delay_r) * repeats + 0.1))))
    mono = x.mean(axis=0)
    sig = mono
    sos = butter("lowpass", lp)
    for r in range(1, repeats + 1):
        sig = filt(sig, sos)
        g = feedback ** r
        for ch, d in ((0, delay_l), (1, delay_r)):
            k = int(round(d * r * SR))
            out[ch, k:k + loop.n] += sig * g
    return loop.fold(out)


# ---------------------------------------------------------------------------
# Loudness (ITU-R BS.1770 / EBU R128), true peak, limiter, mastering
# ---------------------------------------------------------------------------


def _kweight_sos() -> np.ndarray:
    g, q, fc = 4.0, 1 / np.sqrt(2), 1500.0
    a = 10 ** (g / 40)
    w0 = TAU * fc / SR
    al = np.sin(w0) / (2 * q)
    cs, sa = np.cos(w0), 2 * np.sqrt(a) * al
    b0, b1, b2 = a * ((a + 1) + (a - 1) * cs + sa), -2 * a * ((a - 1) + (a + 1) * cs), a * ((a + 1) + (a - 1) * cs - sa)
    a0, a1, a2 = (a + 1) - (a - 1) * cs + sa, 2 * ((a - 1) - (a + 1) * cs), (a + 1) - (a - 1) * cs - sa
    shelf = [b0 / a0, b1 / a0, b2 / a0, 1, a1 / a0, a2 / a0]
    fc, q = 38.0, 0.5
    w0 = TAU * fc / SR
    al = np.sin(w0) / (2 * q)
    b0, b1, b2 = (1 + np.cos(w0)) / 2, -(1 + np.cos(w0)), (1 + np.cos(w0)) / 2
    a0, a1, a2 = 1 + al, -2 * np.cos(w0), 1 - al
    hp = [b0 / a0, b1 / a0, b2 / a0, 1, a1 / a0, a2 / a0]
    return np.array([shelf, hp])


KW = _kweight_sos()


def lufs(x: np.ndarray) -> float:
    """Integrated loudness of a stereo signal (2, n)."""
    y = signal.sosfilt(KW, x, axis=-1)
    e = np.concatenate([[0.0], np.cumsum(np.sum(y ** 2, axis=0))])
    block, step = int(0.4 * SR), int(0.1 * SR)
    if x.shape[1] < block:
        return -70.0
    starts = np.arange(0, x.shape[1] - block + 1, step)
    z = (e[starts + block] - e[starts]) / block
    lk = -0.691 + 10 * np.log10(z + 1e-15)
    z = z[lk > -70]
    rel = -0.691 + 10 * np.log10(z.mean() + 1e-15) - 10
    z = z[-0.691 + 10 * np.log10(z + 1e-15) > rel]
    return float(-0.691 + 10 * np.log10(z.mean() + 1e-15))


def true_peak_db(x: np.ndarray) -> float:
    up = signal.resample_poly(x, 4, 1, axis=-1)
    return float(20 * np.log10(np.max(np.abs(up)) + 1e-12))


def limiter(x: np.ndarray, ceiling_db: float, circular: bool, window: float = 0.012) -> np.ndarray:
    """Look-ahead brick-wall limiter: per-sample gain needed, min-filtered and smoothed so the
    gain is already down when a peak arrives (attack = release = window)."""
    c = db(ceiling_db)
    peak = np.max(np.abs(x), axis=0)
    need = np.minimum(1.0, c / np.maximum(peak, 1e-9))
    w = max(3, int(window * SR))
    mode = "wrap" if circular else "nearest"
    g = minimum_filter1d(need, 2 * w + 1, mode=mode)
    g = uniform_filter1d(g, w, mode=mode)
    g = np.minimum(g, need)  # guard against smoothing round-off
    return x * g


def master(x: np.ndarray, target_lufs: float, tp_max_db: float, circular: bool) -> np.ndarray:
    """Remove DC/subsonics, set integrated loudness, limit so true peak <= tp_max_db."""
    x = x - x.mean(axis=1, keepdims=True)
    x = filt(x, butter("highpass", 28), circular)
    ceiling = tp_max_db - 0.7
    for _ in range(6):
        x = x * db(target_lufs - lufs(x))
        x = limiter(x, ceiling, circular)
        tp = true_peak_db(x)
        if tp > tp_max_db - 0.1:
            ceiling -= tp - (tp_max_db - 0.15)
            continue
        if abs(lufs(x) - target_lufs) < 0.15:
            break
    return x


def write_wav(path: Path, x: np.ndarray, seed: int) -> None:
    rng = np.random.default_rng(seed)
    dither = (rng.random(x.shape) - rng.random(x.shape)) / 32768.0  # TPDF, 1 LSB
    pcm = np.clip(np.round((x + dither) * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.T.tobytes())


# ---------------------------------------------------------------------------
# Spectrogram PNG for visual QA
# ---------------------------------------------------------------------------

_CMAP = np.array([[0, 0, 4], [40, 11, 84], [101, 21, 110], [159, 42, 99], [212, 72, 66],
                  [245, 125, 21], [250, 193, 39], [252, 255, 164]], dtype=float)


def _colour(v: np.ndarray) -> np.ndarray:
    v = np.clip(v, 0, 1) * (len(_CMAP) - 1)
    i = np.minimum(v.astype(int), len(_CMAP) - 2)
    fr = (v - i)[..., None]
    return (_CMAP[i] * (1 - fr) + _CMAP[i + 1] * fr).astype(np.uint8)


def _spec_img(mono: np.ndarray, width: int, height: int, nfft: int = 2048, top: float | None = None) -> np.ndarray:
    hop = max(64, (len(mono) - nfft) // width)
    frames = np.lib.stride_tricks.sliding_window_view(mono, nfft)[::hop][:width]
    mag = np.abs(np.fft.rfft(frames * np.hanning(nfft), axis=1))
    sdb = 20 * np.log10(mag / (nfft / 4) + 1e-9)
    f = np.fft.rfftfreq(nfft, 1 / SR)
    rows = np.searchsorted(f, np.geomspace(30, 20000, height))
    img = sdb[:, np.minimum(rows, len(f) - 1)].T[::-1]
    top = np.percentile(img, 99.7) if top is None else top  # 90 dB range below the loudest bins
    return _colour((img - top + 90) / 90)


def spectrogram_png(x: np.ndarray, path: Path, seam: bool = True) -> None:
    W, H, WH = 1400, 360, 110
    mono = x.mean(axis=0)
    spec = _spec_img(mono, W, H)
    W = spec.shape[1]
    canvas = Image.new("RGB", (W + (420 if seam else 0), H + WH + 6), (18, 18, 22))
    # waveform strip: per-column max |x| of either channel, -1 dBFS line in red
    cols = np.array_split(np.max(np.abs(x), axis=0), W)
    d = ImageDraw.Draw(canvas)
    lim = db(-1)
    for i, c in enumerate(cols):
        p = float(c.max()) if len(c) else 0.0
        h = int(p * (WH - 4) / 2)
        d.line([(i, WH // 2 - h), (i, WH // 2 + h)], fill=(255, 60, 60) if p >= 0.999 else (120, 200, 255))
    for yy in (WH // 2 - int(lim * (WH - 4) / 2), WH // 2 + int(lim * (WH - 4) / 2)):
        d.line([(0, yy), (W, yy)], fill=(200, 40, 40))
    canvas.paste(Image.fromarray(spec), (0, WH + 6))
    dur = x.shape[1] / SR
    step = 1 if dur < 40 else 10
    for s in np.arange(0, dur, step):
        xx = int(s / dur * W)
        d.line([(xx, WH + 6 + H - 8), (xx, WH + 6 + H)], fill=(255, 255, 255))
    for hz in (100, 1000, 10000):  # frequency ticks
        yy = WH + 6 + int((1 - np.log(hz / 30) / np.log(20000 / 30)) * (H - 1))
        d.line([(0, yy), (10, yy)], fill=(255, 255, 255))
    if seam:  # last 2 s + first 2 s, seam marked
        k = 2 * SR
        joined = np.concatenate([mono[-k:], mono[:k]])
        sp = _spec_img(joined, 400, H, nfft=1024)
        canvas.paste(Image.fromarray(sp), (W + 20, WH + 6))
        sx = W + 20 + sp.shape[1] // 2
        d.line([(sx, WH + 6), (sx, WH + 6 + 12)], fill=(255, 255, 255))
        seg = np.concatenate([x[:, -k:], x[:, :k]], axis=1)
        cols = np.array_split(np.max(np.abs(seg), axis=0), 400)
        for i, c in enumerate(cols):
            h = int(float(c.max()) * (WH - 4) / 2)
            d.line([(W + 20 + i, WH // 2 - h), (W + 20 + i, WH // 2 + h)], fill=(120, 255, 160))
        d.line([(sx, 0), (sx, WH)], fill=(255, 255, 255))
    canvas.save(path)


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------


def additive(phase: np.ndarray, amps, phases=None) -> np.ndarray:
    """Sum_k amps[k-1] * sin(k*phase + phases[k-1]); amps may be scalars or per-sample arrays."""
    y = np.zeros(len(phase))
    for k, a in enumerate(amps, start=1):
        ph = 0.0 if phases is None else phases[k - 1]
        y += a * np.sin(k * phase + ph)
    return y


def flute_line(notes, n: int, rng, breath: float = 0.08, vib_cents: float = 20, vib_rate: float = 5.2,
               glide: float = 0.07, bright: float = 1.0) -> np.ndarray:
    """Bansuri-like line. notes = [(start_s, dur_s, hz, flags)], rendered on n samples.

    Sine/triangle-ish additive tone with breath noise, delayed vibrato, legato slides between
    notes (glide in log-frequency), 'chiff' on tongued attacks and slide-ins for flag 's'."""
    t = tsec(n)
    logf = np.full(n, np.log2(notes[0][2]))
    amp = np.zeros(n)
    vib = np.zeros(n)
    chiff = np.zeros(n)
    prev_end = -1.0
    for (t0, dur, hz, flags) in notes:
        i0, i1 = int(t0 * SR), min(n, int((t0 + dur) * SR))
        logf[i0:] = np.log2(hz)
        if "s" in flags:  # slide up from a whole tone below
            k = min(int(0.14 * SR), i1 - i0)
            logf[i0:i0 + k] = np.log2(hz) - (2 / 12) * (1 - ramp(k))
        legato = t0 - prev_end < 0.03
        a_att = int((0.05 if legato else 0.035) * SR)
        rel = int(0.09 * SR)
        env = np.ones(i1 - i0)
        env[:a_att] = np.maximum(ramp(a_att)[: len(env)], 0.75 if legato else 0.0)[: len(env[:a_att])]
        swell = 0.9 + 0.1 * np.sin(np.linspace(0, np.pi, len(env)))
        env *= swell
        amp[i0:i1] = np.maximum(amp[i0:i1], env)
        tail = min(rel, n - i1)
        amp[i1:i1 + tail] = np.maximum(amp[i1:i1 + tail], ramp(rel)[::-1][:tail] * env[-1])
        if dur > 0.35:
            onset = max(0.18, 0.4 * dur)
            vt = tsec(i1 - i0)
            vib[i0:i1] = np.clip((vt - onset) / 0.35, 0, 1) * ("v" in flags or dur > 0.6)
        if not legato:
            k = int(0.03 * SR)
            chiff[i0:i0 + k] += ramp(k)[::-1][: max(0, min(k, n - i0))]
        prev_end = t0 + dur
    # glide: smooth the log-frequency staircase (gives slides at every note change)
    g = int(glide * SR)
    kern = np.hanning(g)
    kern /= kern.sum()
    padded = np.concatenate([np.full(g, logf[0]), logf, np.full(g, logf[-1])])
    logf = np.convolve(padded, kern, mode="same")[g:-g]
    cents = vib_cents * vib * np.sin(TAU * vib_rate * t + 0.3 * np.sin(TAU * 0.4 * t))
    f = 2 ** (logf + cents / 1200)
    ph = TAU * np.cumsum(f) / SR
    a = amp
    tone = (np.sin(ph) + (0.18 + 0.22 * a * bright) * np.sin(2 * ph + 0.4)
            + 0.07 * bright * a * np.sin(3 * ph + 1.1) + 0.025 * bright * np.sin(4 * ph + 0.2))
    noise = rng.standard_normal(n)
    hiss = filt(noise, butter("bandpass", [1500, 7000]))
    pitched = filt(noise, butter("lowpass", 2500)) * (0.6 + 0.4 * np.sin(ph))
    ch = filt(rng.standard_normal(n), butter("bandpass", [2000, 6000])) * chiff
    y = tone * a + breath * (0.6 * hiss + 0.8 * pitched) * a + 0.25 * ch
    y = filt(y, butter("lowpass", 8500))
    return y


def ks_string(freq: float, dur: float, rng, tau: float = 1.5, a: float = 0.18, pick: float = 0.13,
              jawari: float = 0.0, jaw_th: float = 0.35, bend=None, os: int = 4, soft: float = 0.0) -> np.ndarray:
    """Karplus-Strong plucked string, vectorised one period at a time.

    tau    : decay time constant of the fundamental (s)
    a      : loop low-pass [a, 1-2a, a]; larger = darker, faster high-frequency decay
    pick   : pluck position (comb on the excitation)
    jawari : 0..1 one-sided bridge contact (displacement above jaw_th is compressed every
             period), regenerating upper partials while the string is loud: the tanpura/veena buzz
    bend   : optional per-sample semitone curve (gamaka) applied by variable-rate resampling
    soft   : 0..1 low-pass on the excitation (finger vs plectrum)
    """
    sr2 = SR * os
    period = sr2 / freq
    N = int(round(period - 1))
    actual = sr2 / (N + 1)
    g = np.exp(-1 / (freq * tau))
    L = int(dur * sr2) + N
    exc = rng.standard_normal(N)
    if soft > 0:
        # excitation runs at os*SR, so a cutoff designed for SR is scaled down by os
        exc = filt(exc, butter("lowpass", min(0.45 * SR, max(200, freq * (2 + 30 * (1 - soft))) / os)))
    p = max(1, int(pick * N))
    exc = exc - np.roll(exc, p)
    exc = exc - exc.mean()
    exc /= np.max(np.abs(exc)) + 1e-9
    pad = N + 2
    y = np.zeros(pad + L)
    y[pad:pad + N] = exc
    peak0 = 1.0
    th = jaw_th * peak0
    s = pad
    while s < pad + L:
        e = min(s + N, pad + L)
        m = e - s
        fb = g * (a * y[s - N:s - N + m] + (1 - 2 * a) * y[s - N - 1:s - N - 1 + m] + a * y[s - N - 2:s - N - 2 + m])
        if s == pad:
            fb = fb + y[s:e]
        if jawari > 0:
            over = fb - th
            fb = np.where(over > 0, th + over * (1 - jawari), fb)
        y[s:e] = fb
        s = e
    out = y[pad:]
    out = signal.resample_poly(out, 1, os)
    # pitch correction for integer delay + optional gamaka bend
    r0 = freq / (actual)
    n_out = int(dur * SR)
    semis = np.zeros(n_out) if bend is None else np.asarray(bend)[:n_out]
    if len(semis) < n_out:
        semis = np.concatenate([semis, np.full(n_out - len(semis), semis[-1] if len(semis) else 0)])
    rate = r0 * 2 ** (semis / 12)
    pos = np.concatenate([[0.0], np.cumsum(rate)[:-1]])
    pos = pos[pos < len(out) - 1]
    res = np.interp(pos, np.arange(len(out)), out)
    res = filt(res, butter("highpass", 30))
    return fades(res, 0.0015, 0.03)


def kampita(n: int, beats_s: float, depth: float, rate: float = 6.5, end: float = 0.0) -> np.ndarray:
    """Carnatic oscillating gamaka: semitone curve swinging between `depth` and 0, settling on `end`."""
    t = tsec(n)
    osc = depth * (0.5 + 0.5 * np.cos(TAU * rate * t))
    settle = np.clip((t - 0.75 * beats_s) / (0.2 * beats_s + 1e-3), 0, 1)
    return osc * (1 - settle) + end * settle


def gamaka_depth(token: str, scale: list[int]) -> float:
    """Semitones to the neighbouring scale note the kampita swings to: N3 swings up to Sa,
    every other note swings down to the scale note below it."""
    pc = SWARA[token.strip("'.")]
    if pc == 11:
        return 1.0
    below = max([s for s in scale if s < pc], default=scale[-1] - 12)
    return float(below - pc)


def slide_in(n: int, from_semis: float, time: float = 0.09) -> np.ndarray:
    k = min(n, int(time * SR))
    c = np.zeros(n)
    c[:k] = from_semis * (1 - ramp(k))
    return c


def fm_bell(freq: float, dur: float, ratio: float = 1.4, index: float = 3.5, decay: float = 2.2,
            beat_hz: float = 0.7, bright_decay: float = 0.35) -> np.ndarray:
    """Two-operator FM bell (inharmonic sidebands), doubled with a slightly detuned copy for the
    slow beating of a real cast bell."""
    n = int(dur * SR)
    t = tsec(n)
    idx = index * np.exp(-t / (decay * bright_decay)) + 0.25 * index * np.exp(-t / decay)
    env = np.exp(-t / decay)
    y = np.zeros(n)
    for df, g in ((0.0, 1.0), (beat_hz, 0.7)):
        fc = freq + df
        y += g * np.sin(TAU * fc * t + idx * np.sin(TAU * fc * ratio * t))
    y += 0.25 * np.sin(TAU * freq * 2.0 * t) * np.exp(-t / (decay * 0.5))  # octave shimmer
    y *= env
    y = filt(y, butter("lowpass", 11000))
    return fades(y, 0.001, 0.05)


def temple_bell(freq: float, dur: float = 6.0) -> np.ndarray:
    """Larger brass bell: low hum, strike tone and inharmonic FM shimmer."""
    n = int(dur * SR)
    t = tsec(n)
    hum = 0.45 * np.sin(TAU * freq * 0.5 * t) * np.exp(-t / (dur * 0.45))
    body = fm_bell(freq, dur, ratio=1.4, index=2.6, decay=dur * 0.35, beat_hz=1.1)
    upper = 0.35 * fm_bell(freq * 2.76, dur, ratio=1.0, index=1.2, decay=dur * 0.15, beat_hz=2.3)
    return fades(hum + body + upper, 0.001, 0.2)


def marimba(freq: float, dur: float = 1.2, vel: float = 1.0) -> np.ndarray:
    n = int(dur * SR)
    t = tsec(n)
    d1 = 0.25 + 60 / freq
    y = (np.sin(TAU * freq * t) * np.exp(-t / d1)
         + 0.22 * np.sin(TAU * freq * 4 * t) * np.exp(-t / (d1 * 0.25))
         + 0.05 * np.sin(TAU * freq * 10 * t) * np.exp(-t / 0.02))
    return fades(y * vel, 0.0015, 0.03)


def saw_pad_voice(freq: float, n: int, rng, cutoff: float = 1400.0) -> np.ndarray:
    """Band-limited, low-passed sawtooth (additive), random partial phases."""
    t = tsec(n)
    kmax = int(min(cutoff * 3.2, 14000) / freq)
    y = np.zeros(n)
    for k in range(1, max(2, kmax + 1)):
        fk = freq * k
        y += (1 / k) / np.sqrt(1 + (fk / cutoff) ** 4) * np.sin(TAU * fk * t + rng.uniform(0, TAU))
    return y


def pad_chord(freqs, dur: float, rng, cutoff: float = 1400, attack: float = 0.6, release: float = 1.2,
              detune_cents: float = 7.0) -> np.ndarray:
    """Warm stereo pad: three detuned saw voices per note, different detune per channel."""
    n = int((dur + release) * SR)
    out = np.zeros((2, n))
    for f in freqs:
        for ch in range(2):
            for d in (-1, 0, 1):
                cents = d * detune_cents + rng.uniform(-2, 2)
                out[ch] += saw_pad_voice(f * 2 ** (cents / 1200), n, rng, cutoff)
    env = np.ones(n)
    na, nr = int(attack * SR), int(release * SR)
    env[:na] = ramp(na)
    env[n - nr:] = ramp(nr)[::-1]
    out *= env / (3 * len(freqs))
    return out


def kick(f_hi: float = 150, f_lo: float = 50, decay: float = 0.3, click: float = 0.25, rng=None,
         drive: float = 1.5) -> np.ndarray:
    n = int((decay * 3 + 0.05) * SR)
    t = tsec(n)
    f = f_lo + (f_hi - f_lo) * np.exp(-t / 0.035)
    body = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / decay)
    body = np.tanh(drive * body) / np.tanh(drive)
    if rng is not None and click:
        c = filt(rng.standard_normal(n), butter("bandpass", [1200, 5000])) * np.exp(-t / 0.004) * click
        body += c
    return fades(body, 0.0008, 0.02)


def snare(rng, tone: float = 185, decay: float = 0.13, noise: float = 0.8, lp: float = 7000) -> np.ndarray:
    n = int(0.5 * SR)
    t = tsec(n)
    body = (np.sin(TAU * tone * t) + 0.5 * np.sin(TAU * tone * 1.78 * t)) * np.exp(-t / 0.05)
    nz = filt(rng.standard_normal(n), butter("bandpass", [900, lp])) * np.exp(-t / decay)
    return fades(0.6 * body + noise * nz, 0.0008, 0.03)


def rim(rng) -> np.ndarray:
    n = int(0.12 * SR)
    t = tsec(n)
    y = (np.sin(TAU * 1650 * t) * 0.6 + np.sin(TAU * 820 * t)) * np.exp(-t / 0.018)
    y += 0.5 * filt(rng.standard_normal(n), butter("bandpass", [2000, 6000])) * np.exp(-t / 0.006)
    return fades(y, 0.0005, 0.01)


def hat(rng, decay: float = 0.035, open_: bool = False) -> np.ndarray:
    d = 0.22 if open_ else decay
    n = int((d * 5 + 0.01) * SR)
    t = tsec(n)
    y = filt(rng.standard_normal(n), butter("bandpass", [6500, 12500], order=3)) * np.exp(-t / d)
    return fades(y, 0.0005, 0.01)


def clap(rng) -> np.ndarray:
    n = int(0.4 * SR)
    t = tsec(n)
    env = np.zeros(n)
    for k, off in enumerate((0.0, 0.011, 0.021, 0.032)):
        i = int(off * SR)
        env[i:] += np.exp(-(t[: n - i]) / (0.006 if k < 3 else 0.09))
    y = filt(rng.standard_normal(n), butter("bandpass", [900, 2600])) * env
    return fades(y, 0.0005, 0.03)


def shaker(rng) -> np.ndarray:
    n = int(0.12 * SR)
    t = tsec(n)
    env = (1 - np.exp(-t / 0.012)) * np.exp(-t / 0.035)
    return fades(filt(rng.standard_normal(n), butter("bandpass", [4000, 10000])) * env, 0.001, 0.01)


def bass808(freq: float, dur: float, drive: float = 2.2, glide_from: float = 1.0) -> np.ndarray:
    """808-style sub: sine with a short pitch drop onto the tonic, soft-clipped so its odd
    harmonics (3rd = fifth, 5th = major third: both in the pentatonic) carry on phone speakers."""
    n = int((dur + 0.08) * SR)
    t = tsec(n)
    f = freq * (1 + (glide_from - 1) * np.exp(-t / 0.04))
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / max(dur * 0.9, 0.2))
    y = np.tanh(drive * y) / np.tanh(drive)
    y[-int(0.08 * SR):] *= ramp(int(0.08 * SR))[::-1]
    return fades(y, 0.002, 0.05)


def soft_bass(freq: float, dur: float) -> np.ndarray:
    n = int((dur + 0.15) * SR)
    t = tsec(n)
    y = np.sin(TAU * freq * t) + 0.25 * np.sin(TAU * 2 * freq * t) + 0.06 * np.sin(TAU * 3 * freq * t)
    env = np.minimum(1, t / 0.012) * np.exp(-t / (dur * 1.5 + 0.2))
    env[-int(0.15 * SR):] *= ramp(int(0.15 * SR))[::-1]
    return y * env


def membrane(freq: float, ratios, amps, decays, dur: float, bend: float = 0.0, bend_tau: float = 0.02,
             glide_to: float = 1.0, glide_time: float = 0.3) -> np.ndarray:
    """Modal drum: decaying partials with a pitch bend (strike tension / pressed bayan)."""
    n = int(dur * SR)
    t = tsec(n)
    mult = (1 + bend * np.exp(-t / bend_tau)) * (1 + (glide_to - 1) * np.clip(t / glide_time, 0, 1) ** 0.6)
    base = np.cumsum(freq * mult) / SR
    y = np.zeros(n)
    for r, a, d in zip(ratios, amps, decays):
        y += a * np.sin(TAU * r * base) * np.exp(-t / d)
    return y


def tabla(stroke: str, sa: float, rng, vel: float = 1.0) -> np.ndarray:
    """Synthesised tabla strokes; the dayan is tuned to Sa (its near-harmonic modes stay in key)."""
    harm = [1, 2, 3, 4.02, 5.05]
    out = np.zeros(int(0.9 * SR))

    def put(y):
        out[: len(y)] += y[: len(out)]

    def click(level, lo=2500, hi=7000, d=0.004):
        n = int(0.05 * SR)
        return level * filt(rng.standard_normal(n), butter("bandpass", [lo, hi])) * np.exp(-tsec(n) / d)

    if stroke in ("na", "ta", "dha"):
        put(membrane(sa, harm, [0.25, 0.7, 1.0, 0.5, 0.3], [0.28, 0.22, 0.16, 0.1, 0.07], 0.8, bend=0.015))
        put(click(0.6))
    if stroke in ("tin", "dhin"):
        put(membrane(sa, harm, [0.35, 1.0, 0.55, 0.25, 0.12], [0.45, 0.32, 0.2, 0.12, 0.08], 0.8, bend=0.01))
        put(click(0.35, 2000, 5000))
    if stroke == "tun":
        put(membrane(sa, harm, [1.0, 0.35, 0.15, 0.05, 0.02], [0.6, 0.3, 0.15, 0.1, 0.05], 0.8, bend=0.01))
    if stroke in ("ge", "dha", "dhin"):
        put(0.8 * membrane(sa / 2.6, [1, 1.59, 2.14], [1.0, 0.25, 0.1], [0.42, 0.15, 0.08], 0.9,
                           bend=0.04, glide_to=1.22, glide_time=0.28))
    if stroke == "ke":
        n = int(0.12 * SR)
        y = filt(rng.standard_normal(n), butter("lowpass", 700)) * np.exp(-tsec(n) / 0.02)
        y += 0.6 * np.sin(TAU * 130 * tsec(n)) * np.exp(-tsec(n) / 0.03)
        put(y)
    return fades(out * vel, 0.0005, 0.05)


def damru_hit(freq: float, rng, vel: float = 1.0) -> np.ndarray:
    """One damru strike: small tight membrane (circular-membrane mode ratios) plus a bead click."""
    y = membrane(freq, [1, 1.593, 2.136, 2.296, 2.653], [1, 0.45, 0.3, 0.2, 0.12],
                 [0.08, 0.05, 0.04, 0.03, 0.025], 0.3, bend=0.03, bend_tau=0.01)
    n = int(0.03 * SR)
    y[:n] += 0.35 * filt(rng.standard_normal(n), butter("bandpass", [2500, 6500])) * np.exp(-tsec(n) / 0.003)
    return fades(y * vel, 0.0005, 0.02)


def damru_roll(loop: Loop, bus: str, t0: float, length: float, sa: float, rng, gain: float = 1.0,
               rate0: float = 9.0, rate1: float = 22.0, pan: float = 0.0) -> None:
    """Accelerating, crescendoing roll alternating the two heads (Sa and Pa)."""
    t, k = 0.0, 0
    while t < length:
        frac = t / length
        vel = (0.35 + 0.65 * frac ** 1.3) * rng.uniform(0.85, 1.0)
        head = sa * (2 if k % 2 == 0 else 3)  # Sa' and Pa' heads
        loop.add(bus, damru_hit(head, rng, vel), t0 + t, gain, pan + (0.15 if k % 2 else -0.15))
        rate = rate0 + (rate1 - rate0) * frac
        t += 1 / rate
        k += 1


def conch(freq: float, dur: float, rng, swell: float = 1.0) -> np.ndarray:
    """Shankh: brassy additive tone (brighter as it gets louder) through formant peaks, rising
    from slightly flat, with breath noise and a little air flutter."""
    n = int(dur * SR)
    t = tsec(n)
    cents = -130 * np.exp(-t / 0.22) + 6 * np.sin(TAU * 0.7 * t) - 35 * np.clip((t - (dur - 0.35)) / 0.35, 0, 1)
    f = freq * 2 ** (cents / 1200)
    ph = TAU * np.cumsum(f) / SR
    amp = np.clip(t / (0.9 * swell), 0, 1) ** 1.6
    amp *= 1 + 0.04 * np.sin(TAU * 27 * t)  # flutter
    rel = int(0.3 * SR)
    amp[-rel:] *= ramp(rel)[::-1]
    bright = amp
    y = np.zeros(n)
    kmax = int(9000 / freq)
    for k in range(1, kmax + 1):
        y += k ** (-(2.4 - 1.25 * bright)) * np.sin(k * ph + 0.3 * k)
    y *= amp
    breath = filt(rng.standard_normal(n), butter("bandpass", [900, 4000])) * amp * 0.04
    y = y + breath
    sos = np.vstack([peq(600, 7, 1.4), peq(1350, 5, 1.6), peq(2700, 3, 2.0), butter("lowpass", 7000)])
    y = signal.sosfilt(sos, y)
    return fades(y, 0.005, 0.05)


def tanpura_cycle(loop: Loop, bus: str, sa: float, rng, cycle: float, start: float = 0.0,
                  count: int | None = None, gain: float = 1.0, variants: int = 3, ring: float = 7.0) -> None:
    """Tanpura Pa-Sa-Sa-Sa (mandra Pa, two madhya Sa, mandra Sa) with jawari buzz, overlapping decays."""
    strings = [(sa * 0.75, -0.35), (sa, -0.1), (sa, 0.1), (sa * 0.5, 0.35)]
    rendered = {}
    for i, (f, _) in enumerate(strings):
        rendered[i] = [ks_string(f, ring, rng, tau=ring * 0.4, a=0.06, pick=0.17, jawari=0.5,
                                 jaw_th=0.22, soft=0.6) for _ in range(variants)]
    body = np.vstack([peq(220, 3, 0.9), peq(1800, -3, 1.0), butter("lowpass", 6500)])
    for k in rendered:
        rendered[k] = [signal.sosfilt(body, y) for y in rendered[k]]
    total = count if count is not None else int(round(loop.n / SR / cycle))
    for c in range(total):
        for i, (f, p) in enumerate(strings):
            jitter = rng.uniform(-0.03, 0.03)
            y = rendered[i][rng.integers(variants)]
            loop.add(bus, y, start + c * cycle + i * cycle / 4 + jitter, gain * rng.uniform(0.85, 1.0), p)


# ---------------------------------------------------------------------------
# Voice / Om synthesis (additive with moving formants), periodic over the loop
# ---------------------------------------------------------------------------

VOWELS = {  # (F, bandwidth, gain) for a male voice
    "A": [(730, 90, 1.0), (1090, 110, 0.5), (2440, 170, 0.22)],
    "O": [(570, 80, 1.0), (840, 90, 0.45), (2410, 170, 0.12)],
    "U": [(320, 60, 1.0), (800, 80, 0.28), (2240, 150, 0.06)],
    "M": [(250, 50, 1.0), (1000, 200, 0.03), (2200, 200, 0.01)],
}


def quantise(f: float, period_s: float) -> float:
    """Nearest frequency with a whole number of cycles in period_s (keeps loops seamless)."""
    return round(f * period_s) / period_s


def voice_drone(n: int, f0: float, rng, keyframes, cycle_s: float, period_s: float,
                jitter_cents: float = 5.0, max_hz: float = 4500.0, phase_shift: float = 0.0) -> np.ndarray:
    """Additive sung vowel drone. keyframes = [(fraction_of_cycle, vowel, level)], repeated every
    cycle_s (must divide period_s). Harmonic k gets source 1/k times the summed formant
    resonances at k*f0; formants are interpolated between keyframes."""
    f0 = quantise(f0, period_s)
    ctrl_hop = 512
    m = n // ctrl_hop + 2
    tc = np.arange(m) * ctrl_hop / SR
    frac = ((tc / cycle_s) + phase_shift) % 1.0
    kf = sorted(keyframes) + [(1.0 + sorted(keyframes)[0][0], sorted(keyframes)[0][1], sorted(keyframes)[0][2])]
    xs = np.array([k[0] for k in kf])
    level = np.interp(frac, xs, [k[2] for k in kf])
    formants = []
    for j in range(3):
        F = np.interp(frac, xs, [VOWELS[k[1]][j][0] for k in kf])
        B = np.interp(frac, xs, [VOWELS[k[1]][j][1] for k in kf])
        G = np.interp(frac, xs, [VOWELS[k[1]][j][2] for k in kf])
        formants.append((F, B, G))
    # periodic pitch jitter (zero-mean so the phase closes after period_s)
    jit = circ_lfo(n, 0.35, rng) * jitter_cents
    f = f0 * 2 ** (jit / 1200)
    f *= f0 / f.mean()
    ph = TAU * np.cumsum(f) / SR
    y = np.zeros(n)
    idx = np.arange(n) / ctrl_hop
    for k in range(1, int(max_hz / f0) + 1):
        fk = k * f0
        a = sum(G / np.sqrt(1 + ((fk - F) / (B / 2)) ** 2) for F, B, G in formants)
        a = a * level / k ** 0.9
        y += np.interp(idx, np.arange(m), a) * np.sin(k * ph + rng.uniform(0, TAU))
    return y


OM_KEYS = [(0.0, "M", 0.55), (0.07, "A", 0.95), (0.25, "A", 1.0), (0.36, "O", 0.95),
           (0.48, "U", 0.9), (0.6, "M", 0.85), (0.9, "M", 0.7)]


def drone_pad(n: int, freqs, rng, period_s: float, swell_hz: float = 0.02, harmonics: int = 6) -> np.ndarray:
    """Soft stereo drone (each note a few quantised sine partials with slow periodic swells)."""
    out = np.zeros((2, n))
    t = tsec(n)
    for f in freqs:
        for ch in range(2):
            fq = quantise(f * 2 ** (rng.uniform(-1.5, 1.5) / 1200), period_s)
            sw = 0.75 + 0.25 * np.tanh(circ_lfo(n, swell_hz * 3, rng))
            y = np.zeros(n)
            for k in range(1, harmonics + 1):
                y += (1 / k ** 1.8) * np.sin(TAU * quantise(fq * k, period_s) * t + rng.uniform(0, TAU))
            out[ch] += y * sw
    return out / len(freqs)


# ---------------------------------------------------------------------------
# Chant download, decoding and analysis (for the two remixes)
# ---------------------------------------------------------------------------


def http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def fetch_commons(title: str, dest: Path, expect_licence: str) -> Path:
    """Download a Commons original via the API (prop=imageinfo&iiprop=url), verifying the licence."""
    dest.mkdir(parents=True, exist_ok=True)
    out = dest / title.split(":", 1)[1].replace(" ", "_")
    if out.exists() and out.stat().st_size > 10000:
        return out
    q = urllib.parse.urlencode({"action": "query", "format": "json", "prop": "imageinfo",
                                "iiprop": "url|extmetadata", "titles": title})
    info = json.loads(http_get(f"{COMMONS_API}?{q}"))
    page = next(iter(info["query"]["pages"].values()))
    ii = page["imageinfo"][0]
    lic = ii["extmetadata"]["LicenseShortName"]["value"]
    if lic != expect_licence:
        raise SystemExit(f"{title}: licence is {lic!r}, expected {expect_licence!r}")
    url = ii["url"]
    if urllib.parse.urlparse(url).hostname != "upload.wikimedia.org":
        raise SystemExit(f"unexpected host for {title}: {url}")
    out.write_bytes(http_get(url))
    return out


def decode(path: Path) -> np.ndarray:
    """Decode any audio file to float stereo 44.1 kHz with ffmpeg."""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).T.astype(float)


def yin_f0(mono: np.ndarray, fmin: float = 60, fmax: float = 400, win: int = 3072, hop: int = 512,
           thresh: float = 0.2) -> np.ndarray:
    """Frame-wise f0 by the YIN cumulative-mean-normalised difference (autocorrelation based);
    returns only confidently voiced frames."""
    f0s = []
    lo, hi = int(SR / fmax), int(SR / fmin)
    floor = 0.1 * np.sqrt(np.mean(mono ** 2))
    for i in range(0, len(mono) - win, hop):
        fr = mono[i:i + win]
        if np.sqrt(np.mean(fr ** 2)) < floor:
            continue
        r = np.fft.irfft(np.abs(np.fft.rfft(fr, 2 * win)) ** 2)[: win // 2]
        e = np.cumsum(fr[::-1] ** 2)[::-1]
        tau = np.arange(1, win // 2)
        d = r[0] + e[tau] - 2 * r[tau]
        cm = d * tau / np.maximum(np.cumsum(d), 1e-12)
        seg = cm[lo:hi]
        cand = np.where(seg < thresh)[0]
        if len(cand) == 0:
            continue
        j = cand[0]
        while j + 1 < len(seg) and seg[j + 1] < seg[j]:
            j += 1
        if 0 < j < len(seg) - 1:  # parabolic refinement
            a, b, c = seg[j - 1], seg[j], seg[j + 1]
            j = j + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
        f0s.append(SR / (lo + j + 1))  # seg[j] is lag lo + j + 1
    return np.array(f0s)


def detect_tonic(mono: np.ndarray) -> dict:
    """Tonic = median voiced f0 (YIN). If the recording carries a sustained drone (a very narrow,
    prominent low spectral line, e.g. a shruti box or tanpura Sa), its pitch class wins, placed in
    the octave nearest the voice median, because the singers' median can sit on Re or Ga."""
    f0 = yin_f0(mono)
    median = float(np.median(f0))
    n = 65536
    win = np.hanning(n)
    P = np.mean([np.abs(np.fft.rfft(mono[i:i + n] * win)) ** 2 for i in range(0, len(mono) - n, 8192)], axis=0)
    f = np.fft.rfftfreq(n, 1 / SR)
    m = (f > 55) & (f < 700)
    ldb = 10 * np.log10(P[m] + 1e-12)
    pk, props = signal.find_peaks(ldb, prominence=8)
    widths = signal.peak_widths(ldb, pk, rel_height=0.5)[0] * SR / n
    drone = None
    for i in np.argsort(ldb[pk])[::-1][:8]:
        if widths[i] < 2.5:  # a held instrument line, not a wobbling voice
            drone = float(f[m][pk[i]])
            break
    tonic = median
    if drone is not None:
        k = np.round(np.log2(median / drone))
        tonic = drone * 2 ** k
    return {"median_f0": median, "drone_line": drone, "tonic": float(tonic), "voiced_frames": int(len(f0))}


def onset_envelope(mono: np.ndarray, hop: int = 441) -> np.ndarray:
    n = 2048
    frames = np.lib.stride_tricks.sliding_window_view(mono, n)[::hop]
    mag = np.log1p(100 * np.abs(np.fft.rfft(frames * np.hanning(n), axis=1)))
    flux = np.maximum(np.diff(mag, axis=0), 0).sum(axis=1)
    flux = np.concatenate([[0], flux])
    return (flux - flux.mean()) / (flux.std() + 1e-9)


def track_beats(mono: np.ndarray, lo: float = 0.42, hi: float = 0.62) -> tuple[np.ndarray, float]:
    """Dynamic-programming beat tracker (Ellis 2007): returns beat times and the global period."""
    hop = 441
    fps = SR / hop
    env = onset_envelope(mono, hop)
    ac = np.correlate(env, env, "full")[len(env) - 1:]
    lags = np.arange(len(ac)) / fps
    m = (lags > lo) & (lags < hi)
    period = float(lags[m][np.argmax(ac[m])])
    p = period * fps
    score = env.copy()
    back = np.full(len(env), -1)
    for t in range(len(env)):
        a, b = int(t - 2 * p), int(t - p / 2)
        if b <= 0:
            continue
        prev = np.arange(max(0, a), b)
        cost = score[prev] - 120 * np.log((t - prev) / p) ** 2
        j = np.argmax(cost)
        score[t] = env[t] + cost[j]
        back[t] = prev[j]
    t = int(np.argmax(score[-int(p):])) + len(env) - int(p)
    beats = []
    while t >= 0:
        beats.append(t)
        t = back[t]
    return np.array(beats[::-1]) / fps, period


def envelope_follow(mono: np.ndarray, attack: float = 0.02, release: float = 0.3) -> np.ndarray:
    """Attack/release RMS envelope, run at a ~1 kHz control rate and interpolated back."""
    rms = np.sqrt(np.maximum(uniform_filter1d(mono ** 2, int(0.03 * SR)), 0.0))
    step = 44
    r = rms[::step]
    o = np.empty_like(r)
    v = 0.0
    aa, ar = np.exp(-step / (attack * SR)), np.exp(-step / (release * SR))
    for i, x in enumerate(r):
        c = aa if x > v else ar
        v = c * v + (1 - c) * x
        o[i] = v
    return np.interp(np.arange(len(rms)), np.arange(len(r)) * step, o)


# ---------------------------------------------------------------------------
# Composition helpers
# ---------------------------------------------------------------------------


def swing_pos(beat: float, amount: float) -> float:
    """Map a straight position (in beats) to a swung one: offbeat 8ths are delayed by `amount` beats."""
    b, p = divmod(beat, 1.0)
    if p < 0.5:
        p = p * (0.5 + amount) / 0.5
    else:
        p = 0.5 + amount + (p - 0.5) * (0.5 - amount) / 0.5
    return b + p


def melody_events(lines: list[str], sa: float, spb: float, swing: float = 0.0, offset: float = 0.0):
    """Parsed sargam lines -> [(start_s, dur_s, hz, flags, token)] (lines follow each other)."""
    out, base = [], 0.0
    for line in lines:
        ev = parse_line(line)
        for b, d, sw, fl in ev:
            st = swing_pos(base + b, swing) if swing else base + b
            out.append((offset + st * spb, d * spb, swara_hz(sa, sw), fl, sw))
        base += sum(float(tok.split("/")[1].rstrip("ksv")) for tok in line.split() if tok != "|")
    return out


# ---------------------------------------------------------------------------
# Ringtones
# ---------------------------------------------------------------------------


def tone_lofi_krishna_flute(rng, ctx):
    bpm, bars = 75, 8
    spb = 60 / bpm
    loop = Loop(bars * 4 * spb)
    sa = note_hz("D5")
    swing = 0.08
    lines = ["G/.5 P/.5 D/1 S'/1.5s D/.5", "P/1 G/.5 R/.5 G/2v",
             "P/.5 D/.5 S'/.5 R'/.5 G'/1.5s R'/.5", "S'/1 D/1 P/2v",
             "G/.5 P/.5 D/1 S'/1.5s R'/.5", "S'/1 D/.5 P/.5 G/2v",
             "R/.5 G/.5 P/1 G/.5 R/.5 S/3v -/1 S/.5 R/.5"]
    ev = melody_events(lines, sa, spb, swing)
    fl = flute_line([(t, d, f, fl) for t, d, f, fl, _ in ev], loop.n + SR, rng, breath=0.09)
    loop.add("lead", fl, 0.0, 0.5)
    # pad over a D pedal: Dadd9 | Bm7 | D6/9 | A-E-B-F# (quartal), two bars each
    d3 = note_hz("D3")
    chords = [[0, 7, 14, 16], [-3, 4, 7, 12], [0, 4, 9, 14], [-5, 2, 9, 16]]
    for i, ch in enumerate(chords):
        y = pad_chord([d3 * 2 ** (s / 12) for s in ch], 8 * spb, rng, cutoff=1100, attack=0.5, release=1.0)
        loop.add("pad", y, i * 8 * spb, 0.5)
    # bass: tonic only (D2), with octave pops
    d2 = note_hz("D2")
    for bar in range(bars):
        for b, d, mult in ((0, 1.4, 1), (1.5, 0.45, 1), (2.5, 1.2, 1), (3.5, 0.4, 2 if bar % 2 else 1)):
            loop.add("bass", soft_bass(d2 * mult, d * spb), (bar * 4 + swing_pos(b, swing)) * spb, 0.36)
    # drums: boom-bap, swung
    k = kick(f_hi=120, f_lo=48, decay=0.25, click=0.12, rng=rng)
    sn = filt(snare(rng, tone=190, decay=0.11, noise=0.6, lp=5500), butter("lowpass", 6000))
    kicks = []
    for bar in range(bars):
        for b in (0, 1.75 if bar % 2 else 1.5, 2.5):
            tt = (bar * 4 + swing_pos(b, swing)) * spb
            loop.add("drums", k, tt, 0.9)
            kicks.append(tt)
        for b in (1, 3):
            loop.add("drums", sn, (bar * 4 + b) * spb, 0.42)
            loop.add("drums", rim(rng), (bar * 4 + b) * spb + 0.004, 0.18)
        for e in range(8):
            v = 0.17 if e % 2 == 0 else 0.1
            loop.add("drums", hat(rng, 0.03), (bar * 4 + swing_pos(e / 2, swing)) * spb, v * rng.uniform(0.8, 1.1), 0.25)
        if bar % 4 == 3:
            loop.add("drums", rim(rng), (bar * 4 + swing_pos(3.5, swing)) * spb, 0.12, -0.2)
    # vinyl crackle + faint hiss (periodic)
    crack = np.zeros(loop.n)
    for _ in range(int(7 * loop.n / SR)):
        crack[rng.integers(loop.n)] += rng.choice([1, -1]) * rng.lognormal(-3.2, 0.7)
    crack = filt(crack, butter("bandpass", [900, 5000]), True)
    hiss = circ_spectrum_noise(loop.n, rng, bandmag(500, 5000)) * 0.0025
    loop.add("fx", np.vstack([crack + hiss, np.roll(crack, 4410) + hiss]) * 3.0, 0.0)
    # mix: sidechain pad/bass to kick, reverb + dotted-8th echo on the flute
    duck = np.ones(loop.n)
    tt = tsec(int(0.35 * SR))
    shape = 1 - 0.45 * np.exp(-tt / 0.12) * np.minimum(1, tt / 0.005 + 0.2)
    for kt in kicks:
        i = int(kt * SR)
        idx = (i + np.arange(len(shape))) % loop.n
        duck[idx] = np.minimum(duck[idx], shape)
    lead = loop.bus("lead")
    ir = reverb_ir(1.9, seed=11)
    wet = convolve(loop, lead * 0.5 + loop.bus("pad") * 0.25 + loop.bus("drums") * 0.08, ir)
    ech = echo(loop, lead, 0.75 * spb, 1.5 * spb, feedback=0.3, repeats=3, lp=3000)
    mix = (lead + 0.13 * ech + (loop.bus("pad") * 0.8 + loop.bus("bass")) * duck + loop.bus("drums")
           + loop.bus("fx") + 0.22 * wet)
    mix = filt(mix, butter("lowpass", 10500), True)
    return mix, {}


def tone_veena_dhun(rng, ctx):
    bpm, bars = 104, 12
    spb = 60 / bpm
    loop = Loop(bars * 4 * spb)
    sa = note_hz("C4")
    lines = ["S/.5 R/.5 G/1k P/.5 N/.5 S'/1s", "N/.5 P/.5 G/1 R/.5 G/.5 P/1",
             "N/.5 S'/.5 R'/1 S'/.5 N/.5 P/1", "G/.75 R/.25 S/2s .P/.5 .N/.5"]
    lines = lines + lines[:3] + ["P/.5 N/.5 S'/1k G'/.5 R'/.5 S'/1"]
    lines += ["S'/.5 N/.5 S'/.5 R'/.5 G'/1k R'/.5 S'/.5", "N/1k P/.5 N/.5 S'/1s P/1",
              "G/.5 P/.5 N/.5 P/.5 G/1k R/.5 G/.5", "R/.5 S/.5 .N/.5 S/1.5 .P/.5 .N/.5"]
    ev = melody_events(lines, sa, spb)
    body = np.vstack([peq(240, 4, 1.0), peq(1100, 3, 1.5), peq(3200, -2, 1.0), butter("lowpass", 7500)])
    for i, (t0, dur, hz, flags, tok) in enumerate(ev):
        ring = max(dur + 0.9, 1.6)
        n = int(ring * SR)
        bend = None
        if "k" in flags:
            bend = kampita(n, dur, gamaka_depth(tok, [0, 2, 4, 7, 11]))
        elif "s" in flags:
            bend = slide_in(n, -2 if tok.strip("'.") != "S" else -1, 0.12)
        y = ks_string(hz, ring, rng, tau=1.3, a=0.1, pick=0.11, jawari=0.25, jaw_th=0.45, bend=bend, soft=0.2)
        y = signal.sosfilt(body, y)
        loop.add("lead", y, t0, 0.8, -0.1)
    # tanpura drone: one Pa-Sa-Sa-Sa cycle every 2 bars
    tanpura_cycle(loop, "drone", note_hz("C3"), rng, cycle=8 * spb, count=bars // 2, gain=0.36, ring=6.5)
    # tabla groove: 16th grid, dayan tuned to C4
    patterns = [
        ["dha", None, "ge", "na", "tin", None, "na", "ke", "dha", None, "dha", "ge", "na", None, "tin", "na"],
        ["dha", None, "ge", "na", "tin", "na", "ke", "na", "dha", None, "ge", "dha", "tin", None, "na", "ke"],
    ]
    accents = [1.0, 0.4, 0.6, 0.7, 0.85, 0.45, 0.7, 0.5, 0.95, 0.4, 0.7, 0.65, 0.8, 0.45, 0.75, 0.6]
    cache = {}
    for bar in range(bars):
        pat = patterns[1 if bar % 4 == 3 else 0]
        for i, st in enumerate(pat):
            if st is None:
                continue
            key = (st, rng.integers(3))
            if key not in cache:
                cache[key] = tabla(st, sa, rng)
            tt = (bar * 4 + i / 4) * spb + rng.normal(0, 0.003)
            loop.add("perc", cache[key], max(tt, 0), 0.26 * accents[i] * rng.uniform(0.9, 1.05), 0.12)
    for bar in range(bars):  # soft modern kick + shaker underneath
        for b in (0, 2.5):
            loop.add("perc2", kick(f_hi=110, f_lo=52, decay=0.22, click=0.0), (bar * 4 + b) * spb, 0.45)
        for e in range(8):
            loop.add("perc2", shaker(rng), (bar * 4 + e / 2) * spb, 0.08 if e % 2 else 0.05, 0.4)
    ir = reverb_ir(1.7, seed=21)
    wet = convolve(loop, loop.bus("lead") * 0.6 + loop.bus("perc") * 0.15 + loop.bus("drone") * 0.3, ir)
    mix = loop.bus("lead") + loop.bus("drone") + loop.bus("perc") + loop.bus("perc2") + 0.22 * wet
    return mix, {}


def tone_temple_bells_pop(rng, ctx):
    bpm, bars = 108, 12
    spb = 60 / bpm
    loop = Loop(bars * 4 * spb)
    sa = note_hz("F5")
    hook = ["G/.5 P/.5 D/1 P/.5 G/.5 S/1", "R/.5 G/1 R/.5 S/1 .D/1", "G/.5 P/.5 D/1 P/.5 G/.5 S/1",
            "R/.5 G/.5 P/1 G/.5 R/.5 S/1"]
    lines = hook + hook + ["P/.5 D/.5 S'/1 D/.5 P/.5 G/1", "P/.5 G/.5 R/1 S/1 R/1",
                           "G/.5 P/.5 D/1 S'/.5 D/.5 P/1", "G/.5 R/.5 S/2 -/1"]
    for t0, dur, hz, _, _ in melody_events(lines, sa, spb):
        y = fm_bell(hz, max(1.6, dur + 1.2), ratio=3.5, index=1.6, decay=0.7, beat_hz=1.3, bright_decay=0.15)
        loop.add("bells", y, t0, 0.33, rng.uniform(-0.2, 0.2))
    # big temple bell (F4) at the top of every 4 bars, so the tone opens on a bell strike
    for bar in range(0, bars, 4):
        loop.add("bigbell", temple_bell(note_hz("F4"), 5.0), bar * 4 * spb, 0.45, -0.15)
    # marimba ostinato, F pentatonic
    f4 = note_hz("F4")
    osti = ["S", "P", "G", "P", "D", "P", "G", "R"]
    for bar in range(bars):
        for e, sw in enumerate(osti):
            loop.add("marimba", marimba(swara_hz(f4, sw), 1.0, 0.9 if e % 2 == 0 else 0.7),
                     (bar * 4 + e / 2) * spb, 0.3, 0.3 if e % 2 else -0.3)
    # pad over F pedal: F6/9 | Dm7 | Csus/F | F6/9 (2 bars each, repeating)
    f3 = note_hz("F3")
    chords = [[0, 4, 9, 14], [-3, 0, 4, 7], [-5, 0, 2, 7], [0, 7, 9, 16]]
    for i in range(bars // 2):
        ch = chords[i % 4]
        loop.add("pad", pad_chord([f3 * 2 ** (s / 12) for s in ch], 8 * spb, rng, cutoff=1800, attack=0.2,
                                  release=0.6), i * 8 * spb, 0.42)
    # bass on the tonic (F2) with octave bounce
    f2 = note_hz("F2")
    kicks = []
    for bar in range(bars):
        for b, mult, d in ((0, 1, 0.9), (0.75, 1, 0.2), (1.5, 2, 0.4), (2, 1, 0.9), (2.75, 1, 0.2), (3.5, 2, 0.4)):
            loop.add("bass", bass808(f2 * mult, d * spb, drive=1.6), (bar * 4 + b) * spb, 0.42)
        for b in (0, 1.5, 2) if bar % 2 else (0, 2, 2.5):
            loop.add("drums", kick(f_hi=160, f_lo=52, decay=0.2, click=0.25, rng=rng), (bar * 4 + b) * spb, 0.85)
            kicks.append((bar * 4 + b) * spb)
        for b in (1, 3):
            loop.add("drums", clap(rng), (bar * 4 + b) * spb, 0.55, rng.uniform(-0.1, 0.1))
        for s in range(16):
            v = 0.13 if s % 4 == 2 else (0.07 if s % 2 else 0.1)
            loop.add("drums", hat(rng, 0.025, open_=(s % 4 == 2 and bar % 2 == 1)), (bar * 4 + s / 4) * spb, v, 0.3)
    duck = np.ones(loop.n)
    tt = tsec(int(0.3 * SR))
    shape = 1 - 0.5 * np.exp(-tt / 0.1)
    for kt in kicks:
        idx = (int(kt * SR) + np.arange(len(shape))) % loop.n
        duck[idx] = np.minimum(duck[idx], shape)
    ir = reverb_ir(2.0, seed=31, hf_damp=0.4)
    wet = convolve(loop, loop.bus("bells") * 0.6 + loop.bus("bigbell") * 0.6 + loop.bus("marimba") * 0.3
                   + loop.bus("drums") * 0.06, ir)
    mix = (loop.bus("bells") + loop.bus("bigbell") + loop.bus("marimba") + (loop.bus("pad") + loop.bus("bass")) * duck
           + loop.bus("drums") + 0.25 * wet)
    return mix, {}


def tone_shankh_drop(rng, ctx):
    bpm = 90
    spb = 60 / bpm
    bars = 9  # 1 bar conch call + an 8-bar drop
    loop = Loop(bars * 4 * spb)
    sa = note_hz("G4")
    loop.add("conch", conch(sa, 2.55, rng, swell=1.0), 0.0, 0.3)
    damru_roll(loop, "damru", 4 * spb - 1.1, 1.1, sa / 2, rng, gain=0.5)
    g1 = note_hz("G1")
    kicks = []
    for bar in range(1, bars):
        b0 = bar * 4
        # 808 on the tonic: long on 1, pushes on the "and" of 2 and on 3.5
        for b, d, gl in ((0, 1.5, 1.5), (1.75, 0.6, 1.0), (2.5, 1.4, 1.0)):
            loop.add("bass", bass808(g1 * (2 if (bar % 2 == 0 and b == 2.5) else 1), d * spb, drive=2.6, glide_from=gl),
                     (b0 + b) * spb, 0.62)
        for b in ((0, 1.75, 2.5) if bar % 2 else (0, 0.75, 2.5, 3.25)):
            loop.add("drums", kick(f_hi=170, f_lo=50, decay=0.18, click=0.3, rng=rng), (b0 + b) * spb, 0.8)
            kicks.append((b0 + b) * spb)
        for b in (1, 3):
            loop.add("drums", snare(rng, tone=200, decay=0.15, noise=0.9), (b0 + b) * spb, 0.42)
            loop.add("drums", clap(rng), (b0 + b) * spb + 0.003, 0.4)
        for s in range(16):  # trap hats with occasional 32nd rolls
            v = 0.12 if s % 2 == 0 else 0.07
            loop.add("drums", hat(rng, 0.02), (b0 + s / 4) * spb, v, 0.35)
            if bar % 2 == 0 and s in (13, 14):
                loop.add("drums", hat(rng, 0.015), (b0 + s / 4 + 0.125) * spb, 0.06, 0.35)
        if bar % 2 == 0:  # damru roll into every other bar line
            damru_roll(loop, "damru", (b0 + 3) * spb, spb, sa / 2, rng, gain=0.33, rate0=12, rate1=24)
        # pentatonic pluck ostinato (G A B D E)
        arp = ["S", "P", "S'", "P", "D", "P", "S'", "R'"] if bar % 2 else ["S", "P", "S'", "P", "G'", "R'", "S'", "D"]
        for e, sw in enumerate(arp):
            y = ks_string(swara_hz(sa, sw), 0.6, rng, tau=0.25, a=0.15, pick=0.2)
            loop.add("arp", y, (b0 + e / 2) * spb, 1.0, 0.35 if e % 2 else -0.35)
    # conch stabs at the start of bars 5 and 9 (phrase markers)
    for bar in (4, 8):
        loop.add("conch", conch(sa, 1.1, rng, swell=0.35), bar * 4 * spb, 0.2, 0.1)
    # open-fifth pad G-D-G under the drop
    for bar in range(1, bars, 2):
        loop.add("pad", pad_chord([note_hz("G3"), note_hz("D4"), note_hz("G4")], 8 * spb, rng, cutoff=1500,
                                  attack=0.3, release=0.5), bar * 4 * spb, 0.3)
    duck = np.ones(loop.n)
    tt = tsec(int(0.3 * SR))
    shape = 1 - 0.55 * np.exp(-tt / 0.1)
    for kt in kicks:
        idx = (int(kt * SR) + np.arange(len(shape))) % loop.n
        duck[idx] = np.minimum(duck[idx], shape)
    ir = reverb_ir(2.4, seed=41)
    wet = convolve(loop, loop.bus("conch") * 0.6 + loop.bus("damru") * 0.3 + loop.bus("arp") * 0.4
                   + loop.bus("drums") * 0.06, ir)
    mix = (loop.bus("conch") + loop.bus("damru") + loop.bus("bass") + loop.bus("drums") + loop.bus("arp") * duck
           + loop.bus("pad") * duck + 0.24 * wet)
    return mix, {}


def tone_notify_bell(rng, ctx):
    loop = Loop(2.0, circular=False)
    f = note_hz("E6")
    loop.add("bell", fm_bell(f, 2.0, ratio=3.5, index=1.8, decay=0.55, beat_hz=2.0, bright_decay=0.12), 0.0, 0.6, -0.1)
    loop.add("bell", fm_bell(f * 1.5, 2.0, ratio=3.5, index=1.2, decay=0.4, beat_hz=3.1, bright_decay=0.1), 0.07, 0.3, 0.25)
    sh = fm_bell(f * 2, 1.9, ratio=1.0, index=0.6, decay=0.35, beat_hz=4.3)  # shimmer
    loop.add("bell", sh, 0.12, 0.12, -0.3)
    ir = reverb_ir(1.4, seed=51, predelay=0.01)
    wet = convolve(loop, loop.bus("bell"), ir)
    mix = loop.bus("bell") + 0.28 * wet
    mix = fades(mix, 0.0, 0.35)
    return mix, {}


def tone_notify_flute(rng, ctx):
    loop = Loop(2.2, circular=False)
    sa = note_hz("D5")
    notes = [(0.02, 0.14, swara_hz(sa, "S"), ""), (0.16, 0.14, swara_hz(sa, "G"), ""),
             (0.30, 0.14, swara_hz(sa, "P"), ""), (0.44, 1.0, swara_hz(sa, "S'"), "sv")]
    fl = flute_line(notes, int(2.2 * SR), rng, breath=0.08, vib_cents=18, glide=0.05)
    loop.add("lead", fl, 0.0, 0.6)
    ir = reverb_ir(1.5, seed=61)
    wet = convolve(loop, loop.bus("lead"), ir)
    mix = loop.bus("lead") + 0.3 * wet
    mix = fades(mix, 0.0, 0.3)
    return mix, {}


def clean_voice(x: np.ndarray, expander_db: float = 8.0) -> np.ndarray:
    """High-pass the rumble and gently expand the gaps (lowers room hiss between phrases)."""
    x = filt(x, butter("highpass", 50, order=4))
    x = filt(x, butter("lowpass", 11000))  # trims some of the recording's hiss
    x = fades(x, 0.02, 0.05)  # the recording starts on the voice: no click at the loop point
    mono = x.mean(axis=0)
    env = 20 * np.log10(envelope_follow(mono, 0.005, 0.12) + 1e-9)
    active = np.percentile(env, 70)
    thr = active - 16
    gain_db = np.clip((env - thr) / 10, -1, 0) * expander_db
    return x * db(gain_db)


def remix_bed_duck(voice: np.ndarray, depth_db: float) -> np.ndarray:
    env = envelope_follow(voice.mean(axis=0), 0.03, 0.35)
    ref = np.percentile(env, 90) + 1e-9
    amt = np.clip(env / ref, 0, 1) ** 0.7
    return db(-depth_db * amt)


def tone_gayatri_lofi(rng, ctx):
    src = fetch_commons("File:Gayatri_mantra.ogg", ctx["chants"], "CC0")
    voice = clean_voice(decode(src))
    info = detect_tonic(voice.mean(axis=0))
    T = info["tonic"]
    bpm, bars = 74, 8
    spb = 60 / bpm
    loop = Loop(bars * 4 * spb)
    swing = 0.07
    # pad: open fifths on the chant's own tonic (Sa-Pa-Sa'), no thirds to clash with the svaras
    for i in range(bars // 2):
        ch = [T * 2, T * 3, T * 4] if i % 2 == 0 else [T * 2, T * 3, T * 4, T * 6]
        loop.add("pad", pad_chord(ch, 16 * spb, rng, cutoff=1000, attack=1.5, release=2.0), i * 16 * spb, 0.55)
    # high, soft shimmer drone two octaves up
    shimmer = drone_pad(loop.n, [T * 8, T * 12], rng, loop.n / SR, harmonics=2)
    loop.add("pad", shimmer, 0.0, 0.06)
    for bar in range(bars):  # bass on Sa (and its octave)
        for b, d in ((0, 2.5), (2.5, 1.3)):
            loop.add("bass", soft_bass(T, d * spb), (bar * 4 + swing_pos(b, swing)) * spb, 0.5)
    k = kick(f_hi=110, f_lo=46, decay=0.22, click=0.08, rng=rng)
    sn = filt(rim(rng), butter("lowpass", 5000))
    for bar in range(bars):
        for b in (0, 2.5) if bar % 2 else (0, 1.75, 2.5):
            loop.add("drums", k, (bar * 4 + swing_pos(b, swing)) * spb, 0.75)
        for b in (1, 3):
            loop.add("drums", snare(rng, tone=180, decay=0.09, noise=0.45, lp=4500), (bar * 4 + b) * spb, 0.3)
            loop.add("drums", sn, (bar * 4 + b) * spb, 0.12)
        for e in range(8):
            loop.add("drums", hat(rng, 0.025), (bar * 4 + swing_pos(e / 2, swing)) * spb,
                     (0.08 if e % 2 == 0 else 0.05) * rng.uniform(0.8, 1.1), 0.3)
    crack = np.zeros(loop.n)
    for _ in range(int(5 * loop.n / SR)):
        crack[rng.integers(loop.n)] += rng.choice([1, -1]) * rng.lognormal(-3.4, 0.6)
    crack = filt(crack, butter("bandpass", [900, 5000]), True)
    loop.add("fx", np.vstack([crack, np.roll(crack, 3000)]), 0.0, 2.5)
    ir = reverb_ir(2.2, seed=71)
    music_wet = convolve(loop, loop.bus("pad") * 0.4 + loop.bus("drums") * 0.08, ir)
    music = loop.bus("pad") + loop.bus("bass") + loop.bus("drums") + loop.bus("fx") + 0.2 * music_wet
    music = filt(music, butter("lowpass", 9000), True)
    # voice: placed at the top, a touch of room, music ducked under it
    vbus = np.zeros((2, loop.n))
    v = voice[:, : loop.n]
    vbus[:, : v.shape[1]] = v
    vwet = convolve(loop, vbus, reverb_ir(1.4, seed=72, predelay=0.02))
    vmix = vbus + 0.12 * vwet
    music *= db(lufs(vmix) - 9 - lufs(music))
    music = music * remix_bed_duck(vbus, 6.0)
    return vmix + music, {"tonic_hz": round(T, 2), "tonic_analysis": info}


def tone_om_namah_shivaya_beat(rng, ctx):
    src = fetch_commons("File:Om_Namah_Shivaya_Performance_at_Khajuraho_-_2026.ogg", ctx["chants"], "CC BY-SA 4.0")
    raw = decode(src)
    # use 0.05 s .. 22.95 s (the whole performance minus its fade-out tail), soft edges
    voice = filt(raw[:, int(0.05 * SR): int(22.95 * SR)], butter("highpass", 40, order=4))
    voice = fades(voice, 0.02, 0.4)
    info = detect_tonic(voice.mean(axis=0))
    T = info["tonic"]
    beats, period = track_beats(voice.mean(axis=0))
    env = onset_envelope(voice.mean(axis=0))
    strength = np.array([env[min(len(env) - 1, int(b * 100))] for b in beats])
    # downbeat phase: the beat-in-4 with the strongest average onsets
    phase = int(np.argmax([strength[p::4].mean() for p in range(4)]))
    beats = beats[phase:]
    first = beats[0]
    # extend the grid past the chant with the median local period, to 48 beats (12 bars)
    per = float(np.median(np.diff(beats)))
    grid = list(beats[:48])
    while len(grid) < 49:
        grid.append(grid[-1] + per)
    grid = np.array(grid)  # absolute chant time; the file starts with the chant, first downbeat at grid[0]
    L = grid[48] - grid[0]
    loop = Loop(L)
    vbus = np.zeros((2, loop.n + voice.shape[1]))
    vbus[:, : voice.shape[1]] += voice
    vbus = loop.fold(vbus)
    # drone on the chant's Sa: sub, Sa, soft Pa, Sa' (tanpura-like additive, periodic over the loop)
    drone = drone_pad(loop.n, [T, T * 2, T * 4], rng, L, harmonics=5)
    drone += 0.35 * drone_pad(loop.n, [T * 3], rng, L, harmonics=3)
    loop.add("drone", drone, 0.0, 0.8)
    boom = kick(f_hi=T * 2.2, f_lo=T, decay=0.7, click=0.15, rng=rng, drive=1.8)
    for i in range(48):
        tt = grid[i]
        bar_pos = i % 4
        if bar_pos == 0:
            loop.add("drums", boom, tt, 1.0)
            loop.add("drums", membrane(T * 2, [1, 1.5, 2.0], [1, 0.3, 0.2], [0.35, 0.2, 0.1], 1.2, bend=0.05), tt, 0.3)
        if bar_pos == 2:
            loop.add("drums", snare(rng, tone=150, decay=0.3, noise=0.7, lp=5000), tt, 0.45)
            loop.add("drums", boom, tt + per * 0.5, 0.45)
        if i % 8 == 7:  # damru roll leading into every second bar line
            damru_roll(loop, "damru", tt, grid[i + 1] - tt, T * 2, rng, gain=0.3, rate0=10, rate1=22)
        loop.add("drums", shaker(rng), tt + per * 0.5, 0.05, 0.4)
    ir = reverb_ir(3.0, seed=81, hf_damp=0.5)
    wet = convolve(loop, loop.bus("drums") * 0.35 + loop.bus("damru") * 0.4 + loop.bus("drone") * 0.2, ir)
    music = loop.bus("drone") + loop.bus("drums") + loop.bus("damru") + 0.3 * wet
    music *= db(lufs(vbus) - 8 - lufs(music))
    music = music * remix_bed_duck(vbus, 4.0)
    meta = {"tonic_hz": round(T, 2), "tonic_analysis": info, "chant_beat_period_s": round(per, 4),
            "chant_excerpt_s": [0.05, 22.95]}
    return vbus + music, meta


# ---------------------------------------------------------------------------
# Meditation soundscapes (120 s seamless loops)
# ---------------------------------------------------------------------------

MED_S = 120.0


def even_times(rng, total: float, lo: float, hi: float, start: float = 0.0) -> list[float]:
    """Random gaps in [lo, hi], rescaled so they tile the loop exactly."""
    gaps = []
    while sum(gaps) < total - (lo + hi) / 2:
        gaps.append(rng.uniform(lo, hi))
    gaps = np.array(gaps) * total / sum(gaps)
    return list(start + np.concatenate([[0], np.cumsum(gaps)[:-1]]))


def med_om_deep(rng, ctx):
    loop = Loop(MED_S)
    f0 = 136.1
    om = voice_drone(loop.n, f0, rng, OM_KEYS, 8.0, MED_S, jitter_cents=4)
    om2 = voice_drone(loop.n, f0 * 2 ** (3 / 1200), rng, OM_KEYS, 8.0, MED_S, jitter_cents=5, phase_shift=0.03)
    loop.add("om", np.vstack([om + 0.6 * om2, 0.6 * om + om2]), 0.0, 1.0)
    choir = np.zeros((2, loop.n))
    for mult, g in ((1.0, 0.5), (1.5, 0.35), (2.0, 0.3), (0.5, 0.4)):
        for ch in range(2):
            v = voice_drone(loop.n, f0 * mult * 2 ** (rng.uniform(-6, 6) / 1200), rng,
                            [(0.0, "O", 0.8), (0.5, "U", 1.0)], 30.0, MED_S, jitter_cents=6,
                            max_hz=2500, phase_shift=rng.uniform())
            choir[ch] += g * v
    loop.add("choir", choir, 0.0, 0.35)
    ir = reverb_ir(4.5, seed=101, hf_damp=0.6, seconds=5.5)
    wet = convolve(loop, loop.bus("om") * 0.5 + loop.bus("choir"), ir)
    return loop.bus("om") + 0.5 * loop.bus("choir") + 0.35 * wet, {"tonic_hz": f0}


def med_tanpura(rng, ctx):
    loop = Loop(MED_S)
    sa = note_hz("C#3")
    tanpura_cycle(loop, "tan", sa, rng, cycle=5.0, count=24, gain=1.0, variants=4, ring=8.0)
    ir = reverb_ir(2.8, seed=111, hf_damp=0.6)
    wet = convolve(loop, loop.bus("tan"), ir)
    return loop.bus("tan") + 0.22 * wet, {"tonic_hz": round(sa, 2)}


def rain_bed(loop: Loop, rng, level: float = 1.0) -> np.ndarray:
    n = loop.n
    bed = circ_spectrum_noise(n, rng, lambda f: bandmag(300, 5000, 3)(f) * (np.maximum(f, 50) / 1000) ** -0.6, 2)
    swell = db(2.0 * np.tanh(circ_lfo(n, 0.05, rng)))
    bed *= swell * 0.35
    drops = np.zeros((2, n))
    count = int(MED_S * 30)
    for _ in range(count):
        dur = rng.uniform(0.006, 0.022)
        m = int(dur * SR)
        t = tsec(m)
        f0 = rng.uniform(1600, 4800)
        f = f0 * (1 + 0.6 * t / dur)
        y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t / (dur * 0.3))
        y *= rng.lognormal(-1.6, 0.6)
        pos = rng.integers(n)
        p = rng.uniform(-0.9, 0.9)
        st = pan2(fades(y, 0.0005, 0.002), p)
        idx = (pos + np.arange(m)) % n
        drops[:, idx] += st
    drops = filt(drops, butter("lowpass", 5500), True)
    return level * (bed + 0.18 * drops)


def med_rain_bells(rng, ctx):
    loop = Loop(MED_S)
    loop.add("rain", rain_bed(loop, rng), 0.0, 1.0)
    bell_f = note_hz("D4")
    for tt in even_times(rng, MED_S, 12, 20, start=2.0):
        y = temple_bell(bell_f * rng.choice([1.0, 1.0, 1.5]), 9.0)
        y = filt(y, butter("lowpass", 4500))  # distant
        loop.add("bell", y, tt, 0.5 * rng.uniform(0.8, 1.0), rng.uniform(-0.4, 0.4))
    ir = reverb_ir(3.5, seed=121, hf_damp=0.7)
    wet = convolve(loop, loop.bus("bell") + loop.bus("rain") * 0.1, ir)
    return loop.bus("rain") * 0.55 + loop.bus("bell") * 0.5 + 0.45 * wet, {}


def stream_bed(loop: Loop, rng) -> np.ndarray:
    n = loop.n
    out = np.zeros((2, n))
    for lo, hi, rate, g in ((150, 700, 3.0, 0.5), (600, 2200, 5.0, 0.45), (1800, 5500, 7.0, 0.25)):
        for ch in range(2):
            nz = circ_spectrum_noise(n, rng, bandmag(lo, hi))
            mod = 1 + 0.6 * np.tanh(circ_lfo(n, rate, rng))
            out[ch] += g * nz * mod
    bub = np.zeros((2, n))
    for _ in range(int(MED_S * 35)):
        dur = rng.uniform(0.01, 0.04)
        m = int(dur * SR)
        t = tsec(m)
        f0 = rng.uniform(350, 1400)
        y = np.sin(TAU * np.cumsum(f0 * (1 + 0.9 * t / dur)) / SR) * np.exp(-t / (dur * 0.35))
        idx = (rng.integers(n) + np.arange(m)) % n
        bub[:, idx] += pan2(fades(y, 0.001, 0.003) * rng.lognormal(-1.8, 0.5), rng.uniform(-0.7, 0.7))
    return 0.3 * out + 0.25 * bub


def med_river_flute(rng, ctx):
    loop = Loop(MED_S)
    loop.add("water", stream_bed(loop, rng), 0.0, 1.0)
    sa = note_hz("D4")
    phrases = [[(".D", 0.9), ("S", 3.2)], [("S", 0.7), ("R", 0.7), ("G", 3.4)],
               [("G", 0.6), ("R", 0.6), ("S", 0.7), (".D", 1.1), ("S", 3.0)],
               [("G", 0.7), ("P", 0.9), ("G", 0.6), ("R", 0.7), ("G", 3.0)],
               [("P", 0.7), ("D", 0.7), ("S'", 3.6)], [("D", 0.6), ("S'", 0.9), ("D", 0.6), ("P", 0.9), ("G", 2.8)],
               [("G", 0.6), ("R", 0.6), ("S", 0.9), (".D", 0.9), (".P", 0.9), (".D", 0.7), ("S", 3.5)]]
    t = 1.5
    notes = []
    order = [0, 1, 2, 3, 4, 5, 6, 2, 1, 0]
    for k in order:
        for sw, d in phrases[k]:
            notes.append((t, d, swara_hz(sa, sw), "s" if d > 2.5 and rng.random() < 0.5 else ""))
            t += d
        t += rng.uniform(4.0, 7.0)
    scale = (MED_S - 2.0) / t  # fit the phrases into the loop
    notes = [(a * scale, d, f, fl) for a, d, f, fl in notes]
    fl = flute_line(notes, loop.n + 4 * SR, rng, breath=0.1, vib_cents=14, glide=0.12, bright=0.8)
    loop.add("flute", fl, 0.0, 0.5, 0.05)
    loop.add("drone", drone_pad(loop.n, [sa / 2, sa * 0.75], rng, MED_S, harmonics=4), 0.0, 0.12)
    ir = reverb_ir(3.2, seed=131, hf_damp=0.6)
    wet = convolve(loop, loop.bus("flute") + loop.bus("drone") * 0.5, ir)
    return loop.bus("water") * 0.6 + loop.bus("flute") + loop.bus("drone") + 0.32 * wet, {"tonic_hz": round(sa, 2)}


def wind_bed(loop: Loop, rng) -> np.ndarray:
    n = loop.n
    gust = np.tanh(circ_lfo(n, 0.06, rng) * 0.9)
    out = np.zeros((2, n))
    for ch in range(2):
        base = circ_spectrum_noise(n, rng, bandmag(120, 1400))
        air = circ_spectrum_noise(n, rng, bandmag(1500, 5000))
        g2 = np.roll(gust, int(rng.uniform(0.3, 1.0) * SR))
        out[ch] = base * db(6 * g2) * 0.5 + air * db(9 * g2 - 6) * 0.07
        # moaning whistles: narrow bands that take turns as the gust rises
        for i, fc in enumerate((420, 520, 640, 780)):
            nb = circ_spectrum_noise(n, rng, lambda f, fc=fc: 1 / (1 + ((f - fc) / (fc / 40)) ** 2))
            w = np.exp(-((g2 - (-0.6 + 0.45 * i)) / 0.3) ** 2)
            out[ch] += 0.05 * nb * w
    return out


def singing_bowl(freq: float, dur: float, rng, rub: bool = False) -> np.ndarray:
    """Bowl: inharmonic partials, each a beating doublet, very long decays (struck or rubbed)."""
    n = int(dur * SR)
    t = tsec(n)
    ratios = [1.0, 2.71, 5.12, 8.21, 11.9]
    amps = [1.0, 0.55, 0.3, 0.14, 0.06]
    decs = [dur * 0.45, dur * 0.22, dur * 0.1, dur * 0.05, dur * 0.025]
    y = np.zeros(n)
    for r, a, d in zip(ratios, amps, decs):
        f = freq * r
        beat = rng.uniform(0.4, 1.5) * r ** 0.5
        y += a * (np.sin(TAU * f * t + rng.uniform(0, TAU)) + 0.8 * np.sin(TAU * (f + beat) * t)) * np.exp(-t / d)
    if rub:
        env = np.clip(t / (dur * 0.25), 0, 1) ** 2 * np.exp(-np.maximum(t - dur * 0.35, 0) / (dur * 0.25))
        y *= env
    else:
        m = int(0.03 * SR)
        y[:m] += 0.3 * filt(rng.standard_normal(m), butter("lowpass", 900)) * np.exp(-tsec(m) / 0.006)
    return fades(y / 3, 0.004 if not rub else 0.3, 1.0)


def med_himalaya_om(rng, ctx):
    loop = Loop(MED_S)
    loop.add("wind", wind_bed(loop, rng), 0.0, 1.0)
    f0 = 136.1 / 2
    om = voice_drone(loop.n, f0, rng, OM_KEYS, 12.0, MED_S, jitter_cents=4, max_hz=3000)
    om2 = voice_drone(loop.n, f0 * 2, rng, OM_KEYS, 12.0, MED_S, jitter_cents=5, max_hz=3000, phase_shift=0.04)
    loop.add("om", np.vstack([om + 0.45 * om2, 0.8 * om + 0.55 * om2]), 0.0, 1.0)
    for tt in even_times(rng, MED_S, 24, 36, start=6.0):
        loop.add("bowl", singing_bowl(272.2, 22.0, rng), tt, 0.5, rng.uniform(-0.3, 0.3))
    ir = reverb_ir(4.0, seed=141, hf_damp=0.6, seconds=5.0)
    wet = convolve(loop, loop.bus("om") * 0.6 + loop.bus("bowl"), ir)
    return loop.bus("wind") * 0.35 + loop.bus("om") * 0.8 + loop.bus("bowl") * 0.6 + 0.4 * wet, {"tonic_hz": f0 * 2}


def med_singing_bowls(rng, ctx):
    loop = Loop(MED_S)
    base = 136.1
    bowls = [base * 2, base * 3, base * 4, base * 1.5, base * 2 * 2 ** (2 / 12)]  # Sa', Pa', Sa'', Pa, Re'
    for tt in even_times(rng, MED_S, 6.5, 11.0):
        f = bowls[rng.integers(len(bowls))]
        loop.add("bowls", singing_bowl(f, 30.0, rng), tt, 0.5 * rng.uniform(0.7, 1.0), rng.uniform(-0.6, 0.6))
    for tt in even_times(rng, MED_S, 28, 34, start=10.0):  # a rubbed, 'singing' bowl now and then
        loop.add("bowls", singing_bowl(base * 2, 26.0, rng, rub=True), tt, 0.35, rng.uniform(-0.2, 0.2))
    ir = reverb_ir(4.0, seed=151, hf_damp=0.5, seconds=5.0)
    wet = convolve(loop, loop.bus("bowls"), ir)
    return loop.bus("bowls") + 0.3 * wet, {"tonic_hz": base}


def ocean_bed(loop: Loop, rng) -> np.ndarray:
    n = loop.n
    times = even_times(rng, MED_S, 9.0, 11.5)
    wave_env = np.zeros(n)
    foam_env = np.zeros(n)
    for tt in times:
        m = int(14 * SR)
        t = tsec(m)
        rise = 1 / (1 + np.exp(-(t - 4.5) / 0.9))
        fall = np.exp(-np.maximum(t - 5.2, 0) / 2.8)
        e = rise * fall * rng.uniform(0.75, 1.0)
        fo = np.exp(-((t - 5.6) / 1.1) ** 2) + 0.5 * np.exp(-np.maximum(t - 5.6, 0) / 3.0) * (t > 5.6)
        idx = (int(tt * SR) + np.arange(m)) % n
        wave_env[idx] += e
        foam_env[idx] += fo * rng.uniform(0.7, 1.0)
    out = np.zeros((2, n))
    for ch in range(2):
        low = circ_spectrum_noise(n, rng, lambda f: bandmag(60, 900)(f) * (np.maximum(f, 30) / 100) ** -0.5)
        mid = circ_spectrum_noise(n, rng, bandmag(500, 3000))
        hiss = circ_spectrum_noise(n, rng, bandmag(2500, 8000))
        sh = np.roll(wave_env, int(ch * 0.15 * SR))
        fs = np.roll(foam_env, int(ch * 0.2 * SR))
        out[ch] = 0.55 * low * (0.25 + sh) + 0.25 * mid * (0.1 + 0.8 * fs) + 0.06 * hiss * fs
    return out


def med_ocean_om(rng, ctx):
    loop = Loop(MED_S)
    loop.add("sea", ocean_bed(loop, rng), 0.0, 1.0)
    f0 = 136.1
    om = voice_drone(loop.n, f0, rng, OM_KEYS, 10.0, MED_S, jitter_cents=4, max_hz=3500)
    om2 = voice_drone(loop.n, f0 / 2, rng, OM_KEYS, 10.0, MED_S, jitter_cents=4, max_hz=2500, phase_shift=0.02)
    loop.add("om", np.vstack([om + 0.5 * om2, 0.85 * om + 0.6 * om2]), 0.0, 1.0)
    ir = reverb_ir(4.0, seed=161, hf_damp=0.6, seconds=5.0)
    wet = convolve(loop, loop.bus("om"), ir)
    return loop.bus("sea") * 0.6 + loop.bus("om") * 0.45 + 0.25 * wet, {"tonic_hz": f0}


def med_veena_alap(rng, ctx):
    loop = Loop(MED_S)
    sa = note_hz("D3")
    tanpura_cycle(loop, "tan", sa, rng, cycle=6.0, count=20, gain=0.45, variants=3, ring=8.0)
    # alap phrases in Mohanam: (time offset, pluck swara, [(time, target swara)] meends)
    phrases = [
        [(0.0, "S", []), (2.4, "R", [(0.7, "G")]), (5.0, "G", []), (7.6, "R", [(0.6, "S")])],
        [(0.0, "G", []), (1.8, "P", [(0.9, "D"), (1.8, "P")]), (4.6, "G", [(0.8, "R")]), (7.0, "S", [])],
        [(0.0, "P", []), (1.6, "D", []), (3.0, "S'", [(1.2, "R'"), (2.0, "S'")]), (6.0, "D", [(0.8, "P")]),
         (8.4, "G", [])],
        [(0.0, "S'", []), (1.8, "D", [(0.8, "P")]), (3.8, "G", [(0.7, "P"), (1.4, "G")]), (6.2, "R", []),
         (7.6, "S", [(0.9, ".D"), (1.8, "S")])],
        [(0.0, ".D", []), (1.4, "S", []), (2.8, "R", [(0.8, "G")]), (5.2, "P", [(1.0, "G")]), (7.8, "S", [])],
    ]
    body = np.vstack([peq(240, 4, 1.0), peq(1100, 3, 1.5), butter("lowpass", 6500)])
    t = 2.0
    for rep in range(2):
        for ph in phrases:
            for off, sw, meends in ph:
                ring = 4.0
                n = int(ring * SR)
                bend = np.zeros(n)
                cur = 0.0
                base = swara_semis(sw)
                for mt, target in meends:  # smooth glides between scale notes
                    k = int(mt * SR)
                    g = int(0.35 * SR)
                    seg = min(g, n - k)
                    if seg <= 0:
                        break
                    goal = swara_semis(target) - base
                    bend[k:k + seg] = cur + (goal - cur) * ramp(seg)
                    bend[k + seg:] = goal
                    cur = goal
                y = ks_string(swara_hz(sa * 2, sw), ring, rng, tau=1.6, a=0.09, pick=0.11, jawari=0.25,
                              jaw_th=0.45, bend=bend, soft=0.3)
                loop.add("veena", signal.sosfilt(body, y), t + off, 0.5 * rng.uniform(0.85, 1.0), -0.1)
            t += max(o for o, _, _ in ph) + rng.uniform(5.0, 8.0)
    ir = reverb_ir(3.0, seed=171, hf_damp=0.55)
    wet = convolve(loop, loop.bus("veena") + loop.bus("tan") * 0.5, ir)
    return loop.bus("veena") + loop.bus("tan") + 0.3 * wet, {"tonic_hz": round(sa * 2, 2)}


def cricket_chirp(rng, carrier: float, pulses: int, pulse_rate: float) -> np.ndarray:
    pl = 1 / pulse_rate
    n = int((pulses * pl + 0.02) * SR)
    t = tsec(n)
    y = np.sin(TAU * carrier * t) + 0.12 * np.sin(TAU * 2 * carrier * t)
    env = np.zeros(n)
    for p in range(pulses):
        i = int(p * pl * SR)
        m = int(pl * 0.6 * SR)
        env[i:i + m] += np.sin(np.linspace(0, np.pi, m)) ** 2
    return y * env


def med_night_crickets(rng, ctx):
    loop = Loop(MED_S)
    crickets = [(4300, 3, 28, 1.6, -0.6, 0.12), (4650, 4, 32, 1.25, 0.5, 0.09), (3900, 3, 25, 2.1, 0.1, 0.06),
                (5000, 2, 30, 0.9, -0.2, 0.04)]
    for carrier, pulses, prate, rate, pan, g in crickets:
        t = rng.uniform(0, 1)
        on = True
        while t < MED_S:
            if rng.random() < 0.02:  # pauses, like real crickets
                on = not on
            if on:
                c = carrier * rng.uniform(0.995, 1.005)
                loop.add("crickets", cricket_chirp(rng, c, pulses, prate), t, g * rng.uniform(0.8, 1.0), pan)
            t += 1 / rate * rng.uniform(0.92, 1.08)
    # distant tree-cricket trill: continuous soft pulsed tone with slow swells
    n = loop.n
    tt = tsec(n)
    trill = np.sin(TAU * quantise(2900, MED_S) * tt) * (0.5 + 0.5 * np.sin(TAU * quantise(42, MED_S) * tt)) ** 2
    trill *= 0.5 + 0.5 * np.tanh(circ_lfo(n, 0.05, rng))
    loop.add("crickets", np.vstack([trill, np.roll(trill, 900)]), 0.0, 0.012)
    sa = note_hz("A2")
    loop.add("drone", drone_pad(n, [sa, sa * 1.5, sa * 2], rng, MED_S, harmonics=5), 0.0, 0.5)
    air = circ_spectrum_noise(n, rng, bandmag(100, 900), 2) * 0.02
    loop.add("air", air, 0.0)
    ir = reverb_ir(2.5, seed=181, hf_damp=0.5)
    cr = filt(loop.bus("crickets"), butter("lowpass", 7000), True)
    wet = convolve(loop, cr * 2.0 + loop.bus("drone") * 0.3, ir)
    return cr * 2.0 + loop.bus("drone") * 0.6 + loop.bus("air") + 0.35 * wet, {"tonic_hz": round(sa * 2, 2)}


def bird_call(rng, kind: str) -> np.ndarray:
    """Synthesised bird calls from frequency/amplitude contours (FM chirps)."""
    parts = []
    if kind == "koel":  # rising "ku-oo", repeated, climbing
        reps = rng.integers(3, 6)
        base = rng.uniform(950, 1150)
        for r in range(reps):
            b = base * (1 + 0.06 * r)
            d1, d2 = 0.12, rng.uniform(0.28, 0.34)
            f = np.concatenate([np.full(int(d1 * SR), b * 0.92),
                                b * (1.0 + 0.35 * ramp(int(d2 * SR)) ** 0.7)])
            a = np.concatenate([ramp(int(d1 * SR)) * 0.6, np.sin(np.linspace(0, np.pi, int(d2 * SR))) ** 0.6])
            parts.append((f, a * (0.6 + 0.1 * r)))
            gap = int(rng.uniform(0.35, 0.5) * SR)
            parts.append((np.full(gap, b), np.zeros(gap)))
    elif kind == "warbler":
        for _ in range(rng.integers(5, 11)):
            d = rng.uniform(0.04, 0.12)
            m = int(d * SR)
            f0, f1 = rng.uniform(2600, 5200), rng.uniform(2400, 5600)
            shape = rng.choice(["sweep", "trill", "arch"])
            u = np.linspace(0, 1, m)
            if shape == "sweep":
                f = f0 + (f1 - f0) * u
            elif shape == "trill":
                f = f0 * (1 + 0.08 * np.sin(TAU * rng.uniform(25, 45) * u * d))
            else:
                f = f0 + (f1 - f0) * np.sin(np.pi * u)
            parts.append((f, np.sin(np.pi * u) ** 1.5 * rng.uniform(0.5, 1.0)))
            gap = int(rng.uniform(0.02, 0.07) * SR)
            parts.append((np.full(gap, f[-1]), np.zeros(gap)))
    elif kind == "bulbul":
        base = rng.uniform(1500, 2300)
        for _ in range(rng.integers(3, 6)):
            d = rng.uniform(0.09, 0.18)
            m = int(d * SR)
            u = np.linspace(0, 1, m)
            step = rng.choice([0.8, 1.0, 1.25, 1.12])
            f = base * step * (1 + rng.uniform(-0.15, 0.2) * u)
            parts.append((f, np.sin(np.pi * u) ** 0.8))
            gap = int(rng.uniform(0.03, 0.08) * SR)
            parts.append((np.full(gap, f[-1]), np.zeros(gap)))
    else:  # dove: soft low coo-coo
        for _ in range(rng.integers(2, 4)):
            d = rng.uniform(0.35, 0.5)
            m = int(d * SR)
            u = np.linspace(0, 1, m)
            f = rng.uniform(480, 560) * (1 + 0.08 * np.sin(np.pi * u))
            parts.append((f, np.sin(np.pi * u) ** 1.2))
            gap = int(rng.uniform(0.2, 0.35) * SR)
            parts.append((np.full(gap, f[-1]), np.zeros(gap)))
    f = np.concatenate([p[0] for p in parts])
    a = np.concatenate([p[1] for p in parts])
    a = uniform_filter1d(a, 64)
    ph = TAU * np.cumsum(f) / SR
    harm = 0.12 if kind in ("koel", "dove") else 0.05
    y = (np.sin(ph) + harm * np.sin(2 * ph)) * a
    return fades(y, 0.002, 0.01)


def med_dawn_birds(rng, ctx):
    loop = Loop(MED_S)
    kinds = [("koel", 0.25, 14, 26), ("warbler", 0.12, 4, 9), ("bulbul", 0.15, 6, 12), ("dove", 0.2, 18, 30)]
    for kind, g, lo, hi in kinds:
        for who in range(2):  # two individuals of each, different distance and side
            dist = rng.uniform(0.4, 1.0)
            pan = rng.uniform(-0.8, 0.8)
            for tt in even_times(rng, MED_S, lo, hi, start=rng.uniform(0, lo)):
                y = bird_call(rng, kind)
                if dist < 0.7:
                    y = filt(y, butter("lowpass", 3000 + 4000 * dist))
                loop.add("birds", y, tt + rng.uniform(-1, 1), g * dist * rng.uniform(0.8, 1.0), pan)
    sa = note_hz("D3")
    loop.add("drone", drone_pad(loop.n, [sa, sa * 1.5, sa * 2], rng, MED_S, harmonics=5), 0.0, 0.5)
    air = circ_spectrum_noise(loop.n, rng, bandmag(150, 2500), 2) * 0.012
    loop.add("air", air, 0.0)
    ir = reverb_ir(2.2, seed=191, hf_damp=0.4)
    wet = convolve(loop, loop.bus("birds") * 1.6 + loop.bus("drone") * 0.3, ir)
    return loop.bus("birds") * 1.6 + loop.bus("drone") * 0.7 + loop.bus("air") + 0.35 * wet, {"tonic_hz": round(sa, 2)}


# ---------------------------------------------------------------------------
# Catalogue
# ---------------------------------------------------------------------------

GAYATRI_CREDIT = {"author": "Wilfredor", "source": "https://commons.wikimedia.org/wiki/File:Gayatri_mantra.ogg",
                  "licence": "CC0"}
OM_CREDIT = {"author": "Sachin Patel 78",
             "source": "https://commons.wikimedia.org/wiki/File:Om_Namah_Shivaya_Performance_at_Khajuraho_-_2026.ogg",
             "licence": "CC BY-SA 4.0"}

TONES = [
    ("lofi-krishna-flute", "ringtone", "krishna", ("Lo-fi Krishna Flute", "లో-ఫై కృష్ణ మురళి", "लो-फ़ाई कृष्ण बाँसुरी"),
     "Breathy bansuri-style flute in raga Mohanam over a swung lo-fi beat, warm pad and vinyl crackle (75 BPM, D).",
     tone_lofi_krishna_flute),
    ("veena-dhun", "ringtone", "saraswati", ("Veena Dhun", "వీణ ధున్", "वीणा धुन"),
     "Plucked veena melody in Hamsadhwani with gamakas, tabla groove and tanpura drone (104 BPM, C).",
     tone_veena_dhun),
    ("temple-bells-pop", "ringtone", "general", ("Temple Bells Pop", "ఆలయ గంటల పాప్", "मंदिर घंटी पॉप"),
     "Temple bells and a marimba ostinato on a bright pop groove with claps on 2 and 4 (108 BPM, F pentatonic).",
     tone_temple_bells_pop),
    ("shankh-drop", "ringtone", "vishnu", ("Shankh Drop", "శంఖ డ్రాప్", "शंख ड्रॉप"),
     "A conch swell, a damru roll, then a beat drop with deep 808 on the tonic (90 BPM, G).",
     tone_shankh_drop),
    ("gayatri-lofi", "ringtone", "surya", ("Gayatri Lo-fi", "గాయత్రీ లో-ఫై", "गायत्री लो-फ़ाई"),
     "The Gayatri mantra chant over a gentle lo-fi beat and a pad tuned to the chanter's own Sa.",
     tone_gayatri_lofi),
    ("om-namah-shivaya-beat", "ringtone", "shiva", ("Om Namah Shivaya Beat", "ఓం నమః శివాయ బీట్", "ॐ नमः शिवाय बीट"),
     "A live Om Namah Shivaya chant over a deep, slow cinematic beat locked to the chant, damru rolls and a drone on its Sa.",
     tone_om_namah_shivaya_beat),
    ("notify-bell-ting", "notification", "general", ("Bell Ting", "గంట టింగ్", "घंटी टिंग"),
     "A short bright bell ting with a little shimmer.", tone_notify_bell),
    ("notify-flute-call", "notification", "general", ("Flute Call", "మురళి పిలుపు", "बाँसुरी पुकार"),
     "A short rising flute phrase (Sa Ga Pa Sa').", tone_notify_flute),
    ("om-deep", "meditation", "general", ("Deep Om", "లోతైన ఓంకారం", "गहरा ॐ"),
     "A warm Om drone at 136.1 Hz, slowly morphing A-U-M every 8 seconds, over a soft choir. Seamless 2-minute loop.",
     med_om_deep),
    ("tanpura-sa", "meditation", "general", ("Tanpura", "తంబూరా", "तानपुरा"),
     "A tanpura cycling Pa-Sa-Sa-Sa with jawari buzz, tuned to C#. Seamless 2-minute loop.", med_tanpura),
    ("rain-temple-bells", "meditation", "general", ("Rain and Temple Bells", "వానలో ఆలయ గంటలు", "बारिश और मंदिर घंटियाँ"),
     "Soft rain with droplets and a distant temple bell every 12-20 seconds. Seamless 2-minute loop.", med_rain_bells),
    ("river-flute", "meditation", "general", ("River Flute", "నది ఒడ్డున మురళి", "नदी किनारे बाँसुरी"),
     "A flowing stream and a slow, sparse flute alap in raga Bhupali. Seamless 2-minute loop.", med_river_flute),
    ("himalaya-om", "meditation", "general", ("Himalayan Wind and Om", "హిమాలయ గాలి, ఓం", "हिमालय की हवा और ॐ"),
     "Soft mountain wind with a low Om and an occasional singing bowl. Seamless 2-minute loop.", med_himalaya_om),
    ("singing-bowls", "meditation", "general", ("Singing Bowls", "సింగింగ్ బౌల్స్", "सिंगिंग बाउल"),
     "Layered singing bowls with long, beating decays at a slow pace. Seamless 2-minute loop.", med_singing_bowls),
    ("ocean-om", "meditation", "general", ("Ocean Om", "సముద్ర ఓంకారం", "सागर ॐ"),
     "Slow ocean waves under a soft Om. Seamless 2-minute loop.", med_ocean_om),
    ("veena-alap", "meditation", "general", ("Veena Alap", "వీణ ఆలాపన", "वीणा आलाप"),
     "A slow veena alap in raga Mohanam with tanpura. Seamless 2-minute loop.", med_veena_alap),
    ("night-diya", "meditation", "general", ("Night Crickets", "రాత్రి కీచురాళ్ళు", "रात के झींगुर"),
     "Gentle night crickets and a soft drone. Seamless 2-minute loop.", med_night_crickets),
    ("dawn-birds", "meditation", "general", ("Dawn Birds", "ఉదయపు పక్షులు", "भोर के पक्षी"),
     "Sparse synthesised dawn birdsong (koel, warbler, bulbul, dove) over a light drone. Seamless 2-minute loop.",
     med_dawn_birds),
]

TARGETS = {"ringtone": (-14.0, -1.0), "notification": (-14.0, -1.0), "meditation": (-20.0, -3.0)}


def build(slug, kind, deity, titles, desc, fn, out_dir: Path, ctx) -> dict:
    seed = zlib.crc32(slug.encode())
    rng = np.random.default_rng(seed)
    mix, extra = fn(rng, ctx)
    target, tp = TARGETS[kind]
    circular = kind != "notification"
    x = master(mix, target, tp, circular)
    wav = out_dir / f"{slug}.wav"
    write_wav(wav, x, seed)
    spectrogram_png(x, out_dir / f"{slug}.png", seam=circular)
    if slug == "gayatri-lofi":
        licence, credit = "CC0", GAYATRI_CREDIT
        desc_full = desc + " Chant: Wilfredor, CC0, Wikimedia Commons."
    elif slug == "om-namah-shivaya-beat":
        licence, credit = "CC BY-SA 4.0", OM_CREDIT
        desc_full = desc + " Chant: Sachin Patel 78, CC BY-SA 4.0, Wikimedia Commons."
    else:
        licence, credit = "CC0", None
        desc_full = desc
    entry = {"slug": slug, "kind": kind, "title": {"en": titles[0], "te": titles[1], "hi": titles[2]},
             "deity": deity, "seconds": round(x.shape[1] / SR, 3), "description": desc_full,
             "licence": licence, "credit": credit, "file": wav.name,
             "loop": circular, "lufs": round(lufs(x), 2), "true_peak_db": round(true_peak_db(x), 2)}
    entry.update({k: v for k, v in extra.items() if k != "tonic_analysis"})
    if "tonic_analysis" in extra:
        entry["tonic_analysis"] = {k: (round(v, 2) if isinstance(v, float) else v)
                                   for k, v in extra["tonic_analysis"].items()}
    print(f"{slug:24s} {entry['seconds']:7.2f}s  {entry['lufs']:6.2f} LUFS  TP {entry['true_peak_db']:6.2f} dBTP"
          + (f"  tonic {extra['tonic_hz']} Hz" if "tonic_hz" in extra else ""), flush=True)
    return entry


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("out_dir", type=Path)
    ap.add_argument("--only", default="", help="comma-separated slugs to (re)build")
    ap.add_argument("--chant-dir", type=Path, default=None)
    args = ap.parse_args()
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    ctx = {"chants": (args.chant_dir or out.parent / "chants").resolve()}
    only = {s for s in args.only.split(",") if s}
    cat_path = out / "synth.json"
    existing = {}
    if only and cat_path.exists():
        existing = {e["slug"]: e for e in json.loads(cat_path.read_text())}
    entries = []
    for slug, kind, deity, titles, desc, fn in TONES:
        if only and slug not in only:
            if slug in existing:
                entries.append(existing[slug])
            continue
        entries.append(build(slug, kind, deity, titles, desc, fn, out, ctx))
    cat_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote {len(entries)} entries to {cat_path}")


if __name__ == "__main__":
    sys.exit(main())
