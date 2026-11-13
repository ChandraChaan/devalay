/// Devanagari to the other Indian scripts, for Sanskrit and Hindi text (aartis, mantras, Gita verses)
/// shown to readers of another language. The Brahmi-derived Unicode blocks share the ISCII layout, so
/// most letters sit a fixed distance apart; the tables below cover the letters a script lacks.
/// Marathi is written in Devanagari and needs no change.
library;

const _offsets = {
  'bn': 0x80,
  'pa': 0x100,
  'gu': 0x180,
  'or': 0x200,
  'ta': 0x280,
  'te': 0x300,
  'kn': 0x380,
  'ml': 0x400,
};

/// Whether text in [lang] is read in a script other than Devanagari and Latin.
bool needsScriptChange(String lang) => _offsets.containsKey(lang);

/// Nukta letters (क़ ख़ ग़ ज़ ड़ ढ़ फ़ य़) to their base letters.
const _nuktaBase = [0x0915, 0x0916, 0x0917, 0x091C, 0x0921, 0x0922, 0x092B, 0x092F];

/// Tamil has one letter per consonant group; aspirated and voiced forms fold onto it.
const _tamil = <int, String>{
  0x0916: 'க', 0x0917: 'க', 0x0918: 'க', 0x091B: 'ச', 0x091D: 'ஜ', 0x0920: 'ட', 0x0921: 'ட', //
  0x0922: 'ட', 0x0925: 'த', 0x0926: 'த', 0x0927: 'த', 0x092B: 'ப', 0x092C: 'ப', 0x092D: 'ப',
  0x090B: 'ரு', 0x0943: '்ரு', 0x0902: 'ம்', 0x0901: 'ம்', 0x093D: '',
};

/// Letters a script lacks, by language: Devanagari code point -> replacement text.
const _gaps = <String, Map<int, String>>{
  'bn': {0x0935: 'ব', 0x0933: 'ল', 0x0950: 'ওঁ'},
  'pa': {0x090B: 'ਰਿ', 0x0943: '੍ਰਿ', 0x0937: 'ਸ਼', 0x093D: '', 0x0950: 'ੴ', 0x0960: 'ਰੀ', 0x0944: '੍ਰੀ'},
  'gu': {},
  'or': {0x0950: 'ଓଁ'},
  'ta': _tamil,
  'te': {0x0950: 'ఓం'},
  'kn': {0x0950: 'ಓಂ', 0x0934: 'ಳ'},
  'ml': {0x0950: 'ഓം'},
};

/// Scripts without short e/o use the long vowels instead.
const _noShortEO = {'bn', 'pa', 'gu', 'or'};

/// [s] with its Devanagari letters written in the script of [lang]. Other characters are kept.
String toIndicScript(String lang, String s) {
  final offset = _offsets[lang];
  if (offset == null) return s;
  final gaps = _gaps[lang]!;
  final out = StringBuffer();
  var prev = 0;
  for (var c in s.runes) {
    final before = prev;
    prev = c;
    // Tamil writes the dental na (ந) only at the start of a word, the alveolar ன elsewhere.
    if (lang == 'ta' && c == 0x0928) {
      out.write(before >= 0x0900 && before <= 0x097F ? 'ன' : 'ந');
      continue;
    }
    if (c < 0x0900 || c > 0x097F) {
      out.writeCharCode(c);
      continue;
    }
    if (c >= 0x0958 && c <= 0x095F) c = _nuktaBase[c - 0x0958];
    if (c == 0x0929) c = 0x0928; // ऩ -> न
    if (c == 0x0931) c = 0x0930; // ऱ -> र
    if (c == 0x0934 && lang != 'kn') c = 0x0933; // ऴ -> ळ
    // Candra e/o (ऍ ऑ, ॅ ॉ) read as e/o.
    c = switch (c) {
      0x090D => 0x090E,
      0x0911 => 0x0912,
      0x0945 => 0x0946,
      0x0949 => 0x094A,
      _ => c,
    };
    if (_noShortEO.contains(lang)) {
      c = switch (c) {
        0x090E => 0x090F,
        0x0912 => 0x0913,
        0x0946 => 0x0947,
        0x094A => 0x094B,
        _ => c,
      };
    }
    if (c == 0x0964 || c == 0x0965) {
      out.writeCharCode(c); // dandas are shared
      continue;
    }
    if (c == 0x093C || (c >= 0x0951 && c <= 0x0954) || c == 0x093A || c == 0x093B || c == 0x094E || c == 0x094F) {
      continue; // nukta, Vedic accents
    }
    if (c >= 0x0966 && c <= 0x096F) {
      out.write('${c - 0x0966}'); // Western digits read everywhere
      continue;
    }
    final gap = gaps[c];
    if (gap != null) {
      out.write(gap);
      continue;
    }
    out.writeCharCode(c + offset);
  }
  return out.toString();
}
