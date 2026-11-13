import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/holidays.dart';
import '../core/i18n.dart';
import '../core/location.dart';
import '../core/regional.dart';
import '../core/storage.dart';

/// Calendar choices: Amanta or Purnimanta months, an extra solar calendar, and whose state holidays
/// to show. Each is kept in the prefs box; "auto" (no value) follows the language or the city.
Future<void> showCalendarSettings(BuildContext context) => showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => const _CalendarSettingsSheet(),
);

/// One line for the Settings screen: "Purnimanta · Tamil solar calendar · Telangana holidays".
String calendarSettingsSummary(WidgetRef ref) {
  final lang = ref.watch(prefsProvider).language;
  final system = ref.watch(monthSystemProvider);
  final solar = ref.watch(solarCalendarProvider);
  final state = ref.watch(holidayStateProvider);
  return [
    system == MonthSystem.amanta
        ? t3(lang, 'Amanta', 'अमांत', 'అమాంత')
        : t3(lang, 'Purnimanta', 'पूर्णिमांत', 'పూర్ణిమాంత'),
    if (solar != null) solarCalendarLabel(lang, solar),
    if (state != null) stateName(lang, state),
  ].join(' · ');
}

class _CalendarSettingsSheet extends ConsumerWidget {
  const _CalendarSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);
    final lang = prefs.language;
    final city = ref.watch(cityProvider);
    final states = ref.watch(holidayCatalogProvider).value?.states ?? const <String>[];
    final system = Boxes.prefs.get('month_system') as String?;
    final solar = Boxes.prefs.get('solar_calendar') as String?;
    final state = Boxes.prefs.get('holiday_state') as String?;
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    final note = Theme.of(context).textTheme.bodySmall;
    final auto = t3(lang, 'Automatic', 'अपने आप', 'ఆటోమేటిక్');

    Widget choice<T>(String label, T? value, T? group, ValueChanged<T?> onTap, {String? subtitle}) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        value == group ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
        color: value == group ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => onTap(value),
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(t3(lang, 'Lunar month names', 'चंद्र मास के नाम', 'చాంద్రమాన మాసాల పేర్లు'), style: title),
          Text(
            t3(
              lang,
              'North India ends each month on Purnima, so the dark fortnight takes the next month\'s name. Festivals and tithi reminders stay on the same days either way.',
              'उत्तर भारत में मास पूर्णिमा पर पूरा होता है, इसलिए कृष्ण पक्ष अगले मास के नाम से जाना जाता है। दोनों तरह त्योहार और तिथि रिमाइंडर उन्हीं दिनों रहते हैं।',
              'ఉత్తర భారతంలో మాసం పౌర్ణమితో ముగుస్తుంది, అందుకే బహుళ పక్షానికి తర్వాతి మాసం పేరు. ఏ పద్ధతైనా పండుగలు, తిథి రిమైండర్లు అవే రోజుల్లో ఉంటాయి.',
            ),
            style: note,
          ),
          choice<String>(
            auto,
            null,
            system,
            (v) => n.set('month_system', v),
            subtitle: monthSystemLabel(lang, defaultMonthSystem(lang)),
          ),
          for (final s in MonthSystem.values)
            choice<String>(monthSystemLabel(lang, s), s.name, system, (v) => n.set('month_system', v)),
          const Divider(height: 24),
          Text(t3(lang, 'Extra calendar', 'अतिरिक्त पंचांग', 'అదనపు క్యాలెండర్'), style: title),
          Text(
            t3(
              lang,
              'Shows the solar month and date (such as Aippasi 27) in the calendar.',
              'कैलेंडर में सौर मास और तारीख (जैसे ऐप्पसि 27) दिखाता है।',
              'క్యాలెండర్‌లో సౌర మాసం, తేదీ (ఉదా: ఐప్పసి 27) చూపిస్తుంది.',
            ),
            style: note,
          ),
          choice<String>(
            auto,
            null,
            solar,
            (v) => n.set('solar_calendar', v),
            subtitle: solarCalendars.contains(lang)
                ? solarCalendarLabel(lang, lang)
                : t3(lang, 'None for this language', 'इस भाषा के लिए कोई नहीं', 'ఈ భాషకు ఏదీ లేదు'),
          ),
          choice<String>(t3(lang, 'None', 'कोई नहीं', 'ఏదీ వద్దు'), 'none', solar, (v) => n.set('solar_calendar', v)),
          for (final c in solarCalendars)
            choice<String>(solarCalendarLabel(lang, c), c, solar, (v) => n.set('solar_calendar', v)),
          const Divider(height: 24),
          Text(t3(lang, 'State holidays', 'राज्य अवकाश', 'రాష్ట్ర సెలవులు'), style: title),
          Text(
            t3(
              lang,
              'Public and bank holidays from the state government and RBI lists.',
              'राज्य सरकार व RBI की सूची से सार्वजनिक व बैंक अवकाश।',
              'రాష్ట్ర ప్రభుత్వ, RBI జాబితాల నుంచి ప్రభుత్వ, బ్యాంకు సెలవులు.',
            ),
            style: note,
          ),
          choice<String>(
            auto,
            null,
            state,
            (v) => n.set('holiday_state', v),
            subtitle: city.state.isEmpty
                ? t3(lang, 'Your city is outside India', 'आपका शहर भारत से बाहर है', 'మీ నగరం భారత్ బయట ఉంది')
                : t3(
                    lang,
                    'From your city: ${stateName(lang, city.state)}',
                    'आपके शहर से: ${stateName(lang, city.state)}',
                    'మీ నగరం ప్రకారం: ${stateName(lang, city.state)}',
                  ),
          ),
          choice<String>(t3(lang, 'None', 'कोई नहीं', 'ఏదీ వద్దు'), 'none', state, (v) => n.set('holiday_state', v)),
          for (final s in [...states]..sort((a, b) => stateName(lang, a).compareTo(stateName(lang, b))))
            choice<String>(stateName(lang, s), s, state, (v) => n.set('holiday_state', v)),
        ],
      ),
    );
  }
}
