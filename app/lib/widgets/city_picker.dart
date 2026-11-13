import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/holidays.dart';
import '../core/i18n.dart';
import '../core/location.dart';
import '../core/native.dart';
import '../core/storage.dart';
import 'common.dart';

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
  bool _locating = false;

  /// "Use my location": explains first, asks Android for approximate location once, and picks the
  /// nearest city. The position is used on the phone only and is not kept.
  Future<void> _useLocation() async {
    final lang = ref.read(prefsProvider).language;
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.my_location_rounded),
        title: Text(t3(lang, 'Use my location?', 'मेरी लोकेशन इस्तेमाल करें?', 'నా లొకేషన్ వాడాలా?')),
        content: Text(
          t3(
            lang,
            'Devalay checks your approximate location once, now, to pick the nearest city for sunrise, tithi and Rahu Kalam times. It is not saved or sent anywhere, and the app never tracks you in the background.',
            'देवालय अभी एक बार आपकी अनुमानित लोकेशन देखकर सूर्योदय, तिथि और राहु काल के लिए सबसे नज़दीकी शहर चुनता है। लोकेशन न सहेजी जाती है, न कहीं भेजी जाती है, और ऐप पीछे से आपको ट्रैक नहीं करता।',
            'సూర్యోదయం, తిథి, రాహుకాలం సమయాల కోసం దగ్గరి నగరాన్ని ఎంచుకోవడానికి దేవాలయం ఇప్పుడు ఒక్కసారి మీ సుమారు లొకేషన్ చూస్తుంది. అది ఎక్కడా దాచబడదు, పంపబడదు; యాప్ వెనుక నుంచి మిమ్మల్ని ట్రాక్ చేయదు.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t3(lang, 'Not now', 'अभी नहीं', 'ఇప్పుడు వద్దు')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t3(lang, 'Continue', 'आगे बढ़ें', 'కొనసాగించు')),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    setState(() => _locating = true);
    String message;
    try {
      final here = await NativeBridge.approxLocation();
      if (here == null) throw PlatformException(code: 'UNAVAILABLE');
      final (city, km) = nearestCity(here.lat, here.lon);
      await ref.read(prefsProvider.notifier).setCity(city.id);
      message = t3(
        lang,
        'Nearest city: ${city.label(lang)} (${km.round()} km)',
        'सबसे नज़दीकी शहर: ${city.label(lang)} (${km.round()} कि.मी.)',
        'దగ్గరి నగరం: ${city.label(lang)} (${km.round()} కి.మీ.)',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } on PlatformException catch (e) {
      message = switch (e.code) {
        'DENIED' => t3(
          lang,
          'Location permission was not given. Pick your city from the list.',
          'लोकेशन की अनुमति नहीं मिली। सूची से अपना शहर चुनें।',
          'లొకేషన్ అనుమతి ఇవ్వలేదు. జాబితా నుంచి మీ నగరం ఎంచుకోండి.',
        ),
        'OFF' => t3(
          lang,
          'Location is turned off on this phone. Turn it on or pick your city from the list.',
          'फ़ोन में लोकेशन बंद है। उसे चालू करें या सूची से शहर चुनें।',
          'ఫోన్‌లో లొకేషన్ ఆఫ్‌లో ఉంది. ఆన్ చేయండి లేదా జాబితా నుంచి నగరం ఎంచుకోండి.',
        ),
        _ => t3(
          lang,
          'Could not find your location. Pick your city from the list.',
          'आपकी लोकेशन नहीं मिल सकी। सूची से शहर चुनें।',
          'మీ లొకేషన్ దొరకలేదు. జాబితా నుంచి నగరం ఎంచుకోండి.',
        ),
      };
    } finally {
      if (mounted) setState(() => _locating = false);
    }
    if (mounted) toast(context, message);
  }

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
              (c.state.isNotEmpty && stateName(lang, c.state).toLowerCase().contains(q)) ||
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
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && q.isEmpty)
                  ListTile(
                    leading: _locating
                        ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Icon(Icons.my_location_rounded, color: Theme.of(context).colorScheme.primary),
                    title: Text(
                      t3(lang, 'Use my location', 'मेरी लोकेशन इस्तेमाल करें', 'నా లొకేషన్ వాడండి'),
                      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      t3(
                        lang,
                        'Picks the nearest city. Asked once, never tracked.',
                        'सबसे नज़दीकी शहर चुनता है। एक बार पूछता है, ट्रैक नहीं करता।',
                        'దగ్గరి నగరం ఎంచుకుంటుంది. ఒక్కసారే అడుగుతుంది, ట్రాక్ చేయదు.',
                      ),
                    ),
                    onTap: _locating ? null : _useLocation,
                  ),
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
                    subtitle: Text(c.state.isEmpty ? c.tz : stateName(lang, c.state)),
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
