// Plain models parsed from the API. Kept dependency-free (no code generation).

String _s(Object? v) => v?.toString() ?? '';
int _i(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;
List<String> _ls(Object? v) => v is List ? v.map((e) => '$e').toList() : const [];

class Deity {
  Deity(Map j)
    : id = _i(j['id']),
      slug = _s(j['slug']),
      name = _s(j['name']),
      nameHi = _s(j['name_hi']),
      description = _s(j['description']),
      imageUrl = _s(j['image_url']),
      color = _s(j['color']),
      weekday = j['weekday'] as int?;
  final int id;
  final String slug, name, nameHi, description, imageUrl, color;
  final int? weekday;
}

mixin Licensed {
  String get attribution;
  String get license;
  String get sourceUrl;
}

class Track with Licensed {
  Track(Map j)
    : id = _i(j['id']),
      slug = _s(j['slug']),
      title = _s(j['title']),
      titleHi = _s(j['title_hi']),
      kind = _s(j['kind']),
      deityId = j['deity_id'] as int?,
      audioUrl = _s(j['audio_url']),
      artworkUrl = _s(j['artwork_url']),
      durationSec = _i(j['duration_sec']),
      artist = _s(j['artist']),
      textSlug = j['text_slug'] as String?,
      attribution = _s(j['attribution']),
      license = _s(j['license']),
      sourceUrl = _s(j['source_url']),
      isPremium = j['is_premium'] == true,
      raw = Map<String, dynamic>.from(j);
  final int id;
  final String slug, title, titleHi, kind, audioUrl, artworkUrl, artist;
  @override
  final String attribution, license, sourceUrl;
  final int? deityId;
  final int durationSec;
  final String? textSlug;
  final bool isPremium;
  final Map<String, dynamic> raw;
}

class TextSummary {
  TextSummary(Map j)
    : id = _i(j['id']),
      slug = _s(j['slug']),
      title = _s(j['title']),
      titleHi = _s(j['title_hi']),
      kind = _s(j['kind']),
      deityId = j['deity_id'] as int?;
  final int id;
  final String slug, title, titleHi, kind;
  final int? deityId;
}

class TextItem with Licensed {
  TextItem(Map j)
    : slug = _s(j['slug']),
      title = _s(j['title']),
      titleHi = _s(j['title_hi']),
      kind = _s(j['kind']),
      body = _s(j['body']),
      transliteration = _s(j['transliteration']),
      meaning = _s(j['meaning']),
      benefits = _s(j['benefits']),
      deityId = j['deity_id'] as int?,
      attribution = _s(j['attribution']),
      license = _s(j['license']),
      sourceUrl = _s(j['source_url']);
  final String slug, title, titleHi, kind, body, transliteration, meaning, benefits;
  final int? deityId;
  @override
  final String attribution, license, sourceUrl;
}

class Verse {
  Verse(Map j)
    : chapter = _i(j['chapter']),
      verse = _i(j['verse']),
      sanskrit = _s(j['sanskrit']),
      transliteration = _s(j['transliteration']),
      translation = _s(j['translation_en']),
      translator = _s(j['translation_author']);
  final int chapter, verse;
  final String sanskrit, transliteration, translation, translator;
  String get ref => '$chapter.$verse';
}

class GitaChapter {
  GitaChapter(Map j)
    : number = _i(j['number']),
      nameSanskrit = _s(j['name_sanskrit']),
      nameTranslit = _s(j['name_translit']),
      nameEn = _s(j['name_en']),
      summary = _s(j['summary']),
      verseCount = _i(j['verse_count']),
      verses = (j['verses'] as List? ?? const []).map((v) => Verse(v as Map)).toList();
  final int number, verseCount;
  final String nameSanskrit, nameTranslit, nameEn, summary;
  final List<Verse> verses;
}

class Wallpaper with Licensed {
  Wallpaper(Map j)
    : id = _i(j['id']),
      title = _s(j['title']),
      deityId = j['deity_id'] as int?,
      imageUrl = _s(j['image_url']),
      thumbUrl = _s(j['thumb_url']),
      width = _i(j['width']),
      height = _i(j['height']),
      color = _s(j['dominant_color']),
      isPremium = j['is_premium'] == true,
      attribution = _s(j['attribution']),
      license = _s(j['license']),
      sourceUrl = _s(j['source_url']);
  final int id, width, height;
  final int? deityId;
  final String title, imageUrl, thumbUrl, color;
  final bool isPremium;
  @override
  final String attribution, license, sourceUrl;
  double get aspect => width > 0 && height > 0 ? width / height : 0.7;
}

class Video with Licensed {
  Video(Map j)
    : id = _i(j['id']),
      title = _s(j['title']),
      description = _s(j['description']),
      videoUrl = _s(j['video_url']),
      thumbnailUrl = _s(j['thumbnail_url']),
      durationSec = _i(j['duration_sec']),
      year = j['year'] as int?,
      attribution = _s(j['attribution']),
      license = _s(j['license']),
      sourceUrl = _s(j['source_url']);
  final int id, durationSec;
  final int? year;
  final String title, description, videoUrl, thumbnailUrl;
  @override
  final String attribution, license, sourceUrl;
}

class Book with Licensed {
  Book(Map j)
    : slug = _s(j['slug']),
      title = _s(j['title']),
      titleHi = _s(j['title_hi']),
      author = _s(j['author']),
      description = _s(j['description']),
      chapterCount = _i(j['chapter_count']),
      chapters = (j['chapters'] as List? ?? const [])
          .map((c) => (number: _i((c as Map)['number']), title: _s(c['title'])))
          .toList(),
      attribution = _s(j['attribution']),
      license = _s(j['license']),
      sourceUrl = _s(j['source_url']);
  final String slug, title, titleHi, author, description;
  final int chapterCount;
  final List<({int number, String title})> chapters;
  @override
  final String attribution, license, sourceUrl;
}

class Festival {
  Festival(Map j)
    : slug = _s(j['slug']),
      kind = _s(j['kind']),
      name = _s(j['name']),
      nameHi = _s(j['name_hi']),
      deity = _s(j['deity']),
      date = DateTime.parse(_s(j['date'])),
      major = j['major'] == true,
      description = _s(j['description']);
  final String slug, kind, name, nameHi, deity, description;
  final DateTime date;
  final bool major;

  int daysFrom(DateTime today) =>
      DateTime(date.year, date.month, date.day).difference(DateTime(today.year, today.month, today.day)).inDays;
}

class HomeBanner {
  HomeBanner(Map j)
    : title = _s(j['title']),
      subtitle = _s(j['subtitle']),
      imageUrl = _s(j['image_url']),
      deepLink = _s(j['deep_link']);
  final String title, subtitle, imageUrl, deepLink;
}

class UserProfile {
  UserProfile(Map j)
    : id = _i(j['id']),
      email = _s(j['email']),
      displayName = _s(j['display_name']),
      role = _s(j['role']),
      isPremium = j['is_premium'] == true,
      premiumUntil = j['premium_until'] == null ? null : DateTime.tryParse(_s(j['premium_until'])),
      rashi = j['rashi'] as String?;
  final int id;
  final String email, displayName, role;
  final bool isPremium;
  final DateTime? premiumUntil;
  final String? rashi;
}

List<String> tagsOf(Map j) => _ls(j['tags']);

const rashiList = [
  ('mesha', 'Aries', 'मेष', '♈'),
  ('vrishabha', 'Taurus', 'वृषभ', '♉'),
  ('mithuna', 'Gemini', 'मिथुन', '♊'),
  ('karka', 'Cancer', 'कर्क', '♋'),
  ('simha', 'Leo', 'सिंह', '♌'),
  ('kanya', 'Virgo', 'कन्या', '♍'),
  ('tula', 'Libra', 'तुला', '♎'),
  ('vrishchika', 'Scorpio', 'वृश्चिक', '♏'),
  ('dhanu', 'Sagittarius', 'धनु', '♐'),
  ('makara', 'Capricorn', 'मकर', '♑'),
  ('kumbha', 'Aquarius', 'कुंभ', '♒'),
  ('meena', 'Pisces', 'मीन', '♓'),
];
