const test = require('node:test');
const assert = require('node:assert');
const lib = require('../lib');

const ok = { title: { te: 'నేటి పంచాంగం', en: "Today's Panchang" }, body: { en: 'Open it' }, audience: { type: 'all' } };

test('parses a valid request and keeps per-language text', () => {
  const r = lib.parseRequest({ ...ok, link: 'devalay://panchang', name: ' Karthika ' });
  assert.deepStrictEqual(r.title, ok.title);
  assert.strictEqual(r.link, 'devalay://panchang');
  assert.strictEqual(r.name, 'Karthika');
  assert.strictEqual(r.dryRun, false);
});

test('rejects bad input', () => {
  const bad = (d, code = 'invalid-argument') => assert.throws(() => lib.parseRequest(d), (e) => e.code === code);
  bad({ ...ok, title: { en: '  ' } });
  bad({ ...ok, title: { xx: 'hi' } });
  bad({ ...ok, body: { en: 'x'.repeat(401) } });
  bad({ ...ok, link: 'javascript:alert(1)' });
  bad({ ...ok, link: 'devalay://Panchang/../x y' });
  bad({ ...ok, image: 'http://insecure.example/x.png' });
  bad({ ...ok, audience: { type: 'everyone' } });
  bad({ ...ok, audience: { type: 'lang', value: 'fr' } });
  bad({ ...ok, audience: { type: 'state' } });
  bad({ ...ok, audience: { type: 'inactive', value: '0' } });
});

test('text falls back to English, then the first language written', () => {
  assert.strictEqual(lib.textFor({ te: 'తె', en: 'en' }, 'kn'), 'en');
  assert.strictEqual(lib.textFor({ te: 'తె' }, 'hi'), 'తె');
  assert.strictEqual(lib.textFor({ te: 'తె', en: 'en' }, 'te'), 'తె');
});

test('quiet hours are 9 PM to 6 AM India time', () => {
  assert.strictEqual(lib.inQuietHours(new Date('2026-11-27T15:29:00Z')), false); // 20:59 IST
  assert.strictEqual(lib.inQuietHours(new Date('2026-11-27T15:30:00Z')), true); // 21:00 IST
  assert.strictEqual(lib.inQuietHours(new Date('2026-11-28T00:29:00Z')), true); // 05:59 IST
  assert.strictEqual(lib.inQuietHours(new Date('2026-11-28T00:30:00Z')), false); // 06:00 IST
});

test('everyone and a language go by topic; segments by token', () => {
  assert.strictEqual(lib.topicsFor({ type: 'all' }).length, 11);
  assert.deepStrictEqual(lib.topicsFor({ type: 'lang', value: 'te' }), [{ topic: 'lang_te', lang: 'te' }]);
  assert.strictEqual(lib.topicsFor({ type: 'state', value: 'AP' }), null);
});

test('token audiences pick the right installs and skip those without a token', () => {
  const now = new Date('2026-11-27T10:00:00Z');
  const day = 86400000;
  const installs = [
    { id: 'a', data: { t: 'tok-a', lang: 'te', state: 'AP', v: '1.5.7', lastSeen: now.getTime() - 5 * day } },
    { id: 'b', data: { t: 'tok-b', lang: 'en', state: 'TG', v: '1.5.6', lastSeen: { toMillis: () => now.getTime() - day / 2 } } },
    { id: 'c', data: { lang: 'te', state: 'AP', v: '1.5.7', lastSeen: now.getTime() - 9 * day } },
  ];
  const ids = (a) => lib.pickInstalls(installs, a, now).map((i) => i.id);
  assert.deepStrictEqual(ids({ type: 'state', value: 'AP' }), ['a']);
  assert.deepStrictEqual(ids({ type: 'version', value: '1.5.6' }), ['b']);
  assert.deepStrictEqual(ids({ type: 'inactive', value: '3' }), ['a']);
  assert.deepStrictEqual(ids({ type: 'user', value: 'b' }), ['b']);
  assert.strictEqual(lib.reach(installs, { type: 'all' }, now), 3);
  assert.strictEqual(lib.reach(installs, { type: 'lang', value: 'te' }, now), 2);
});

test('messages carry the campaign, link and the announcements channel', () => {
  const r = lib.parseRequest({ ...ok, link: 'devalay://panchang', image: 'https://x.test/a.png' });
  const m = lib.message(r, 'CAMP1', 'te', { topic: 'lang_te' });
  assert.strictEqual(m.topic, 'lang_te');
  assert.strictEqual(m.notification.title, 'నేటి పంచాంగం');
  assert.strictEqual(m.notification.body, 'Open it');
  assert.strictEqual(m.notification.imageUrl, 'https://x.test/a.png');
  assert.deepStrictEqual(m.data, { c: 'CAMP1', link: 'devalay://panchang' });
  assert.strictEqual(m.android.notification.channelId, 'announcements');
});
