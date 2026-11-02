import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'storage.dart';

/// Favourites are stored on the device first (works signed-out and offline) and
/// mirrored to the account when the user signs in.
class FavoriteItem {
  FavoriteItem({required this.type, required this.id, required this.title, this.subtitle = '', this.image = ''});
  final String type, id, title, subtitle, image;

  String get key => '$type:$id';
  Map<String, dynamic> toJson() => {'type': type, 'id': id, 'title': title, 'subtitle': subtitle, 'image': image};
  static FavoriteItem fromJson(Map j) => FavoriteItem(
    type: j['type'],
    id: j['id'],
    title: j['title'] ?? '',
    subtitle: j['subtitle'] ?? '',
    image: j['image'] ?? '',
  );
}

class FavoritesNotifier extends Notifier<Map<String, FavoriteItem>> {
  @override
  Map<String, FavoriteItem> build() => {
    for (final e in Boxes.favorites.toMap().entries) '${e.key}': FavoriteItem.fromJson(e.value as Map),
  };

  bool contains(String type, String id) => state.containsKey('$type:$id');

  Future<void> toggle(FavoriteItem item) async {
    final api = ref.read(apiProvider);
    final next = Map<String, FavoriteItem>.from(state);
    if (next.containsKey(item.key)) {
      next.remove(item.key);
      await Boxes.favorites.delete(item.key);
      if (TokenStore.access != null) {
        api.delete('/favorites/${item.type}/${item.id}').catchError((_) {});
      }
    } else {
      next[item.key] = item;
      await Boxes.favorites.put(item.key, item.toJson());
      if (TokenStore.access != null) {
        api.put('/favorites', data: {'item_type': item.type, 'item_id': item.id}).catchError((_) {});
      }
    }
    state = next;
  }

  /// Uploads device favourites after sign-in. Items saved from another device appear
  /// in the server list; we keep them by id (titles fill in when opened).
  Future<void> syncWithServer() async {
    final api = ref.read(apiProvider);
    try {
      final items = state.values.map((f) => {'item_type': f.type, 'item_id': f.id}).toList();
      final server = await api.post('/favorites/sync', data: items) as List;
      final next = Map<String, FavoriteItem>.from(state);
      for (final s in server.cast<Map>()) {
        final key = '${s['item_type']}:${s['item_id']}';
        if (!next.containsKey(key)) {
          final item = FavoriteItem(type: s['item_type'], id: s['item_id'], title: '${s['item_type']} ${s['item_id']}');
          next[key] = item;
          await Boxes.favorites.put(key, item.toJson());
        }
      }
      state = next;
    } catch (_) {
      // Offline: sync happens again on next sign-in.
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Map<String, FavoriteItem>>(FavoritesNotifier.new);
