// Devalay Cloud Functions. sendPush: the owner's admin screen sends a notification to everyone, a
// language, a state, an app version, installs inactive for N days, or one install. Only an admin
// (custom claim `admin`, or an admins/{uid} record) may call it. Each send is recorded in
// campaigns/{id}; installs add their opens to it (firestore.rules), so the admin sees an open rate.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const lib = require('./lib');

initializeApp();
setGlobalOptions({ region: 'asia-south1', maxInstances: 2, memory: '256MiB', timeoutSeconds: 120 });

const db = getFirestore();

async function isAdmin(auth) {
  if (!auth) return false;
  if (auth.token && auth.token.admin === true) return true;
  return (await db.doc(`admins/${auth.uid}`).get()).exists;
}

/** Every install summary with the fields an audience needs (a few hundred today; select() keeps it light). */
async function installs() {
  const snap = await db.collection('installs').select('t', 'lang', 'state', 'v', 'lastSeen').get();
  return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
}

const DEAD_TOKEN = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);

exports.sendPush = onCall(async (request) => {
  if (!(await isAdmin(request.auth))) throw new HttpsError('permission-denied', 'Only the owner can send notifications.');
  let req;
  try {
    req = lib.parseRequest(request.data);
  } catch (e) {
    if (e instanceof lib.PushError) throw new HttpsError(e.code, e.message);
    throw e;
  }
  const all = await installs();
  const estimate = lib.reach(all, req.audience);
  if (req.dryRun) return { reach: estimate };
  if (lib.isBroadcast(req.audience.type) && lib.inQuietHours() && !req.force) {
    throw new HttpsError('failed-precondition', 'Quiet hours (9 PM–6 AM India time): send in the morning, or tick "Send anyway".');
  }

  const topics = lib.topicsFor(req.audience);
  // Recorded before sending, so an install that opens the message at once already finds it to count.
  const ref = db.collection('campaigns').doc();
  await ref.set({
    name: req.name,
    title: req.title,
    body: req.body,
    link: req.link,
    image: req.image,
    audience: req.audience,
    by: request.auth.uid,
    at: FieldValue.serverTimestamp(),
    topics: topics ? topics.map((t) => t.topic) : [],
    reach: estimate,
    status: 'sending',
    sent: 0,
    failed: 0,
    opens: 0,
  });
  const messaging = getMessaging();
  let sent = 0;
  let failed = 0;
  if (topics) {
    for (const t of topics) {
      try {
        await messaging.send(lib.message(req, ref.id, t.lang, { topic: t.topic }));
        sent += 1;
      } catch (e) {
        failed += 1;
        logger.warn('topic send failed', t.topic, e.message);
      }
    }
  } else {
    const targets = lib.pickInstalls(all, req.audience);
    for (let i = 0; i < targets.length; i += 500) {
      const chunk = targets.slice(i, i + 500);
      const res = await messaging.sendEach(chunk.map(({ data }) => lib.message(req, ref.id, data.lang || 'en', { token: data.t })));
      sent += res.successCount;
      failed += res.failureCount;
      // Uninstalled apps: forget their tokens so later sends and estimates skip them.
      const dead = res.responses
        .map((r, j) => (!r.success && r.error && DEAD_TOKEN.has(r.error.code) ? chunk[j].id : null))
        .filter(Boolean);
      await Promise.all(dead.map((id) => db.doc(`installs/${id}`).update({ t: FieldValue.delete() }).catch(() => {})));
    }
  }

  await ref.update({ status: 'sent', sent, failed });
  logger.info('sendPush', { id: ref.id, audience: req.audience, reach: estimate, sent, failed });
  return { id: ref.id, reach: estimate, sent, failed };
});
