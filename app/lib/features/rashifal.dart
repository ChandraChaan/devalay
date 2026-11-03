import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../core/i18n.dart';
import '../core/providers.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class RashifalScreen extends ConsumerWidget {
  const RashifalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(rashifalProvider);
    final mine = ref.watch(prefsProvider).rashi;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'rashifal'))),
      body: data.when(
        loading: () => const LoadingList(height: 90),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(rashifalProvider)),
        data: (list) {
          final ordered = [...list.where((r) => r['rashi'] == mine), ...list.where((r) => r['rashi'] != mine)];
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: ordered.length,
            itemBuilder: (_, i) {
              final r = ordered[i];
              final isMine = r['rashi'] == mine;
              return GradientCard(
                colors: isMine
                    ? Palette.sunrise
                    : (i.isEven ? Palette.dusk : const [Color(0xFF283593), Color(0xFF4A148C)]),
                padding: 10,
                onTap: () => _open(context, ref, r),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${r['symbol']}', style: const TextStyle(fontSize: 34, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '${r['name']}',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    Text('${r['name_en']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '★' * (r['rating'] as int) + '☆' * (5 - (r['rating'] as int)),
                      style: const TextStyle(color: Palette.gold, fontSize: 13),
                    ),
                    if (isMine) const Text('Your rashi', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ).animate().fadeIn(delay: (35 * i).ms).scale(begin: const Offset(0.9, 0.9));
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref, Map r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Row(
              children: [
                Text('${r['symbol']}', style: const TextStyle(fontSize: 44)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${r['name']} · ${r['name_en']}', style: Theme.of(ctx).textTheme.headlineSmall),
                      Text(
                        'Moon in ${r['moon_rashi']} · house ${r['moon_house']} from your sign',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: '${r['symbol']} ${r['name']} — ${r['overview']}\n\n🪔 Devalay'),
                  ),
                  icon: const Icon(Icons.share_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${r['overview']}', style: const TextStyle(fontSize: 18, height: 1.5)),
            const SizedBox(height: 16),
            for (final (icon, key, title) in [
              ('❤️', 'love', l3(ref, 'Relationships', 'संबंध', 'బంధాలు')),
              ('💼', 'career', l3(ref, 'Work', 'कार्य', 'పని')),
              ('🌿', 'health', l3(ref, 'Health', 'स्वास्थ्य', 'ఆరోగ్యం')),
              ('🪔', 'remedy', l3(ref, 'Upay', 'उपाय', 'పరిహారం')),
            ])
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Text(icon, style: const TextStyle(fontSize: 26)),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r[key]}', style: const TextStyle(fontSize: 15, height: 1.4)),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _Lucky(label: l3(ref, 'Lucky colour', 'शुभ रंग', 'అదృష్ట రంగు'), value: '${r['lucky_color']}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Lucky(
                    label: l3(ref, 'Lucky number', 'शुभ अंक', 'అదృష్ట సంఖ్య'),
                    value: '${r['lucky_number']}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${r['disclaimer']}', style: Theme.of(ctx).textTheme.bodySmall, textAlign: TextAlign.center),
            if (Boxes.prefs.get('rashi') != r['rashi'])
              TextButton(
                onPressed: () {
                  ref.read(prefsProvider.notifier).setRashi('${r['rashi']}');
                  Navigator.pop(ctx);
                },
                child: Text(l3(ref, 'Make this my rashi', 'इसे मेरी राशि बनाएँ', 'ఇది నా రాశి')),
              ),
          ],
        ),
      ),
    );
  }
}

class _Lucky extends StatelessWidget {
  const _Lucky({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Palette.marigold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
    child: Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
