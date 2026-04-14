/**
 * VISTA — Field Migration Script
 * Renames: users[*].Hasapprovedshortstay  →  users[*].hasActiveShortStay
 *
 * Background
 * ----------
 * The field was originally written with an inconsistent case. All client code
 * now writes/reads 'hasActiveShortStay'. This script performs the one-time
 * rename on every existing document that still carries the old field name.
 *
 * Safety guarantees
 * -----------------
 *   - DRY RUN by default. Pass --execute to actually commit writes.
 *   - Uses Firestore batch writes (max 500 ops per batch) for atomicity.
 *   - Skips documents that already have 'hasActiveShortStay' (idempotent).
 *   - Skips documents that have neither field (no short-stay students).
 *   - Prints a full report before committing any write.
 *
 * Usage
 * -----
 *   cd scripts
 *
 *   Provide the service account JSON via --sa flag:
 *     node migrate_shortstay_field.js --sa /path/to/serviceAccount.json
 *     node migrate_shortstay_field.js --sa /path/to/serviceAccount.json --execute
 *
 *   Download the service account JSON from:
 *   Firebase Console → Project Settings → Service Accounts → Generate New Private Key
 */

const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// ── Auth ───────────────────────────────────────────────────────────────────
const saFlagIdx = process.argv.indexOf('--sa');
if (saFlagIdx !== -1 && process.argv[saFlagIdx + 1]) {
  // Resolve relative to CWD, not __dirname
  const path = require('path');
  const saPath = path.resolve(process.cwd(), process.argv[saFlagIdx + 1]);
  const sa = require(saPath);
  admin.initializeApp({ credential: admin.credential.cert(sa) });
  console.log('Auth: service account JSON loaded');
} else {
  console.error('');
  console.error('ERROR: No service account provided.');
  console.error('');
  console.error('Usage:');
  console.error('  node migrate_shortstay_field.js --sa /path/to/serviceAccount.json');
  console.error('  node migrate_shortstay_field.js --sa /path/to/serviceAccount.json --execute');
  console.error('');
  console.error('Download your service account JSON from:');
  console.error('  Firebase Console → Project Settings → Service Accounts → Generate New Private Key');
  process.exit(1);
}

const db         = getFirestore('default');
const DRY_RUN    = !process.argv.includes('--execute');
const BATCH_SIZE = 400; // safely below Firestore's 500-op limit

// ── Field names ────────────────────────────────────────────────────────────
const OLD_FIELD = 'Hasapprovedshortstay';
const NEW_FIELD = 'hasActiveShortStay';

// ── Counters ───────────────────────────────────────────────────────────────
let scanned   = 0;
let migrated  = 0;
let skipped   = 0;
let alreadyOk = 0;

async function migrate() {
  console.log('');
  console.log('='.repeat(64));
  console.log(' VISTA — Firestore Field Migration');
  console.log(`   ${OLD_FIELD}  →  ${NEW_FIELD}`);
  console.log(`   Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : '*** EXECUTE — WILL WRITE TO FIRESTORE ***'}`);
  console.log('='.repeat(64));
  console.log('');

  const snapshot = await db.collection('users').get();
  scanned = snapshot.size;
  console.log(`Fetched ${scanned} user document(s). Analysing...\n`);

  // Collect docs that need updating
  const toMigrate = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // Already has new field — no action needed
    if (NEW_FIELD in data) {
      alreadyOk++;
      continue;
    }

    // Has old field — needs migration
    if (OLD_FIELD in data) {
      toMigrate.push({ ref: doc.ref, id: doc.id, value: data[OLD_FIELD] });
      continue;
    }

    // Has neither — regular student or warden without short-stay history
    skipped++;
  }

  console.log('--- Analysis Results ---');
  console.log(`  Documents scanned      : ${scanned}`);
  console.log(`  Already have new field : ${alreadyOk}`);
  console.log(`  Neither field (skip)   : ${skipped}`);
  console.log(`  Need migration         : ${toMigrate.length}`);
  console.log('');

  if (toMigrate.length === 0) {
    console.log('Nothing to migrate. All documents are already up to date.');
    process.exit(0);
  }

  // Print preview
  console.log('--- Documents to migrate ---');
  toMigrate.forEach(({ id, value }) => {
    console.log(`  [${id}]  ${OLD_FIELD}=${value}  →  ${NEW_FIELD}=${value}`);
  });
  console.log('');

  if (DRY_RUN) {
    console.log('DRY RUN complete. No writes performed.');
    console.log('Re-run with --execute to apply the migration.');
    process.exit(0);
  }

  // ── Execute in batches ─────────────────────────────────────────────────
  console.log('Committing writes...');

  for (let i = 0; i < toMigrate.length; i += BATCH_SIZE) {
    const chunk = toMigrate.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const { ref, value } of chunk) {
      batch.update(ref, {
        [NEW_FIELD] : value,                    // write new field with correct name
        [OLD_FIELD] : FieldValue.delete(),      // delete old field
      });
    }

    await batch.commit();
    migrated += chunk.length;
    console.log(`  Committed batch (${migrated}/${toMigrate.length})`);
  }

  console.log('');
  console.log('='.repeat(64));
  console.log(` Migration complete.`);
  console.log(`   Migrated  : ${migrated}`);
  console.log(`   Skipped   : ${skipped}`);
  console.log(`   Already OK: ${alreadyOk}`);
  console.log('='.repeat(64));
  console.log('');
}

migrate()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('\nFATAL ERROR:', err.message);
    process.exit(1);
  });
