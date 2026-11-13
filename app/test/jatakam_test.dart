import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/jatakam.dart';
import 'package:flutter_test/flutter_test.dart';

/// The on-phone Jatakam against JPL DE421 (Skyfield), for 150 births from 1900 to 2049
/// (test/data/jatakam_vectors.json, written by backend/scripts/jatakam_vectors.py).
void main() {
  final cases = (jsonDecode(File('test/data/jatakam_vectors.json').readAsStringSync()) as List).cast<Map>();
  double diff(num a, num b) => ((a - b + 540) % 360 - 180).abs().toDouble();
  Jatakam chart(Map c) =>
      Jatakam.compute(DateTime.parse(c['utc'] as String), (c['lat'] as num).toDouble(), (c['lon'] as num).toDouble());

  // Degrees. Meeus' Sun and Moon are good to seconds of arc; JPL's Table 1 elements to about 0.2 degree
  // for Jupiter and Saturn (its stated accuracy for 1800-2050).
  const tolerance = {
    'sun': 0.015,
    'moon': 0.008,
    'mercury': 0.03,
    'venus': 0.04,
    'mars': 0.06,
    'jupiter': 0.25,
    'saturn': 0.3,
    'ascendant': 0.01,
  };
  const grahas = {
    'sun': Graha.sun,
    'moon': Graha.moon,
    'mercury': Graha.mercury,
    'venus': Graha.venus,
    'mars': Graha.mars,
    'jupiter': Graha.jupiter,
    'saturn': Graha.saturn,
  };

  test('every graha and the lagna agree with DE421', () {
    for (final c in cases) {
      final j = chart(c);
      for (final MapEntry(key: k, value: g) in grahas.entries) {
        expect(diff(j.of(g), c[k] as num), lessThan(tolerance[k]!), reason: '$k for ${c['utc']}');
      }
      expect(diff(j.lagna, c['ascendant'] as num), lessThan(tolerance['ascendant']!), reason: 'lagna ${c['utc']}');
      expect((j.ayanamsa - (c['ayanamsa'] as num)).abs(), lessThan(1e-5));
    }
  });

  test('Moon nakshatra, pada and rashi and the lagna sign match', () {
    for (final c in cases) {
      final j = chart(c);
      final moon = (c['moon'] as num).toDouble();
      if (j.boundaries(moonMargin: 0.01, lagnaMargin: 0.02).isNotEmpty) continue;
      expect(j.nakshatra, moon ~/ (360 / 27));
      expect(j.pada, (moon % (360 / 27)) ~/ (360 / 108) + 1);
      expect(j.moonRashi, moon ~/ 30);
      expect(j.lagnaRashi, (c['ascendant'] as num) ~/ 30);
    }
  });

  test('births near a boundary are flagged', () {
    // 1 January 2000, 00:00 UTC, New Delhi: lagna near the end of Kanya.
    final j = Jatakam.compute(DateTime.utc(2000), 28.61, 77.21);
    expect(j.boundaries(lagnaMargin: 30), contains(Boundary.lagna));
    expect(j.lagnaMinutesToEdge, lessThanOrEqualTo(60));
    expect(j.house(Graha.ketu), (j.house(Graha.rahu) + 5) % 12 + 1);
  });
}
