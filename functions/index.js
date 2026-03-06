const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions } = require('firebase-functions/v2');

initializeApp();

// Set global options, specifically region
setGlobalOptions({ region: 'us-central1' });

// Initialize Firestore for 'default' database ID as specified in your Flutter service
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

/**
 * Common logic to send notifications to students
 */
async function sendNotificationToEligibleStudents(isMissedReminder = false) {
    const dateStr = getCurrentDateString();
    console.log(`Starting reminder run for date: ${dateStr}, isMissed: ${isMissedReminder}`);

    try {
        // 1. Get all approved students
        const studentsSnapshot = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', true)
            .get();

        if (studentsSnapshot.empty) {
            console.log('No approved students found.');
            return;
        }

        // 2. Get students currently on leave
        const today = new Date();
        const leavesSnapshot = await db.collection('leave_requests')
            .where('status', '==', 'Approved')
            .get();

        const onLeaveStudentIds = new Set();
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

        // 3. If it's the missed reminder, check who already marked attendance
        const markedStudentIds = new Set();
        if (isMissedReminder) {
            const attendanceSnapshot = await db.collection('attendance')
                .where('date', '==', dateStr)
                .get();
            attendanceSnapshot.forEach(doc => {
                markedStudentIds.add(doc.data().studentId);
            });
        }

        // 4. Filter students and collect tokens
        const tokens = [];
        studentsSnapshot.forEach(doc => {
            const data = doc.data();
            const uid = data.uid || doc.id;
            const fcmToken = data.fcmToken;

            const isOnLeave = onLeaveStudentIds.has(uid);
            const isMarked = isMissedReminder && markedStudentIds.has(uid);

            if (fcmToken && !isOnLeave && !isMarked) {
                tokens.push(fcmToken);
            }
        });

        if (tokens.length === 0) {
            console.log('No eligible students to notify.');
            return;
        }

        // 5. Send multicast message
        const message = {
            notification: {
                title: isMissedReminder ? 'Attendance Reminder!' : 'Time for Night Attendance!',
                body: isMissedReminder
                    ? "You haven't marked your night attendance yet. Please do it immediately."
                    : 'It is 10:00 PM. Please mark your night attendance now.',
            },
            tokens: tokens,
        };

        const response = await messaging.sendEachForMulticast(message);
        console.log(`${response.successCount} messages sent. ${response.failureCount} failed.`);
    } catch (error) {
        console.error('Error in sendNotificationToEligibleStudents:', error);
    }
}

/**
 * Scheduled function for 10:00 PM IST daily
 * 10:00 PM IST is 16:30 UTC
 */
exports.nightAttendanceReminder = onSchedule('30 16 * * *', async (event) => {
    await sendNotificationToEligibleStudents(false);
});

/**
 * Scheduled function for 10:20 PM IST daily
 * 10:20 PM IST is 16:50 UTC
 */
exports.nightAttendanceMissedReminder = onSchedule('50 16 * * *', async (event) => {
    await sendNotificationToEligibleStudents(true);
});
