import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/listening.dart';
import '../core/models.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mandala.dart';

const chantCounts = [11, 21, 108];

/// Japa with a recording: pick a short mantra and a count; the clip repeats that many times with a
/// big counter, then stops by itself. Keeps playing with the screen off (lock-screen controls).
class ChantScreen extends ConsumerStatefulWidget {
  const ChantScreen({super.key});
  @override
  ConsumerState<ChantScreen> createState() => _ChantScreenState();
}

class _ChantScreenState extends ConsumerState<ChantScreen> {
  int? _trackId;
  int _times = 11;

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final audio = ref.read(audioProvider);
    final mantras = ref.watch(chantMantrasProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Chant with the mantra', 'मंत्र के साथ जाप करें', 'మంత్రంతో జపం చేయండి'))),
      body: ValueListenableBuilder<ChantProgress?>(
        valueListenable: audio.chant,
        builder: (context, progress, _) => progress != null
            ? _Counter(progress: progress)
            : mantras.when(
                loading: () => const LoadingList(),
                error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(allTracksProvider)),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.music_off_rounded,
                        title: t3(lang, 'Nothing here yet', 'अभी यहाँ कुछ नहीं', 'ఇక్కడ ఇంకా ఏమీ లేదు'),
                      )
                    : _Picker(
                        mantras: list,
                        selected: _trackId ?? list.first.id,
                        times: _times,
                        onSelect: (id) => setState(() => _trackId = id),
                        onTimes: (n) => setState(() => _times = n),
                        onStart: () {
                          final t = list.firstWhere((t) => t.id == (_trackId ?? list.first.id));
                          audio.startChant(t, _times);
                        },
                      ),
              ),
      ),
    );
  }
}

class _Picker extends ConsumerWidget {
  const _Picker({
    required this.mantras,
    required this.selected,
    required this.times,
    required this.onSelect,
    required this.onTimes,
    required this.onStart,
  });
  final List<Track> mantras;
  final int selected, times;
  final ValueChanged<int> onSelect, onTimes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final scheme = Theme.of(context).colorScheme;
    final total = Boxes.stats.get('chants_total', defaultValue: 0) as int;
    final track = mantras.firstWhere((t) => t.id == selected, orElse: () => mantras.first);
    final minutes = (track.durationSec * times / 60).ceil();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120).withSystemInsets(context),
      children: [
        Text(
          t3(lang, 'Choose a mantra', 'मंत्र चुनें', 'మంత్రం ఎంచుకోండి'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final t in mantras)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: t.id == selected ? scheme.primary : Colors.transparent, width: 2),
              ),
              child: ListTile(
                minVerticalPadding: 12,
                leading: SizedBox(width: 52, height: 52, child: NetImage(t.artworkUrl, radius: 12)),
                title: Text(t.label(lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                subtitle: Text(formatDuration(Duration(seconds: t.durationSec))),
                trailing: Icon(
                  t.id == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: t.id == selected ? scheme.primary : null,
                ),
                onTap: () => onSelect(t.id),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text(
          t3(lang, 'How many times?', 'कितनी बार?', 'ఎన్ని సార్లు?'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final n in chantCounts)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    selected: times == n,
                    onSelected: (_) => onTimes(n),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          t3(lang, 'About $minutes min', 'लगभग $minutes मिनट', 'సుమారు $minutes నిమిషాలు'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(
              t3(lang, 'Start chanting', 'जाप शुरू करें', 'జపం ప్రారంభించండి'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (total > 0) ...[
          const SizedBox(height: 16),
          Text(
            t3(
              lang,
              'You have chanted $total times with Devalay 🙏',
              'आपने Devalay के साथ $total बार जाप किया 🙏',
              'మీరు Devalay తో $total సార్లు జపించారు 🙏',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _Counter extends ConsumerWidget {
  const _Counter({required this.progress});
  final ChantProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = uiLang(ref);
    final audio = ref.read(audioProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final p = progress;
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120).withSystemInsets(context),
      children: [
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Mandala(size: 260, color: Palette.gold, opacity: playing ? 0.3 : 0.12, spin: playing && !p.finished),
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: p.preparing ? null : p.done / p.target,
                    strokeWidth: 10,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: const AlwaysStoppedAnimation(Palette.saffron),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (p.finished)
                      const Text('🙏', style: TextStyle(fontSize: 56))
                    else
                      Text('${p.done}', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, height: 1)),
                    Text(
                      p.finished ? '${p.done} / ${p.target}' : '/ ${p.target}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          p.track.label(lang),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          p.preparing
              ? t3(lang, 'Getting the mantra ready…', 'मंत्र तैयार हो रहा है…', 'మంత్రం సిద్ధమవుతోంది…')
              : p.finished
              ? t3(lang, '${p.target} times complete', '${p.target} बार पूरा हुआ', '${p.target} సార్లు పూర్తయింది')
              : t3(
                  lang,
                  'Keep the phone aside and chant along',
                  'फ़ोन रख दें और साथ में जाप करें',
                  'ఫోన్ పక్కన పెట్టి కలిసి జపించండి',
                ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (p.finished)
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => audio.startChant(p.track, p.target),
              icon: const Icon(Icons.replay_rounded),
              label: Text(
                t3(lang, 'Chant again', 'फिर से जाप करें', 'మళ్ళీ జపించండి'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else if (!p.preparing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                iconSize: 40,
                padding: const EdgeInsets.all(14),
                tooltip: playing ? t3(lang, 'Pause', 'रोकें', 'ఆపు') : t3(lang, 'Resume', 'जारी रखें', 'కొనసాగించు'),
                onPressed: audio.toggle,
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: audio.stopChant,
            icon: Icon(p.finished ? Icons.list_rounded : Icons.stop_rounded),
            label: Text(
              p.finished
                  ? t3(lang, 'Choose another mantra', 'दूसरा मंत्र चुनें', 'మరో మంత్రం ఎంచుకోండి')
                  : t3(lang, 'Stop', 'बंद करें', 'ఆపివేయండి'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
