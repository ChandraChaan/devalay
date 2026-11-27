// Pure helpers for sendPush (index.js): validation, audiences and FCM messages. No Firebase calls,
// so test/lib.test.js runs them with plain `node --test`.

const LANGS = ['en', 'hi', 'te', 'ta', 'kn', 'ml', 'mr', 'bn', 'gu', 'pa', 'or'];
const AUDIENCES = ['all', 'lang', 'state', 'inactive', 'version', 'user'];
const LINK = /^(devalay:\/\/[a-z0-9][a-z0-9/_-]{0,80}|https:\/\/[^\s]{1,300})$/;

/** A request error the callable turns into an HttpsError with this code. */
class PushError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

/** Per-language text: {te: '...', en: '...'}; trimmed, empty languages dropped. */
function texts(raw, max, what) {
  if (!raw || typeof raw !== 'object') throw new PushError('invalid-argument', `${what} is missing`);
  const out = {};
  for (const [lang, value] of Object.entries(raw)) {
    if (!LANGS.includes(lang)) throw new PushError('invalid-argument', `Unknown language ${lang}`);
    const v = `${value ?? ''}`.trim();
    if (v.length > max) throw new PushError('invalid-argument', `${what} (${lang}) is longer than ${max}`);
    if (v) out[lang] = v;
  }
  if (!Object.keys(out).length) throw new PushError('invalid-argument', `${what} is empty`);
  return out;
}

/** The text for one language: its own, else English, else the first one written. */
function textFor(map, lang) {
  return map[lang] || map.en || Object.values(map)[0];
}

/** Checks and normalises what the admin screen sent. */
function parseRequest(data) {
  const d = data || {};
  const title = texts(d.title, 80, 'Title');
  const body = texts(d.body, 400, 'Message');
  const link = `${d.link ?? ''}`.trim();
  if (link && !LINK.test(link)) throw new PushError('invalid-argument', 'The link must be devalay://… or https://…');
  const image = `${d.image ?? ''}`.trim();
  if (image && !/^https:\/\/[^\s]{1,300}$/.test(image)) throw new PushError('invalid-argument', 'The image must be an https:// link');
  const a = d.audience || {};
  const type = `${a.type ?? ''}`;
  if (!AUDIENCES.includes(type)) throw new PushError('invalid-argument', `Unknown audience ${type}`);
  const value = `${a.value ?? ''}`.trim();
  if (type === 'lang' && !LANGS.includes(value)) throw new PushError('invalid-argument', 'Pick a language');
  if (['state', 'version', 'user'].includes(type) && !value) throw new PushError('invalid-argument', `Pick a ${type}`);
  if (type === 'inactive' && !(Number(value) >= 1)) throw new PushError('invalid-argument', 'Inactive days must be 1 or more');
  return {
    name: `${d.name ?? ''}`.trim().slice(0, 80),
    title,
    body,
    link,
    image,
    audience: { type, value },
    dryRun: d.dryRun === true,
    force: d.force === true,
  };
}

/** Broadcasts (not one person) wait for the morning: 9 PM to 6 AM India time is quiet. */
function inQuietHours(now = new Date()) {
  const minutes = (now.getUTCHours() * 60 + now.getUTCMinutes() + 330) % 1440; // IST is UTC+5:30
  const hour = Math.floor(minutes / 60);
  return hour >= 21 || hour < 6;
}

const isBroadcast = (type) => type !== 'user';

/** Audiences sent by topic (every install subscribes to lang_xx); the rest go to device tokens. */
function topicsFor(audience) {
  if (audience.type === 'all') return LANGS.map((l) => ({ topic: `lang_${l}`, lang: l }));
  if (audience.type === 'lang') return [{ topic: `lang_${audience.value}`, lang: audience.value }];
  return null;
}

/** Install summaries (id + data) that a token audience reaches. Installs without a token are skipped. */
function pickInstalls(installs, audience, now = new Date()) {
  const cutoff = now.getTime() - Number(audience.value) * 86400000;
  return installs.filter(({ id, data }) => {
    if (!data || typeof data.t !== 'string' || !data.t) return false;
    switch (audience.type) {
      case 'state':
        return data.state === audience.value;
      case 'version':
        return data.v === audience.value;
      case 'user':
        return id === audience.value;
      case 'inactive': {
        const last = data.lastSeen && typeof data.lastSeen.toMillis === 'function' ? data.lastSeen.toMillis() : Number(data.lastSeen);
        return Number.isFinite(last) && last < cutoff;
      }
      default:
        return false;
    }
  });
}

/** How many installs an audience covers, for the composer's estimate and the open rate. */
function reach(installs, audience, now = new Date()) {
  if (audience.type === 'all') return installs.length;
  if (audience.type === 'lang') return installs.filter((i) => i.data && i.data.lang === audience.value).length;
  return pickInstalls(installs, audience, now).length;
}

/** One FCM HTTP v1 message, to a topic or a token, in [lang]. */
function message(req, campaign, lang, target) {
  const notification = { title: textFor(req.title, lang), body: textFor(req.body, lang) };
  if (req.image) notification.imageUrl = req.image;
  return {
    ...target,
    notification,
    data: { c: campaign, link: req.link },
    android: { priority: 'high', notification: { channelId: 'announcements', icon: 'ic_notification' } },
  };
}

module.exports = { LANGS, PushError, parseRequest, textFor, inQuietHours, isBroadcast, topicsFor, pickInstalls, reach, message };
