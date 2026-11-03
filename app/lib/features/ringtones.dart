import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/audio.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/native.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class RingtonesScreen extends ConsumerWidget {
  const RingtonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const q = (kind: 'ringtone', deity: null);
    final tones = ref.watch(tracksProvider(q));
    final current = ref.watch(currentTrackProvider).value;
    final playing = ref.watch(playingProvider).value ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'ringtones'))),
      body: tones.when(
        loading: () => const LoadingList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(tracksProvider(q))),
        data: (list) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GradientCard(
              colors: Palette.dusk,
              child: Row(
                children: [
                  const Text('🔔', style: TextStyle(fontSize: 36)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pick(
                        ref,
                        'Ab ring mein honge Bhagwan. Original temple bells, shankh and bansuri, free to use.',
                        'अब रिंग में होंगे भगवान। मूल मंदिर घंटियाँ, शंख और बाँसुरी, निःशुल्क।',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final t in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => current?.id == t.id
                              ? ref.read(audioProvider).toggle()
                              : ref.read(audioProvider).playOne(t),
                          icon: Icon(current?.id == t.id && playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.label(uiLang(ref)),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              Text('${t.durationSec}s · ${t.license}', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _set(context, ref, t),
                          child: Text(l3(ref, 'Set', 'लगाएँ', 'పెట్టండి')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _set(BuildContext context, WidgetRef ref, Track t) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label, icon) in [
              ('ringtone', 'Phone ringtone', Icons.phone_in_talk_rounded),
              ('notification', 'Notification sound', Icons.notifications_rounded),
              ('alarm', 'Alarm', Icons.alarm_rounded),
            ])
              ListTile(leading: Icon(icon), title: Text(label), onTap: () => Navigator.pop(ctx, value)),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) return;
    if (!await NativeBridge.canWriteSettings()) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('One-time permission'),
          content: const Text(
            'Android needs "Modify system settings" permission for Devalay to change your ringtone. '
            'Turn it on, then come back and tap Set again.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open settings')),
          ],
        ),
      );
      if (ok == true) await NativeBridge.openWriteSettings();
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${t.slug}.m4a';
      if (!await File(path).exists()) await Dio().download(t.audioUrl, path);
      await NativeBridge.setRingtone(path, 'Devalay - ${t.title}', type);
      if (context.mounted) toast(context, '${t.title} set as $type 🙏');
    } catch (e) {
      if (context.mounted) toast(context, 'Could not set ringtone: $e');
    }
  }
}
