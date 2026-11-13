import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/gochara.dart';
import '../core/i18n.dart';
import '../core/jatakam.dart';
import '../core/jyotish.dart';
import '../core/location.dart';
import '../core/models.dart';
import '../core/names.dart';
import '../core/profiles.dart';
import '../core/storage.dart';
import '../core/theme.dart';
import 'grahanam.dart';
import 'matching.dart' show nakshatraName;

/// Jatakam from the date, time and place of birth: lagna, Moon rashi, nakshatra and pada, and the
/// sidereal (Lahiri) positions of the nine grahas in South and North Indian charts. Worked out on the
/// phone (core/jatakam.dart), so it needs no internet.
class JatakamScreen extends ConsumerStatefulWidget {
  const JatakamScreen({super.key});
  @override
  ConsumerState<JatakamScreen> createState() => _JatakamScreenState();
}

class _JatakamScreenState extends ConsumerState<JatakamScreen> {
  final _name = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  final _offset = TextEditingController(text: '5:30');
  DateTime? _date;
  TimeOfDay? _time;
  late String _cityId = ref.read(cityProvider).id;
  BirthProfile? _result;
  bool _south = true;

  bool get _other => _cityId == '_other';

  @override
  void dispose() {
    for (final c in [_name, _lat, _lon, _offset]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _offsetMinutes() {
    final m = RegExp(r'^([+-]?)(\d{1,2})(?::(\d{2}))?$').firstMatch(_offset.text.trim());
    if (m == null) return null;
    final v = int.parse(m[2]!) * 60 + int.parse(m[3] ?? '0');
    return m[1] == '-' ? -v : v;
  }

  BirthProfile? _build(String lang) {
    if (_date == null || _time == null) return null;
    final local = DateTime(_date!.year, _date!.month, _date!.day, _time!.hour, _time!.minute);
    final name = _name.text.trim();
    if (_other) {
      final lat = double.tryParse(_lat.text.trim()), lon = double.tryParse(_lon.text.trim());
      final off = _offsetMinutes();
      if (lat == null || lon == null || off == null || lat.abs() > 66 || lon.abs() > 180) return null;
      return BirthProfile(
        name: name,
        local: local,
        place: '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}',
        lat: lat,
        lon: lon,
        offsetMinutes: off,
      );
    }
    final city = cities.firstWhere((c) => c.id == _cityId);
    return BirthProfile(name: name, local: local, place: city.name, lat: city.lat, lon: city.lon, zone: city.tz);
  }

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final saved = ref.watch(profilesProvider);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(t3(lang, 'Jatakam (birth chart)', 'जन्म कुंडली', 'జాతకం'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            t3(
              lang,
              'Enter the date, time and place of birth. Everything is worked out on your phone and stays on it.',
              'जन्म की तिथि, समय और स्थान भरें। सारी गणना आपके फ़ोन पर होती है और वहीं रहती है।',
              'పుట్టిన తేదీ, సమయం, స్థలం ఇవ్వండి. లెక్కలన్నీ మీ ఫోన్‌లోనే జరుగుతాయి, అక్కడే ఉంటాయి.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in saved)
                  InputChip(
                    avatar: const Icon(Icons.person_rounded, size: 18),
                    label: Text(p.name.isEmpty ? fmtDate(lang, 'd MMM yyyy', p.local) : p.name),
                    onPressed: () => setState(() => _result = p),
                    onDeleted: () => ref.read(profilesProvider.notifier).remove(p),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _form(lang),
          if (r != null) ..._results(lang, r),
        ],
      ),
    );
  }

  Widget _form(String lang) {
    final dateText = _date == null ? '—' : fmtDate(lang, 'd MMM yyyy', _date!);
    final timeText = _time == null ? '—' : hourMinute(lang, DateTime(2000, 1, 1, _time!.hour, _time!.minute));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: t3(lang, 'Name (optional)', 'नाम (वैकल्पिक)', 'పేరు (ఐచ్ఛికం)')),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cake_rounded),
                    label: Text('${t3(lang, 'Date', 'तिथि', 'తేదీ')}: $dateText'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2049, 12, 31),
                        initialDate: _date ?? DateTime(1990, 1, 1),
                        initialEntryMode: DatePickerEntryMode.input,
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text('${t3(lang, 'Time', 'समय', 'సమయం')}: $timeText'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _time ?? const TimeOfDay(hour: 6, minute: 0),
                        initialEntryMode: TimePickerEntryMode.input,
                      );
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _cityId,
              isExpanded: true,
              decoration: InputDecoration(labelText: t3(lang, 'Place of birth', 'जन्म स्थान', 'జన్మ స్థలం')),
              items: [
                for (final c in cities) DropdownMenuItem(value: c.id, child: Text(c.label(lang))),
                DropdownMenuItem(
                  value: '_other',
                  child: Text(
                    t3(
                      lang,
                      'Another place (enter latitude and longitude)',
                      'अन्य स्थान (अक्षांश और देशांतर भरें)',
                      'వేరే స్థలం (అక్షాంశం, రేఖాంశం ఇవ్వండి)',
                    ),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _cityId = v!),
            ),
            if (_other) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: t3(lang, 'Latitude (N +)', 'अक्षांश (उत्तर +)', 'అక్షాంశం (ఉత్తరం +)'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lon,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: t3(lang, 'Longitude (E +)', 'देशांतर (पूर्व +)', 'రేఖాంశం (తూర్పు +)'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _offset,
                      decoration: InputDecoration(labelText: t3(lang, 'UTC offset', 'UTC अंतर', 'UTC తేడా')),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(t3(lang, 'Make the Jatakam', 'कुंडली बनाएँ', 'జాతకం వేయండి')),
              onPressed: () {
                final p = _build(lang);
                if (p == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t3(
                          lang,
                          'Fill in the date, time and place of birth.',
                          'जन्म की तिथि, समय और स्थान भरें।',
                          'పుట్టిన తేదీ, సమయం, స్థలం నింపండి.',
                        ),
                      ),
                    ),
                  );
                  return;
                }
                setState(() => _result = p);
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(String lang, BirthProfile p) {
    final j = p.chart;
    final flags = j.boundaries();
    final saved = ref.watch(profilesProvider).any((x) => x.name == p.name && x.local == p.local);
    final prefs = ref.watch(prefsProvider);
    final mine = prefs.birthStar == j.nakshatra && prefs.rashi == rashiList[j.moonRashi].$1;
    Widget fact(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      ),
    );
    return [
      const SizedBox(height: 16),
      if (p.name.isNotEmpty)
        Text(p.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      Text(
        '${fmtDate(lang, 'EEEE, d MMM yyyy', p.local)}, ${hourMinute(lang, p.local)} · '
        '${p.zone == null ? p.place : (cities.where((c) => c.name == p.place).firstOrNull?.label(lang) ?? p.place)}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact(t3(lang, 'Lagna', 'लग्न', 'లగ్నం'), signName(lang, j.lagnaRashi)),
              fact(
                t3(lang, 'Rashi (Moon sign)', 'राशि (चंद्र राशि)', 'రాశి (చంద్ర రాశి)'),
                signName(lang, j.moonRashi),
              ),
              fact(
                t3(lang, 'Nakshatra', 'नक्षत्र', 'నక్షత్రం'),
                '${nakshatraName(lang, j.nakshatra)} ${t3(lang, 'pada', 'पद', 'పాదం')} ${j.pada}',
              ),
            ],
          ),
        ),
      ),
      if (flags.isNotEmpty)
        Card(
          color: Colors.orange.withValues(alpha: 0.12),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(t3(lang, 'Close to a boundary', 'सीमा के पास', 'సరిహద్దుకు దగ్గరగా')),
            subtitle: Text(
              [
                if (flags.contains(Boundary.lagna))
                  t3(
                    lang,
                    'The lagna changes sign if the birth time is off by about {0} minutes. Check the time of birth.',
                    'जन्म समय लगभग {0} मिनट आगे-पीछे होने पर लग्न बदल जाएगा। जन्म समय जाँच लें।',
                    'పుట్టిన సమయం సుమారు {0} నిమిషాలు అటూ ఇటూ అయితే లగ్నం మారుతుంది. సమయం సరిచూసుకోండి.',
                  ).replaceAll('{0}', '${max(1, j.lagnaMinutesToEdge.round())}'),
                if (flags.any((f) => f != Boundary.lagna))
                  t3(
                    lang,
                    'The Moon is at the edge of a nakshatra pada or rashi; a few minutes of birth time decide it.',
                    'चंद्रमा नक्षत्र पद या राशि की सीमा पर है; जन्म समय के कुछ मिनट इसका निर्णय करते हैं।',
                    'చంద్రుడు నక్షత్ర పాదం లేదా రాశి సరిహద్దులో ఉన్నాడు; పుట్టిన సమయంలో కొన్ని నిమిషాలే దీన్ని నిర్ణయిస్తాయి.',
                  ),
              ].join('\n'),
            ),
          ),
        ),
      const SizedBox(height: 8),
      SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: true, label: Text(t3(lang, 'South Indian', 'दक्षिण भारतीय', 'దక్షిణ భారత'))),
          ButtonSegment(value: false, label: Text(t3(lang, 'North Indian', 'उत्तर भारतीय', 'ఉత్తర భారత'))),
        ],
        selected: {_south},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => _south = s.first),
      ),
      const SizedBox(height: 10),
      AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _south
              ? _SouthChart(j, lang, Theme.of(context).colorScheme, _centre(lang, p))
              : _NorthChart(j, lang, Theme.of(context).colorScheme),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              _row(lang, t3(lang, 'Lagna', 'लग्न', 'లగ్నం'), j.lagna, 1, bold: true),
              for (final g in Graha.values) _row(lang, grahaName(lang, g), j.of(g), j.house(g)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            icon: Icon(mine ? Icons.check_rounded : Icons.star_rounded),
            label: Text(
              t3(
                lang,
                'Use as my birth star and rashi',
                'इसे मेरा जन्म नक्षत्र और राशि बनाएँ',
                'దీన్ని నా జన్మ నక్షత్రం, రాశిగా ఉంచండి',
              ),
            ),
            onPressed: mine
                ? null
                : () async {
                    final n = ref.read(prefsProvider.notifier);
                    await n.set('birth_star', j.nakshatra);
                    await n.setRashi(rashiList[j.moonRashi].$1);
                  },
          ),
          OutlinedButton.icon(
            icon: Icon(saved ? Icons.bookmark_added_rounded : Icons.bookmark_add_rounded),
            label: Text(t3(lang, 'Save for marriage matching', 'विवाह मिलान के लिए सहेजें', 'వివాహ పొంతన కోసం దాచండి')),
            onPressed: saved || p.name.isEmpty ? null : () => ref.read(profilesProvider.notifier).save(p),
          ),
        ],
      ),
      if (p.name.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            t3(lang, 'Add a name to save this birth.', 'सहेजने के लिए नाम जोड़ें।', 'దాచడానికి పేరు ఇవ్వండి.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      const SizedBox(height: 12),
      Text(
        t3(
          lang,
          'Positions are sidereal (Lahiri ayanamsa); Rahu is the mean node. The Sun, Moon and lagna are accurate to '
              'a fraction of a minute of arc, the slow planets to about a fifth of a degree.',
          'स्थितियाँ निरयण (लाहिड़ी अयनांश) हैं; राहु मध्यम पात है। सूर्य, चंद्र और लग्न कला के अंश तक सटीक हैं, '
              'धीमे ग्रह लगभग 0.2 अंश तक।',
          'స్థానాలు నిరయన (లాహిరి అయనాంశ); రాహువు మధ్యమ పాతం. సూర్యుడు, చంద్రుడు, లగ్నం కళలో భాగం వరకు ఖచ్చితం, '
              'నెమ్మదిగా కదిలే గ్రహాలు సుమారు 0.2 డిగ్రీ వరకు.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  String _centre(String lang, BirthProfile p) =>
      '${p.name.isEmpty ? t3(lang, 'Rashi', 'राशि', 'రాశి') : p.name}\n${fmtDate(lang, 'd MMM yyyy', p.local)}\n${hourMinute(lang, p.local)}';

  Widget _row(String lang, String name, double lon, int house, {bool bold = false}) {
    final inSign = lon % 30;
    final deg = inSign.floor(), minutes = ((inSign - deg) * 60).floor();
    final nak = lon ~/ (360 / 27), pada = (lon % (360 / 27)) ~/ (360 / 108) + 1;
    return ListTile(
      dense: true,
      title: Text(name, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      subtitle: Text('${nakshatraName(lang, nak)} $pada'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text("${signName(lang, lon ~/ 30)} $deg°${minutes.toString().padLeft(2, '0')}'"),
          Pill('${t3(lang, 'House', 'भाव', 'భావం')} $house', color: Palette.saffron),
        ],
      ),
    );
  }
}

String grahaName(String lang, Graha g) => switch (g) {
  Graha.sun => t3(lang, 'Sun (Surya)', 'सूर्य', 'సూర్యుడు'),
  Graha.moon => t3(lang, 'Moon (Chandra)', 'चंद्र', 'చంద్రుడు'),
  Graha.mars => t3(lang, 'Mars (Mangal)', 'मंगल', 'కుజుడు'),
  Graha.mercury => t3(lang, 'Mercury (Budh)', 'बुध', 'బుధుడు'),
  Graha.jupiter => t3(lang, 'Jupiter (Guru)', 'गुरु (बृहस्पति)', 'గురువు (బృహస్పతి)'),
  Graha.venus => t3(lang, 'Venus (Shukra)', 'शुक्र', 'శుక్రుడు'),
  Graha.saturn => t3(lang, 'Saturn (Shani)', 'शनि', 'శని'),
  Graha.rahu => t3(lang, 'Rahu', 'राहु', 'రాహువు'),
  Graha.ketu => t3(lang, 'Ketu', 'केतु', 'కేతువు'),
};

/// Two-letter graha marks for the charts.
String grahaMark(String lang, Graha g) => switch (g) {
  Graha.sun => t3(lang, 'Su', 'सू', 'సూ'),
  Graha.moon => t3(lang, 'Mo', 'चं', 'చం'),
  Graha.mars => t3(lang, 'Ma', 'मं', 'కు'),
  Graha.mercury => t3(lang, 'Me', 'बु', 'బు'),
  Graha.jupiter => t3(lang, 'Ju', 'गु', 'గు'),
  Graha.venus => t3(lang, 'Ve', 'शु', 'శు'),
  Graha.saturn => t3(lang, 'Sa', 'श', 'శ'),
  Graha.rahu => t3(lang, 'Ra', 'रा', 'రా'),
  Graha.ketu => t3(lang, 'Ke', 'के', 'కే'),
};

String lagnaMark(String lang) => t3(lang, 'Asc', 'ल', 'ల');

List<String> _marksIn(Jatakam j, String lang, int sign) => [
  if (j.lagnaRashi == sign) lagnaMark(lang),
  for (final g in Graha.values)
    if (j.rashiOf(g) == sign) grahaMark(lang, g),
];

void _text(Canvas canvas, String text, Offset centre, double maxWidth, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
}

/// South Indian chart: signs in fixed boxes, Meena at the top left, running clockwise.
class _SouthChart extends CustomPainter {
  _SouthChart(this.j, this.lang, this.scheme, this.centre);
  final Jatakam j;
  final String lang;
  final ColorScheme scheme;
  final String centre;

  // (row, column) of each sign, Mesha first.
  static const cells = [(0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (3, 3), (3, 2), (3, 1), (3, 0), (2, 0), (1, 0), (0, 0)];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 4;
    final line = Paint()
      ..color = scheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final style = TextStyle(color: scheme.onSurface, fontSize: s / 6, fontWeight: FontWeight.w700);
    final small = TextStyle(color: scheme.outline, fontSize: s / 9);
    for (var sign = 0; sign < 12; sign++) {
      final (r, c) = cells[sign];
      final rect = Rect.fromLTWH(c * s, r * s, s, s);
      if (j.lagnaRashi == sign) {
        canvas.drawRect(rect, Paint()..color = Palette.saffron.withValues(alpha: 0.15));
        canvas.drawLine(rect.topLeft, rect.topLeft + Offset(s / 4, s / 4), line);
      }
      canvas.drawRect(rect, line);
      _text(canvas, signName(lang, sign), rect.bottomCenter - Offset(0, s / 9), s - 4, small);
      _text(canvas, _marksIn(j, lang, sign).join(' '), rect.center, s - 6, style);
    }
    _text(
      canvas,
      centre,
      Offset(size.width / 2, size.height / 2),
      2 * s - 8,
      TextStyle(color: scheme.onSurface, fontSize: s / 7),
    );
  }

  @override
  bool shouldRepaint(covariant _SouthChart old) => old.j != j || old.lang != lang || old.centre != centre;
}

/// North Indian chart: houses in fixed places, the lagna at the top, sign numbers in each house.
class _NorthChart extends CustomPainter {
  _NorthChart(this.j, this.lang, this.scheme);
  final Jatakam j;
  final String lang;
  final ColorScheme scheme;

  // Centre of each house (1-12) in a unit square, and where its sign number goes.
  static const centres = [
    (0.5, 0.25), (0.25, 0.1), (0.1, 0.25), (0.25, 0.5), (0.1, 0.75), (0.25, 0.9), //
    (0.5, 0.75), (0.75, 0.9), (0.9, 0.75), (0.75, 0.5), (0.9, 0.25), (0.75, 0.1),
  ];
  static const numbers = [
    (0.5, 0.42), (0.25, 0.2), (0.2, 0.25), (0.42, 0.5), (0.2, 0.75), (0.25, 0.8), //
    (0.5, 0.58), (0.75, 0.8), (0.8, 0.75), (0.58, 0.5), (0.8, 0.25), (0.75, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final line = Paint()
      ..color = scheme.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(Offset.zero & size, line);
    canvas.drawLine(Offset.zero, Offset(w, w), line);
    canvas.drawLine(Offset(w, 0), Offset(0, w), line);
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, 0)
        ..lineTo(w, w / 2)
        ..lineTo(w / 2, w)
        ..lineTo(0, w / 2)
        ..close(),
      line,
    );
    final style = TextStyle(color: scheme.onSurface, fontSize: w / 24, fontWeight: FontWeight.w700);
    final small = TextStyle(color: Palette.saffron, fontSize: w / 30, fontWeight: FontWeight.w700);
    for (var h = 0; h < 12; h++) {
      final sign = (j.lagnaRashi + h) % 12;
      final (x, y) = centres[h];
      final (nx, ny) = numbers[h];
      _text(canvas, '${sign + 1}', Offset(nx * w, ny * w), w / 8, small);
      _text(canvas, _marksIn(j, lang, sign).join(' '), Offset(x * w, y * w), h % 3 == 0 ? w / 4 : w / 7, style);
    }
  }

  @override
  bool shouldRepaint(covariant _NorthChart old) => old.j != j || old.lang != lang;
}
