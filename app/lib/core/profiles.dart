import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'jatakam.dart';
import 'storage.dart';

/// A saved birth: what the Jatakam screen was given and the stars it found. Kept on the phone only
/// (Hive prefs box, key 'birth_profiles'), and offered to marriage matching.
class BirthProfile {
  BirthProfile({
    required this.name,
    required this.local,
    required this.place,
    required this.lat,
    required this.lon,
    this.zone,
    this.offsetMinutes,
  });

  final String name;

  /// Birth date and time on the local clock (stored without a zone).
  final DateTime local;
  final String place;
  final double lat, lon;

  /// IANA zone for a listed city (its historical offsets apply), or a fixed offset for another place.
  final String? zone;
  final int? offsetMinutes;

  static bool _zonesReady = false;

  DateTime get utc {
    if (zone != null) {
      if (!_zonesReady) {
        tzdata.initializeTimeZones();
        _zonesReady = true;
      }
      final t = local;
      return tz.TZDateTime(tz.getLocation(zone!), t.year, t.month, t.day, t.hour, t.minute).toUtc();
    }
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    ).subtract(Duration(minutes: offsetMinutes ?? 330));
  }

  Jatakam get chart => Jatakam.compute(utc, lat, lon);

  Map<String, Object?> toMap() => {
    'name': name,
    'local': local.toIso8601String(),
    'place': place,
    'lat': lat,
    'lon': lon,
    'tz': zone,
    'offset': offsetMinutes,
  };

  static BirthProfile fromMap(Map m) => BirthProfile(
    name: '${m['name'] ?? ''}',
    local: DateTime.parse('${m['local']}'),
    place: '${m['place'] ?? ''}',
    lat: (m['lat'] as num).toDouble(),
    lon: (m['lon'] as num).toDouble(),
    zone: m['tz'] as String?,
    offsetMinutes: m['offset'] as int?,
  );
}

class ProfilesNotifier extends Notifier<List<BirthProfile>> {
  static const _key = 'birth_profiles';

  @override
  List<BirthProfile> build() => [
    for (final m in (Boxes.prefs.get(_key) as List?) ?? const []) BirthProfile.fromMap(m as Map),
  ];

  Future<void> _save(List<BirthProfile> list) async {
    await Boxes.prefs.put(_key, [for (final p in list) p.toMap()]);
    state = list;
  }

  /// Adds [p], replacing a saved birth with the same name.
  Future<void> save(BirthProfile p) => _save([...state.where((x) => x.name != p.name), p]);

  Future<void> remove(BirthProfile p) => _save(state.where((x) => x.name != p.name).toList());
}

final profilesProvider = NotifierProvider<ProfilesNotifier, List<BirthProfile>>(ProfilesNotifier.new);
