import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/gochara.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/names.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Weekly, monthly or yearly Rashi phalalu for one Moon sign, from the transits of the Moon, Sun,
/// Jupiter and Saturn (core/gochara.dart).
class PeriodRashifal extends ConsumerStatefulWidget {
  const PeriodRashifal({super.key, required this.period});
  final Period period;
  @override
  ConsumerState<PeriodRashifal> createState() => _PeriodRashifalState();
}

class _PeriodRashifalState extends ConsumerState<PeriodRashifal> with AutomaticKeepAliveClientMixin {
  late int _rashi = rashiList.indexWhere((r) => r.$1 == ref.read(prefsProvider).rashi).clamp(0, 11);
  late DateTime _day = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  DateTime _shift(int by) => switch (widget.period) {
    Period.week => _day.add(Duration(days: 7 * by)),
    Period.month => DateTime(_day.year, _day.month + by, 1),
    Period.year => DateTime(_day.year + by, 1, 1),
  };

  String _title(String lang, DateTime a, DateTime b) => switch (widget.period) {
    Period.week => '${fmtDate(lang, 'd MMM', a)} – ${fmtDate(lang, 'd MMM yyyy', b)}',
    Period.month => fmtDate(lang, 'MMMM yyyy', a),
    Period.year => '${a.year}',
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = uiLang(ref);
    final tx = ref.watch(gocharaProvider);
    return tx.when(
      loading: () => const LoadingList(height: 90),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(gocharaProvider)),
      data: (tx) {
        final r = periodReading(lang, tx, _rashi, widget.period, _day);
        bool inRange(DateTime d) {
          final (a, b) = periodSpan(widget.period, d);
          return tx.covers(a) || tx.covers(b);
        }

        final (slug, _, _, symbol) = rashiList[_rashi];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < 12; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${rashiList[i].$4} ${signName(lang, i)}'),
                        selected: _rashi == i,
                        onSelected: (_) => setState(() => _rashi = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: inRange(_shift(-1)) ? () => setState(() => _day = _shift(-1)) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _title(lang, r.start, r.end),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: inRange(_shift(1)) ? () => setState(() => _day = _shift(1)) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            GradientCard(
              colors: Palette.dusk,
              padding: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(symbol, style: const TextStyle(fontSize: 38, color: Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              signName(lang, _rashi),
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '★' * r.stars + '☆' * (5 - r.stars),
                              style: const TextStyle(color: Palette.gold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        color: Colors.white,
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                '$symbol ${signName(lang, _rashi)} · ${_title(lang, r.start, r.end)}\n\n${r.overview}\n\n'
                                '${r.sections.map((s) => '${s.emoji} ${s.title}\n${s.text}').join('\n\n')}\n\n🪔 Devalay',
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(r.overview, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final s in r.sections)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Text(s.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(s.text, style: const TextStyle(fontSize: 15, height: 1.4)),
                  ),
                ),
              ),
            Text(
              t3(
                lang,
                'Counted from the Moon sign (Chandra rashi) with the real positions of the Moon, Sun, Jupiter and '
                    'Saturn. For reflection and inspiration, not prediction.',
                'चंद्र राशि से गिना गया, चंद्र, सूर्य, गुरु और शनि की वास्तविक स्थितियों से। चिंतन और प्रेरणा हेतु, '
                    'भविष्यवाणी नहीं।',
                'చంద్ర రాశి నుండి లెక్కించినది, చంద్రుడు, సూర్యుడు, గురువు, శని అసలు స్థానాలతో. ఆలోచనకు, ప్రేరణకు '
                    'మాత్రమే, జోస్యం కాదు.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (Boxes.prefs.get('rashi') != slug)
              TextButton(
                onPressed: () => ref.read(prefsProvider.notifier).setRashi(slug),
                child: Text(l3(ref, 'Make this my rashi', 'इसे मेरी राशि बनाएँ', 'ఇది నా రాశి')),
              ),
          ],
        );
      },
    );
  }
}
