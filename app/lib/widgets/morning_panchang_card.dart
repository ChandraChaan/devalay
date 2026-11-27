import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/location.dart';
import '../core/notifications.dart';
import '../core/retention.dart';
import '../core/storage.dart';
import '../core/usage.dart';
import 'city_picker.dart';
import 'common.dart';

/// Home card offering the two daily touch points: the morning Panchang notification and the
/// home-screen widget. It names the city the times are for, because most people never change the
/// default. It goes away once all three are set up, or when closed.
class MorningPanchangCard extends ConsumerStatefulWidget {
  const MorningPanchangCard({super.key});

  @override
  ConsumerState<MorningPanchangCard> createState() => _MorningPanchangCardState();
}

class _MorningPanchangCardState extends ConsumerState<MorningPanchangCard> with WidgetsBindingObserver {
  bool _closed = Boxes.prefs.get(morningCardClosedKey, defaultValue: false) as bool;
  bool _canPin = false;
  bool _hasWidget = false;
  bool _busy = false;
  bool _seen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWidgets();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The launcher's "Add widget" sheet takes the app to the background; look again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkWidgets();
  }

  Future<void> _checkWidgets() async {
    final canPin = await canPinWidget();
    final count = await installedWidgetCount();
    if (!mounted) return;
    setState(() {
      _canPin = canPin;
      _hasWidget = count > 0;
    });
  }

  Future<void> _turnOn(String lang) async {
    setState(() => _busy = true);
    final on = await setMorningPanchang(ref, true, source: 'home_card');
    if (!mounted) return;
    setState(() => _busy = false);
    final p = ref.read(prefsProvider);
    toast(
      context,
      on
          ? t3(
              lang,
              "Today's Panchang will arrive every morning at ${clock12(p.panchangHour, p.panchangMinute)}",
              'हर सुबह ${clock12(p.panchangHour, p.panchangMinute)} बजे आज का पंचांग मिलेगा',
              'ప్రతి ఉదయం ${clock12(p.panchangHour, p.panchangMinute)}కు నేటి పంచాంగం వస్తుంది',
            )
          : t3(
              lang,
              'Allow notifications for Devalay in your phone settings to get reminders.',
              'रिमाइंडर पाने के लिए फ़ोन की सेटिंग में देवालय की सूचनाएँ चालू करें।',
              'రిమైండర్ల కోసం ఫోన్ సెట్టింగ్స్‌లో దేవాలయం నోటిఫికేషన్లు అనుమతించండి.',
            ),
    );
  }

  void _close() {
    Boxes.prefs.put(morningCardClosedKey, true);
    Usage.record('morning_card_closed');
    setState(() => _closed = true);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(prefsProvider);
    final needsWidget = _canPin && !_hasWidget;
    // Stays while anything is left to set up: the message, the widget, or a city of the user's own.
    if (_closed || !prefs.onboarded || (prefs.panchangDaily && !needsWidget && cityChosen)) {
      return const SizedBox.shrink();
    }
    if (!_seen) {
      _seen = true;
      Usage.record('morning_card_shown');
    }
    final lang = prefs.language;
    final city = ref.watch(cityProvider);
    final time = clock12(prefs.panchangHour, prefs.panchangMinute);
    const white = TextStyle(color: Colors.white, height: 1.3);
    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF9A3412),
      visualDensity: VisualDensity.compact,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GradientCard(
        colors: const [Color(0xFF9A3412), Color(0xFFEA580C), Color(0xFFF59E0B)],
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌅', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t3(lang, "Today's Panchang, every morning", 'हर सुबह आज का पंचांग', 'ప్రతి ఉదయం నేటి పంచాంగం'),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t3(
                          lang,
                          'Tithi, nakshatra, Rahu Kalam and sunrise at $time, as a notification and on your home screen.',
                          'तिथि, नक्षत्र, राहु काल और सूर्योदय, सुबह $time बजे सूचना में और होम स्क्रीन पर।',
                          'తిథి, నక్షత్రం, రాహు కాలం, సూర్యోదయం ఉదయం $timeకు నోటిఫికేషన్‌గా, హోమ్ స్క్రీన్‌పై కూడా.',
                        ),
                        style: white,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: _close,
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Times are for one city; most people never change it, so it is named and one tap away.
            InkWell(
              onTap: () => showCityPicker(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t3(
                          lang,
                          'Times for ${city.label(lang)}',
                          '${city.label(lang)} का समय',
                          '${city.label(lang)} సమయాలు',
                        ),
                        style: white.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t3(lang, 'Change', 'बदलें', 'మార్చండి'),
                      style: white.copyWith(decoration: TextDecoration.underline, decorationColor: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!prefs.panchangDaily)
                  FilledButton.icon(
                    style: buttonStyle,
                    onPressed: _busy ? null : () => _turnOn(lang),
                    icon: const Icon(Icons.notifications_active_rounded, size: 18),
                    label: Text(t3(lang, 'Turn on', 'चालू करें', 'ఆన్ చేయండి')),
                  )
                else
                  Text(
                    '✓ ${t3(lang, 'Morning Panchang', 'सुबह का पंचांग', 'ఉదయపు పంచాంగం')}',
                    style: white.copyWith(fontWeight: FontWeight.w700),
                  ),
                if (needsWidget)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => pinPanchangWidget(source: 'home_card'),
                    icon: const Icon(Icons.widgets_rounded, size: 18),
                    label: Text(t3(lang, 'Add widget', 'विजेट जोड़ें', 'విడ్జెట్ జోడించండి')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
