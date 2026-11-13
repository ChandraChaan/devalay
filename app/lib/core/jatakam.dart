import 'dart:math';

/// Jatakam (birth chart) worked out on the phone, so it needs no server.
///
/// - Sun: Meeus, Astronomical Algorithms (2nd ed.), chapter 25, with nutation and aberration.
/// - Moon: Meeus chapter 47 (the ELP-2000/82 series truncated to its 60 largest longitude terms).
/// - Planets: JPL's "Keplerian Elements for Approximate Positions of the Major Planets", Table 1
///   (E. M. Standish, valid 1800-2050), https://ssd.jpl.nasa.gov/planets/approx_pos.html.
/// - Rahu: the Moon's mean ascending node (Meeus 47.7); Ketu is opposite.
/// - Time: ΔT polynomials of Espenak and Meeus (NASA, https://eclipse.gsfc.nasa.gov/SEhelp/deltatpoly2004.html);
///   sidereal time from Meeus 12.4; nutation from Meeus chapter 22 (the four largest terms).
/// - Sidereal longitudes use the Lahiri ayanamsa exactly as the server's Panchang does, so the phone and the
///   calendar agree on nakshatras.
///
/// test/jatakam_test.dart checks every body against JPL DE421 (via Skyfield) for 150 births from 1900 to 2049.
class Jatakam {
  Jatakam._(this.utc, this.lat, this.lon, this.ayanamsa, this.lagna, this.grahas);

  /// Birth moment in UTC, place (degrees, east and north positive).
  final DateTime utc;
  final double lat, lon;
  final double ayanamsa;

  /// Sidereal longitude of the ascendant.
  final double lagna;

  /// Sidereal longitudes of the nine grahas, in [Graha] order.
  final List<double> grahas;

  static Jatakam compute(DateTime utc, double lat, double lon) {
    final jdUt = julianDay(utc);
    final jd = jdUt + deltaT(utc.year + (utc.month - 0.5) / 12) / 86400;
    final aya = lahiri(jd);
    final nut = _Nutation(jd);
    double sid(double tropical) => _norm(tropical - aya);
    final rahu = _norm(meanNode(jd) + nut.dPsi - aya);
    final planets = [for (final p in _planets) sid(_planetLongitude(p, jd) + nut.dPsi)];
    return Jatakam._(utc, lat, lon, aya, sid(_ascendant(jdUt, jd, lat, lon, nut)), [
      sid(sunLongitude(jd) + nut.dPsi),
      sid(moonLongitude(jd) + nut.dPsi),
      planets[2], // Mars
      planets[0], // Mercury
      planets[3], // Jupiter
      planets[1], // Venus
      planets[4], // Saturn
      rahu,
      _norm(rahu + 180),
    ]);
  }

  double of(Graha g) => grahas[g.index];

  int get lagnaRashi => lagna ~/ 30;
  int get moonRashi => of(Graha.moon) ~/ 30;

  /// Birth nakshatra 0 (Ashwini) to 26 (Revati) and pada 1-4, from the Moon.
  int get nakshatra => of(Graha.moon) ~/ (360 / 27);
  int get pada => (of(Graha.moon) % (360 / 27)) ~/ (360 / 108) + 1;

  /// House (1-12) of a graha counted from the lagna, whole-sign.
  int house(Graha g) => (rashiOf(g) - lagnaRashi) % 12 + 1;
  int rashiOf(Graha g) => of(g) ~/ 30;

  /// Things that sit within [margin] degrees of a division, where a few minutes' error in the birth time
  /// or our theory changes the answer. Lagna moves about 1 degree in 4 minutes; the Moon 1 degree in 2 hours.
  List<Boundary> boundaries({double lagnaMargin = 1.0, double moonMargin = 0.05}) {
    double edge(double lon, double size) {
      final r = lon % size;
      return min(r, size - r);
    }

    return [
      if (edge(lagna, 30) < lagnaMargin) Boundary.lagna,
      if (edge(of(Graha.moon), 30) < moonMargin) Boundary.rashi,
      if (edge(of(Graha.moon), 360 / 27) < moonMargin) Boundary.nakshatra,
      if (edge(of(Graha.moon), 360 / 108) < moonMargin) Boundary.pada,
    ];
  }

  /// Minutes of birth-time error that would move the lagna into the next or previous sign.
  double get lagnaMinutesToEdge {
    final r = lagna % 30;
    return min(r, 30 - r) * 4;
  }
}

enum Graha { sun, moon, mars, mercury, jupiter, venus, saturn, rahu, ketu }

enum Boundary { lagna, rashi, nakshatra, pada }

double _norm(double d) => (d % 360 + 360) % 360;
double _rad(double d) => d * pi / 180;
double _deg(double r) => r * 180 / pi;

/// Julian Day of a UTC moment.
double julianDay(DateTime utc) => utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;

/// TT - UT in seconds (Espenak & Meeus) for a decimal year, 1800 to 2150.
double deltaT(double y) {
  double t;
  if (y < 1860) {
    t = y - 1800;
    return 13.72 -
        0.332447 * t +
        0.0068612 * pow(t, 2) +
        0.0041116 * pow(t, 3) -
        0.00037436 * pow(t, 4) +
        0.0000121272 * pow(t, 5) -
        0.0000001699 * pow(t, 6) +
        0.000000000875 * pow(t, 7);
  }
  if (y < 1900) {
    t = y - 1860;
    return 7.62 +
        0.5737 * t -
        0.251754 * t * t +
        0.01680668 * pow(t, 3) -
        0.0004473624 * pow(t, 4) +
        pow(t, 5) / 233174;
  }
  if (y < 1920) {
    t = y - 1900;
    return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * pow(t, 3) - 0.000197 * pow(t, 4);
  }
  if (y < 1941) {
    t = y - 1920;
    return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * pow(t, 3);
  }
  if (y < 1961) {
    t = y - 1950;
    return 29.07 + 0.407 * t - t * t / 233 + pow(t, 3) / 2547;
  }
  if (y < 1986) {
    t = y - 1975;
    return 45.45 + 1.067 * t - t * t / 260 - pow(t, 3) / 718;
  }
  if (y < 2005) {
    t = y - 2000;
    return 63.86 +
        0.3345 * t -
        0.060374 * t * t +
        0.0017275 * pow(t, 3) +
        0.000651814 * pow(t, 4) +
        0.00002373599 * pow(t, 5);
  }
  if (y < 2050) {
    t = y - 2000;
    return 62.92 + 0.32217 * t + 0.005589 * t * t;
  }
  return -20 + 32 * pow((y - 1820) / 100, 2) - 0.5628 * (2150 - y);
}

/// Lahiri (Chitrapaksha) ayanamsa as the server computes it: 23.85709 degrees at J2000 plus
/// 50.2788 arcseconds a year.
double lahiri(double jdTT) => 23.85709 + 50.2788 / 3600 * (jdTT - 2451545.0) / 365.25;

class _Nutation {
  _Nutation(double jd) {
    final t = (jd - 2451545.0) / 36525;
    final omega = _rad(125.04452 - 1934.136261 * t);
    final l = _rad(280.4665 + 36000.7698 * t);
    final lm = _rad(218.3165 + 481267.8813 * t);
    dPsi = (-17.20 * sin(omega) - 1.32 * sin(2 * l) - 0.23 * sin(2 * lm) + 0.21 * sin(2 * omega)) / 3600;
    final dEps = (9.20 * cos(omega) + 0.57 * cos(2 * l) + 0.10 * cos(2 * lm) - 0.09 * cos(2 * omega)) / 3600;
    final eps0 = 23.439291111 - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600;
    eps = eps0 + dEps;
  }

  /// Nutation in longitude and the true obliquity, degrees.
  late final double dPsi;
  late final double eps;
}

/// The Sun's geometric longitude corrected for aberration (Meeus 25.2-25.4, without nutation).
double sunLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
  final m = _rad(357.52911 + 35999.05029 * t - 0.0001537 * t * t);
  final c =
      (1.914602 - 0.004817 * t - 0.000014 * t * t) * sin(m) +
      (0.019993 - 0.000101 * t) * sin(2 * m) +
      0.000289 * sin(3 * m);
  return _norm(l0 + c - 0.00569);
}

// Meeus Table 47.A, longitude: multiples of D, M, M', F and the coefficient in 1e-6 degree.
const _moonTerms = <List<int>>[
  [0, 0, 1, 0, 6288774], [2, 0, -1, 0, 1274027], [2, 0, 0, 0, 658314], [0, 0, 2, 0, 213618], //
  [0, 1, 0, 0, -185116], [0, 0, 0, 2, -114332], [2, 0, -2, 0, 58793], [2, -1, -1, 0, 57066],
  [2, 0, 1, 0, 53322], [2, -1, 0, 0, 45758], [0, 1, -1, 0, -40923], [1, 0, 0, 0, -34720],
  [0, 1, 1, 0, -30383], [2, 0, 0, -2, 15327], [0, 0, 1, 2, -12528], [0, 0, 1, -2, 10980],
  [4, 0, -1, 0, 10675], [0, 0, 3, 0, 10034], [4, 0, -2, 0, 8548], [2, 1, -1, 0, -7888],
  [2, 1, 0, 0, -6766], [1, 0, -1, 0, -5163], [1, 1, 0, 0, 4987], [2, -1, 1, 0, 4036],
  [2, 0, 2, 0, 3994], [4, 0, 0, 0, 3861], [2, 0, -3, 0, 3665], [0, 1, -2, 0, -2689],
  [2, 0, -1, 2, -2602], [2, -1, -2, 0, 2390], [1, 0, 1, 0, -2348], [2, -2, 0, 0, 2236],
  [0, 1, 2, 0, -2120], [0, 2, 0, 0, -2069], [2, -2, -1, 0, 2048], [2, 0, 1, -2, -1773],
  [2, 0, 0, 2, -1595], [4, -1, -1, 0, 1215], [0, 0, 2, 2, -1110], [3, 0, -1, 0, -892],
  [2, 1, 1, 0, -810], [4, -1, -2, 0, 759], [0, 2, -1, 0, -713], [2, 2, -1, 0, -700],
  [2, 1, -2, 0, 691], [2, -1, 0, -2, 596], [4, 0, 1, 0, 549], [0, 0, 4, 0, 537],
  [4, -1, 0, 0, 520], [1, 0, -2, 0, -487], [2, 1, 0, -2, -399], [0, 0, 2, -2, -381],
  [1, 1, 1, 0, 351], [3, 0, -2, 0, -340], [4, 0, -3, 0, 330], [2, -1, 2, 0, 327],
  [0, 2, 1, 0, -323], [1, 1, -1, 0, 299], [2, 0, 3, 0, 294],
];

/// The Moon's geocentric longitude, mean equinox of date (Meeus chapter 47).
double moonLongitude(double jd) {
  final t = (jd - 2451545.0) / 36525;
  final t2 = t * t, t3 = t2 * t, t4 = t3 * t;
  final lp = 218.3164477 + 481267.88123421 * t - 0.0015786 * t2 + t3 / 538841 - t4 / 65194000;
  final d = 297.8501921 + 445267.1114034 * t - 0.0018819 * t2 + t3 / 545868 - t4 / 113065000;
  final m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t2 + t3 / 24490000;
  final mp = 134.9633964 + 477198.8675055 * t + 0.0087414 * t2 + t3 / 69699 - t4 / 14712000;
  final f = 93.2720950 + 483202.0175233 * t - 0.0036539 * t2 - t3 / 3526000 + t4 / 863310000;
  final a1 = 119.75 + 131.849 * t, a2 = 53.09 + 479264.290 * t;
  final e = 1 - 0.002516 * t - 0.0000074 * t2;
  var sum = 0.0;
  for (final term in _moonTerms) {
    final arg = _rad(term[0] * d + term[1] * m + term[2] * mp + term[3] * f);
    final factor = term[1].abs() == 1 ? e : (term[1].abs() == 2 ? e * e : 1.0);
    sum += term[4] * factor * sin(arg);
  }
  sum += 3958 * sin(_rad(a1)) + 1962 * sin(_rad(lp - f)) + 318 * sin(_rad(a2));
  return _norm(lp + sum / 1e6);
}

/// Longitude of the Moon's mean ascending node, mean equinox of date (Meeus 47.7).
double meanNode(double jd) {
  final t = (jd - 2451545.0) / 36525;
  return _norm(125.0445479 - 1934.1362891 * t + 0.0020754 * t * t + t * t * t / 467441 - pow(t, 4) / 60616000);
}

// JPL Table 1: a (au), e, I, L, long. perihelion, long. node (degrees) and their rates per Julian century.
const _planets = <List<double>>[
  // Mercury
  [
    0.38709927, 0.20563593, 7.00497902, 252.25032350, 77.45779628, 48.33076593, //
    0.00000037, 0.00001906, -0.00594749, 149472.67411175, 0.16047689, -0.12534081,
  ],
  // Venus
  [
    0.72333566, 0.00677672, 3.39467605, 181.97909950, 131.60246718, 76.67984255, //
    0.00000390, -0.00004107, -0.00078890, 58517.81538729, 0.00268329, -0.27769418,
  ],
  // Mars
  [
    1.52371034, 0.09339410, 1.84969142, -4.55343205, -23.94362959, 49.55953891, //
    0.00001847, 0.00007882, -0.00813131, 19140.30268499, 0.44441088, -0.29257343,
  ],
  // Jupiter
  [
    5.20288700, 0.04838624, 1.30439695, 34.39644051, 14.72847983, 100.47390909, //
    -0.00011607, -0.00013253, -0.00183714, 3034.74612775, 0.21252668, 0.20469106,
  ],
  // Saturn
  [
    9.53667594, 0.05386179, 2.48599187, 49.95424423, 92.59887831, 113.66242448, //
    -0.00125060, -0.00050991, 0.00193609, 1222.49362201, -0.41897216, -0.28867794,
  ],
];
const _emBary = <double>[
  1.00000261, 0.01671123, -0.00001531, 100.46457166, 102.93768193, 0.0, //
  0.00000562, -0.00004392, -0.01294668, 35999.37244981, 0.32327364, 0.0,
];

/// Heliocentric ecliptic coordinates (J2000, au) from JPL's elements.
List<double> _helio(List<double> el, double jd) {
  final t = (jd - 2451545.0) / 36525;
  double at(int i) => el[i] + el[i + 6] * t;
  final a = at(0), e = at(1), inc = _rad(at(2)), l = at(3), peri = at(4), node = at(5);
  final w = _rad(peri - node), om = _rad(node);
  var m = (l - peri) % 360;
  if (m > 180) m -= 360;
  final mr = _rad(m);
  var ea = mr + e * sin(mr);
  for (var i = 0; i < 8; i++) {
    ea -= (ea - e * sin(ea) - mr) / (1 - e * cos(ea));
  }
  final xp = a * (cos(ea) - e), yp = a * sqrt(1 - e * e) * sin(ea);
  return [
    (cos(w) * cos(om) - sin(w) * sin(om) * cos(inc)) * xp + (-sin(w) * cos(om) - cos(w) * sin(om) * cos(inc)) * yp,
    (cos(w) * sin(om) + sin(w) * cos(om) * cos(inc)) * xp + (-sin(w) * sin(om) + cos(w) * cos(om) * cos(inc)) * yp,
    sin(w) * sin(inc) * xp + cos(w) * sin(inc) * yp,
  ];
}

/// Geocentric longitude of a planet, mean equinox of date, with light time and annual aberration.
double _planetLongitude(List<double> el, double jd) {
  final earth = _helio(_emBary, jd);
  var p = _helio(el, jd);
  for (var i = 0; i < 2; i++) {
    final dist = sqrt(pow(p[0] - earth[0], 2) + pow(p[1] - earth[1], 2) + pow(p[2] - earth[2], 2));
    p = _helio(el, jd - 0.0057755183 * dist);
  }
  final x = p[0] - earth[0], y = p[1] - earth[1], z = p[2] - earth[2];
  final lam = _deg(atan2(y, x));
  final beta = atan2(z, sqrt(x * x + y * y));
  final t = (jd - 2451545.0) / 36525;
  // Precession from the J2000 ecliptic to the equinox of date (Meeus 21, general precession in longitude).
  final precessed = lam + 1.396971 * t + 0.0003086 * t * t;
  // Annual aberration (Meeus 23.2, leading term); the Sun's true longitude is the Earth's plus 180.
  final sun = _rad(_deg(atan2(earth[1], earth[0])) + 180 + 1.396971 * t);
  final aberration = -20.49552 / 3600 * cos(sun - _rad(precessed)) / cos(beta);
  return _norm(precessed + aberration);
}

/// Tropical ascendant (degrees, equinox of date) for a place.
double _ascendant(double jdUt, double jdTT, double lat, double lon, [_Nutation? nutation]) {
  final nut = nutation ?? _Nutation(jdTT);
  final t = (jdUt - 2451545.0) / 36525;
  final gmst = 280.46061837 + 360.98564736629 * (jdUt - 2451545.0) + 0.000387933 * t * t - t * t * t / 38710000;
  final ramc = _rad(_norm(gmst + nut.dPsi * cos(_rad(nut.eps)) + lon));
  final eps = _rad(nut.eps), phi = _rad(lat);
  return _norm(_deg(atan2(cos(ramc), -(sin(ramc) * cos(eps) + tan(phi) * sin(eps)))));
}
