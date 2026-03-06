const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

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
        const studentsSnapshot = await db.collection('users')
            .where('role', '==', 'student')
            .where('isApproved', '==', true)
            .get();

        if (studentsSnapshot.empty) {
            console.log('No approved students found.');
            return;
        }

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

        const markedStudentIds = new Set();
        if (isMissedReminder) {
            const attendanceSnapshot = await db.collection('attendance')
                .where('date', '==', dateStr)
                .get();
            attendanceSnapshot.forEach(doc => {
                markedStudentIds.add(doc.data().studentId);
            });
        }

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
        console.log(`${response.successCount} messages sent.`);
    } catch (error) {
        console.error('Error in sendNotificationToEligibleStudents:', error);
    }
}

/**
 * Scheduled function for 10:00 PM IST daily (16:30 UTC)
 */
exports.nightAttendanceReminder = functions.region('asia-south1').pubsub.schedule('30 16 * * *').onRun(async (context) => {
    await sendNotificationToEligibleStudents(false);
});

/**
 * Scheduled function for 10:20 PM IST daily (16:50 UTC)
 */
exports.nightAttendanceMissedReminder = functions.region('asia-south1').pubsub.schedule('50 16 * * *').onRun(async (context) => {
    await sendNotificationToEligibleStudents(true);
});

/**
 * Real-time Triggers
 */

exports.notifyWardenNewRegistration = functions.region('asia-south1').firestore.document('users/{uid}').onCreate(async (snapshot, context) => {
    const newUser = snapshot.data();
    if (newUser.role !== 'student' || newUser.isApproved === true) return;

    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'Warden')
            .where('hostel', '==', newUser.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Student Registration',
                    body: `${newUser.name} has registered for ${newUser.hostel}. Approval pending.`,
                },
                tokens: tokens,
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewRegistration:', error);
    }
});

exports.notifyWardenNewLeave = functions.region('asia-south1').firestore.document('leave_requests/{id}').onCreate(async (snapshot, context) => {
    const leave = snapshot.data();
    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'Warden')
            .where('hostel', '==', leave.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Leave Request',
                    body: `${leave.studentName} has requested leave from ${leave.outDate}.`,
                },
                tokens: tokens,
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewLeave:', error);
    }
});

exports.notifyWardenNewComplaint = functions.region('asia-south1').firestore.document('complaints/{id}').onCreate(async (snapshot, context) => {
    const complaint = snapshot.data();
    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'Warden')
            .where('hostel', '==', complaint.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        if (complaint.targetRoles && complaint.targetRoles.includes('Head Warden')) {
            const headWardens = await db.collection('users').where('role', '==', 'Head Warden').get();
            headWardens.forEach(doc => {
                if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
            });
        }

        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Complaint Received',
                    body: `A new complaint has been filed for ${complaint.hostel}: ${complaint.subject}`,
                },
                tokens: [...new Set(tokens)],
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewComplaint:', error);
    }
});

exports.notifyStudentOnUpdate = functions.region('asia-south1').firestore.document('{col}/{id}').onUpdate(async (change, context) => {
    const col = context.params.col;
    if (!['users', 'leave_requests', 'complaints'].includes(col)) return;

    const oldData = change.before.data();
    const newData = change.after.data();

    let title = '';
    let body = '';
    let studentUid = '';

    if (col === 'users') {
        if (oldData.isApproved === false && newData.isApproved === true) {
            title = 'Registration Approved!';
            body = `Your registration for ${newData.hostel} has been approved. Room: ${newData.roomNumber}`;
            studentUid = newData.uid;
        }
    } else if (col === 'leave_requests') {
        if (oldData.status !== newData.status) {
            title = 'Leave Request Update';
            body = `Your leave request has been ${newData.status.toLowerCase()}.`;
            studentUid = newData.studentId;
        }
    } else if (col === 'complaints') {
        if (oldData.status !== newData.status || oldData.isEscalated !== newData.isEscalated) {
            title = 'Complaint Update';
            body = newData.isEscalated ? 'Your complaint has been escalated.' : `Status now: ${newData.status}`;
            studentUid = newData.studentId;
        }
    }

    if (title && studentUid) {
        const studentDoc = await db.collection('users').doc(studentUid).get();
        const token = studentDoc.data()?.fcmToken;
        if (token) {
            await messaging.send({ notification: { title, body }, token: token });
        }
    }
});
