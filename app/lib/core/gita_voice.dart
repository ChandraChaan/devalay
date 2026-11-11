import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'audio.dart';
import 'models.dart';
import 'storage.dart';

/// What the Gita player reads aloud for each verse.
enum GitaReadMode { both, sanskrit, translation }

/// Which half of a verse is being spoken right now.
enum VersePart { sanskrit, translation }

@immutable
class GitaVoiceState {
  const GitaVoiceState({
    this.playing = false,
    this.chapter,
    this.index,
    this.verse,
    this.part,
    this.mode = GitaReadMode.both,
    this.rate = 1.0,
    this.noSanskritVoice = false,
  });

  final bool playing;
  final int? chapter;

  /// Index into the chapter's verse list of the verse being read.
  final int? index;
  final VersePart? part;
  final GitaReadMode mode;

  /// Speed shown to the user: 0.75x, 1x, 1.25x, 1.5x.
  final double rate;

  /// True when the device has no Hindi voice, so Sanskrit is skipped.
  final bool noSanskritVoice;

  /// Verse number (not index) being read.
  final int? verse;

  bool isSpeaking(Verse v, VersePart p) => playing && chapter == v.chapter && verse == v.verse && part == p;

  GitaVoiceState copyWith({
    bool? playing,
    int? chapter,
    int? index,
    int? verse,
    VersePart? part,
    bool clearPart = false,
    GitaReadMode? mode,
    double? rate,
    bool? noSanskritVoice,
  }) => GitaVoiceState(
    playing: playing ?? this.playing,
    chapter: chapter ?? this.chapter,
    index: index ?? this.index,
    verse: verse ?? this.verse,
    part: clearPart ? null : (part ?? this.part),
    mode: mode ?? this.mode,
    rate: rate ?? this.rate,
    noSanskritVoice: noSanskritVoice ?? this.noSanskritVoice,
  );
}

/// Reads the Bhagavad Gita aloud verse by verse with the device's own
/// text-to-speech voices (Sanskrit through a Hindi voice, the translation
/// through an Indian English voice). Nothing is downloaded or streamed.
class GitaVoice extends Notifier<GitaVoiceState> {
  static const rates = [0.75, 1.0, 1.25, 1.5];

  final _tts = FlutterTts();
  bool _configured = false;
  bool? _hasHindi;

  /// Bumped on every start/stop so a running loop knows it was cancelled.
  int _session = 0;
  Object? _owner;

  @override
  GitaVoiceState build() {
    ref.onDispose(() => _tts.stop());
    return GitaVoiceState(
      mode:
          GitaReadMode.values[(Boxes.prefs.get('gita_voice_mode', defaultValue: 0) as int).clamp(
            0,
            GitaReadMode.values.length - 1,
          )],
      rate: (Boxes.prefs.get('gita_voice_rate', defaultValue: 1.0) as num).toDouble(),
    );
  }

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.awaitSpeakCompletion(true);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]);
    }
  }

  Future<bool> _hindiAvailable() async {
    if (_hasHindi != null) return _hasHindi!;
    try {
      final v = await _tts.isLanguageAvailable('hi-IN');
      _hasHindi = v == true || v == 1;
    } catch (_) {
      _hasHindi = true; // let the engine try; it falls back to its default voice
    }
    return _hasHindi!;
  }

  // Android's engine speaks at 0.5 for "normal"; iOS uses the same scale.
  double get _engineRate => 0.5 * state.rate;

  Future<void> setMode(GitaReadMode m) async {
    state = state.copyWith(mode: m);
    await Boxes.prefs.put('gita_voice_mode', m.index);
  }

  Future<void> cycleRate() async {
    final i = rates.indexOf(state.rate);
    final next = rates[(i + 1) % rates.length];
    state = state.copyWith(rate: next);
    await Boxes.prefs.put('gita_voice_rate', next);
    await _tts.setSpeechRate(_engineRate);
  }

  /// Starts reading [chapter] from verse index [start]. [onVerse] fires as
  /// each verse begins so the screen can turn the page; [onDone] fires after
  /// the last verse. [owner] identifies the screen that started playback, so
  /// a screen being disposed only stops its own session.
  Future<void> play(
    GitaChapter chapter,
    int start, {
    required Object owner,
    void Function(int index)? onVerse,
    VoidCallback? onDone,
    bool announce = false,
  }) async {
    final session = ++_session;
    _owner = owner;
    await _tts.stop();
    await _configure();
    // Do not talk over a bhajan that is playing in the background.
    try {
      await ref.read(audioProvider).player.pause();
    } catch (_) {}
    final hindi = await _hindiAvailable();
    state = state.copyWith(
      playing: true,
      chapter: chapter.number,
      index: start,
      clearPart: true,
      noSanskritVoice: !hindi,
    );
    await WakelockPlus.enable();
    await _tts.setSpeechRate(_engineRate);

    bool live() => session == _session;

    if (announce && start == 0) {
      await _tts.setLanguage('en-IN');
      await _tts.speak('Chapter ${chapter.number}. ${chapter.nameEn}.');
      if (!live()) return;
    }

    for (var i = start; i < chapter.verses.length; i++) {
      if (!live()) return;
      final v = chapter.verses[i];
      state = state.copyWith(index: i, verse: v.verse, clearPart: true);
      onVerse?.call(i);
      if (state.mode != GitaReadMode.translation && hindi) {
        state = state.copyWith(part: VersePart.sanskrit);
        await _tts.setLanguage('hi-IN');
        await _tts.speak(_cleanSanskrit(v.sanskrit));
        if (!live()) return;
      }
      if (state.mode != GitaReadMode.sanskrit || !hindi) {
        state = state.copyWith(part: VersePart.translation);
        await _tts.setLanguage('en-IN');
        await _tts.speak(v.translation);
        if (!live()) return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!live()) return;
    state = state.copyWith(playing: false, clearPart: true);
    await WakelockPlus.disable();
    onDone?.call();
  }

  /// Stops playback. With [owner], only stops if that screen started it.
  Future<void> stop({Object? owner}) async {
    if (owner != null && owner != _owner) return;
    _session++;
    _owner = null;
    await _tts.stop();
    await WakelockPlus.disable();
    if (ref.mounted) state = state.copyWith(playing: false, clearPart: true);
  }

  /// Verse numbers (॥२-४७॥) and dandas would be read out as digits/pauses.
  static String _cleanSanskrit(String s) => s
      .replaceAll(RegExp(r'॥\s*[०-९0-9\s.\-]*\s*॥'), '। ')
      .replaceAll(RegExp(r'[|।॥]+'), '। ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

final gitaVoiceProvider = NotifierProvider<GitaVoice, GitaVoiceState>(GitaVoice.new);
