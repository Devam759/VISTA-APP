const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const path = require('path');

// Initialize Firebase Admin SDK
let serviceAccount;
try {
    // Try loading from environment variable (for GitHub Actions)
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } else {
        // Fallback to local file
        serviceAccount = require('../vista-jklu-firebase-adminsdk-fbsvc-913cb243b4.json');
    }
} catch (e) {
    console.error('Failed to load service account:', e.message);
    process.exit(1);
}

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

// Use 'default' database ID to match the app's configuration
const db = getFirestore('default');
const messaging = getMessaging();

/**
 * Helper to get the current date in YYYY-MM-DD format based on a specific timezone
 * Defaulting to Asia/Kolkata (IST) since VISTA app seems to be for JKLU (India)
 */
function getCurrentDate() {
    const date = new Date();
    // We need to match Dart's timestamp.year-timestamp.month-timestamp.day exactly
    // Dart does not zero-pad the month or day by default in that string interpolation.
    // In Javascript timezone handling: (assuming IST)
    const options = { timeZone: 'Asia/Kolkata' };
    const formatterString = date.toLocaleString('en-US', { ...options, year: 'numeric', month: 'numeric', day: 'numeric' });
    // en-US formats as M/D/YYYY
    const parts = formatterString.split('/');
    return `${parts[2]}-${parts[0]}-${parts[1]}`;
}

/**
 * 10:00 PM Reminder: Send to ALL approved students who are NOT on leave.
 */
async function sendGeneralReminder() {
    console.log('--- Starting 10:00 PM General Reminder ---');
    const dateStr = getCurrentDate();

    try {
        // 1. Get all approved students
        const studentsSnapshot = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', true)
            .get();

        // 2. Get students currently on leave
        const leavesSnapshot = await db.collection('leave_requests')
            .where('status', '==', 'Approved')
            .get();

        // Filter leaves that are active today
        // Assuming outDate and inDate are stored as Timestamp or string. 
        // We will do a basic check here.
        const onLeaveStudentIds = new Set();
        const today = new Date(); // Or proper timezone date

        leavesSnapshot.forEach(doc => {
            const data = doc.data();
            // Leave logic: assuming data.outDate and data.inDate are Date strings or Firestore Timestamps
            // A safe way is to just exclude them if today is between outDate and inDate
            try {
                const outDate = data.outDate.toDate ? data.outDate.toDate() : new Date(data.outDate);
                const inDate = data.inDate.toDate ? data.inDate.toDate() : new Date(data.inDate);

                // Reset times for date-only comparison
                outDate.setHours(0, 0, 0, 0);
                inDate.setHours(23, 59, 59, 999);

                if (today >= outDate && today <= inDate) {
                    onLeaveStudentIds.add(data.studentId);
                }
            } catch (e) {
                console.warn('Error parsing leave dates for doc:', doc.id, e);
            }
        });

        const tokens = [];
        studentsSnapshot.forEach(doc => {
            const data = doc.data();
            if (!onLeaveStudentIds.has(data.uid) && data.fcmToken) {
                tokens.push(data.fcmToken);
            }
        });

        if (tokens.length === 0) {
            console.log('No eligible students found with FCM tokens.');
            return;
        }

        // Send notifications
        const message = {
            notification: {
                title: 'Time for Night Attendance!',
                body: 'Please mark your night attendance now.',
            },
            tokens: tokens,
        };

        const response = await messaging.sendEachForMulticast(message);
        console.log(response.successCount + ' messages were sent successfully');
        if (response.failureCount > 0) {
            console.log(response.failureCount + ' messages failed.');
        }
    } catch (error) {
        console.error('Error sending general reminder:', error);
    }
}

/**
 * 10:20 PM Reminder: Send only to students who missed marking attendance and are NOT on leave.
 */
async function sendMissedReminder() {
    console.log('--- Starting 10:20 PM Missed Attendance Reminder ---');
    const dateStr = getCurrentDate();

    try {
        // 1. Get all approved students
        const studentsSnapshot = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', true)
            .get();

        // 2. Get today's attendance records to see who already marked it
        const attendanceSnapshot = await db.collection('attendance')
            .where('date', '==', dateStr)
            .get();

        const markedStudentIds = new Set();
        attendanceSnapshot.forEach(doc => {
            markedStudentIds.add(doc.data().studentId);
        });

        // 3. Get students currently on leave
        const leavesSnapshot = await db.collection('leave_requests')
            .where('status', '==', 'Approved')
            .get();

        const onLeaveStudentIds = new Set();
        const today = new Date();

        leavesSnapshot.forEach(doc => {
            const data = doc.data();
            try {
                const outDate = data.outDate.toDate ? data.outDate.toDate() : new Date(data.outDate);
                const inDate = data.inDate.toDate ? data.inDate.toDate() : new Date(data.inDate);
                outDate.setHours(0, 0, 0, 0);
                inDate.setHours(23, 59, 59, 999);

                if (today >= outDate && today <= inDate) {
                    onLeaveStudentIds.add(data.studentId);
                }
            } catch (e) {
                console.warn('Error parsing leave dates for doc:', doc.id, e);
            }
        });

        const tokens = [];
        studentsSnapshot.forEach(doc => {
            const data = doc.data();
            const isMarked = markedStudentIds.has(data.uid);
            const isOnLeave = onLeaveStudentIds.has(data.uid);

            if (!isMarked && !isOnLeave && data.fcmToken) {
                tokens.push(data.fcmToken);
            }
        });

        if (tokens.length === 0) {
            console.log('No eligible students forgot to mark attendance or no tokens found.');
            return;
        }

        const message = {
            notification: {
                title: 'Attendance Reminder!',
                body: 'You haven\'t marked your night attendance yet. Please do it immediately.',
            },
            tokens: tokens,
        };

        const response = await messaging.sendEachForMulticast(message);
        console.log(response.successCount + ' messages were sent successfully');
    } catch (error) {
        console.error('Error sending missed reminder:', error);
    }
}

const args = process.argv.slice(2);
if (args[0] === '10pm') {
    sendGeneralReminder().then(() => process.exit(0));
} else if (args[0] === '1020pm') {
    sendMissedReminder().then(() => process.exit(0));
} else {
    console.log('Please specify "10pm" or "1020pm" as an argument.');
    process.exit(1);
}
