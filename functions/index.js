const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore('default');
const messaging = getMessaging();

// â”€â”€ FCM error codes that indicate a permanently invalid token â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const STALE_TOKEN_ERRORS = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Assigns a secure sequence ID to a new document (e.g., LA2412, CA241)
 * securely on the server using a Firestore transaction.
 */
async function assignSeqId(docRef, prefix) {
    const counterRef = db.collection('counters').doc(prefix);
    try {
        await db.runTransaction(async (transaction) => {
            const snapshot = await transaction.get(counterRef);
            let currentVal = 0;
            if (snapshot.exists) {
                currentVal = snapshot.data().current ?? 0;
            }
            const nextVal = currentVal + 1;
            transaction.set(counterRef, { current: nextVal });
            const yearStr = new Date().getFullYear().toString().slice(-2);
            const seqId = `${prefix}${yearStr}${nextVal}`;
            transaction.update(docRef, { seqId: seqId });
        });
    } catch (e) {
        console.error(`[assignSeqId] Failed to assign seqId for ${prefix}`, e);
    }
}

/**
 * After a multicast send, purge any FCM tokens that Firebase marked as
 * permanently invalid. Stale tokens accumulate silently and skew delivery stats.
 *
 * @param {admin.messaging.BatchResponse} response - Result from sendEachForMulticast
 * @param {string[]} tokens - The token array sent, parallel to response.responses
 * @param {string[]} uids   - The uid array parallel to tokens (for Firestore lookup)
 */
async function purgeStaleTokens(response, tokens, uids) {
  const purgePromises = [];
  response.responses.forEach((res, idx) => {
    if (res.success) return;
    const errCode = res.error?.code ?? '';
    if (STALE_TOKEN_ERRORS.has(errCode)) {
      const staleToken = tokens[idx];
      // Find the user document by token and null it out.
      purgePromises.push(
        db.collection('users')
          .where('fcmToken', '==', staleToken)
          .limit(1)
          .get()
          .then(snap => {
            if (!snap.empty) {
              return snap.docs[0].ref.update({ fcmToken: null });
            }
          })
          .catch(e => console.warn(`[purgeStaleTokens] Error purging token: ${e}`))
      );
    }
  });
  await Promise.allSettled(purgePromises);
}

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
    const d = ist.getDate().toString().padStart(2, '0');
    const m = (ist.getMonth() + 1).toString().padStart(2, '0');
    const y = ist.getFullYear();
    return `${d}-${m}-${y}`;
}

/**
 * Common logic to send notifications to students
 */
async function sendNotificationToEligibleStudents() {
    const dateStr = getCurrentDateString();
    const nowIST = getISTDate();
    console.log(`Starting reminder run for date: ${dateStr}`);

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
            if (!data.checkInDate || !data.checkOutDate || !data.studentId) return;
            const start = data.checkInDate.toDate();
            const end = data.checkOutDate.toDate();
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
            if (!data.fromDate || !data.toDate || !data.studentId) return;
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

        // 4. Note: No longer checking "already marked" (removed 10:20 PM reminder)
        const tokens = [];
        const uids   = [];
        studentsSnapshot.forEach(doc => {
            const data = doc.data();
            const uid = data.uid || doc.id;
            const fcmToken = data.fcmToken;

            if (!fcmToken || typeof fcmToken !== 'string') return;
            if (onLeaveStudentIds.has(uid)) return;

            // Day scholars are eligible ONLY if they have an active, approved short stay for the current date
            const isEligibleHosteller = !data.isDayScholar || activeShortStayUids.has(uid);

            if (isEligibleHosteller) {
                tokens.push(fcmToken);
                uids.push(uid);
            }
        });

        if (tokens.length === 0) {
            console.log('No eligible students to notify.');
            return;
        }

        const message = {
            notification: {
                title: 'Time for Night Attendance!',
                body: 'It is 10:00 PM. Please mark your night attendance now.',
            },
            android: {
                priority: 'high',
            },
            apns: {
                payload: {
                    aps: {
                        contentAvailable: true,
                    },
                },
            },
            tokens: tokens,
        };

        const response = await messaging.sendEachForMulticast(message);
        console.log(`${response.successCount} messages sent to ${tokens.length} potential tokens.`);

        // Purge permanently-invalid tokens to keep Firestore clean.
        if (response.failureCount > 0) {
            await purgeStaleTokens(response, tokens, uids);
        }
    } catch (error) {
        console.error('Error in sendNotificationToEligibleStudents:', error);
    }
}

/**
 * Scheduled function for 10:00 PM IST daily
 */
exports.nightAttendanceReminder = functions.region('asia-south1')
    .pubsub.schedule('00 22 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        await sendNotificationToEligibleStudents();
    });

/**
 * Sends a push notification when a new manual nudge is created in the notifications collection.
 */
exports.sendManualNotification = functions.region('asia-south1').firestore.database('default').document('notifications/{id}').onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    if (!data || !data.studentId) return;

    try {
        const studentSnap = await db.collection('users').doc(data.studentId).get();
        if (!studentSnap.exists) return;

        const student = studentSnap.data();
        const fcmToken = student.fcmToken;

        if (!fcmToken || typeof fcmToken !== 'string') {
            console.log(`[sendManualNotification] No valid token for student ${data.studentId}`);
            return;
        }

        const message = {
            notification: {
                title: data.title || 'Attendance Reminder',
                body: data.body || 'Please mark your attendance.',
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: data.type || 'attendance_nudge',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'attendance_reminders',
                },
            },
            token: fcmToken,
        };

        const response = await messaging.send(message);
        console.log(`Success sending manual notification to ${data.studentId}:`, response);
    } catch (error) {
        console.error(`Error sending manual notification for ${context.params.id}:`, error);
    }
});

/**
 * Real-time Triggers
 */

exports.notifyWardenNewRegistration = functions.region('asia-south1').firestore.database('default').document('users/{uid}').onCreate(async (snapshot, context) => {
    const newUser = snapshot.data();
    // Guard: only notify for pending student registrations.
    if (!newUser || newUser.role !== 'student' || newUser.isApproved === true) return;
    // Guard: require a hostel value to route notifications correctly.
    if (!newUser.hostel || typeof newUser.hostel !== 'string') {
        console.warn(`[notifyWardenNewRegistration] User ${context.params.uid} missing hostel field.`);
        return;
    }

    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', '==', newUser.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token && typeof token === 'string') tokens.push(token);
        });

        if (tokens.length > 0) {
            const response = await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Student Registration',
                    body: `${newUser.name || 'A student'} has registered for ${newUser.hostel}. Approval pending.`,
                },
                tokens: tokens,
            });
            if (response.failureCount > 0) await purgeStaleTokens(response, tokens, []);
        }
    } catch (error) {
        console.error('Error in notifyWardenNewRegistration:', error);
    }
});

exports.notifyWardenNewLeave = functions.region('asia-south1').firestore.database('default').document('leave_requests/{id}').onCreate(async (snapshot, context) => {
    // 1. Assign Sequence ID server-side
    await assignSeqId(snapshot.ref, 'LA');

    const leave = snapshot.data();
    if (!leave || !leave.hostel || !leave.studentName) {
        console.warn('[notifyWardenNewLeave] Missing required fields in leave request.');
        return;
    }

    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', '==', leave.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token && typeof token === 'string') tokens.push(token);
        });

        if (tokens.length > 0) {
            const response = await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Leave Request',
                    body: `${leave.studentName} has requested leave from ${leave.fromDate}.`,
                },
                tokens: tokens,
            });
            if (response.failureCount > 0) await purgeStaleTokens(response, tokens, []);
        }
    } catch (error) {
        console.error('Error in notifyWardenNewLeave:', error);
    }
});

exports.notifyWardenNewComplaint = functions.region('asia-south1').firestore.database('default').document('complaints/{id}').onCreate(async (snapshot, context) => {
    // 1. Assign Sequence ID server-side
    await assignSeqId(snapshot.ref, 'CA');

    const complaint = snapshot.data();
    if (!complaint || !complaint.hostel || !complaint.title) {
        console.warn('[notifyWardenNewComplaint] Missing required fields in complaint.');
        return;
    }

    try {
        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', '==', complaint.hostel)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token && typeof token === 'string') tokens.push(token);
        });

        if (complaint.targetRoles && (
            complaint.targetRoles.includes('headWarden') ||
            complaint.targetRoles.includes('Head Warden')
        )) {
            const headWardens = await db.collection('users').where('role', '==', 'headWarden').get();
            headWardens.forEach(doc => {
                const token = doc.data().fcmToken;
                if (token && typeof token === 'string') tokens.push(token);
            });
        }

        const uniqueTokens = [...new Set(tokens)];
        if (uniqueTokens.length > 0) {
            const response = await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Complaint Received',
                    body: `A new complaint has been filed for ${complaint.hostel}: ${complaint.title}`,
                },
                tokens: uniqueTokens,
            });
            if (response.failureCount > 0) await purgeStaleTokens(response, uniqueTokens, []);
        }
    } catch (error) {
        console.error('Error in notifyWardenNewComplaint:', error);
    }
});

exports.notifyWardenNewShortStay = functions.region('asia-south1').firestore.database('default').document('short_stay_requests/{id}').onCreate(async (snapshot, context) => {
    // 1. Assign Sequence ID server-side
    await assignSeqId(snapshot.ref, 'SS');

    const request = snapshot.data();
    if (!request || !request.gender || !request.studentName) {
        console.warn('[notifyWardenNewShortStay] Missing required fields in short stay request.');
        return;
    }

    // Validate gender to avoid injecting unexpected hostel values.
    if (!['Male', 'Female'].includes(request.gender)) {
        console.warn(`[notifyWardenNewShortStay] Unexpected gender value: ${request.gender}`);
        return;
    }

    try {
        const targetHostels = request.gender === 'Male' ? ['BH1', 'BH2'] : ['GH1', 'GH2'];

        const wardens = await db.collection('users')
            .where('role', '==', 'warden')
            .where('hostel', 'in', targetHostels)
            .get();

        const tokens = [];
        wardens.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token && typeof token === 'string') tokens.push(token);
        });

        const headWardens = await db.collection('users').where('role', '==', 'headWarden').get();
        headWardens.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token && typeof token === 'string') tokens.push(token);
        });

        const uniqueTokens = [...new Set(tokens)];
        if (uniqueTokens.length > 0) {
            const response = await messaging.sendEachForMulticast({
                notification: {
                    title: 'New Short Stay Request',
                    body: `${request.studentName} (${request.gender}) is requesting a short stay for ${request.reason || 'unspecified reason'}.`,
                },
                tokens: uniqueTokens,
            });
            if (response.failureCount > 0) await purgeStaleTokens(response, uniqueTokens, []);
        }
    } catch (error) {
        console.error('Error in notifyWardenNewShortStay:', error);
    }
});

// Allowed collection names to prevent wildcard abuse.
const NOTIFIABLE_COLLECTIONS = new Set([
    'users',
    'leave_requests',
    'complaints',
    'short_stay_requests',
]);

exports.notifyStudentOnUpdate = functions.region('asia-south1').firestore.database('default').document('{col}/{id}').onUpdate(async (change, context) => {
    const col = context.params.col;

    // Hard whitelist â€” ignore any collection not in our set.
    if (!NOTIFIABLE_COLLECTIONS.has(col)) return;

    const oldData = change.before.data();
    const newData = change.after.data();

    // Avoid triggering if status hasn't changed.
    if (oldData.status === newData.status && col !== 'users') return;

    let title = '';
    let body = '';
    let studentUid = '';

    if (col === 'users') {
        if (oldData.isApproved === false && newData.isApproved === true) {
            title = 'Registration Approved!';
            body = `Your registration for ${newData.hostel || 'your hostel'} has been approved. Room: ${newData.roomNumber || 'TBD'}`;
            studentUid = newData.uid || '';
        }
    } else if (col === 'leave_requests') {
        title = 'Leave Request Update';
        body = `Your leave request has been ${(newData.status || '').toLowerCase()}.`;
        studentUid = newData.studentId || '';
    } else if (col === 'short_stay_requests') {
        title = 'Short Stay Update';
        body = `Your short stay request is now ${(newData.status || '').toLowerCase()}${newData.roomNumber ? '. Allotted Room: ' + newData.roomNumber : ''}.`;
        studentUid = newData.studentId || '';
    } else if (col === 'complaints') {
        title = 'Complaint Update';
        body = newData.isEscalated
            ? 'Your complaint has been escalated.'
            : `Status now: ${newData.status || 'updated'}`;
        studentUid = newData.studentId || '';
    }

    if (title && studentUid) {
        try {
            const studentDoc = await db.collection('users').doc(studentUid).get();
            const token = studentDoc.data()?.fcmToken;
            if (token && typeof token === 'string') {
                const sendResult = await messaging.send({ notification: { title, body }, token });
                console.log(`[notifyStudentOnUpdate] Sent to ${studentUid}: ${sendResult}`);
            }
        } catch (e) {
            // If the token is stale, purge it.
            const errCode = e?.errorInfo?.code ?? '';
            if (STALE_TOKEN_ERRORS.has(errCode) && studentUid) {
                await db.collection('users').doc(studentUid)
                    .update({ fcmToken: null })
                    .catch(purgeErr => console.warn('[notifyStudentOnUpdate] Purge failed:', purgeErr));
            } else {
                console.error('[notifyStudentOnUpdate] Send failed:', e);
            }
        }
    }
});
/**
 * Scheduled function to handle:
 * 1. Automatic Escalation of Pending complaints after 3 days.
 * 2. Automatic Confirmation of Resolved complaints after 7 days (if student hasn't verified).
 * Runs daily at 1:00 AM IST.
 */
exports.autoProcessComplaints = functions.region('asia-south1')
    .pubsub.schedule('0 1 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        const now = new Date();
        const threeDaysAgo = new Date(now.getTime() - (3 * 24 * 60 * 60 * 1000));
        const sevenDaysAgo = new Date(now.getTime() - (7 * 24 * 60 * 60 * 1000));

        console.log('Starting auto-process for complaints...');

        try {
            // 1. Process 3-Day Escalation
            const pendingComplaints = await db.collection('complaints')
                .where('status', '==', 'Pending')
                .where('createdAt', '<=', threeDaysAgo)
                .get();

            const escalationPromises = [];
            pendingComplaints.forEach(doc => {
                const data = doc.data();
                // Avoid re-escalating if already at top level
                if (data.targetRoles && data.targetRoles.includes('Chief Warden')) return;

                let nextRoles = Array.from(data.targetRoles || []);
                let nextRole = '';

                if (nextRoles.includes('Head Warden')) {
                    if (!nextRoles.includes('Chief Warden')) nextRoles.push('Chief Warden');
                    nextRole = 'Chief Warden';
                } else if (nextRoles.includes('Warden')) {
                    if (!nextRoles.includes('Head Warden')) nextRoles.push('Head Warden');
                    nextRole = 'Head Warden';
                } else {
                    // Default fallback if roles are empty
                    nextRoles = ['Warden', 'Head Warden'];
                    nextRole = 'Head Warden';
                }

                escalationPromises.push(doc.ref.update({
                    isEscalated: true,
                    targetRole: nextRole,
                    targetRoles: nextRoles,
                    updatedAt: FieldValue.serverTimestamp(),
                }));
            });

            // 2. Process 7-Day Auto-Resolution (Confirmed)
            // Note: We use 'resolvedAt' field added to the model
            const resolvedComplaints = await db.collection('complaints')
                .where('status', '==', 'Resolved')
                .where('resolvedAt', '<=', sevenDaysAgo)
                .get();

            const confirmationPromises = [];
            resolvedComplaints.forEach(doc => {
                confirmationPromises.push(doc.ref.update({
                    status: 'Confirmed',
                    studentConfirmed: true,
                    updatedAt: FieldValue.serverTimestamp(),
                }));
            });

            await Promise.all([...escalationPromises, ...confirmationPromises]);
            console.log(`Auto-processed ${escalationPromises.length} escalations and ${confirmationPromises.length} confirmations.`);
        } catch (error) {
            console.error('Error in autoProcessComplaints:', error);
        }
    });

/**
 * Scheduled function to clean up Firestore image references older than 90 days.
 * Note: The actual file deletion is handled by the Storage Lifecycle Rule.
 * Runs daily at 2:00 AM IST.
 */
exports.cleanupOldComplaintImages = functions.region('asia-south1')
    .pubsub.schedule('0 2 * * *')
    .timeZone('Asia/Kolkata')
    .onRun(async (context) => {
        const ninetyDaysAgo = new Date(Date.now() - (90 * 24 * 60 * 60 * 1000));
        console.log(`Starting cleanup of image references older than: ${ninetyDaysAgo}`);

        try {
            const oldComplaintsSnap = await db.collection('complaints')
                .where('imageUrl', '!=', null)
                .where('createdAt', '<=', ninetyDaysAgo)
                .get();

            if (oldComplaintsSnap.empty) {
                console.log('No old image references to clean up.');
                return;
            }

            const batch = db.batch();
            oldComplaintsSnap.forEach(doc => {
                batch.update(doc.ref, {
                    imageUrl: null,
                    imageDeletedAt: FieldValue.serverTimestamp() // Log for auditing
                });
            });

            await batch.commit();
            console.log(`Successfully cleared ${oldComplaintsSnap.size} image references from Firestore.`);
        } catch (error) {
            console.error('Error in cleanupOldComplaintImages:', error);
        }
    });


// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  H1 - Server-Side Geofence: validateAndMarkAttendance
//  Callable HTTPS function: validates GPS server-side before writing attendance.
//  Client usage: FirebaseFunctions.instanceFor(region:'asia-south1')
//                  .httpsCallable('validateAndMarkAttendance').call({...})
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

const JKLU_GEOFENCE = [
  [26.83578622, 75.65131165],[26.83740740, 75.65114535],
  [26.83662239, 75.64845745],[26.83605158, 75.64818118],
  [26.83546162, 75.65019753],[26.83460988, 75.65087344],
  [26.83401423, 75.65117888],[26.83333241, 75.65138273],
  [26.83262606, 75.65278552],[26.83388768, 75.65269735],
  [26.83412283, 75.65222863],[26.83494166, 75.65249585],
];

function isInsideGeofence(lat, lng, polygon) {
  let inside = false, j = polygon.length - 1;
  for (let i = 0; i < polygon.length; i++) {
    const xi = polygon[i][0], yi = polygon[i][1];
    const xj = polygon[j][0], yj = polygon[j][1];
    if (((yi > lng) !== (yj > lng)) && (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi)) inside = !inside;
    j = i;
  }
  return inside;
}

exports.validateAndMarkAttendance = functions.region('asia-south1').https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
  const uid = context.auth.uid;
  const { latitude, longitude, status, hostel, roomNumber, studentName, date } = data;

  if (typeof latitude !== 'number' || typeof longitude !== 'number')
    throw new functions.https.HttpsError('invalid-argument', 'lat/lng must be numbers.');
  if (!['Present', 'Late'].includes(status))
    throw new functions.https.HttpsError('invalid-argument', 'status must be Present or Late.');
  if (!hostel || typeof hostel !== 'string')
    throw new functions.https.HttpsError('invalid-argument', 'hostel required.');
  if (!date || !/^\d{2}-\d{2}-\d{4}$/.test(date))
    throw new functions.https.HttpsError('invalid-argument', 'date must be DD-MM-YYYY.');

  // Server-side geofence - cannot be spoofed by Fake GPS
  if (!isInsideGeofence(latitude, longitude, JKLU_GEOFENCE)) {
    console.warn(`[geofence] UID ${uid} REJECTED at (${latitude},${longitude})`);
    throw new functions.https.HttpsError('failed-precondition', 'You must be inside JKLU campus.');
  }

  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) throw new functions.https.HttpsError('not-found', 'Profile not found.');
  const userDoc = userSnap.data();
  if (!userDoc.isApproved || userDoc.isAccountActive === false)
    throw new functions.https.HttpsError('permission-denied', 'Account not approved or inactive.');

  const existing = await db.collection('attendance')
    .where('studentId', '==', uid).where('date', '==', date).limit(1).get();
  if (!existing.empty) throw new functions.https.HttpsError('already-exists', 'Attendance already marked today.');

  await db.collection('attendance').add({
    studentId: uid,
    studentName: studentName || userDoc.name || '',
    hostel,
    roomNumber: roomNumber || 'N/A',
    status,
    date,
    lat: latitude,
    lng: longitude,
    timestamp: FieldValue.serverTimestamp(),
    markedViaServer: true,
  });

  console.log(`[geofence] SUCCESS: ${uid} marked ${status} on ${date}`);
  return { success: true };
});
