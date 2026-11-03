import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/config.dart';
import '../core/i18n.dart';
import '../core/location.dart';
import '../core/notifications.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

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
                      ? 'Premium until ${auth.user!.premiumUntil?.toLocal().toString().substring(0, 10)}'
                      : 'Free plan',
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
                subtitle: const Text('Permanently removes your account and synced data'),
                onTap: () => _deleteAccount(context, ref),
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: Text(
                  t3(lang, 'Sign in / create account', 'साइन इन / खाता बनाएँ', 'సైన్ ఇన్ / ఖాతా సృష్టించండి'),
                ),
                subtitle: const Text('Optional: sync favourites and Premium across devices'),
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
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'te', label: Text('తెలుగు')),
                ButtonSegment(value: 'hi', label: Text('हिन्दी')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {prefs.language},
              onSelectionChanged: (s) => n.setLanguage(s.first),
            ),
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
            onTap: () => _pickCity(context, ref),
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
          _Header(t3(lang, 'About', 'जानकारी', 'గురించి')),
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
              if (context.mounted) toast(context, 'Cache cleared');
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Devalay 1.0.0'),
            subtitle: Text('No ads · No trackers · Open source'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _pickCity(BuildContext context, WidgetRef ref) {
    final lang = ref.read(prefsProvider).language;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, scroll) => ListView(
          controller: scroll,
          children: [
            for (final c in cities)
              ListTile(
                title: Text(c.label(lang)),
                subtitle: Text(c.tz),
                trailing: ref.read(prefsProvider).cityId == c.id ? const Icon(Icons.check_rounded) : null,
                onTap: () {
                  ref.read(prefsProvider.notifier).setCity(c.id);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This permanently deletes your account, synced favourites and subscription link. '
              'Content saved on this phone stays. Cancel any Play subscription in Google Play.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authProvider.notifier).deleteAccount(password.text);
      if (context.mounted) toast(context, 'Account deleted');
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
