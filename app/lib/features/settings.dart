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
import '../widgets/common.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);
    final auth = ref.watch(authProvider);
    final hi = prefs.language == 'hi';
    final city = ref.watch(cityProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'settings'))),
      body: ListView(
        children: [
          _Header(hi ? 'खाता' : 'Account'),
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
              title: Text(hi ? 'साइन आउट' : 'Sign out'),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: Text(hi ? 'खाता हटाएँ' : 'Delete account', style: const TextStyle(color: Colors.red)),
              subtitle: const Text('Permanently removes your account and synced data'),
              onTap: () => _deleteAccount(context, ref),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login_rounded),
              title: Text(hi ? 'साइन इन / खाता बनाएँ' : 'Sign in / create account'),
              subtitle: const Text('Optional: sync favourites and Premium across devices'),
              onTap: () => context.push('/login'),
            ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_rounded),
            title: Text(tr(ref, 'premium')),
            onTap: () => context.push('/premium'),
          ),
          _Header(hi ? 'पसंद' : 'Preferences'),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(hi ? 'भाषा' : 'Language'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'hi', label: Text('हिन्दी')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {prefs.language},
              onSelectionChanged: (s) => n.setLanguage(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode_rounded),
            title: Text(hi ? 'थीम' : 'Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: prefs.themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (m) => n.setTheme(m!),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.place_rounded),
            title: Text(hi ? 'पंचांग शहर' : 'Panchang city'),
            subtitle: Text(hi ? city.nameHi : city.name),
            onTap: () => _pickCity(context, ref),
          ),
          _Header(hi ? 'सूचनाएँ' : 'Reminders'),
          SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: Text(hi ? 'दैनिक प्रार्थना' : 'Daily prayer reminder'),
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
            title: Text(hi ? 'समय बदलें' : 'Change time'),
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
          _Header(hi ? 'जानकारी' : 'About'),
          ListTile(
            leading: const Icon(Icons.copyright_rounded),
            title: Text(hi ? 'सामग्री श्रेय और लाइसेंस' : 'Content credits & licences'),
            onTap: () => context.push('/credits'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded),
            title: Text(hi ? 'गोपनीयता नीति' : 'Privacy policy'),
            onTap: () => launchUrl(Uri.parse('${AppConfig.apiBaseUrl}/privacy'), mode: LaunchMode.externalApplication),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: Text(hi ? 'ऑफ़लाइन कैश साफ़ करें' : 'Clear offline cache'),
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
    final hi = ref.read(prefsProvider).language == 'hi';
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
                title: Text(hi ? c.nameHi : c.name),
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
