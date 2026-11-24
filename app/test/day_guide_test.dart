import 'package:devalay/core/day_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Disha Shool by weekday', () {
    expect(
      [for (var d = DateTime.monday; d <= DateTime.sunday; d++) dishaShool(d)],
      [
        Direction.east, // Monday
        Direction.north, // Tuesday
        Direction.north, // Wednesday
        Direction.south, // Thursday
        Direction.west, // Friday
        Direction.east, // Saturday
        Direction.west, // Sunday
      ],
    );
  });

  test('every nakshatra has a nature, in the classic groups', () {
    final counts = <StarNature, int>{};
    for (var n = 1; n <= 27; n++) {
      counts.update(starNature(n), (c) => c + 1, ifAbsent: () => 1);
    }
    expect(counts, {
      StarNature.fixed: 4,
      StarNature.movable: 5,
      StarNature.swift: 3,
      StarNature.soft: 4,
      StarNature.sharp: 4,
      StarNature.fierce: 5,
      StarNature.mixed: 2,
    });
    expect(starNature(8), StarNature.swift); // Pushya
    expect(starNature(19), StarNature.sharp); // Mula
  });

  test('tithi notes: Rikta, Ekadashi, Purnima and Amavasya', () {
    expect(tithiNote('en', 4)!.avoid, isTrue); // Shukla Chaturthi
    expect(tithiNote('en', 24)!.avoid, isTrue); // Krishna Navami
    expect(tithiNote('en', 29)!.avoid, isTrue); // Krishna Chaturdashi
    expect(tithiNote('en', 30)!.text, startsWith('Amavasya'));
    expect(tithiNote('en', 15)!.text, startsWith('Purnima'));
    expect(tithiNote('en', 26)!.text, startsWith('Ekadashi'));
    expect(tithiNote('en', 2), isNull);
  });
}
