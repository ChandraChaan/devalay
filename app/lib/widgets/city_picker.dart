import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/location.dart';
import '../core/storage.dart';

/// Picks the city all Panchang times are computed for, with search.
Future<void> showCityPicker(BuildContext context, WidgetRef ref) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _CitySheet(),
);

class _CitySheet extends ConsumerStatefulWidget {
  const _CitySheet();
  @override
  ConsumerState<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends ConsumerState<_CitySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final lang = prefs.language;
    final q = _q.trim().toLowerCase();
    final shown = cities
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.label(lang).toLowerCase().contains(q) ||
              c.nameHi.contains(q) ||
              c.tz.toLowerCase().contains(q),
        )
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t3(lang, 'Panchang city', 'पंचांग शहर', 'పంచాంగం నగరం'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  t3(
                    lang,
                    'Sunrise, tithi end times and Rahu Kalam are worked out for this city. Pick the nearest one.',
                    'सूर्योदय, तिथि का समय और राहु काल इसी शहर के लिए हैं। सबसे नज़दीकी शहर चुनें।',
                    'సూర్యోదయం, తిథి సమయాలు, రాహుకాలం ఈ నగరం ప్రకారం. దగ్గరలోని నగరం ఎంచుకోండి.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: t3(lang, 'Search city', 'शहर खोजें', 'నగరం వెతకండి'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (final c in shown)
                  ListTile(
                    leading: Icon(
                      prefs.cityId == c.id ? Icons.place_rounded : Icons.location_city_rounded,
                      color: prefs.cityId == c.id ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(
                      c.label(lang),
                      style: TextStyle(fontWeight: prefs.cityId == c.id ? FontWeight.w700 : FontWeight.w500),
                    ),
                    subtitle: Text(c.tz),
                    trailing: prefs.cityId == c.id ? const Icon(Icons.check_rounded) : null,
                    onTap: () {
                      ref.read(prefsProvider.notifier).setCity(c.id);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
