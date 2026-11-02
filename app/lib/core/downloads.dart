import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'storage.dart';

class DownloadLimitReached implements Exception {}

/// Offline audio stored in the app's private files directory.
class DownloadStore extends Notifier<Map<int, Map>> {
  final _progress = <int, double>{};
  final _dio = Dio();

  @override
  Map<int, Map> build() => {for (final e in Boxes.downloads.toMap().entries) int.parse('${e.key}'): e.value as Map};

  String? localPath(int trackId) => state[trackId]?['path'] as String?;
  bool isDownloaded(int trackId) => state.containsKey(trackId);
  double? progress(int trackId) => _progress[trackId];

  Future<void> download(Track t, {required bool premium, int freeLimit = 20}) async {
    if (isDownloaded(t.id)) return;
    if (!premium && state.length >= freeLimit) throw DownloadLimitReached();
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/audio');
    await dir.create(recursive: true);
    final ext = Uri.parse(t.audioUrl).path.split('.').last;
    final path = '${dir.path}/${t.id}.${ext.length <= 4 ? ext : 'mp3'}';
    _progress[t.id] = 0;
    ref.notifyListeners();
    try {
      await _dio.download(
        t.audioUrl,
        path,
        onReceiveProgress: (got, total) {
          if (total > 0) {
            _progress[t.id] = got / total;
            ref.notifyListeners();
          }
        },
      );
      final entry = {
        'path': path,
        'track': t.raw,
        'size': await File(path).length(),
        'at': DateTime.now().toIso8601String(),
      };
      await Boxes.downloads.put('${t.id}', entry);
      state = {...state, t.id: entry};
    } catch (e) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      rethrow;
    } finally {
      _progress.remove(t.id);
      ref.notifyListeners();
    }
  }

  Future<void> remove(int trackId) async {
    final path = localPath(trackId);
    if (path != null && await File(path).exists()) await File(path).delete();
    await Boxes.downloads.delete('$trackId');
    state = Map.of(state)..remove(trackId);
  }

  List<Track> get tracks => state.values.map((e) => Track(e['track'] as Map)).toList();
  int get totalBytes => state.values.fold(0, (sum, e) => sum + ((e['size'] as int?) ?? 0));
}

final downloadsProvider = NotifierProvider<DownloadStore, Map<int, Map>>(DownloadStore.new);
