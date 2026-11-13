import 'package:devalay/core/matching.dart';
import 'package:flutter_test/flutter_test.dart';

// Nakshatra and rashi numbers used below.
const ashwini = 0, bharani = 1, krittika = 2, rohini = 3, mrigashira = 4, ardra = 5, punarvasu = 6, pushya = 7;
const ashlesha = 8, magha = 9, uttaraPhalguni = 11, hasta = 12, chitra = 13, swati = 14, vishakha = 15;
const anuradha = 16, jyeshtha = 17, mula = 18, purvaAshadha = 19, uttaraAshadha = 20, shravana = 21;
const dhanishta = 22, shatabhisha = 23, purvaBhadrapada = 24, revati = 26;
const mesha = 0, vrishabha = 1, mithuna = 2, karka = 3, simha = 4, kanya = 5, tula = 6, vrishchika = 7;
const dhanu = 8, makara = 9, kumbha = 10, meena = 11;

void main() {
  group('birth star', () {
    test('rashi follows nakshatra and pada', () {
      expect(rashiOf(ashwini, 1), mesha);
      expect(rashiOf(krittika, 1), mesha);
      expect(rashiOf(krittika, 2), vrishabha);
      expect(rashiOf(mrigashira, 2), vrishabha);
      expect(rashiOf(mrigashira, 3), mithuna);
      expect(rashiOf(punarvasu, 4), karka);
      expect(rashiOf(uttaraAshadha, 1), dhanu);
      expect(rashiOf(uttaraAshadha, 2), makara);
      expect(rashiOf(purvaBhadrapada, 4), meena);
      expect(rashiOf(revati, 4), meena);
      expect(rashisOf(chitra), [kanya, tula]);
      expect(rashisOf(rohini), [vrishabha]);
      expect(padasIn(vishakha, vrishchika), [4]);
    });

    test('validity', () {
      expect(const BirthStar(krittika, mesha).isValid, isTrue);
      expect(const BirthStar(krittika, mithuna).isValid, isFalse);
      expect(const BirthStar(krittika, mesha, pada: 2).isValid, isFalse);
      expect(BirthStar.withPada(krittika, 2).rashi, vrishabha);
    });
  });

  group('classifications match the published lists', () {
    List<int> where<T>(T Function(int) f, T v) => [
      for (var n = 0; n < 27; n++)
        if (f(n) == v) n,
    ];

    test('gana (onlinejyotish.com, hindutone.com)', () {
      expect(where(ganaOf, Gana.deva), [
        ashwini,
        mrigashira,
        punarvasu,
        pushya,
        hasta,
        swati,
        anuradha,
        shravana,
        revati,
      ]);
      expect(where(ganaOf, Gana.rakshasa), [
        krittika,
        ashlesha,
        magha,
        chitra,
        vishakha,
        jyeshtha,
        mula,
        dhanishta,
        shatabhisha,
      ]);
    });

    test('nadi (hindutone.com)', () {
      expect(where(nadiOf, Nadi.adi), [
        ashwini,
        ardra,
        punarvasu,
        uttaraPhalguni,
        hasta,
        jyeshtha,
        mula,
        shatabhisha,
        purvaBhadrapada,
      ]);
      expect(where(nadiOf, Nadi.antya), [
        krittika,
        rohini,
        ashlesha,
        magha,
        swati,
        vishakha,
        uttaraAshadha,
        shravana,
        revati,
      ]);
    });

    test('rajju (hindutone.com, findyourfate.com)', () {
      expect(where(rajjuOf, Rajju.siro), [mrigashira, chitra, dhanishta]);
      expect(where(rajjuOf, Rajju.kantha), [rohini, ardra, hasta, swati, shravana, shatabhisha]);
      expect(where(rajjuOf, Rajju.nabhi), [
        krittika,
        punarvasu,
        uttaraPhalguni,
        vishakha,
        uttaraAshadha,
        purvaBhadrapada,
      ]);
      expect(where(rajjuOf, Rajju.pada), [ashwini, ashlesha, magha, jyeshtha, mula, revati]);
    });

    test('yoni (onlinejyotish.com)', () {
      expect(where(yoniOf, Yoni.horse), [ashwini, shatabhisha]);
      expect(where(yoniOf, Yoni.dog), [ardra, mula]);
      expect(where(yoniOf, Yoni.monkey), [purvaAshadha, shravana]);
      expect(where(yoniOf, Yoni.mongoose), [uttaraAshadha]);
      for (final y in Yoni.values) {
        expect(where(yoniOf, y), isNotEmpty);
      }
    });

    test('varna and vashya (Drik Panchang)', () {
      expect(
        [
          for (var r = 0; r < 12; r++)
            if (varnaOf(r) == Varna.brahmin) r,
        ],
        [karka, vrishchika, meena],
      );
      expect(
        [
          for (var r = 0; r < 12; r++)
            if (varnaOf(r) == Varna.shudra) r,
        ],
        [mithuna, tula, kumbha],
      );
      expect(vashyaOf(const BirthStar(rohini, vrishabha)), Vashya.chatushpada);
      expect(vashyaOf(const BirthStar(dhanishta, kumbha)), Vashya.manava);
      expect(vashyaOf(const BirthStar(magha, simha)), Vashya.vanachara);
      expect(vashyaOf(const BirthStar(jyeshtha, vrishchika)), Vashya.keeta);
      // Dhanu: manava to 15°, then chatushpada. Makara: chatushpada to 15°, then jalachara.
      expect(vashyaOf(const BirthStar(mula, dhanu)), Vashya.manava);
      expect(vashyaOf(const BirthStar(purvaAshadha, dhanu)), Vashya.chatushpada);
      expect(vashyaOf(BirthStar.withPada(uttaraAshadha, 1)), Vashya.chatushpada);
      expect(vashyaOf(BirthStar.withPada(uttaraAshadha, 2)), Vashya.chatushpada);
      expect(vashyaOf(BirthStar.withPada(shravana, 1)), Vashya.chatushpada);
      expect(vashyaOf(BirthStar.withPada(shravana, 3)), Vashya.jalachara);
      expect(vashyaOf(const BirthStar(dhanishta, makara)), Vashya.jalachara);
    });
  });

  group('point tables', () {
    test('graha maitri gives the published 7 x 7 table', () {
      // Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn.
      const published = [
        [5.0, 5.0, 5.0, 4.0, 5.0, 0.0, 0.0],
        [5.0, 5.0, 4.0, 1.0, 4.0, 0.5, 0.5],
        [5.0, 4.0, 5.0, 0.5, 5.0, 3.0, 0.5],
        [4.0, 1.0, 0.5, 5.0, 0.5, 5.0, 4.0],
        [5.0, 4.0, 5.0, 0.5, 5.0, 0.5, 3.0],
        [0.0, 0.5, 3.0, 5.0, 0.5, 5.0, 5.0],
        [0.0, 0.5, 0.5, 4.0, 3.0, 5.0, 5.0],
      ];
      for (final a in Planet.values) {
        for (final b in Planet.values) {
          expect(maitriPoints(a, b), published[a.index][b.index], reason: '$a $b');
        }
      }
    });

    test('yoni is symmetric with 0 only for the seven sworn enemies', () {
      final zeros = <String>{};
      for (final a in Yoni.values) {
        expect(yoniPoints[a.index][a.index], 4);
        for (final b in Yoni.values) {
          expect(yoniPoints[a.index][b.index], yoniPoints[b.index][a.index]);
          if (yoniPoints[a.index][b.index] == 0) zeros.add(([a.name, b.name]..sort()).join('-'));
        }
      }
      expect(zeros, {
        'buffalo-horse',
        'elephant-lion',
        'monkey-sheep',
        'mongoose-serpent',
        'deer-dog',
        'cat-rat',
        'cow-tiger',
      });
    });

    test('maximums add to 36', () {
      expect(Koota.values.fold<int>(0, (s, k) => s + k.maxPoints), 36);
    });
  });

  group('ashtakoota', () {
    test("hindutone.com's worked example: bride Rohini (Vrishabha), groom Pushya (Karka)", () {
      final r = ashtakoota(const BirthStar(rohini, vrishabha), const BirthStar(pushya, karka));
      expect(r.of(Koota.varna).points, 1);
      expect(r.of(Koota.tara).points, 1.5);
      expect(r.of(Koota.grahaMaitri).points, 0.5);
      expect(r.of(Koota.bhakoot).points, 7);
      expect(r.of(Koota.nadi).points, 8);
      // From the tables: Vashya chatushpada-jalachara 1, Yoni serpent-sheep 2, Gana bride Manushya-groom Deva 5.
      expect(r.of(Koota.vashya).points, 1);
      expect(r.of(Koota.yoni).points, 2);
      expect(r.of(Koota.gana).points, 5);
      expect(r.total, 26);
      expect(r.verdict, GunaVerdict.veryGood);
    });

    test('same star: 28 points, but Nadi dosha makes it inauspicious (Drik Panchang)', () {
      const s = BirthStar(ashwini, mesha);
      final r = ashtakoota(s, s);
      expect(r.total, 28);
      expect(r.nadiDosha, isTrue);
      expect(r.verdict, GunaVerdict.notRecommended);
    });

    test('tara counts both ways', () {
      // Ashwini to Krittika is 3 (vipat); Krittika to Ashwini is 26 (remainder 8, mitra).
      expect(taraOf(ashwini, krittika), Tara.vipat);
      expect(taraOf(krittika, ashwini), Tara.mitra);
      final r = ashtakoota(const BirthStar(ashwini, mesha), const BirthStar(krittika, mesha));
      expect(r.of(Koota.tara).points, 1.5);
    });

    test('varna counts only when the groom is equal or higher', () {
      final up = ashtakoota(const BirthStar(rohini, vrishabha), const BirthStar(pushya, karka));
      final down = ashtakoota(const BirthStar(pushya, karka), const BirthStar(rohini, vrishabha));
      expect(up.of(Koota.varna).points, 1);
      expect(down.of(Koota.varna).points, 0);
    });

    test('bhakoot dosha for 2/12, 5/9 and 6/8', () {
      expect(bhakootOk(mesha, vrishabha), isFalse);
      expect(bhakootOk(mesha, simha), isFalse);
      expect(bhakootOk(mesha, kanya), isFalse);
      expect(bhakootOk(mesha, vrishchika), isFalse);
      expect(bhakootOk(mesha, mithuna), isTrue);
      expect(bhakootOk(mesha, tula), isTrue);
      expect(bhakootOk(mesha, mesha), isTrue);
    });

    test('every valid pair scores within range', () {
      final stars = [
        for (var n = 0; n < 27; n++)
          for (final r in rashisOf(n)) BirthStar(n, r),
      ];
      for (final b in stars) {
        for (final g in stars) {
          final r = ashtakoota(b, g);
          for (final s in r.scores) {
            expect(s.points, inInclusiveRange(0, s.max));
          }
          expect(porutham(b, g).count, inInclusiveRange(0, 10));
        }
      }
    });
  });

  group('porutham', () {
    test('rajju: Mula and Jyeshtha are both feet (tuningmymelody example)', () {
      final p = porutham(const BirthStar(mula, dhanu), const BirthStar(jyeshtha, vrishchika));
      expect(p[Porutham.rajju], isFalse);
      expect(p.essentialOk, isFalse);
    });

    test('vedha pairs', () {
      expect(isVedha(ashwini, jyeshtha), isTrue);
      expect(isVedha(rohini, swati), isTrue);
      expect(isVedha(mrigashira, dhanishta), isTrue);
      expect(isVedha(chitra, mrigashira), isTrue);
      expect(isVedha(ashwini, bharani), isFalse);
      expect(isVedha(mrigashira, mrigashira), isFalse);
    });

    test('counts from the bride', () {
      // Bride Ashwini, groom Pushya: count 8. Dina yes, Mahendra no, Stree Deergha no.
      final p = porutham(const BirthStar(ashwini, mesha), const BirthStar(pushya, karka));
      expect(p[Porutham.dina], isTrue);
      expect(p[Porutham.mahendra], isFalse);
      expect(p[Porutham.streeDeergha], isFalse);
      // Bride Ashwini, groom Uttara Ashadha: count 21. Mahendra no, Stree Deergha yes, Dina no.
      final q = porutham(const BirthStar(ashwini, mesha), const BirthStar(uttaraAshadha, makara));
      expect(q[Porutham.dina], isFalse);
      expect(q[Porutham.streeDeergha], isTrue);
      // Bride Ashwini, groom Rohini: count 4. Mahendra yes.
      expect(porutham(const BirthStar(ashwini, mesha), const BirthStar(rohini, vrishabha))[Porutham.mahendra], isTrue);
    });

    test('same star keeps Dina only for the listed stars', () {
      expect(porutham(const BirthStar(rohini, vrishabha), const BirthStar(rohini, vrishabha))[Porutham.dina], isTrue);
      expect(porutham(const BirthStar(bharani, mesha), const BirthStar(bharani, mesha))[Porutham.dina], isFalse);
    });

    test('gana, rasi, rasyadhipati, vasya, yoni', () {
      // Bride Rohini (Vrishabha, Manushya, serpent), groom Pushya (Karka, Deva, sheep).
      final p = porutham(const BirthStar(rohini, vrishabha), const BirthStar(pushya, karka));
      expect(p[Porutham.gana], isTrue);
      expect(p[Porutham.rasi], isFalse); // Karka is 3rd from Vrishabha.
      expect(p[Porutham.rasyadhipati], isFalse); // Venus counts the Moon an enemy.
      expect(p[Porutham.vasya], isTrue); // Karka is vasya to Vrishabha.
      expect(p[Porutham.yoni], isTrue);
      // Bride Ashwini (horse), groom Hasta (buffalo): sworn enemies.
      expect(porutham(const BirthStar(ashwini, mesha), const BirthStar(hasta, kanya))[Porutham.yoni], isFalse);
      // Deva bride, Rakshasa groom.
      expect(porutham(const BirthStar(ashwini, mesha), const BirthStar(magha, simha))[Porutham.gana], isFalse);
      // Rasi: 7th from the bride's rashi is good, 8th is not.
      expect(porutham(const BirthStar(ashwini, mesha), const BirthStar(swati, tula))[Porutham.rasi], isTrue);
      expect(porutham(const BirthStar(ashwini, mesha), const BirthStar(jyeshtha, vrishchika))[Porutham.rasi], isFalse);
      // Vasya either way: Mesha holds Simha.
      expect(porutham(const BirthStar(magha, simha), const BirthStar(ashwini, mesha))[Porutham.vasya], isTrue);
    });
  });
}
