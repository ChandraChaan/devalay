/// Marriage matching from the bride's and groom's birth nakshatra and rashi, worked out on the phone.
///
/// Two traditions:
/// - Ashtakoota Guna Milan (North India): eight kootas, 36 points.
/// - Dasha Porutham (South India, the "10 poruthams"): ten checks, each a match or not.
///
/// Nakshatras are 0-26 (Ashwini = 0), rashis 0-11 (Mesha = 0) and padas 1-4.
///
/// Sources the tables were checked against (November 2026):
/// - Varna and Vashya groups: Drik Panchang, "Varna Kuta" and "Vashya Kuta" tutorials.
/// - Vashya and Gana points (bride by groom), Tara rule, Yoni and Gana of each nakshatra: onlinejyotish.com,
///   "Marriage matching" articles. The Gana table also matches PyJHora's.
/// - Yoni points: the 14 x 14 chart on aaps.space; its seven 0-point pairs are the seven "mahavaira" pairs
///   onlinejyotish.com lists.
/// - Graha Maitri: the planets' natural friendships, scored 5 / 4 / 3 / 1 / 0.5 / 0 as hindutone.com
///   describes; this gives the same 7 x 7 table PyJHora prints.
/// - Bhakoot, Nadi groups and the score bands: hindutone.com and Drik Panchang's Kundali Match page.
/// - Porutham: hindutone.com, findyourfate.com and tuningmymelody.blogspot.com. Where they differ, two of the
///   three agreeing decided it (noted below). The Vasya rashi list is the classical one; AstroVed's list
///   agrees on ten of the twelve rashis.
library;

/// Rashi (0-11) that holds [pada] (1-4) of [nakshatra] (0-26). Each rashi spans nine padas.
int rashiOf(int nakshatra, int pada) => (nakshatra * 4 + pada - 1) ~/ 9;

/// The rashis [nakshatra] falls in: one, or two when it straddles a sign boundary.
List<int> rashisOf(int nakshatra) => {rashiOf(nakshatra, 1), rashiOf(nakshatra, 4)}.toList();

/// The padas of [nakshatra] that lie in [rashi].
List<int> padasIn(int nakshatra, int rashi) => [
  for (var p = 1; p <= 4; p++)
    if (rashiOf(nakshatra, p) == rashi) p,
];

/// One person's birth star: nakshatra and rashi of the Moon at birth, and the pada when known.
class BirthStar {
  const BirthStar(this.nakshatra, this.rashi, {this.pada});

  /// The rashi follows from the pada.
  BirthStar.withPada(this.nakshatra, int this.pada) : rashi = rashiOf(nakshatra, pada);

  final int nakshatra;
  final int rashi;
  final int? pada;

  bool get isValid =>
      nakshatra >= 0 &&
      nakshatra < 27 &&
      (pada == null
          ? rashisOf(nakshatra).contains(rashi)
          : pada! >= 1 && pada! <= 4 && rashiOf(nakshatra, pada!) == rashi);

  /// Where the Moon sits in the rashi, as the midpoint of the known pada (or of the nakshatra's part of the
  /// rashi when the pada is not given), in degrees 0-30.
  double get degreeInRashi {
    final padas = pada == null ? padasIn(nakshatra, rashi) : [pada!];
    final first = nakshatra * 4 + padas.first - 1 - rashi * 9;
    final last = nakshatra * 4 + padas.last - 1 - rashi * 9;
    return (first + last + 1) / 2 * 10 / 3;
  }

  @override
  bool operator ==(Object other) =>
      other is BirthStar && other.nakshatra == nakshatra && other.rashi == rashi && other.pada == pada;

  @override
  int get hashCode => Object.hash(nakshatra, rashi, pada);
}

/// Count from [from] to [to] with [from] as 1, round a circle of [n].
int countFrom(int from, int to, int n) => (to - from) % n + 1;

// ---------------------------------------------------------------------------------------------------------
// Classifications

enum Varna { brahmin, kshatriya, vaishya, shudra }

enum Vashya { chatushpada, manava, jalachara, vanachara, keeta }

enum Yoni { horse, elephant, sheep, serpent, dog, cat, rat, cow, buffalo, tiger, deer, monkey, mongoose, lion }

enum Gana { deva, manushya, rakshasa }

enum Nadi { adi, madhya, antya }

enum Planet { sun, moon, mars, mercury, jupiter, venus, saturn }

/// Rajju, the body part a nakshatra rules: feet, waist, navel, neck and head.
enum Rajju { pada, kati, nabhi, kantha, siro }

/// Tara, the 9-fold count from one nakshatra to another (remainder 1 = janma ... 0 = parama mitra).
enum Tara { janma, sampat, vipat, kshema, pratyari, sadhaka, vadha, mitra, paramaMitra }

const _varnaOfRashi = [
  Varna.kshatriya, Varna.vaishya, Varna.shudra, Varna.brahmin, // Mesha .. Karka
  Varna.kshatriya, Varna.vaishya, Varna.shudra, Varna.brahmin, // Simha .. Vrishchika
  Varna.kshatriya, Varna.vaishya, Varna.shudra, Varna.brahmin, // Dhanu .. Meena
];

Varna varnaOf(int rashi) => _varnaOfRashi[rashi];

/// Drik Panchang: Dhanu is manava for 0-15° and chatushpada after; Makara is chatushpada for 0-15° and
/// jalachara after. A pada that straddles 15° (Purva Ashadha 1, Shravana 2) goes with the later half.
Vashya vashyaOf(BirthStar s) => switch (s.rashi) {
  0 || 1 => Vashya.chatushpada,
  2 || 5 || 6 || 10 => Vashya.manava,
  3 || 11 => Vashya.jalachara,
  4 => Vashya.vanachara,
  7 => Vashya.keeta,
  8 => s.degreeInRashi < 15 ? Vashya.manava : Vashya.chatushpada,
  _ => s.degreeInRashi < 15 ? Vashya.chatushpada : Vashya.jalachara,
};

const _yoniOfNakshatra = [
  Yoni.horse,
  Yoni.elephant,
  Yoni.sheep,
  Yoni.serpent,
  Yoni.serpent,
  Yoni.dog,
  Yoni.cat,
  Yoni.sheep,
  Yoni.cat,
  Yoni.rat,
  Yoni.rat,
  Yoni.cow,
  Yoni.buffalo,
  Yoni.tiger,
  Yoni.buffalo,
  Yoni.tiger,
  Yoni.deer,
  Yoni.deer,
  Yoni.dog,
  Yoni.monkey,
  Yoni.mongoose,
  Yoni.monkey,
  Yoni.lion,
  Yoni.horse,
  Yoni.lion,
  Yoni.cow,
  Yoni.elephant,
];

Yoni yoniOf(int nakshatra) => _yoniOfNakshatra[nakshatra];

/// Ashwini, Bharani, Krittika: Deva, Manushya, Rakshasa, and so on in the classical order.
const _ganaOfNakshatra = [
  Gana.deva,
  Gana.manushya,
  Gana.rakshasa,
  Gana.manushya,
  Gana.deva,
  Gana.manushya,
  Gana.deva,
  Gana.deva,
  Gana.rakshasa,
  Gana.rakshasa,
  Gana.manushya,
  Gana.manushya,
  Gana.deva,
  Gana.rakshasa,
  Gana.deva,
  Gana.rakshasa,
  Gana.deva,
  Gana.rakshasa,
  Gana.rakshasa,
  Gana.manushya,
  Gana.manushya,
  Gana.deva,
  Gana.rakshasa,
  Gana.rakshasa,
  Gana.manushya,
  Gana.manushya,
  Gana.deva,
];

Gana ganaOf(int nakshatra) => _ganaOfNakshatra[nakshatra];

/// Nadi runs Adi, Madhya, Antya, then back Antya, Madhya, Adi, and so on.
Nadi nadiOf(int nakshatra) {
  final i = nakshatra % 6;
  return Nadi.values[i < 3 ? i : 5 - i];
}

/// Rajju climbs from the feet to the head and back down in a zigzag of nine.
Rajju rajjuOf(int nakshatra) {
  final i = nakshatra % 9;
  return Rajju.values[i < 5 ? i : 8 - i];
}

const _lordOfRashi = [
  Planet.mars, Planet.venus, Planet.mercury, Planet.moon, Planet.sun, Planet.mercury, //
  Planet.venus, Planet.mars, Planet.jupiter, Planet.saturn, Planet.saturn, Planet.jupiter,
];

Planet lordOf(int rashi) => _lordOfRashi[rashi];

/// Tara of [to] counted from [from].
Tara taraOf(int from, int to) => Tara.values[(countFrom(from, to, 27) - 1) % 9];

/// Vipat, pratyari and vadha (counts 3, 5 and 7 in each cycle of nine) are the unlucky taras.
bool isGoodTara(Tara t) => t != Tara.vipat && t != Tara.pratyari && t != Tara.vadha;

// ---------------------------------------------------------------------------------------------------------
// Planetary friendship (naisargika maitri)

enum Relation { friend, neutral, enemy }

const _friends = {
  Planet.sun: {Planet.moon, Planet.mars, Planet.jupiter},
  Planet.moon: {Planet.sun, Planet.mercury},
  Planet.mars: {Planet.sun, Planet.moon, Planet.jupiter},
  Planet.mercury: {Planet.sun, Planet.venus},
  Planet.jupiter: {Planet.sun, Planet.moon, Planet.mars},
  Planet.venus: {Planet.mercury, Planet.saturn},
  Planet.saturn: {Planet.mercury, Planet.venus},
};

const _enemies = {
  Planet.sun: {Planet.venus, Planet.saturn},
  Planet.moon: <Planet>{},
  Planet.mars: {Planet.mercury},
  Planet.mercury: {Planet.moon},
  Planet.jupiter: {Planet.mercury, Planet.venus},
  Planet.venus: {Planet.sun, Planet.moon},
  Planet.saturn: {Planet.sun, Planet.moon, Planet.mars},
};

/// How [a] regards [b].
Relation relation(Planet a, Planet b) {
  if (_friends[a]!.contains(b)) return Relation.friend;
  if (_enemies[a]!.contains(b)) return Relation.enemy;
  return Relation.neutral;
}

/// Graha Maitri points for two sign lords: 5 for the same lord or two friends, 4 friend and neutral,
/// 3 both neutral, 1 friend and enemy, 0.5 neutral and enemy, 0 both enemies.
double maitriPoints(Planet a, Planet b) {
  if (a == b) return 5;
  final pair = {relation(a, b), relation(b, a)};
  final both = pair.length == 1;
  if (pair.contains(Relation.enemy)) {
    if (both) return 0;
    return pair.contains(Relation.friend) ? 1 : 0.5;
  }
  if (both) return pair.first == Relation.friend ? 5 : 3;
  return 4;
}

// ---------------------------------------------------------------------------------------------------------
// Point tables

/// Vashya points, bride's group (rows) by groom's group (columns), from onlinejyotish.com.
const vashyaPoints = [
  [2.0, 1.0, 1.0, 0.0, 1.0],
  [1.0, 2.0, 0.5, 0.0, 1.0],
  [1.0, 0.5, 2.0, 1.0, 1.0],
  [0.0, 0.0, 1.0, 2.0, 0.0],
  [1.0, 0.0, 1.0, 0.0, 2.0],
];

/// Yoni points in [Yoni] order. Symmetric.
const yoniPoints = [
  [4, 2, 2, 3, 2, 2, 2, 1, 0, 1, 3, 3, 2, 1],
  [2, 4, 3, 3, 2, 2, 2, 2, 3, 1, 2, 3, 2, 0],
  [2, 3, 4, 2, 1, 2, 1, 3, 3, 1, 2, 0, 3, 1],
  [3, 3, 2, 4, 2, 1, 1, 1, 1, 2, 2, 2, 0, 2],
  [2, 2, 1, 2, 4, 2, 1, 2, 2, 1, 0, 2, 1, 1],
  [2, 2, 2, 1, 2, 4, 0, 2, 2, 1, 3, 3, 2, 1],
  [2, 2, 1, 1, 1, 0, 4, 2, 2, 2, 2, 2, 1, 2],
  [1, 2, 3, 1, 2, 2, 2, 4, 3, 0, 3, 2, 2, 1],
  [0, 3, 3, 1, 2, 2, 2, 3, 4, 1, 2, 2, 2, 1],
  [1, 1, 1, 2, 1, 1, 2, 0, 1, 4, 1, 1, 2, 1],
  [3, 2, 2, 2, 0, 3, 2, 3, 2, 1, 4, 2, 2, 1],
  [3, 3, 0, 2, 2, 3, 2, 2, 2, 1, 2, 4, 3, 2],
  [2, 2, 3, 0, 1, 2, 1, 2, 2, 2, 2, 3, 4, 2],
  [1, 0, 1, 2, 1, 1, 2, 1, 1, 1, 1, 2, 2, 4],
];

/// Gana points, bride's gana (rows) by groom's gana (columns).
const ganaPoints = [
  [6, 6, 0],
  [5, 6, 0],
  [1, 0, 6],
];

// ---------------------------------------------------------------------------------------------------------
// Ashtakoota

enum Koota { varna, vashya, tara, yoni, grahaMaitri, gana, bhakoot, nadi }

extension KootaMax on Koota {
  /// Varna 1, Vashya 2, ... Nadi 8: 36 in all.
  int get maxPoints => index + 1;
}

class KootaScore {
  const KootaScore(this.koota, this.points);
  final Koota koota;
  final double points;
  int get max => koota.maxPoints;
  bool get isFull => points == max;
  bool get isZero => points == 0;
}

/// Overall reading of the score, from Drik Panchang's bands.
enum GunaVerdict { excellent, veryGood, middling, notRecommended }

class AshtakootaResult {
  const AshtakootaResult(this.scores);
  final List<KootaScore> scores;

  double get total => scores.fold(0, (sum, s) => sum + s.points);
  KootaScore of(Koota k) => scores[k.index];

  /// Both Moons in the same Nadi.
  bool get nadiDosha => of(Koota.nadi).isZero;

  /// Moon signs 2/12, 5/9 or 6/8 from each other.
  bool get bhakootDosha => of(Koota.bhakoot).isZero;

  /// Drik Panchang: with Bhakoot favourable, 31+ is excellent, 21-30 very good, 17-20 middling. With Bhakoot
  /// unfavourable, 26+ is very good and 21-25 middling. An unfavourable Nadi outweighs any total.
  GunaVerdict get verdict {
    final t = total;
    if (nadiDosha) return GunaVerdict.notRecommended;
    if (bhakootDosha) {
      if (t >= 26) return GunaVerdict.veryGood;
      if (t >= 21) return GunaVerdict.middling;
      return GunaVerdict.notRecommended;
    }
    if (t >= 31) return GunaVerdict.excellent;
    if (t >= 21) return GunaVerdict.veryGood;
    if (t >= 17) return GunaVerdict.middling;
    return GunaVerdict.notRecommended;
  }
}

/// Bhakoot is lost when the Moon signs are 2/12, 5/9 or 6/8 from each other.
bool bhakootOk(int brideRashi, int groomRashi) =>
    !const {2, 12, 5, 9, 6, 8}.contains(countFrom(brideRashi, groomRashi, 12));

AshtakootaResult ashtakoota(BirthStar bride, BirthStar groom) {
  final b = bride.nakshatra, g = groom.nakshatra;
  final tara = (isGoodTara(taraOf(b, g)) ? 1.5 : 0.0) + (isGoodTara(taraOf(g, b)) ? 1.5 : 0.0);
  return AshtakootaResult([
    KootaScore(Koota.varna, varnaOf(groom.rashi).index <= varnaOf(bride.rashi).index ? 1 : 0),
    KootaScore(Koota.vashya, vashyaPoints[vashyaOf(bride).index][vashyaOf(groom).index]),
    KootaScore(Koota.tara, tara),
    KootaScore(Koota.yoni, yoniPoints[yoniOf(b).index][yoniOf(g).index].toDouble()),
    KootaScore(Koota.grahaMaitri, maitriPoints(lordOf(bride.rashi), lordOf(groom.rashi))),
    KootaScore(Koota.gana, ganaPoints[ganaOf(b).index][ganaOf(g).index].toDouble()),
    KootaScore(Koota.bhakoot, bhakootOk(bride.rashi, groom.rashi) ? 7 : 0),
    KootaScore(Koota.nadi, nadiOf(b) == nadiOf(g) ? 0 : 8),
  ]);
}

// ---------------------------------------------------------------------------------------------------------
// Dasha Porutham

enum Porutham { dina, gana, mahendra, streeDeergha, yoni, rasi, rasyadhipati, vasya, rajju, vedha }

/// Counts from the bride's star to the groom's that keep Dina. 17, 22 and 27 are left out by two of the three
/// sources (22 is vainasika, 27 the star just before the bride's).
const dinaCounts = {2, 4, 6, 8, 9, 11, 13, 15, 18, 20, 24, 26};

/// The same star for both keeps Dina only for these: Rohini, Ardra, Magha, Hasta, Vishakha, Shravana, Revati.
const dinaSameStar = {3, 5, 9, 12, 15, 21, 26};

const mahendraCounts = {4, 7, 10, 13, 16, 19, 22, 25};

/// Counts from the bride's rashi to the groom's that keep Rasi porutham: the same rashi or beyond the sixth,
/// except the eighth (6/8).
const rasiCounts = {1, 7, 9, 10, 11, 12};

/// The rashis each rashi holds in vasya (Mesha: Simha and Vrishchika, ...).
const vasyaRashis = [
  {4, 7},
  {3, 6},
  {5},
  {7, 8},
  {6},
  {2, 11},
  {5, 9},
  {3},
  {11},
  {0, 10},
  {0},
  {9},
];

/// Pairs of nakshatras that obstruct each other (vedha). Mrigashira, Chitra and Dhanishta all do.
const vedhaPairs = [
  {0, 17}, {1, 16}, {2, 15}, {3, 14}, {5, 21}, {6, 20}, {7, 19}, {8, 18}, //
  {9, 26}, {10, 25}, {11, 24}, {12, 23}, {4, 13}, {4, 22}, {13, 22},
];

bool isVedha(int a, int b) => vedhaPairs.any((p) => p.contains(a) && p.contains(b) && a != b);

/// The seven sworn-enemy yonis (horse-buffalo, elephant-lion, sheep-monkey, serpent-mongoose, dog-deer,
/// cat-rat, cow-tiger): the 0-point cells of [yoniPoints].
bool yoniEnemies(Yoni a, Yoni b) => yoniPoints[a.index][b.index] == 0;

class PoruthamResult {
  const PoruthamResult(this.matches);
  final Map<Porutham, bool> matches;

  bool operator [](Porutham p) => matches[p]!;
  int get count => matches.values.where((m) => m).length;

  /// Rajju and Vedha are the two a South Indian match is not made without.
  bool get essentialOk => this[Porutham.rajju] && this[Porutham.vedha];
}

PoruthamResult porutham(BirthStar bride, BirthStar groom) {
  final b = bride.nakshatra, g = groom.nakshatra;
  final count = countFrom(b, g, 27);
  final gb = ganaOf(b), gg = ganaOf(g);
  final lb = lordOf(bride.rashi), lg = lordOf(groom.rashi);
  return PoruthamResult({
    Porutham.dina: count == 1 ? dinaSameStar.contains(b) : dinaCounts.contains(count),
    // Same gana, or Deva with Manushya: the pairs that score 5 or 6 of 6 in Gana koota.
    Porutham.gana: gb == gg || (gb != Gana.rakshasa && gg != Gana.rakshasa),
    Porutham.mahendra: mahendraCounts.contains(count),
    Porutham.streeDeergha: count > 13,
    Porutham.yoni: !yoniEnemies(yoniOf(b), yoniOf(g)),
    Porutham.rasi: rasiCounts.contains(countFrom(bride.rashi, groom.rashi, 12)),
    // Lost when either lord counts the other an enemy.
    Porutham.rasyadhipati: relation(lb, lg) != Relation.enemy && relation(lg, lb) != Relation.enemy,
    Porutham.vasya: vasyaRashis[bride.rashi].contains(groom.rashi) || vasyaRashis[groom.rashi].contains(bride.rashi),
    Porutham.rajju: rajjuOf(b) != rajjuOf(g),
    Porutham.vedha: !isVedha(b, g),
  });
}
