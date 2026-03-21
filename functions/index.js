const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore('default');
const messaging = getMessaging();

/**
 * Helper to get current Date in Asia/Kolkata
 */
function getISTDate() {
    const now = new Date();
    return new Date(now.toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
}

/**
 * Helper to get current date in YYYY-M-D format (matching Dart's format)
 */
function getCurrentDateString() {
    const ist = getISTDate();
    return `${ist.getFullYear()}-${ist.getMonth() + 1}-${ist.getDate()}`;
}

/**
 * Common logic to send notifications to students
 */
async function sendNotificationToEligibleStudents(isMissedReminder = false) {
    const dateStr = getCurrentDateString();
    const nowIST = getISTDate();
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

        // 2. Get active approved short stays (for day scholars)
        const activeShortStays = await db.collection('short_stay_requests')
            .where('status', '==', 'Approved')
            .get();
        
        const activeShortStayUids = new Set();
        activeShortStays.forEach(doc => {
            const data = doc.data();
            const start = data.checkInDate.toDate();
            const end = data.checkOutDate.toDate();
            // Reset times for date-only comparison or keep as is if they are midnight
            start.setHours(0, 0, 0, 0);
            end.setHours(23, 59, 59, 999);
            if (nowIST >= start && nowIST <= end) {
                activeShortStayUids.add(data.studentId);
            }
        });

        // 3. Get active approved leaves
        const leavesSnapshot = await db.collection('leave_requests')
            .where('status', '==', 'Approved')
            .get();

        const onLeaveStudentIds = new Set();
        leavesSnapshot.forEach(doc => {
            const data = doc.data();
            try {
                const fromDate = data.fromDate.toDate ? data.fromDate.toDate() : new Date(data.fromDate);
                const toDate = data.toDate.toDate ? data.toDate.toDate() : new Date(data.toDate);
                fromDate.setHours(0, 0, 0, 0);
                toDate.setHours(23, 59, 59, 999);
                if (nowIST >= fromDate && nowIST <= toDate) {
                    onLeaveStudentIds.add(data.studentId);
                }
            } catch (e) {
                console.warn('Error parsing leave dates for doc:', doc.id, e);
            }
        });

        // 4. Get today's attendance (if missed reminder)
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
            
            // Exclude if on leave
            if (onLeaveStudentIds.has(uid)) return;
            
            // Inclusion logic:
            // - Regular hosteller (not day scholar)
            // - OR Day Scholar with ACTIVE short stay
            const isEligibleHosteller = !data.isDayScholar || activeShortStayUids.has(uid);
            
            // Exclude if already marked (for 10:20 PM)
            const isMarked = isMissedReminder && markedStudentIds.has(uid);

            if (fcmToken && isEligibleHosteller && !isMarked) {
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
        console.log(`${response.successCount} messages sent to ${tokens.length} potential tokens.`);
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

exports.notifyWardenNewRegistration = functions.region('asia-south1').firestore.database('default').document('users/{uid}').onCreate(async (snapshot, context) => {
    const newUser = snapshot.data();
    if (newUser.role !== 'student' || newUser.isApproved === true) return;

    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
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

exports.notifyWardenNewLeave = functions.region('asia-south1').firestore.database('default').document('leave_requests/{id}').onCreate(async (snapshot, context) => {
    const leave = snapshot.data();
    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
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
                    body: `${leave.studentName} has requested leave from ${leave.fromDate}.`,
                },
                tokens: tokens,
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewLeave:', error);
    }
});

exports.notifyWardenNewComplaint = functions.region('asia-south1').firestore.database('default').document('complaints/{id}').onCreate(async (snapshot, context) => {
    const complaint = snapshot.data();
    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', '==', complaint.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        if (complaint.targetRoles && (complaint.targetRoles.includes('headWarden') || complaint.targetRoles.includes('Head Warden'))) {
            const headWardens = await db.collection('users').where('role', '==', 'headWarden').get();
            headWardens.forEach(doc => {
                if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
            });
        }

        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Complaint Received',
                    body: `A new complaint has been filed for ${complaint.hostel}: ${complaint.title}`,
                },
                tokens: [...new Set(tokens)],
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewComplaint:', error);
    }
});

exports.notifyWardenNewShortStay = functions.region('asia-south1').firestore.database('default').document('short_stay_requests/{id}').onCreate(async (snapshot, context) => {
    const request = snapshot.data();
    try {
        // Short stay for boys goes to BH1/BH2 wardens, girls to GH1/GH2
        const targetHostels = request.gender === 'Male' ? ['BH1', 'BH2'] : ['GH1', 'GH2'];
        
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', 'in', targetHostels)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        // Always notify Head Warden for all short stays
        const headWardens = await db.collection('users').where('role', '==', 'headWarden').get();
        headWardens.forEach(doc => {
            if (doc.data().fcmToken) tokens.push(doc.data().fcmToken);
        });

        if (tokens.length > 0) {
            await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Short Stay Request',
                    body: `${request.studentName} (${request.gender}) is requesting a short stay for ${request.reason}.`,
                },
                tokens: [...new Set(tokens)],
            });
        }
    } catch (error) {
        console.error('Error in notifyWardenNewShortStay:', error);
    }
});

exports.notifyStudentOnUpdate = functions.region('asia-south1').firestore.database('default').document('{col}/{id}').onUpdate(async (change, context) => {
    const col = context.params.col;
    if (!['users', 'leave_requests', 'complaints', 'short_stay_requests'].includes(col)) return;

    const oldData = change.before.data();
    const newData = change.after.data();

    // Avoid triggering if status hasn't changed
    if (oldData.status === newData.status && col !== 'users') return;

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
        title = 'Leave Request Update';
        body = `Your leave request has been ${newData.status.toLowerCase()}.`;
        studentUid = newData.studentId;
    } else if (col === 'short_stay_requests') {
        title = 'Short Stay Update';
        body = `Your short stay request is now ${newData.status.toLowerCase()}${newData.roomNumber ? '. Allotted Room: ' + newData.roomNumber : ''}.`;
        studentUid = newData.studentId;
    } else if (col === 'complaints') {
        title = 'Complaint Update';
        body = newData.isEscalated ? 'Your complaint has been escalated.' : `Status now: ${newData.status}`;
        studentUid = newData.studentId;
    }

    if (title && studentUid) {
        const studentDoc = await db.collection('users').doc(studentUid).get();
        const token = studentDoc.data()?.fcmToken;
        if (token) {
            await messaging.send({ notification: { title, body }, token: token });
        }
    }
});
