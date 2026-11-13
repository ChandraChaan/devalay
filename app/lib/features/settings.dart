import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/config.dart';
import '../core/calendar_reminders.dart';
import '../core/app_care.dart';
import '../core/i18n.dart';
import '../core/languages.dart';
import '../core/location.dart';
import '../core/notifications.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/city_picker.dart';
import '../widgets/language_picker.dart';
import '../widgets/common.dart';
import 'calendar_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);
    final auth = ref.watch(authProvider);
    final lang = prefs.language;
    final city = ref.watch(cityProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'settings'))),
      body: ListView(
        children: [
          if (!AppConfig.staticApi) ...[
            _Header(t3(lang, 'Account', 'खाता', 'ఖాతా')),
            if (auth.signedIn) ...[
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(auth.user!.email),
                subtitle: Text(
                  auth.isPremium
                      ? l3(
                          ref,
                          'Premium until ${auth.user!.premiumUntil?.toLocal().toString().substring(0, 10)}',
                          '${auth.user!.premiumUntil?.toLocal().toString().substring(0, 10)} तक प्रीमियम',
                          '${auth.user!.premiumUntil?.toLocal().toString().substring(0, 10)} వరకు ప్రీమియం',
                        )
                      : l3(ref, 'Free plan', 'मुफ़्त प्लान', 'ఉచిత ప్లాన్'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: Text(t3(lang, 'Sign out', 'साइन आउट', 'సైన్ అవుట్')),
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                title: Text(
                  t3(lang, 'Delete account', 'खाता हटाएँ', 'ఖాతా తొలగించండి'),
                  style: const TextStyle(color: Colors.red),
                ),
                subtitle: Text(
                  l3(
                    ref,
                    'Permanently removes your account and synced data',
                    'आपका खाता और सिंक किया गया डेटा हमेशा के लिए हटा देता है',
                    'మీ ఖాతాను, సింక్ చేసిన డేటాను శాశ్వతంగా తొలగిస్తుంది',
                  ),
                ),
                onTap: () => _deleteAccount(context, ref),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: Text(
                  t3(lang, 'Sign in / create account', 'साइन इन / खाता बनाएँ', 'సైన్ ఇన్ / ఖాతా సృష్టించండి'),
                ),
                subtitle: Text(
                  l3(
                    ref,
                    'Optional: sync favourites and Premium across devices',
                    'वैकल्पिक: पसंदीदा और प्रीमियम सभी डिवाइस पर सिंक करें',
                    'ఐచ్ఛికం: ఇష్టమైనవి, ప్రీమియంను అన్ని పరికరాల్లో సింక్ చేయండి',
                  ),
                ),
                onTap: () => context.push('/login'),
              ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_rounded),
              title: Text(tr(ref, 'premium')),
              onTap: () => context.push('/premium'),
            ),
          ],
          _Header(t3(lang, 'Preferences', 'पसंद', 'ప్రాధాన్యతలు')),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(t3(lang, 'Language', 'भाषा', 'భాష')),
            subtitle: Text(languageOf(prefs.language).native),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLanguagePicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_rounded),
            title: Text(t3(lang, 'Theme', 'थीम', 'థీమ్')),
            trailing: DropdownButton<ThemeMode>(
              value: prefs.themeMode,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(t3(lang, 'System', 'सिस्टम', 'ఫోన్ ప్రకారం'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(t3(lang, 'Light', 'लाइट', 'లైట్'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(t3(lang, 'Dark', 'डार्क', 'డార్క్'))),
              ],
              onChanged: (m) => n.setTheme(m!),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: Text(t3(lang, 'App colour', 'ऐप का रंग', 'యాప్ రంగు')),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final a in Accent.values)
                    Tooltip(
                      message: t3(lang, a.en, a.hi, a.te),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => n.setAccent(a),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.isDark ? a.dark : a.light,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: prefs.accent == a ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: prefs.accent == a ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.place_rounded),
            title: Text(t3(lang, 'Panchang city', 'पंचांग शहर', 'పంచాంగం నగరం')),
            subtitle: Text(city.label(lang)),
            onTap: () => showCityPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: Text(tr(ref, 'calendar')),
            subtitle: Text(calendarSettingsSummary(ref)),
            onTap: () => showCalendarSettings(context),
          ),
          _Header(t3(lang, 'Reminders', 'सूचनाएँ', 'రిమైండర్లు')),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: Text(t3(lang, 'Daily prayer reminder', 'दैनिक प्रार्थना', 'రోజువారీ పూజ రిమైండర్')),
            subtitle: Text(
              '${prefs.reminderHour.toString().padLeft(2, '0')}:${prefs.reminderMinute.toString().padLeft(2, '0')}',
            ),
            value: prefs.dailyReminder,
            onChanged: (v) async {
              if (v && !await Notifications.requestPermission()) return;
              await n.set('daily_reminder', v);
              v
                  ? await Notifications.scheduleDaily(prefs.reminderHour, prefs.reminderMinute, lang: prefs.language)
                  : await Notifications.cancelDaily();
            },
          ),
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(t3(lang, 'Change time', 'समय बदलें', 'సమయం మార్చండి')),
            enabled: prefs.dailyReminder,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: prefs.reminderHour, minute: prefs.reminderMinute),
              );
              if (t == null) return;
              await n.set('reminder_hour', t.hour);
              await n.set('reminder_minute', t.minute);
              await Notifications.scheduleDaily(t.hour, t.minute, lang: prefs.language);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wb_twilight_rounded),
            title: Text(t3(lang, 'Morning Panchang', 'सुबह का पंचांग', 'ఉదయపు పంచాంగం')),
            subtitle: Text(
              '${t3(lang, 'Tithi, nakshatra, Rahu Kalam and festivals at', 'तिथि, नक्षत्र, राहु काल व त्योहार,', 'తిథి, నక్షత్రం, రాహు కాలం, పండుగలు')} '
              '${clock12(prefs.panchangHour, prefs.panchangMinute)}',
            ),
            value: prefs.panchangDaily,
            onChanged: (v) async {
              if (v && !await Notifications.requestPermission()) return;
              await n.set('panchang_daily', v);
              await refreshPanchangNotifications(ref);
            },
          ),
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text(t3(lang, 'Change time', 'समय बदलें', 'సమయం మార్చండి')),
            enabled: prefs.panchangDaily,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: prefs.panchangHour, minute: prefs.panchangMinute),
              );
              if (t == null) return;
              await n.set('panchang_hour', t.hour);
              await n.set('panchang_minute', t.minute);
              await refreshPanchangNotifications(ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore_rounded),
            title: Text(t3(lang, 'Backup & export', 'बैकअप और एक्सपोर्ट', 'బ్యాకప్ & ఎక్స్‌పోర్ట్')),
            subtitle: Text(
              t3(
                lang,
                'Backup file, calendar export, birthdays from contacts',
                'बैकअप फ़ाइल, कैलेंडर एक्सपोर्ट, संपर्कों से जन्मदिन',
                'బ్యాకప్ ఫైల్, క్యాలెండర్ ఎక్స్‌పోర్ట్, కాంటాక్ట్‌ల నుండి పుట్టినరోజులు',
              ),
            ),
            onTap: () => context.push('/backup'),
          ),
          _Header(t3(lang, 'About', 'जानकारी', 'గురించి')),
          ListTile(
            leading: const Icon(Icons.star_rate_rounded),
            title: Text(
              t3(
                lang,
                'Rate Devalay on Google Play',
                'Google Play पर देवालय को रेट करें',
                'Google Playలో దేవాలయాన్ని రేట్ చేయండి',
              ),
            ),
            onTap: rateApp,
          ),
          ListTile(
            leading: const Icon(Icons.feedback_rounded),
            title: Text(t3(lang, 'Send feedback', 'सुझाव भेजें', 'సూచనలు పంపండి')),
            onTap: sendFeedback,
          ),
          ListTile(
            leading: const Icon(Icons.copyright_rounded),
            title: Text(
              t3(lang, 'Content credits & licences', 'सामग्री श्रेय और लाइसेंस', 'కంటెంట్ క్రెడిట్స్ & లైసెన్సులు'),
            ),
            onTap: () => context.push('/credits'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: Text(t3(lang, 'Privacy policy', 'गोपनीयता नीति', 'గోప్యతా విధానం')),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: Text(t3(lang, 'Clear offline cache', 'ऑफ़लाइन कैश साफ़ करें', 'ఆఫ్‌లైన్ కాష్ తొలగించండి')),
            onTap: () async {
              await Boxes.cache.clear();
              if (context.mounted) {
                toast(context, t3(appLang, 'Cache cleared', 'कैश साफ़ हो गया', 'కాష్ తొలగించబడింది'));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: FutureBuilder(
              future: PackageInfo.fromPlatform(),
              builder: (_, s) => Text('Devalay ${s.data?.version ?? ''}'),
            ),
            subtitle: Text(
              t3(
                lang,
                'No ads · No analytics · Open source',
                'विज्ञापन नहीं · एनालिटिक्स नहीं · ओपन सोर्स',
                'ప్రకటనలు లేవు · అనలిటిక్స్ లేవు · ఓపెన్ సోర్స్',
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final lang = appLang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t3(lang, 'Delete account?', 'खाता हटाएँ?', 'ఖాతా తొలగించాలా?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t3(
                lang,
                'This permanently deletes your account, synced favourites and subscription link. '
                    'Content saved on this phone stays. Cancel any Play subscription in Google Play.',
                'इससे आपका खाता, सिंक किए गए पसंदीदा और सदस्यता का जुड़ाव हमेशा के लिए हट जाएगा। '
                    'इस फ़ोन पर सहेजी गई सामग्री बनी रहेगी। Play की कोई भी सदस्यता Google Play में जाकर रद्द करें।',
                'దీంతో మీ ఖాతా, సింక్ చేసిన ఇష్టమైనవి, సబ్‌స్క్రిప్షన్ లింక్ శాశ్వతంగా తొలగిపోతాయి. '
                    'ఈ ఫోన్‌లో దాచినవి అలాగే ఉంటాయి. Play సబ్‌స్క్రిప్షన్ ఏదైనా ఉంటే Google Playలో రద్దు చేయండి.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(hintText: t3(lang, 'Password', 'पासवर्ड', 'పాస్‌వర్డ్')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t3(lang, 'Cancel', 'रद्द करें', 'రద్దు'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t3(lang, 'Delete', 'हटाएँ', 'తొలగించండి')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount(password.text);
      if (context.mounted) toast(context, t3(appLang, 'Account deleted', 'खाता हटा दिया गया', 'ఖాతా తొలగించాం'));
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
    ),
  );
}
