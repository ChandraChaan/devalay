import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio.dart';
import '../core/api.dart';
import '../core/downloads.dart';
import '../core/favorites.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../widgets/common.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).values.toList();
    const icons = {'track': '🎵', 'text': '📜', 'verse': '🪈', 'wallpaper': '🖼️', 'book': '📚', 'video': '🎬'};
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'favorites'))),
      body: favs.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border_rounded,
              title: t3(appLang, 'No favourites yet', 'अभी कोई पसंदीदा नहीं', 'ఇంకా ఇష్టమైనవి లేవు'),
              subtitle: t3(
                appLang,
                'Tap the heart on any aarti, verse, track or wallpaper to keep it here.',
                'किसी भी आरती, श्लोक, गीत या वॉलपेपर पर दिल दबाएँ, वह यहाँ रहेगा।',
                'ఏ హారతి, శ్లోకం, పాట లేదా వాల్‌పేపర్‌పై హృదయం గుర్తు నొక్కితే ఇక్కడ ఉంటుంది.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: favs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final f = favs[i];
                return Dismissible(
                  key: ValueKey(f.key),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline_rounded),
                  ),
                  onDismissed: (_) => ref.read(favoritesProvider.notifier).toggle(f),
                  child: Card(
                    child: ListTile(
                      leading: f.image.isNotEmpty
                          ? SizedBox(width: 48, height: 48, child: NetImage(f.image, radius: 10))
                          : Text(icons[f.type] ?? '⭐', style: const TextStyle(fontSize: 28)),
                      title: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: f.subtitle.isEmpty
                          ? null
                          : Text(f.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(context, ref, f),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, FavoriteItem f) async {
    switch (f.type) {
      case 'text':
        context.push('/text/${f.id}');
      case 'verse':
        final p = f.id.split('.');
        context.push('/gita/${p[0]}?verse=${p[1]}');
      case 'book':
        context.push('/books/${f.id}');
      case 'track':
        try {
          final t = Track(await ref.read(apiProvider).get('/tracks/${f.id}') as Map);
          await ref.read(audioProvider).playOne(t);
          if (context.mounted) context.push('/player');
        } catch (_) {
          if (context.mounted) toast(context, tr(ref, 'error'));
        }
      case 'wallpaper':
        final data = await ref.read(apiProvider).get('/wallpapers', query: {'page_size': 100}) as Map;
        final w = (data['items'] as List).map((e) => Wallpaper(e as Map)).where((w) => '${w.id}' == f.id).firstOrNull;
        if (w != null && context.mounted) context.push('/wallpaper', extra: w);
    }
  }
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(downloadsProvider);
    final store = ref.read(downloadsProvider.notifier);
    final tracks = store.tracks;
    final mb = (store.totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'downloads'))),
      body: tracks.isEmpty
          ? EmptyState(
              icon: Icons.download_for_offline_outlined,
              title: t3(appLang, 'No downloads', 'कोई डाउनलोड नहीं', 'డౌన్‌లోడ్‌లు లేవు'),
              subtitle: t3(
                appLang,
                'Open the player and tap Download to listen without internet.',
                'बिना इंटरनेट सुनने के लिए प्लेयर खोलकर डाउनलोड दबाएँ।',
                'ఇంటర్నెట్ లేకుండా వినడానికి ప్లేయర్ తెరిచి డౌన్‌లోడ్ నొక్కండి.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${tracks.length} tracks · $mb MB on this device', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => ref.read(audioProvider).playQueue(tracks),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t3(appLang, 'Play all offline', 'सब ऑफ़लाइन चलाएँ', 'అన్నీ ఆఫ్‌లైన్‌లో ప్లే చేయండి')),
                ),
                const SizedBox(height: 8),
                for (final (i, t) in tracks.indexed)
                  ListTile(
                    leading: SizedBox(width: 48, height: 48, child: NetImage(t.artworkUrl, radius: 10)),
                    title: Text(t.label(uiLang(ref))),
                    onTap: () => ref.read(audioProvider).playQueue(tracks, index: i),
                    trailing: IconButton(
                      onPressed: () => store.remove(t.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ),
              ],
            ),
    );
  }
}
