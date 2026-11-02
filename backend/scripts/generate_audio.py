"""Synthesise Devalay's original sounds (released CC0) into media/seed/ and the app's assets.

Everything is generated from first principles with numpy (additive synthesis,
modal bells, plucked strings), so there are no third-party rights involved.
Requires ffmpeg for AAC encoding.

Usage: python scripts/generate_audio.py
"""

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "media" / "seed"
APP_ASSETS = ROOT.parent / "app" / "assets" / "sounds"
rng = np.random.default_rng(108)


def t(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def bell(freq: float, seconds: float, brightness: float = 1.0) -> np.ndarray:
    """Modal bell: inharmonic partials with individual decays (ratios from measured church/temple bells)."""
    x = t(seconds)
    partials = [(0.5, 1.0, 1.2), (1.0, 0.8, 1.0), (1.183, 0.5, 1.6), (1.506, 0.45, 2.0),
                (2.0, 0.35, 2.4), (2.514, 0.25 * brightness, 3.2), (2.662, 0.2 * brightness, 3.6),
                (3.011, 0.15 * brightness, 4.5), (4.166, 0.08 * brightness, 6.0)]
    out = np.zeros_like(x)
    for ratio, amp, decay in partials:
        beat = 1 + 0.002 * np.sin(2 * np.pi * 0.7 * x)  # slight shimmer
        out += amp * np.sin(2 * np.pi * freq * ratio * x * beat) * np.exp(-decay * x / seconds * 4)
    strike = np.exp(-x * 80) * rng.normal(0, 0.3, len(x))
    return out + strike * 0.2


def pluck(freq: float, seconds: float, damping: float = 0.996) -> np.ndarray:
    """Karplus-Strong plucked string, brightened with a jawari-like buzz for the tanpura."""
    n = int(SR * seconds)
    period = int(SR / freq)
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damping * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return np.tanh(out * 1.6)


def om(seconds: float, base: float = 136.1) -> np.ndarray:
    """Om drone on 136.1 Hz with a slow vowel morph from 'aa' to 'oo' to a hummed 'mm'."""
    x = t(seconds)
    cycle = (x % 8) / 8
    vowel = np.clip(cycle * 3, 0, 3)
    out = np.zeros_like(x)
    for h in range(1, 14):
        open_ = np.exp(-((h - 4) ** 2) / 8)        # 'aa': strong mid harmonics
        round_ = np.exp(-((h - 2) ** 2) / 3)       # 'oo': low harmonics
        hum = 1.0 if h == 1 else 0.15 / h           # 'mm': nearly pure tone
        w = np.where(vowel < 1, open_, np.where(vowel < 2, round_, hum))
        out += w / h * np.sin(2 * np.pi * base * h * x + h)
    breath = 0.5 + 0.5 * np.sin(np.pi * np.clip((x % 8) / 7.6, 0, 1))
    return out * breath


def conch(seconds: float, freq: float = 233.0) -> np.ndarray:
    x = t(seconds)
    env = np.clip(x / 0.8, 0, 1) * np.clip((seconds - x) / 1.2, 0, 1)
    pitch = freq * (1 + 0.02 * np.minimum(x, 1.0) + 0.004 * np.sin(2 * np.pi * 5 * x))
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    tone = sum(np.sin(phase * h) / h ** 1.3 for h in range(1, 10))
    noise = np.convolve(rng.normal(0, 1, len(x)), np.ones(30) / 30, mode="same")
    return (tone + 0.15 * noise) * env


def flute_note(freq: float, seconds: float) -> np.ndarray:
    x = t(seconds)
    env = np.clip(x / 0.08, 0, 1) * np.clip((seconds - x) / 0.25, 0, 1)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * x) * np.clip(x / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    tone = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    breath = np.convolve(rng.normal(0, 1, len(x)), np.ones(12) / 12, mode="same") * 0.06
    return (tone + breath) * env


def drum(seconds: float, freq: float = 110) -> np.ndarray:
    x = t(seconds)
    pitch = freq * (1 + 1.5 * np.exp(-x * 30))
    body = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-x * 9)
    slap = rng.normal(0, 1, len(x)) * np.exp(-x * 60) * 0.3
    return body + slap


def place(track: np.ndarray, clip: np.ndarray, at: float, gain: float = 1.0) -> None:
    i = int(at * SR)
    j = min(len(track), i + len(clip))
    track[i:j] += clip[: j - i] * gain


def reverb(x: np.ndarray, wet: float = 0.25) -> np.ndarray:
    out = x.copy()
    for delay, g in [(0.029, 0.5), (0.037, 0.42), (0.053, 0.35), (0.071, 0.3), (0.113, 0.22), (0.163, 0.15)]:
        d = int(delay * SR)
        out[d:] += x[:-d] * g * wet * 2
    return out


def normalise(x: np.ndarray, peak: float = 0.89) -> np.ndarray:
    fade = min(len(x) // 10, int(0.05 * SR))
    x = x.copy()
    x[:fade] *= np.linspace(0, 1, fade)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x / (np.max(np.abs(x)) or 1) * peak


SA = 261.63  # Sa (C4) for melodic pieces
BHUPALI = {"S": 1, "R": 9 / 8, "G": 5 / 4, "P": 3 / 2, "D": 5 / 3, "S'": 2}


def melody(notes: list[tuple[str, float]], tempo: float = 1.0) -> np.ndarray:
    total = sum(d for _, d in notes) * tempo + 1.5
    out = np.zeros(int(total * SR))
    pos = 0.0
    for note, dur in notes:
        place(out, flute_note(SA * BHUPALI[note], dur * tempo * 1.1), pos, 0.8)
        pos += dur * tempo
    return out


def build() -> dict[str, np.ndarray]:
    sounds = {}
    sounds["temple-bell"] = reverb(bell(392, 6.0), 0.3)
    sounds["ghanti"] = reverb(sum_clips([(bell(880, 1.6, 1.5), k * 0.28) for k in range(8)], 4.0), 0.2)
    sounds["shankh"] = reverb(conch(4.5), 0.35)
    om_loop = om(48.0)
    sounds["om-chant-drone"] = reverb(om_loop, 0.3)
    tanpura = np.zeros(int(SR * 40))
    for k in range(10):  # Pa - Sa' - Sa' - Sa (low) cycle, 4 seconds each
        for i, f in enumerate([SA * 0.75, SA, SA, SA / 2]):
            place(tanpura, pluck(f, 3.5, 0.9985), k * 4 + i * 1.0, 0.7)
    sounds["tanpura-drone"] = reverb(tanpura, 0.25)
    phrase = [("S", .5), ("R", .5), ("G", 1), ("P", .5), ("D", .5), ("S'", 1.5), ("D", .5), ("P", .5),
              ("G", 1), ("R", .5), ("S", 1.5)]
    sounds["bhupali-flute"] = reverb(melody(phrase * 2, 0.55), 0.3)
    damru = np.zeros(int(SR * 6))
    for k, at in enumerate([0, .18, .36, .9, 1.08, 1.26, 1.8, 1.98, 2.16, 2.34, 2.7, 2.88, 3.06, 3.6, 3.78, 3.96, 4.5]):
        place(damru, drum(0.4, 180 if k % 2 else 140), at, 0.9)
    sounds["damru-rhythm"] = reverb(damru, 0.15)

    # Ringtones (about 20-30 s; the phone repeats them)
    ring_bells = np.zeros(int(SR * 24))
    for k in range(6):
        place(ring_bells, bell(392, 4.0), k * 4, 0.9)
        place(ring_bells, bell(587, 3.0, 1.2), k * 4 + 1.0, 0.5)
    sounds["ringtone-temple-bells"] = reverb(ring_bells, 0.3)
    ring_shankh = np.zeros(int(SR * 20))
    for k in range(4):
        place(ring_shankh, conch(3.5), k * 5, 0.9)
        place(ring_shankh, bell(523, 1.5), k * 5 + 3.6, 0.4)
    sounds["ringtone-shankh-naad"] = reverb(ring_shankh, 0.3)
    sounds["ringtone-bhupali-flute"] = reverb(melody(phrase * 3, 0.5), 0.3)
    ring_om = om(24.0)
    place(ring_om, bell(392, 5.0), 0.0, 1.2)
    place(ring_om, bell(392, 5.0), 12.0, 1.2)
    sounds["ringtone-om-shanti"] = reverb(ring_om, 0.3)
    sounds["notification-ghanti"] = reverb(sum_clips([(bell(1046, 1.2, 1.5), 0), (bell(1318, 1.2, 1.5), 0.18)], 1.6), 0.2)
    return {k: normalise(v) for k, v in sounds.items()}


def sum_clips(clips: list[tuple[np.ndarray, float]], seconds: float) -> np.ndarray:
    out = np.zeros(int(SR * seconds))
    for clip, at in clips:
        place(out, clip, at)
    return out


def write(name: str, data: np.ndarray, folder: Path) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        with wave.open(tmp.name, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((data * 32767).astype(np.int16).tobytes())
        out = folder / f"{name}.m4a"
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "aac", "-b:a", "96k", str(out)],
                       check=True)
    return out


def main() -> None:
    sounds = build()
    for name, data in sounds.items():
        path = write(name, data, MEDIA)
        print(f"{path.relative_to(ROOT)}  {len(data) / SR:.1f}s  {path.stat().st_size // 1024} KB")
    # The Virtual Mandir works offline, so its sounds ship inside the app.
    for name in ("temple-bell", "ghanti", "shankh", "om-chant-drone", "notification-ghanti"):
        write(name, sounds[name], APP_ASSETS)


if __name__ == "__main__":
    main()
