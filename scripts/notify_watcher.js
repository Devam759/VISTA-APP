const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);

initializeApp({
    credential: cert(serviceAccount)
});

const db = getFirestore('default');
const messaging = getMessaging();

/**
 * Helper to get current date in YYYY-M-D format (matching Dart's format)
 */
function getCurrentDateString() {
    const date = new Date();
    const options = { timeZone: 'Asia/Kolkata' };
    const formatterString = date.toLocaleString('en-US', { ...options, year: 'numeric', month: 'numeric', day: 'numeric' });
    const parts = formatterString.split('/'); // M/D/YYYY
    return `${parts[2]}-${parts[0]}-${parts[1]}`;
}

async function runWatcher() {
    console.log('--- NOTIFICATION WATCHER RUNNING ---');
    const now = new Date();
    const istTime = new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
    const hours = istTime.getHours();
    const minutes = istTime.getMinutes();

    try {
        // 1. ATTENDANCE REMINDERS (10:00 PM and 10:20 PM IST)
        if (hours === 22 && (minutes >= 0 && minutes <= 30)) {
            console.log('[Attendance] Checking for reminders...');
            const dateStr = getCurrentDateString();

            // Get all approved students
            const students = await db.collection('users')
                .where('role', '==', 'student')
                .where('isApproved', '==', true)
                .get();

            // Get marked attendance for today
            const marked = await db.collection('attendance')
                .where('date', '==', dateStr)
                .get();
            const markedIds = new Set(marked.docs.map(d => d.data().studentId));

            const tokens = [];
            students.docs.forEach(s => {
                const data = s.data();
                if (!markedIds.has(s.id) && data.fcmToken) tokens.push(data.fcmToken);
            });

            if (tokens.length > 0) {
                const isMissed = minutes >= 20;
                await messaging.sendEachForMulticast({
                    notification: {
                        title: isMissed ? 'Reminder: Attendance' : 'Night Attendance!',
                        body: isMissed ? "You missed the first call! Mark attendance now." : 'Please mark your night attendance.'
                    },
                    tokens: tokens
                });
                console.log(`[Attendance] Reminders sent to ${tokens.length} students.`);
            }
        }

        // 2. New Registrations
        const newRegs = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', false)
            .where('registrationNotified', '==', false)
            .get();

        for (const doc of newRegs.docs) {
            const user = doc.data();
            const wardens = await db.collection('users')
                .where('role', '==', 'warden')
                .where('hostel', '==', user.hostel)
                .get();
            const tokens = wardens.docs.map(w => w.data().fcmToken).filter(t => !!t);

            if (tokens.length > 0) {
                await messaging.sendEachForMulticast({
                    notification: { title: 'New Student', body: `${user.name} applied for ${user.hostel}.` },
                    tokens: tokens
                });
            }
            await doc.ref.update({ registrationNotified: true });
        }

        // 3. New Leave/Complaint
        const cols = ['leave_requests', 'complaints'];
        for (const col of cols) {
            const pendings = await db.collection(col).where('isNotified', '==', false).get();
            for (const doc of pendings.docs) {
                const item = doc.data();
                const wardens = await db.collection('users')
                    .where('role', '==', 'warden')
                    .where('hostel', '==', item.hostel)
                    .get();
                const tokens = wardens.docs.map(w => w.data().fcmToken).filter(t => !!t);

                if (col === 'complaints' && (item.targetRole === 'Head Warden' || item.targetRole === 'headWarden')) {
                    const hw = await db.collection('users').where('role', '==', 'headWarden').get();
                    hw.forEach(h => { if (h.data().fcmToken) tokens.push(h.data().fcmToken); });
                }

                if (tokens.length > 0) {
                    await messaging.sendEachForMulticast({
                        notification: {
                            title: col === 'leave_requests' ? 'New Leave' : 'New Complaint',
                            body: col === 'leave_requests' ? `${item.studentName} is requesting leave.` : `Title: ${item.title}`
                        },
                        tokens: [...new Set(tokens)]
                    });
                }
                await doc.ref.update({ isNotified: true });
            }
        }

        // 4. Status Updates
        for (const col of cols) {
            const requests = await db.collection(col).get();
            for (const doc of requests.docs) {
                const item = doc.data();
                if (item.status !== item.lastStatusNotified) {
                    const student = await db.collection('users').doc(item.studentId).get();
                    const token = student.data()?.fcmToken;
                    if (token) {
                        await messaging.send({
                            notification: { title: 'Update Received', body: `Your ${col.replace('_', ' ')} is now ${item.status}` },
                            token: token
                        });
                    }
                    await doc.ref.update({ lastStatusNotified: item.status });
                }
            }
        }

        // 5. Approvals
        const approvals = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', true)
            .where('approvalNotified', '==', false)
            .get();
        for (const doc of approvals.docs) {
            const s = doc.data();
            if (s.fcmToken) {
                await messaging.send({
                    notification: { title: 'Approved!', body: `Your account for ${s.hostel} is ready.` },
                    token: s.fcmToken
                });
            }
            await doc.ref.update({ approvalNotified: true });
        }

    } catch (error) {
        console.error('Watcher Error:', error);
    }
}

runWatcher();
