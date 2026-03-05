/**
 * VISTA — Warden Seeder Script
 * Database ID: "default" (not the standard "(default)")
 */

const admin = require('firebase-admin');
const https = require('https');
const sa = require('../vista-jklu-firebase-adminsdk-fbsvc-913cb243b4.json');

admin.initializeApp({ credential: admin.credential.cert(sa) });

const auth = admin.auth();
const PROJECT_ID = 'vista-jklu';
const DB_ID = 'default'; // custom database name

const wardens = [
    { email: 'bh1@jklu.edu.in', password: 'bh1bh1', name: 'BH1 Warden', hostel: 'BH1' },
    { email: 'bh2@jklu.edu.in', password: 'bh2bh2', name: 'BH2 Warden', hostel: 'BH2' },
    { email: 'gh1@jklu.edu.in', password: 'gh1gh1', name: 'GH1 Warden', hostel: 'GH1' },
    { email: 'gh2@jklu.edu.in', password: 'gh2gh2', name: 'GH2 Warden', hostel: 'GH2' },
];

async function getToken() {
    const t = await admin.app().options.credential.getAccessToken();
    return t.access_token;
}

function firestoreWrite(token, docId, data) {
    const fields = {};
    for (const [k, v] of Object.entries(data)) {
        if (v === null) fields[k] = { nullValue: null };
        else if (typeof v === 'boolean') fields[k] = { booleanValue: v };
        else fields[k] = { stringValue: String(v) };
    }
    const body = JSON.stringify({ fields });
    const path = `/v1/projects/${PROJECT_ID}/databases/${DB_ID}/documents/users/${docId}`;

    return new Promise((resolve, reject) => {
        const req = https.request({
            hostname: 'firestore.googleapis.com',
            path,
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
            },
        }, (res) => {
            let d = '';
            res.on('data', c => d += c);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) resolve();
                else reject(new Error(`HTTP ${res.statusCode}: ${d.substring(0, 200)}`));
            });
        });
        req.on('error', reject);
        req.write(body);
        req.end();
    });
}

async function seedWardens() {
    console.log('🌱 Seeding warden accounts...\n');
    const token = await getToken();

    for (const warden of wardens) {
        let uid = null;

        // Step 1: Get or create Firebase Auth user
        try {
            const existing = await auth.getUserByEmail(warden.email);
            uid = existing.uid;
            console.log(`⚠️  ${warden.email} already exists (uid: ${uid})`);
        } catch (e) {
            if (e.code === 'auth/user-not-found') {
                try {
                    const newUser = await auth.createUser({
                        email: warden.email,
                        password: warden.password,
                        displayName: warden.name,
                    });
                    uid = newUser.uid;
                    console.log(`✅ Auth created: ${warden.email} (uid: ${uid})`);
                } catch (createErr) {
                    console.error(`❌ Auth create failed for ${warden.email}:`, createErr.message);
                    continue;
                }
            } else {
                console.error(`❌ Auth lookup failed for ${warden.email}:`, e.message);
                continue;
            }
        }

        // Step 2: Write Firestore profile via REST
        try {
            await firestoreWrite(token, uid, {
                uid,
                name: warden.name,
                email: warden.email,
                role: 'warden',
                hostel: warden.hostel,
                isApproved: true,
                phoneNumber: null,
                roomNumber: null,
            });
            console.log(`📄 Firestore profile saved for ${warden.hostel} Warden (uid: ${uid})\n`);
        } catch (fsErr) {
            console.error(`❌ Firestore write failed for ${warden.email}:`, fsErr.message);
        }
    }

    console.log('✨ Done! All warden accounts are ready.');
    process.exit(0);
}

seedWardens().catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
});
