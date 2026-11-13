import 'dart:convert';
import 'dart:io';

import 'package:devalay/core/gochara.dart';
import 'package:devalay/core/jyotish.dart';
import 'package:devalay/core/location.dart';
import 'package:devalay/core/static_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Muhurtham, eclipse and gochara data as the server exports it (fixtures from backend/app/services).
void main() {
  Object load(String name) => jsonDecode(File('test/data/$name').readAsStringSync());
  final tx = Transits(load('gochara_2026.json') as Map);

  test('static files for the new endpoints', () {
    final hyd = cities.firstWhere((c) => c.id == 'hyderabad');
    expect(StaticApi.file('/muhurtham', hyd.query), 'muhurtham/city-hyderabad.json');
    expect(StaticApi.file('/eclipses', hyd.query), 'eclipses/city-hyderabad.json');
    expect(StaticApi.file('/gochara', null), 'gochara/index.json');
  });

  test('muhurtham days keep the local clock', () {
    final data = load('muhurtham_hyderabad.json') as Map;
    final vivaha = [for (final d in (data['kinds'] as Map)['vivaha'] as List) MuhurthamDay('vivaha', d as Map)];
    // Drik Panchang, Hyderabad: 18 January 2027, 9:05 pm to 9:12 pm.
    final d = vivaha.firstWhere((x) => x.date == DateTime(2027, 1, 18));
    expect(d.at(d.windows.first.$1), DateTime(2027, 1, 18, 21, 5));
    expect(d.at(d.windows.first.$2), DateTime(2027, 1, 18, 21, 13));
    final night = vivaha.firstWhere((x) => x.date == DateTime(2027, 1, 19));
    expect(night.at(night.windows.last.$2).day, 20); // runs past midnight to the next sunrise
    expect(night.lagna!.$3, 6); // Tula
  });

  test('eclipses parse with Sutak only when visible', () {
    final all = [for (final e in load('eclipses_delhi.json') as List) Eclipse(e as Map)];
    final march = all.firstWhere((e) => !e.solar && e.date == DateTime(2026, 3, 3));
    expect(march.type, 'total');
    expect(march.sutakStart, DateTime(2026, 3, 3, 6, 20));
    expect(march.title('en'), 'Total lunar eclipse');
    expect(march.note('en'), contains('Sutak from 6:20 AM'));
    final august = all.firstWhere((e) => e.solar && e.date == DateTime(2027, 8, 2));
    expect(august.title('en'), 'Partial solar eclipse');
    expect(all.where((e) => !e.visible).every((e) => e.sutakStart == null), isTrue);
    expect(all.firstWhere((e) => e.type == 'penumbral' && e.visible).note('en'), contains('no Sutak'));
  });

  test('transits answer sign and house questions', () {
    // Saturn enters Mesha on 3 June 2027 and returns to Meena in October; Jupiter turns back into Karka.
    expect(tx.signOn('saturn', DateTime(2027, 5, 1)), 11);
    expect(tx.signOn('saturn', DateTime(2027, 7, 1)), 0);
    expect(tx.changes('jupiter', DateTime(2027, 1, 1), DateTime(2027, 1, 31)).single.$2, 3);
    expect(houseFrom(11, 0), 2);
    expect(periodSpan(Period.week, DateTime(2026, 11, 13)), (DateTime(2026, 11, 9), DateTime(2026, 11, 15)));
  });

  test('period readings are built from the transits', () {
    for (final period in Period.values) {
      for (var rashi = 0; rashi < 12; rashi++) {
        final r = periodReading('en', tx, rashi, period, DateTime(2027, 3, 10));
        expect(r.stars, inInclusiveRange(1, 5));
        expect(r.overview, isNotEmpty);
        expect(r.sections, isNotEmpty);
      }
    }
    // Saturn in Meena all of March 2027: Meena natives are in the peak of Sade Sati.
    final meena = periodReading('en', tx, 11, Period.month, DateTime(2027, 3, 1));
    expect(meena.sections.map((s) => s.text).join(), contains('peak of Sade Sati'));
    // The Sun enters Meena around 15 March 2027, so the month mentions the change.
    final mesha = periodReading('en', tx, 0, Period.month, DateTime(2027, 3, 1));
    expect(mesha.sections.firstWhere((s) => s.title == 'Sun').text, contains('moves into'));
    // Chandrashtamam: the Moon in the 8th from the Moon sign on those days.
    final week = periodReading('en', tx, 4, Period.week, DateTime(2027, 3, 10));
    for (final d in week.careDays) {
      expect(houseFrom(4, tx.moonOn(d)), 8);
    }
    final hindi = periodReading('hi', tx, 4, Period.year, DateTime(2027, 3, 10));
    expect(hindi.overview, isNot(contains('year')));
  });
}
