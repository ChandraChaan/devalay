import 'package:devalay/core/firebase.dart';
import 'package:devalay/core/telugu.dart';
import 'package:devalay/features/bhakti_videos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sanskrit converts to Telugu script', () {
    expect(toTeluguScript('ॐ नमः शिवाय'), 'ఓం నమః శివాయ');
    expect(toTeluguScript('कर्मण्येवाधिकारस्ते'), 'కర్మణ్యేవాధికారస్తే');
    expect(toTeluguScript('श्री राम ।'), 'శ్రీ రామ ।');
    expect(toTeluguScript('Gita 2.47'), 'Gita 2.47');
  });

  test('weekday deities and samvatsara tables line up', () {
    expect(teluguWeekdayDeity, hasLength(7));
    expect(teluguWeekdayDeity[5], 'venkateswara'); // Saturday
    expect(teluguSamvatsara, hasLength(60));
    expect(teluguSamvatsara[39], 'పరాభవ'); // 2026-27
    expect(teluguNakshatra, hasLength(28));
    expect(teluguYoga, hasLength(28));
  });

  test('YouTube feed parsing', () {
    const xml = '''<feed><entry><yt:videoId>abc123</yt:videoId><title>తిరుమల &amp; తిరుపతి</title>
<published>2026-11-01T10:00:00+00:00</published></entry><entry><title>no id</title></entry></feed>''';
    final v = parseYoutubeFeed(xml);
    expect(v, hasLength(1));
    expect(v.first.id, 'abc123');
    expect(v.first.title, 'తిరుమల & తిరుపతి');
  });

  test('force update compares version names, not per-ABI build numbers', () {
    expect(versionCodeOf('1.1.0'), 10100);
    expect(versionCodeOf('1.2.3'), 10203);
    expect(versionCodeOf('2.0'), 20000);
  });
}
