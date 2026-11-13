import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/matching.dart';
import '../core/models.dart';
import '../core/telugu.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Marriage matching from the birth stars: Ashtakoota Guna Milan (36 points) and the 10 Porutham.
/// Everything is worked out on the phone by core/matching.dart.
class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

/// One side of the form. The rashi is null until a nakshatra is picked.
class _Entry {
  const _Entry({this.nakshatra, this.pada, this.rashi});
  final int? nakshatra;
  final int? pada;
  final int? rashi;

  BirthStar? get star => nakshatra == null || rashi == null ? null : BirthStar(nakshatra!, rashi!, pada: pada);

  _Entry withNakshatra(int n) {
    final rashis = rashisOf(n);
    // Default to the rashi that holds most of the nakshatra.
    rashis.sort((a, b) => padasIn(n, b).length.compareTo(padasIn(n, a).length));
    return _Entry(nakshatra: n, rashi: rashis.first);
  }

  _Entry withPada(int? p) =>
      _Entry(nakshatra: nakshatra, pada: p, rashi: p == null || nakshatra == null ? rashi : rashiOf(nakshatra!, p));

  _Entry withRashi(int r) => _Entry(nakshatra: nakshatra, rashi: r);
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  var _bride = const _Entry();
  var _groom = const _Entry();
  var _south = false;

  @override
  Widget build(BuildContext context) {
    final lang = uiLang(ref);
    final bride = _bride.star, groom = _groom.star;
    return Scaffold(
      appBar: AppBar(title: Text(tr(ref, 'matching'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            t3(
              lang,
              "Pick the bride's and groom's birth nakshatra and rashi. Add the pada if you know it.",
              'वधू और वर का जन्म नक्षत्र और राशि चुनें। पद पता हो तो वह भी चुनें।',
              'వధూవరుల జన్మ నక్షత్రం, రాశి ఎంచుకోండి. పాదం తెలిస్తే అది కూడా ఎంచుకోండి.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _PersonCard(
            lang: lang,
            title: t3(lang, 'Bride', 'वधू', 'వధువు'),
            emoji: '👰',
            entry: _bride,
            onChanged: (e) => setState(() => _bride = e),
          ),
          const SizedBox(height: 10),
          _PersonCard(
            lang: lang,
            title: t3(lang, 'Groom', 'वर', 'వరుడు'),
            emoji: '🤵',
            entry: _groom,
            onChanged: (e) => setState(() => _groom = e),
          ),
          const SizedBox(height: 16),
          if (bride == null || groom == null)
            EmptyState(
              icon: Icons.favorite_border_rounded,
              title: t3(
                lang,
                'Choose both birth stars to see the match',
                'मिलान देखने के लिए दोनों जन्म नक्षत्र चुनें',
                'పొంతన చూడటానికి ఇద్దరి జన్మ నక్షత్రాలు ఎంచుకోండి',
              ),
            )
          else ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(t3(lang, 'Guna Milan (36)', 'गुण मिलान (36)', 'గుణ మేళనం (36)')),
                ),
                ButtonSegment(value: true, label: Text(t3(lang, '10 Porutham', '10 पोरुत्तम', 'దశవిధ పొంతన'))),
              ],
              selected: {_south},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _south = s.first),
            ),
            const SizedBox(height: 12),
            if (_south)
              _PoruthamView(lang: lang, bride: bride, groom: groom)
            else
              _GunaView(lang: lang, bride: bride, groom: groom),
          ],
          const SizedBox(height: 16),
          _Disclaimer(lang: lang),
        ],
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.lang,
    required this.title,
    required this.emoji,
    required this.entry,
    required this.onChanged,
  });
  final String lang, title, emoji;
  final _Entry entry;
  final ValueChanged<_Entry> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = entry.nakshatra;
    final rashis = n == null ? <int>[] : rashisOf(n);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$emoji  $title', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            _Picker<int>(
              label: t3(lang, 'Nakshatra (birth star)', 'नक्षत्र (जन्म तारा)', 'నక్షత్రం (జన్మ తార)'),
              value: n,
              items: [for (var i = 0; i < 27; i++) (i, nakshatraName(lang, i))],
              onChanged: (v) => onChanged(entry.withNakshatra(v!)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _Picker<int?>(
                    label: t3(lang, 'Pada', 'पद', 'పాదం'),
                    value: entry.pada,
                    items: [
                      (null, t3(lang, 'Not known', 'पता नहीं', 'తెలియదు')),
                      for (var p = 1; p <= 4; p++) (p, '$p'),
                    ],
                    onChanged: n == null ? null : (v) => onChanged(entry.withPada(v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _Picker<int>(
                    label: t3(lang, 'Rashi (Moon sign)', 'राशि (चंद्र राशि)', 'రాశి (చంద్ర రాశి)'),
                    value: entry.rashi,
                    items: [for (final r in rashis) (r, rashiName(lang, r))],
                    // With the pada known the rashi is fixed; otherwise only a split nakshatra offers a choice.
                    onChanged: entry.pada != null || rashis.length < 2 ? null : (v) => onChanged(entry.withRashi(v!)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        menuMaxHeight: 420,
        items: [
          for (final (v, text) in items)
            DropdownMenuItem(
              value: v,
              child: Text(text, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------------------------------------
// Guna Milan

class _GunaView extends StatelessWidget {
  const _GunaView({required this.lang, required this.bride, required this.groom});
  final String lang;
  final BirthStar bride, groom;

  @override
  Widget build(BuildContext context) {
    final r = ashtakoota(bride, groom);
    final total = r.total;
    final (verdict, colors) = switch (r.verdict) {
      GunaVerdict.excellent => (t3(lang, 'Excellent match', 'उत्तम मिलान', 'ఉత్తమ పొంతన'), Palette.tulsi),
      GunaVerdict.veryGood => (
        t3(lang, 'Very good match', 'बहुत अच्छा मिलान', 'చాలా మంచి పొంతన'),
        const [Color(0xFF2E7D32), Color(0xFF558B2F)],
      ),
      GunaVerdict.middling => (t3(lang, 'Average match', 'मध्यम मिलान', 'మధ్యమ పొంతన'), Palette.sunrise),
      GunaVerdict.notRecommended => (
        t3(lang, 'Not recommended', 'अनुशंसित नहीं', 'సిఫార్సు చేయదగినది కాదు'),
        const [Color(0xFF6D1B1B), Color(0xFFB71C1C)],
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientCard(
          colors: colors,
          padding: 18,
          child: Column(
            children: [
              Text(
                '${_num(total)} / 36',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
              ),
              Text(
                verdict,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: total / 36,
                  minHeight: 8,
                  color: Palette.gold,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t3(
                  lang,
                  '18 or more is the usual minimum. 21 to 30 is very good.',
                  'आम तौर पर कम से कम 18 गुण देखे जाते हैं। 21 से 30 बहुत अच्छा है।',
                  'సాధారణంగా కనీసం 18 గుణాలు చూస్తారు. 21 నుండి 30 చాలా మంచిది.',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
        if (r.nadiDosha)
          _Warning(
            t3(
              lang,
              'Nadi dosha: both are in the same Nadi. Traditionally this outweighs the total.',
              'नाडी दोष: दोनों की नाडी एक है। परंपरा में यह कुल गुणों से अधिक महत्वपूर्ण माना जाता है।',
              'నాడీ దోషం: ఇద్దరిదీ ఒకే నాడి. సంప్రదాయంలో ఇది మొత్తం గుణాల కంటే ముఖ్యం.',
            ),
          ),
        if (r.bhakootDosha)
          _Warning(
            t3(
              lang,
              'Bhakoot dosha: the Moon signs are 2/12, 5/9 or 6/8 from each other.',
              'भकूट दोष: दोनों राशियाँ एक-दूसरे से 2/12, 5/9 या 6/8 पर हैं।',
              'భకూట దోషం: రెండు రాశులు ఒకదానికొకటి 2/12, 5/9 లేదా 6/8 స్థానాల్లో ఉన్నాయి.',
            ),
          ),
        const SizedBox(height: 8),
        for (final (i, s) in r.scores.indexed)
          _Row(
            title: _kootaName(lang, s.koota),
            meaning: _kootaMeaning(lang, s.koota),
            detail: _kootaDetail(lang, s.koota, bride, groom),
            trailing: '${_num(s.points)} / ${s.max}',
            good: s.points >= s.max / 2,
            fill: s.points / s.max,
          ).animate().fadeIn(delay: (40 * i).ms),
      ],
    );
  }
}

String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

String _kootaName(String lang, Koota k) => switch (k) {
  Koota.varna => t3(lang, 'Varna', 'वर्ण', 'వర్ణ'),
  Koota.vashya => t3(lang, 'Vashya', 'वश्य', 'వశ్య'),
  Koota.tara => t3(lang, 'Tara', 'तारा', 'తారా'),
  Koota.yoni => t3(lang, 'Yoni', 'योनि', 'యోని'),
  Koota.grahaMaitri => t3(lang, 'Graha Maitri', 'ग्रह मैत्री', 'గ్రహ మైత్రి'),
  Koota.gana => t3(lang, 'Gana', 'गण', 'గణ'),
  Koota.bhakoot => t3(lang, 'Bhakoot', 'भकूट', 'భకూట'),
  Koota.nadi => t3(lang, 'Nadi', 'नाडी', 'నాడి'),
};

String _kootaMeaning(String lang, Koota k) => switch (k) {
  Koota.varna => t3(lang, 'Mutual respect and comfort', 'परस्पर सम्मान और सहजता', 'పరస్పర గౌరవం, సౌఖ్యం'),
  Koota.vashya => t3(lang, 'Mutual attraction and influence', 'परस्पर आकर्षण और प्रभाव', 'పరస్పర ఆకర్షణ, ప్రభావం'),
  Koota.tara => t3(
    lang,
    'Luck and well-being, from the count between the two stars',
    'भाग्य और कुशलता, दोनों नक्षत्रों की गिनती से',
    'అదృష్టం, క్షేమం — రెండు నక్షత్రాల మధ్య లెక్క నుండి',
  ),
  Koota.yoni => t3(
    lang,
    'Physical and instinctive compatibility',
    'शारीरिक और स्वाभाविक अनुकूलता',
    'శారీరక, సహజ అనుకూలత',
  ),
  Koota.grahaMaitri => t3(
    lang,
    'Mental friendship, from the lords of the Moon signs',
    'मानसिक मित्रता, दोनों राशियों के स्वामियों से',
    'మానసిక స్నేహం — రాశ్యాధిపతుల మైత్రి నుండి',
  ),
  Koota.gana => t3(
    lang,
    'Temperament: Deva, Manushya or Rakshasa',
    'स्वभाव: देव, मनुष्य या राक्षस',
    'స్వభావం: దేవ, మనుష్య లేదా రాక్షస',
  ),
  Koota.bhakoot => t3(
    lang,
    'Family welfare, wealth and children, from the distance between the Moon signs',
    'परिवार का कल्याण, धन और संतान, दोनों राशियों की दूरी से',
    'కుటుంబ క్షేమం, ధనం, సంతానం — రెండు రాశుల దూరం నుండి',
  ),
  Koota.nadi => t3(
    lang,
    'Health and children. The same Nadi for both is a dosha.',
    'स्वास्थ्य और संतान। दोनों की एक ही नाडी होना दोष है।',
    'ఆరోగ్యం, సంతానం. ఇద్దరిదీ ఒకే నాడి అయితే దోషం.',
  ),
};

String _pair(String lang, String bride, String groom) =>
    '${t3(lang, 'Bride', 'वधू', 'వధువు')}: $bride · ${t3(lang, 'Groom', 'वर', 'వరుడు')}: $groom';

String _kootaDetail(String lang, Koota k, BirthStar b, BirthStar g) => switch (k) {
  Koota.varna => _pair(lang, _varna(lang, varnaOf(b.rashi)), _varna(lang, varnaOf(g.rashi))),
  Koota.vashya => _pair(lang, _vashya(lang, vashyaOf(b)), _vashya(lang, vashyaOf(g))),
  Koota.tara =>
    '${t3(lang, 'Bride to groom', 'वधू से वर', 'వధువు నుండి వరుడు')}: ${_tara(lang, taraOf(b.nakshatra, g.nakshatra))} · '
        '${t3(lang, 'groom to bride', 'वर से वधू', 'వరుడు నుండి వధువు')}: ${_tara(lang, taraOf(g.nakshatra, b.nakshatra))}',
  Koota.yoni => _pair(lang, _yoni(lang, yoniOf(b.nakshatra)), _yoni(lang, yoniOf(g.nakshatra))),
  Koota.grahaMaitri => _pair(lang, _planet(lang, lordOf(b.rashi)), _planet(lang, lordOf(g.rashi))),
  Koota.gana => _pair(lang, _gana(lang, ganaOf(b.nakshatra)), _gana(lang, ganaOf(g.nakshatra))),
  Koota.bhakoot => _pair(lang, rashiName(lang, b.rashi), rashiName(lang, g.rashi)),
  Koota.nadi => _pair(lang, _nadi(lang, nadiOf(b.nakshatra)), _nadi(lang, nadiOf(g.nakshatra))),
};

// ---------------------------------------------------------------------------------------------------------
// 10 Porutham

class _PoruthamView extends StatelessWidget {
  const _PoruthamView({required this.lang, required this.bride, required this.groom});
  final String lang;
  final BirthStar bride, groom;

  @override
  Widget build(BuildContext context) {
    final r = porutham(bride, groom);
    final ok = r.essentialOk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientCard(
          colors: ok && r.count >= 5 ? Palette.tulsi : const [Color(0xFF6D1B1B), Color(0xFFB71C1C)],
          padding: 18,
          child: Column(
            children: [
              Text(
                '${r.count} / 10',
                style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
              ),
              Text(
                t3(lang, 'poruthams match', 'पोरुत्तम मेल खाते हैं', 'పొంతనలు కుదిరాయి'),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                ok
                    ? t3(
                        lang,
                        'Rajju and Vedha both match. Many families look for at least five of the ten.',
                        'रज्जु और वेध दोनों मेल खाते हैं। कई परिवार दस में से कम से कम पाँच देखते हैं।',
                        'రజ్జు, వేధ రెండూ కుదిరాయి. చాలా కుటుంబాలు పదిలో కనీసం ఐదు చూస్తాయి.',
                      )
                    : t3(
                        lang,
                        'Rajju or Vedha does not match. Traditionally a match is not made without these two.',
                        'रज्जु या वेध मेल नहीं खाता। परंपरा में इन दोनों के बिना विवाह तय नहीं किया जाता।',
                        'రజ్జు లేదా వేధ కుదరలేదు. సంప్రదాయంలో ఈ రెండూ లేకుండా సంబంధం కుదుర్చరు.',
                      ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.96, 0.96)),
        const SizedBox(height: 8),
        for (final (i, p) in Porutham.values.indexed)
          _Row(
            title: _poruthamName(lang, p),
            meaning: _poruthamMeaning(lang, p),
            detail: _poruthamDetail(lang, p, bride, groom),
            trailing: r[p] ? '✓' : '✗',
            good: r[p],
            essential: p == Porutham.rajju || p == Porutham.vedha,
          ).animate().fadeIn(delay: (40 * i).ms),
      ],
    );
  }
}

String _poruthamName(String lang, Porutham p) => switch (p) {
  Porutham.dina => t3(lang, 'Dina', 'दिन', 'దిన'),
  Porutham.gana => t3(lang, 'Gana', 'गण', 'గణ'),
  Porutham.mahendra => t3(lang, 'Mahendra', 'माहेंद्र', 'మాహేంద్ర'),
  Porutham.streeDeergha => t3(lang, 'Stree Deergha', 'स्त्री दीर्घ', 'స్త్రీ దీర్ఘ'),
  Porutham.yoni => t3(lang, 'Yoni', 'योनि', 'యోని'),
  Porutham.rasi => t3(lang, 'Rasi', 'राशि', 'రాశి'),
  Porutham.rasyadhipati => t3(lang, 'Rasyadhipati', 'राश्याधिपति', 'రాశ్యాధిపతి'),
  Porutham.vasya => t3(lang, 'Vasya', 'वश्य', 'వశ్య'),
  Porutham.rajju => t3(lang, 'Rajju', 'रज्जु', 'రజ్జు'),
  Porutham.vedha => t3(lang, 'Vedha', 'वेध', 'వేధ'),
};

String _poruthamMeaning(String lang, Porutham p) => switch (p) {
  Porutham.dina => t3(
    lang,
    'Health and long, happy days together',
    'स्वास्थ्य और साथ के लंबे, सुखी दिन',
    'ఆరోగ్యం, కలిసి సుఖమైన దీర్ఘ జీవితం',
  ),
  Porutham.gana => t3(
    lang,
    'Temperaments that suit each other',
    'एक-दूसरे के अनुकूल स्वभाव',
    'ఒకరికొకరు సరిపడే స్వభావం',
  ),
  Porutham.mahendra => t3(lang, 'Children and prosperity', 'संतान और समृद्धि', 'సంతానం, అభివృద్ధి'),
  Porutham.streeDeergha => t3(
    lang,
    "The bride's well-being and prosperity",
    'वधू का कल्याण और समृद्धि',
    'వధువు క్షేమం, ఐశ్వర్యం',
  ),
  Porutham.yoni => t3(lang, 'Physical compatibility', 'शारीरिक अनुकूलता', 'శారీరక అనుకూలత'),
  Porutham.rasi => t3(
    lang,
    'Harmony in the family, from the Moon signs',
    'परिवार में सामंजस्य, दोनों राशियों से',
    'కుటుంబంలో సామరస్యం — రాశుల నుండి',
  ),
  Porutham.rasyadhipati => t3(
    lang,
    'Friendship between the lords of the Moon signs',
    'दोनों राशियों के स्वामियों की मित्रता',
    'రాశ్యాధిపతుల మధ్య స్నేహం',
  ),
  Porutham.vasya => t3(lang, 'Mutual attraction and affection', 'परस्पर आकर्षण और स्नेह', 'పరస్పర ఆకర్షణ, అనురాగం'),
  Porutham.rajju => t3(
    lang,
    'Long married life. The same rajju for both is avoided.',
    'लंबा वैवाहिक जीवन। दोनों का एक ही रज्जु वर्जित है।',
    'దీర్ఘ దాంపత్యం. ఇద్దరిదీ ఒకే రజ్జు అయితే నిషిద్ధం.',
  ),
  Porutham.vedha => t3(
    lang,
    'Freedom from affliction. Some stars obstruct each other.',
    'कष्टों से मुक्ति। कुछ नक्षत्र एक-दूसरे को बाधित करते हैं।',
    'బాధల నుండి విముక్తి. కొన్ని నక్షత్రాలు ఒకదానినొకటి వేధిస్తాయి.',
  ),
};

String _countFromBride(String lang, int n) =>
    '${t3(lang, "Count from the bride's star", 'वधू के नक्षत्र से गिनती', 'వధువు నక్షత్రం నుండి లెక్క')}: $n';

String _poruthamDetail(String lang, Porutham p, BirthStar b, BirthStar g) {
  final count = countFrom(b.nakshatra, g.nakshatra, 27);
  return switch (p) {
    Porutham.dina || Porutham.mahendra || Porutham.streeDeergha => _countFromBride(lang, count),
    Porutham.gana => _pair(lang, _gana(lang, ganaOf(b.nakshatra)), _gana(lang, ganaOf(g.nakshatra))),
    Porutham.yoni => _pair(lang, _yoni(lang, yoniOf(b.nakshatra)), _yoni(lang, yoniOf(g.nakshatra))),
    Porutham.rasi =>
      '${t3(lang, "Count from the bride's rashi", 'वधू की राशि से गिनती', 'వధువు రాశి నుండి లెక్క')}: '
          '${countFrom(b.rashi, g.rashi, 12)}',
    Porutham.rasyadhipati => _pair(lang, _planet(lang, lordOf(b.rashi)), _planet(lang, lordOf(g.rashi))),
    Porutham.vasya => _pair(lang, rashiName(lang, b.rashi), rashiName(lang, g.rashi)),
    Porutham.rajju => _pair(lang, _rajju(lang, rajjuOf(b.nakshatra)), _rajju(lang, rajjuOf(g.nakshatra))),
    Porutham.vedha => _pair(lang, nakshatraName(lang, b.nakshatra), nakshatraName(lang, g.nakshatra)),
  };
}

// ---------------------------------------------------------------------------------------------------------
// Shared pieces

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.meaning,
    required this.detail,
    required this.trailing,
    required this.good,
    this.fill,
    this.essential = false,
  });
  final String title, meaning, detail, trailing;
  final bool good, essential;
  final double? fill;

  @override
  Widget build(BuildContext context) {
    final color = good ? const Color(0xFF2E7D32) : Palette.vermilion;
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    essential ? '$title ★' : title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  trailing,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(meaning, style: const TextStyle(height: 1.3)),
            const SizedBox(height: 4),
            Text(detail, style: small),
            if (fill != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fill,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Palette.vermilion.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Palette.vermilion.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: Palette.vermilion),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(height: 1.3))),
      ],
    ),
  );
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Palette.marigold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🙏', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t3(
              lang,
              'This is the traditional star match from the birth stars alone. It does not read the full horoscopes '
                  '(Kuja dosha, dashas and more), and traditions differ in the details. Please consult your family '
                  'priest or astrologer before deciding.',
              'यह केवल जन्म नक्षत्रों से किया गया पारंपरिक मिलान है। इसमें पूरी कुंडली (मंगल दोष, दशा आदि) नहीं देखी '
                  'जाती, और परंपराओं में नियम कुछ अलग होते हैं। निर्णय से पहले अपने कुल पुरोहित या ज्योतिषी से परामर्श '
                  'करें।',
              'ఇది జన్మ నక్షత్రాల నుండి మాత్రమే చూసే సంప్రదాయ పొంతన. ఇందులో పూర్తి జాతకం (కుజ దోషం, దశలు మొదలైనవి) '
                  'చూడబడదు, సంప్రదాయాన్ని బట్టి నియమాలు కొంత మారుతాయి. నిర్ణయం తీసుకునే ముందు మీ కుటుంబ పురోహితుడిని '
                  'లేదా జ్యోతిష్యుడిని సంప్రదించండి.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------------------------------------
// Names

const _nakshatraEn = [
  'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra', 'Punarvasu', 'Pushya', 'Ashlesha', //
  'Magha', 'Purva Phalguni', 'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
  'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana', 'Dhanishta', 'Shatabhisha',
  'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
];

const _nakshatraHi = [
  'अश्विनी', 'भरणी', 'कृत्तिका', 'रोहिणी', 'मृगशिरा', 'आर्द्रा', 'पुनर्वसु', 'पुष्य', 'आश्लेषा', //
  'मघा', 'पूर्वा फाल्गुनी', 'उत्तरा फाल्गुनी', 'हस्त', 'चित्रा', 'स्वाती', 'विशाखा', 'अनुराधा', 'ज्येष्ठा',
  'मूल', 'पूर्वाषाढ़ा', 'उत्तराषाढ़ा', 'श्रवण', 'धनिष्ठा', 'शतभिषा', 'पूर्वा भाद्रपद', 'उत्तरा भाद्रपद', 'रेवती',
];

String nakshatraName(String lang, int n) => t3(lang, _nakshatraEn[n], _nakshatraHi[n], teluguNakshatra[n + 1]);

const _rashiSanskrit = [
  'Mesha', 'Vrishabha', 'Mithuna', 'Karka', 'Simha', 'Kanya', //
  'Tula', 'Vrishchika', 'Dhanu', 'Makara', 'Kumbha', 'Meena',
];

String rashiName(String lang, int r) {
  final (slug, en, hi, symbol) = rashiList[r];
  return '$symbol ${t3(lang, '${_rashiSanskrit[r]} ($en)', hi, teluguRashiBySlug[slug] ?? hi)}';
}

String _varna(String lang, Varna v) => switch (v) {
  Varna.brahmin => t3(lang, 'Brahmin', 'ब्राह्मण', 'బ్రాహ్మణ'),
  Varna.kshatriya => t3(lang, 'Kshatriya', 'क्षत्रिय', 'క్షత్రియ'),
  Varna.vaishya => t3(lang, 'Vaishya', 'वैश्य', 'వైశ్య'),
  Varna.shudra => t3(lang, 'Shudra', 'शूद्र', 'శూద్ర'),
};

String _vashya(String lang, Vashya v) => switch (v) {
  Vashya.chatushpada => t3(lang, 'Quadruped', 'चतुष्पद', 'చతుష్పాద'),
  Vashya.manava => t3(lang, 'Human', 'मानव', 'మానవ'),
  Vashya.jalachara => t3(lang, 'Water', 'जलचर', 'జలచర'),
  Vashya.vanachara => t3(lang, 'Wild', 'वनचर', 'వనచర'),
  Vashya.keeta => t3(lang, 'Insect', 'कीट', 'కీటక'),
};

String _tara(String lang, Tara t) => switch (t) {
  Tara.janma => t3(lang, 'Janma', 'जन्म', 'జన్మ'),
  Tara.sampat => t3(lang, 'Sampat', 'संपत', 'సంపత్'),
  Tara.vipat => t3(lang, 'Vipat', 'विपत', 'విపత్'),
  Tara.kshema => t3(lang, 'Kshema', 'क्षेम', 'క్షేమ'),
  Tara.pratyari => t3(lang, 'Pratyari', 'प्रत्यरि', 'ప్రత్యక్'),
  Tara.sadhaka => t3(lang, 'Sadhaka', 'साधक', 'సాధక'),
  Tara.vadha => t3(lang, 'Vadha', 'वध', 'వధ'),
  Tara.mitra => t3(lang, 'Mitra', 'मित्र', 'మిత్ర'),
  Tara.paramaMitra => t3(lang, 'Parama Mitra', 'परम मित्र', 'పరమ మిత్ర'),
};

String _yoni(String lang, Yoni y) => switch (y) {
  Yoni.horse => t3(lang, 'Horse', 'अश्व', 'గుర్రం'),
  Yoni.elephant => t3(lang, 'Elephant', 'गज', 'ఏనుగు'),
  Yoni.sheep => t3(lang, 'Sheep', 'मेढ़ा', 'మేక'),
  Yoni.serpent => t3(lang, 'Serpent', 'सर्प', 'సర్పం'),
  Yoni.dog => t3(lang, 'Dog', 'श्वान', 'కుక్క'),
  Yoni.cat => t3(lang, 'Cat', 'मार्जार', 'పిల్లి'),
  Yoni.rat => t3(lang, 'Rat', 'मूषक', 'ఎలుక'),
  Yoni.cow => t3(lang, 'Cow', 'गौ', 'ఆవు'),
  Yoni.buffalo => t3(lang, 'Buffalo', 'महिष', 'గేదె'),
  Yoni.tiger => t3(lang, 'Tiger', 'व्याघ्र', 'పులి'),
  Yoni.deer => t3(lang, 'Deer', 'मृग', 'జింక'),
  Yoni.monkey => t3(lang, 'Monkey', 'वानर', 'కోతి'),
  Yoni.mongoose => t3(lang, 'Mongoose', 'नकुल', 'ముంగిస'),
  Yoni.lion => t3(lang, 'Lion', 'सिंह', 'సింహం'),
};

String _gana(String lang, Gana g) => switch (g) {
  Gana.deva => t3(lang, 'Deva', 'देव', 'దేవ'),
  Gana.manushya => t3(lang, 'Manushya', 'मनुष्य', 'మనుష్య'),
  Gana.rakshasa => t3(lang, 'Rakshasa', 'राक्षस', 'రాక్షస'),
};

String _nadi(String lang, Nadi n) => switch (n) {
  Nadi.adi => t3(lang, 'Adi', 'आदि', 'ఆది'),
  Nadi.madhya => t3(lang, 'Madhya', 'मध्य', 'మధ్య'),
  Nadi.antya => t3(lang, 'Antya', 'अंत्य', 'అంత్య'),
};

String _planet(String lang, Planet p) => switch (p) {
  Planet.sun => t3(lang, 'Sun', 'सूर्य', 'సూర్యుడు'),
  Planet.moon => t3(lang, 'Moon', 'चंद्र', 'చంద్రుడు'),
  Planet.mars => t3(lang, 'Mars', 'मंगल', 'కుజుడు'),
  Planet.mercury => t3(lang, 'Mercury', 'बुध', 'బుధుడు'),
  Planet.jupiter => t3(lang, 'Jupiter', 'गुरु', 'గురువు'),
  Planet.venus => t3(lang, 'Venus', 'शुक्र', 'శుక్రుడు'),
  Planet.saturn => t3(lang, 'Saturn', 'शनि', 'శని'),
};

String _rajju(String lang, Rajju r) => switch (r) {
  Rajju.pada => t3(lang, 'Feet', 'पाद', 'పాద'),
  Rajju.kati => t3(lang, 'Waist', 'कटि', 'కటి'),
  Rajju.nabhi => t3(lang, 'Navel', 'नाभि', 'నాభి'),
  Rajju.kantha => t3(lang, 'Neck', 'कंठ', 'కంఠ'),
  Rajju.siro => t3(lang, 'Head', 'शिर', 'శిరో'),
};
