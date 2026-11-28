import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'age.dart' as age;
import 'age.dart' show ageGroupFor;
import 'jatakam.dart';
import 'location.dart';
import 'muhurta.dart';
import 'profiles.dart';
import 'storage.dart';

/// "About you": the user's own name and birth details, and the stars worked out from them.
///
/// Everything is optional. It is kept on the phone (Hive prefs, key 'profile'); the rashi and birth star
/// it gives are also written to the prefs the rest of the app already reads ('rashi', 'birth_star'), so
/// Tarabalam, Chandrabalam, Rashifal and the morning Panchang follow the profile. A short copy goes to
/// the owner's statistics only while "Share usage statistics" is on ([toInstall]), and a backup to the
/// user's own Google account when they sign in (core/account.dart).
enum Gender { male, female, other }

@immutable
class AboutYou {
  const AboutYou({
    this.name = '',
    this.gender,
    this.birthDate,
    this.birthMinutes,
    this.placeId,
    this.place = '',
    this.lat,
    this.lon,
    this.zone,
    this.gotra = '',
    this.rashi,
    this.nakshatra,
    this.pada,
    this.lagna,
    this.starsByHand = false,
    this.updated,
  });

  static const empty = AboutYou();

  final String name;
  final Gender? gender;

  /// Date of birth (the time is in [birthMinutes]).
  final DateTime? birthDate;

  /// Time of birth as minutes after local midnight, or null when not known.
  final int? birthMinutes;

  /// Place of birth: a city from the app's list ([placeId], [zone]) with its position.
  final String? placeId;
  final String place;
  final double? lat, lon;
  final String? zone;

  final String gotra;

  /// Moon sign 0 (Mesha) to 11, birth nakshatra 0 (Ashwini) to 26 with pada 1 to 4, lagna 0 to 11.
  final int? rashi, nakshatra, pada, lagna;

  /// The user set the stars themselves (from their own horoscope); they are not recomputed.
  final bool starsByHand;
  final DateTime? updated;

  bool get isEmpty =>
      name.isEmpty &&
      gender == null &&
      birthDate == null &&
      placeId == null &&
      gotra.isEmpty &&
      rashi == null &&
      nakshatra == null &&
      lagna == null;

  /// First name only, for greetings ("Ravi" from "Ravi Kumar").
  String get firstName {
    final n = name.trim();
    if (n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  bool get hasPlace => lat != null && lon != null && placeId != null;

  int? ageOn(DateTime today) => birthDate == null ? null : age.ageOn(birthDate!, today);

  String? ageGroupOn(DateTime today) => birthDate == null ? null : ageGroupFor(birthDate!, today);

  /// Under 18 by the date of birth given. Unknown ages are not treated as minors.
  bool isMinorOn(DateTime today) => (ageOn(today) ?? 99) < 18;

  /// Born on 29 February: celebrated on 28 February in other years.
  bool isBirthday(DateTime today) {
    final b = birthDate;
    if (b == null || b.year > today.year) return false;
    final next = birthdayIn(today.year);
    return next != null && next.month == today.month && next.day == today.day;
  }

  DateTime? birthdayIn(int year) {
    final b = birthDate;
    if (b == null) return null;
    final leap = DateTime(year, 2, 29).month == 2;
    if (b.month == 2 && b.day == 29 && !leap) return DateTime(year, 2, 28);
    return DateTime(year, b.month, b.day);
  }

  /// The next birthday on or after [from]'s date.
  DateTime? nextBirthday(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final thisYear = birthdayIn(today.year);
    if (thisYear == null) return null;
    return thisYear.isBefore(today) ? birthdayIn(today.year + 1) : thisYear;
  }

  /// The birth for the Jatakam screen; noon when the time is not known.
  BirthProfile? get birth {
    final b = birthDate;
    if (b == null || !hasPlace) return null;
    final m = birthMinutes ?? 12 * 60;
    return BirthProfile(
      name: name.trim(),
      local: DateTime(b.year, b.month, b.day, m ~/ 60, m % 60),
      place: place,
      lat: lat!,
      lon: lon!,
      zone: zone,
    );
  }

  /// Rashi, nakshatra, pada and lagna from the birth details, as far as they are certain: without a
  /// birth time the lagna is unknown, and the Moon's sign and star are given only when they stay the same
  /// all day. Null when the date or place is missing.
  ({int? rashi, int? nakshatra, int? pada, int? lagna})? computeStars() {
    final b = birthDate;
    if (b == null || !hasPlace) return null;
    try {
      Jatakam at(int minutes) => BirthProfile(
        name: '',
        local: DateTime(b.year, b.month, b.day, minutes ~/ 60, minutes % 60),
        place: place,
        lat: lat!,
        lon: lon!,
        zone: zone,
      ).chart;
      if (birthMinutes case final m?) {
        final c = at(m);
        return (rashi: c.moonRashi, nakshatra: c.nakshatra, pada: c.pada, lagna: c.lagnaRashi);
      }
      final start = at(0), end = at(23 * 60 + 59);
      return (
        rashi: start.moonRashi == end.moonRashi ? start.moonRashi : null,
        nakshatra: start.nakshatra == end.nakshatra ? start.nakshatra : null,
        pada: null,
        lagna: null,
      );
    } catch (e) {
      debugPrint('Profile: could not work out the stars: $e');
      return null;
    }
  }

  /// This profile with the stars recomputed from the birth details, unless the user set them by hand.
  AboutYou withComputedStars() {
    if (starsByHand) return this;
    final s = computeStars();
    if (s == null) return this;
    return copyWith(rashi: () => s.rashi, nakshatra: () => s.nakshatra, pada: () => s.pada, lagna: () => s.lagna);
  }

  AboutYou copyWith({
    String? name,
    Gender? Function()? gender,
    DateTime? Function()? birthDate,
    int? Function()? birthMinutes,
    City? Function()? city,
    String? gotra,
    int? Function()? rashi,
    int? Function()? nakshatra,
    int? Function()? pada,
    int? Function()? lagna,
    bool? starsByHand,
    DateTime? updated,
  }) {
    final c = city == null ? null : city();
    final keepPlace = city == null;
    return AboutYou(
      name: name ?? this.name,
      gender: gender == null ? this.gender : gender(),
      birthDate: birthDate == null ? this.birthDate : birthDate(),
      birthMinutes: birthMinutes == null ? this.birthMinutes : birthMinutes(),
      placeId: keepPlace ? placeId : c?.id,
      place: keepPlace ? place : (c?.name ?? ''),
      lat: keepPlace ? lat : c?.lat,
      lon: keepPlace ? lon : c?.lon,
      zone: keepPlace ? zone : c?.tz,
      gotra: gotra ?? this.gotra,
      rashi: rashi == null ? this.rashi : rashi(),
      nakshatra: nakshatra == null ? this.nakshatra : nakshatra(),
      pada: pada == null ? this.pada : pada(),
      lagna: lagna == null ? this.lagna : lagna(),
      starsByHand: starsByHand ?? this.starsByHand,
      updated: updated ?? this.updated,
    );
  }

  Map<String, Object?> toMap() => {
    if (name.isNotEmpty) 'name': name,
    if (gender != null) 'gender': gender!.name,
    if (birthDate != null) 'dob': isoDate(birthDate!),
    'tob': ?birthMinutes,
    'placeId': ?placeId,
    if (place.isNotEmpty) 'place': place,
    'lat': ?lat,
    'lon': ?lon,
    'tz': ?zone,
    if (gotra.isNotEmpty) 'gotra': gotra,
    'rashi': ?rashi,
    'nakshatra': ?nakshatra,
    'pada': ?pada,
    'lagna': ?lagna,
    if (starsByHand) 'byHand': true,
    if (updated != null) 'updated': updated!.toUtc().toIso8601String(),
  };

  /// Reads what [toMap] wrote, or a backup from the cloud. Anything malformed is dropped, never thrown.
  static AboutYou fromMap(Map? m) {
    if (m == null) return empty;
    String str(Object? v, int max) {
      final s = v is String ? v.trim() : '';
      return s.length > max ? s.substring(0, max) : s;
    }

    int? idx(Object? v, int from, int to) => v is int && v >= from && v <= to ? v : null;
    double? deg(Object? v, double max) => v is num && v.isFinite && v.abs() <= max ? v.toDouble() : null;
    final dob = m['dob'] is String ? DateTime.tryParse(m['dob'] as String) : null;
    final placeId = m['placeId'] is String ? m['placeId'] as String : null;
    final city = placeId == null ? null : cityById(placeId);
    final lat = deg(m['lat'], 90), lon = deg(m['lon'], 180);
    final placed = city != null || (placeId != null && lat != null && lon != null);
    return AboutYou(
      name: str(m['name'], 60),
      gender: Gender.values.where((g) => g.name == m['gender']).firstOrNull,
      birthDate: dob == null ? null : DateTime(dob.year, dob.month, dob.day),
      birthMinutes: idx(m['tob'], 0, 24 * 60 - 1),
      placeId: placed ? placeId : null,
      place: placed ? str(m['place'], 80).ifEmpty(city?.name ?? '') : '',
      lat: placed ? (lat ?? city?.lat) : null,
      lon: placed ? (lon ?? city?.lon) : null,
      zone: placed ? (m['tz'] is String ? m['tz'] as String : city?.tz) : null,
      gotra: str(m['gotra'], 40),
      rashi: idx(m['rashi'], 0, 11),
      nakshatra: idx(m['nakshatra'], 0, 26),
      pada: idx(m['pada'], 1, 4),
      lagna: idx(m['lagna'], 0, 11),
      starsByHand: m['byHand'] == true,
      updated: m['updated'] is String ? DateTime.tryParse(m['updated'] as String) : null,
    );
  }

  /// The copy in the owner's usage statistics (installs/{uid}.profile), sent only while the user shares
  /// usage statistics. The city name stands for the place (no coordinates).
  Map<String, Object> toInstall(DateTime today) => {
    if (name.trim().isNotEmpty) 'n': _cut(name.trim(), 40),
    if (gender != null) 'g': gender!.name[0],
    if (birthDate != null) 'dob': isoDate(birthDate!),
    'tob': ?birthMinutes,
    'ag': ?ageGroupOn(today),
    'r': ?rashi,
    's': ?nakshatra,
    'l': ?lagna,
    if (place.isNotEmpty) 'bp': _cut(place, 60),
    if (gotra.isNotEmpty) 'go': _cut(gotra, 40),
  };

  @override
  bool operator ==(Object other) => other is AboutYou && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().entries.map((e) => '${e.key}=${e.value}'));
}

String _cut(String s, int max) => s.length > max ? s.substring(0, max) : s;

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

City? cityById(String id) => cities.where((c) => c.id == id).firstOrNull;

/// Things that should follow the profile when it changes: the usage-statistics copy, the birthday
/// notification and the Google backup. Set by main.dart (core/profile_sync.dart); tests leave it empty.
typedef ProfileListener = Future<void> Function(AboutYou profile);
final profileListeners = <ProfileListener>[];

class AboutYouNotifier extends Notifier<AboutYou> {
  static const key = 'profile';

  @override
  AboutYou build() => AboutYou.fromMap(Boxes.prefs.get(key) as Map?);

  /// Saves [p] (stars recomputed unless set by hand) and points the app's rashi and birth star at it.
  Future<void> save(AboutYou p) async {
    final next = p.withComputedStars().copyWith(updated: DateTime.now().toUtc());
    await _write(next);
    final prefs = ref.read(prefsProvider.notifier);
    if (next.nakshatra != null) await prefs.set('birth_star', next.nakshatra);
    if (next.rashi != null) await prefs.setRashi(rashiNames[next.rashi!].toLowerCase());
  }

  /// Replaces the profile with one restored from a backup, without stamping it as a new edit.
  Future<void> restore(AboutYou p) async {
    await _write(p);
    final prefs = ref.read(prefsProvider.notifier);
    if (p.nakshatra != null) await prefs.set('birth_star', p.nakshatra);
    if (p.rashi != null) await prefs.setRashi(rashiNames[p.rashi!].toLowerCase());
  }

  /// The birth-star sheet on Home changed the star or sign: keep the profile in step (as set by hand).
  Future<void> starsChanged({int? nakshatra, int? rashi}) async {
    final p = state;
    if (p.isEmpty || (p.nakshatra == nakshatra && p.rashi == rashi)) return;
    final pada = p.nakshatra == nakshatra ? p.pada : null;
    await _write(
      p.copyWith(
        nakshatra: () => nakshatra,
        rashi: () => rashi,
        pada: () => pada,
        starsByHand: true,
        updated: DateTime.now().toUtc(),
      ),
    );
  }

  /// Removes the profile from the phone. The rashi and birth star it set stay unless [stars] is true.
  Future<void> clear({bool stars = false}) async {
    final old = state;
    await _write(AboutYou.empty);
    if (stars) {
      final prefs = ref.read(prefsProvider.notifier);
      if (old.nakshatra != null && ref.read(prefsProvider).birthStar == old.nakshatra) {
        await prefs.set('birth_star', null);
      }
      if (old.rashi != null && ref.read(prefsProvider).rashi == rashiNames[old.rashi!].toLowerCase()) {
        await prefs.setRashi(null);
      }
    }
  }

  Future<void> _write(AboutYou p) async {
    if (p.isEmpty) {
      await Boxes.prefs.delete(key);
    } else {
      await Boxes.prefs.put(key, p.toMap());
    }
    state = p;
    for (final l in profileListeners) {
      try {
        await l(p);
      } catch (e) {
        debugPrint('Profile listener failed: $e');
      }
    }
  }
}

final aboutYouProvider = NotifierProvider<AboutYouNotifier, AboutYou>(AboutYouNotifier.new);
