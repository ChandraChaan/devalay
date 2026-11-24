#!/usr/bin/env node
// Grants or revokes the Devalay admin custom claim. Run by the owner only, on a trusted computer:
//
//   gcloud auth application-default login     # once, as the owner of devalay-chandra
//   cd tools/admin && npm install
//   node set-admin-claim.mjs --email you@gmail.com            # grant
//   node set-admin-claim.mjs --email you@gmail.com --revoke   # revoke
//
// The account must have signed in once with Google from the app's admin screen first. After a
// grant, tap "Check again" there (the app asks for a fresh token). Fixed to project devalay-chandra.
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const args = process.argv.slice(2);
const email = args[args.indexOf('--email') + 1];
const revoke = args.includes('--revoke');
if (!email || args.indexOf('--email') < 0) {
  console.error('Usage: node set-admin-claim.mjs --email you@gmail.com [--revoke]');
  process.exit(1);
}
initializeApp({ credential: applicationDefault(), projectId: 'devalay-chandra' });
const auth = getAuth();
const user = await auth.getUserByEmail(email);
const claims = { ...(user.customClaims ?? {}) };
if (revoke) delete claims.admin;
else claims.admin = true;
await auth.setCustomUserClaims(user.uid, claims);
if (revoke) await auth.revokeRefreshTokens(user.uid);
console.log(`${revoke ? 'Revoked' : 'Granted'} admin for ${user.uid}`);
