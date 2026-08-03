import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../models/mess_model.dart';
import '../models/vista_user.dart';
import 'mess_qr_service.dart';
import 'cache_service.dart';

class MessScanValidationResult {
  final bool isGranted;
  final String message;
  final VistaUser? student;
  final MessMealType? mealType;

  MessScanValidationResult({
    required this.isGranted,
    required this.message,
    this.student,
    this.mealType,
  });
}

class MessService {
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
      app: Firebase.app(), databaseId: 'default');

  // ── Shared stream subjects ─────────────────────────────────────────────────
  // A single BehaviorSubject backs each high-frequency read-only stream so all
  // UI subscribers share ONE Firestore snapshot listener instead of each
  // creating their own. This is the main driver of Firestore read reduction.

  BehaviorSubject<Map<MessMealType, List<String>>>? _staplesSubject;
  StreamSubscription<Map<MessMealType, List<String>>>? _stapleSub;

  BehaviorSubject<MessWeeklyPdf?>? _weeklyPdfSubject;
  StreamSubscription<MessWeeklyPdf?>? _weeklyPdfSub;

  String _formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  // ── MENU OPERATIONS ───────────────────────────────────────────────────────

  /// Stream of menu items for a specific date (YYYY-MM-DD).
  /// Emits the cached list immediately (if available) then follows Firestore.
  Stream<List<MessMenuItem>> getMenuForDateStream(DateTime date) {
    final dateStr = _formatDate(date);
    final cacheKey = CacheService.messMenuKey(dateStr);
    final liveStream = _db
        .collection('mess_menu')
        .where('date', isEqualTo: dateStr)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((doc) => MessMenuItem.fromMap(doc.data(), doc.id))
              .toList();
          CacheService.instance.set<List<MessMenuItem>>(
            cacheKey,
            list,
            ttl: const Duration(minutes: 10),
          );
          return list;
        });

    final cached = CacheService.instance.get<List<MessMenuItem>>(cacheKey);
    if (cached != null) {
      return Rx.concat([Stream.value(cached), liveStream]);
    }
    return liveStream;
  }

  /// Updates or creates a daily menu item for a specific meal
  Future<void> updateDailyMenu({
    required DateTime date,
    required MessMealType mealType,
    required List<String> items,
    required String updatedBy,
  }) async {
    final dateStr = _formatDate(date);
    final docId = "${dateStr}_${mealType.name}";

    final menuItem = MessMenuItem(
      id: docId,
      date: dateStr,
      mealType: mealType,
      items: items,
      updatedBy: updatedBy,
      updatedAt: DateTime.now(),
    );

    await _db.collection('mess_menu').doc(docId).set(menuItem.toMap(), SetOptions(merge: true));
  }

  /// Shared stream of permanent daily staples.
  /// All subscribers share ONE Firestore listener via BehaviorSubject.
  Stream<Map<MessMealType, List<String>>> getPermanentStaplesStream() {
    if (_staplesSubject == null) {
      final subject = BehaviorSubject<Map<MessMealType, List<String>>>();
      _staplesSubject = subject;

      // Seed with cache immediately if available.
      final cached = CacheService.instance
          .get<Map<MessMealType, List<String>>>(CacheService.messStaplesKey);
      if (cached != null) subject.add(cached);

      _stapleSub = _db.collection('mess_staples').snapshots().map((snap) {
        final Map<MessMealType, List<String>> res = {};
        for (final doc in snap.docs) {
          final mealType = MessMealType.values.firstWhere(
            (m) => m.name == doc.id,
            orElse: () => MessMealType.breakfast,
          );
          final List<dynamic> itemsRaw = doc.data()['items'] ?? [];
          res[mealType] = itemsRaw.map((e) => e.toString()).toList();
        }
        return res;
      }).listen(
        (data) {
          CacheService.instance.set<Map<MessMealType, List<String>>>(
            CacheService.messStaplesKey,
            data,
            ttl: const Duration(minutes: 15),
          );
          subject.add(data);
        },
        onError: subject.addError,
      );

      // Auto-dispose when all subscribers leave.
      subject.onCancel = () {
        _stapleSub?.cancel();
        _stapleSub = null;
        _staplesSubject = null;
      };
    }
    return _staplesSubject!.stream;
  }

  /// Updates permanent staples for a meal type in Firestore
  Future<void> updatePermanentStaples(MessMealType mealType, List<String> items) async {
    await _db.collection('mess_staples').doc(mealType.name).set({
      'mealType': mealType.name,
      'items': items,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Batch updates multiple daily menu items for the entire week
  Future<void> updateWeeklyMenuBatch(List<MessMenuItem> menuItems) async {
    final batch = _db.batch();
    for (final item in menuItems) {
      final docRef = _db.collection('mess_menu').doc(item.id);
      batch.set(docRef, item.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ── WEEKLY PDF MENU ───────────────────────────────────────────────────────

  /// Shared stream of active weekly menu PDF metadata.
  /// All subscribers share ONE Firestore listener via BehaviorSubject.
  Stream<MessWeeklyPdf?> getActiveWeeklyPdfStream() {
    if (_weeklyPdfSubject == null) {
      final subject = BehaviorSubject<MessWeeklyPdf?>();
      _weeklyPdfSubject = subject;

      // Seed with cache immediately if available.
      final cached =
          CacheService.instance.get<MessWeeklyPdf?>(CacheService.messWeeklyPdfKey);
      if (cached != null) subject.add(cached);

      _weeklyPdfSub = _db
          .collection('mess_weekly_pdf')
          .orderBy('version', descending: true)
          .limit(1)
          .snapshots()
          .map((snap) {
            if (snap.docs.isEmpty) return null;
            return MessWeeklyPdf.fromMap(snap.docs.first.data(), snap.docs.first.id);
          })
          .listen(
            (data) {
              CacheService.instance.set<MessWeeklyPdf?>(
                CacheService.messWeeklyPdfKey,
                data,
                ttl: const Duration(minutes: 30),
              );
              subject.add(data);
            },
            onError: subject.addError,
          );

      subject.onCancel = () {
        _weeklyPdfSub?.cancel();
        _weeklyPdfSub = null;
        _weeklyPdfSubject = null;
      };
    }
    return _weeklyPdfSubject!.stream;
  }

  /// Save uploaded Weekly PDF metadata in Firestore
  Future<void> saveWeeklyPdfMetadata({
    required String title,
    required String pdfUrl,
    required String storagePath,
    required String uploadedBy,
  }) async {
    final snap = await _db.collection('mess_weekly_pdf').orderBy('version', descending: true).limit(1).get();
    int newVersion = 1;
    if (snap.docs.isNotEmpty) {
      final prev = snap.docs.first.data();
      newVersion = (prev['version'] is int ? prev['version'] as int : 1) + 1;
    }

    final docRef = _db.collection('mess_weekly_pdf').doc();
    final pdf = MessWeeklyPdf(
      id: docRef.id,
      title: title,
      pdfUrl: pdfUrl,
      storagePath: storagePath,
      uploadedBy: uploadedBy,
      uploadedAt: DateTime.now(),
      version: newVersion,
    );

    await docRef.set(pdf.toMap());
  }

  /// Uploads PDF bytes (works cross-platform: Web, Android, iOS) to Firebase Storage and saves document metadata in Firestore.
  Future<void> uploadWeeklyPdfBytes({
    required Uint8List bytes,
    required String fileName,
    required String title,
    required String uploadedBy,
  }) async {
    final storageRef = FirebaseStorage.instanceFor(bucket: 'gs://vista-app-c84cb.firebasestorage.app')
        .ref('mess_weekly_pdf/${DateTime.now().millisecondsSinceEpoch}_$fileName');

    final uploadTask = storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    final snap = await uploadTask;
    final downloadUrl = await snap.ref.getDownloadURL();

    await saveWeeklyPdfMetadata(
      title: title,
      pdfUrl: downloadUrl,
      storagePath: storageRef.fullPath,
      uploadedBy: uploadedBy,
    );
  }

  // ── SCANNER & REAL-TIME VALIDATION ────────────────────────────────────────

  /// Core validation engine called by Mess Manager & Admin scanners
  Future<MessScanValidationResult> verifyAndRecordMealScan({
    required String qrPayload,
    required String scannerId,
    required String scannerName,
  }) async {
    final now = DateTime.now();
    final dateStr = _formatDate(now);

    // 1. Verify Active Meal Timing
    final activeMeal = MessTimings.getCurrentMeal(now);
    if (activeMeal == null) {
      await _logScanAttempt(
        studentId: 'UNKNOWN',
        studentName: 'Unknown',
        rollNo: 'UNKNOWN',
        hostel: 'N/A',
        mealType: MessMealType.breakfast,
        date: dateStr,
        scannerId: scannerId,
        status: 'FAIL',
        failureReason: 'Outside Meal Timings',
      );
      return MessScanValidationResult(
        isGranted: false,
        message: 'Access Denied: Mess is currently closed. Outside official meal hours.',
      );
    }

    // 2. Validate Cryptographic QR Payload
    final qrResult = MessQrService.validateQrPayload(qrPayload);
    if (!qrResult.isValid || qrResult.uid == null) {
      final reason = qrResult.failureReason ?? 'Invalid or tampered QR code payload';
      await _logScanAttempt(
        studentId: 'UNKNOWN',
        studentName: 'Unknown',
        rollNo: 'UNKNOWN',
        hostel: 'N/A',
        mealType: activeMeal,
        date: dateStr,
        scannerId: scannerId,
        status: 'FAIL',
        failureReason: reason,
      );
      return MessScanValidationResult(
        isGranted: false,
        message: 'Access Denied: $reason',
        mealType: activeMeal,
      );
    }

    final uid = qrResult.uid!;

    // 3. Fetch Student Account Data
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) {
      await _logScanAttempt(
        studentId: uid,
        studentName: 'Unknown',
        rollNo: qrResult.rollNo ?? 'UNKNOWN',
        hostel: 'N/A',
        mealType: activeMeal,
        date: dateStr,
        scannerId: scannerId,
        status: 'FAIL',
        failureReason: 'Student record not found in system',
      );
      return MessScanValidationResult(
        isGranted: false,
        message: 'Access Denied: Student account not found.',
        mealType: activeMeal,
      );
    }

    final student = VistaUser.fromMap(userDoc.data()!);

    // 4. Enforce Single-Entry-Per-Meal Rule
    final attendanceDocId = "${dateStr}_${uid}_${activeMeal.name}";
    final existingAttendance = await _db.collection('mess_attendance').doc(attendanceDocId).get();

    if (existingAttendance.exists) {
      await _logScanAttempt(
        studentId: student.uid,
        studentName: student.name,
        rollNo: student.rollNo ?? 'N/A',
        hostel: student.hostel ?? 'N/A',
        mealType: activeMeal,
        date: dateStr,
        scannerId: scannerId,
        status: 'FAIL',
        failureReason: 'Already claimed ${activeMeal.displayName} today',
      );
      return MessScanValidationResult(
        isGranted: false,
        message: 'Access Denied: Student has ALREADY claimed ${activeMeal.displayName} today.',
        student: student,
        mealType: activeMeal,
      );
    }

    // 5. SUCCESS: Record Attendance & Scan Log
    final attendance = MessAttendance(
      id: attendanceDocId,
      studentId: student.uid,
      studentName: student.name,
      rollNo: student.rollNo ?? 'N/A',
      hostel: student.hostel ?? 'Day Scholar',
      roomNo: student.roomNumber,
      photoUrl: null,
      mealType: activeMeal,
      date: dateStr,
      timestamp: now,
      scannerId: scannerId,
      status: 'PASS',
    );

    await _db.collection('mess_attendance').doc(attendanceDocId).set(attendance.toMap());

    await _logScanAttempt(
      studentId: student.uid,
      studentName: student.name,
      rollNo: student.rollNo ?? 'N/A',
      hostel: student.hostel ?? 'N/A',
      mealType: activeMeal,
      date: dateStr,
      scannerId: scannerId,
      status: 'PASS',
    );

    return MessScanValidationResult(
      isGranted: true,
      message: 'Access Granted: Welcome to Mess!',
      student: student,
      mealType: activeMeal,
    );
  }

  Future<void> _logScanAttempt({
    required String studentId,
    required String studentName,
    required String rollNo,
    required String hostel,
    required MessMealType mealType,
    required String date,
    required String scannerId,
    required String status,
    String? failureReason,
  }) async {
    final docRef = _db.collection('mess_scan_logs').doc();
    final log = MessScanLog(
      id: docRef.id,
      studentId: studentId,
      studentName: studentName,
      rollNo: rollNo,
      hostel: hostel,
      mealType: mealType,
      date: date,
      timestamp: DateTime.now(),
      scannerId: scannerId,
      status: status,
      failureReason: failureReason,
    );
    await docRef.set(log.toMap());
  }

  // ── STUDENT HISTORY & STREAMS ─────────────────────────────────────────────

  /// Stream of meal attendance records for a specific student
  Stream<List<MessAttendance>> getStudentMealHistoryStream(String studentId) {
    return _db
        .collection('mess_attendance')
        .where('studentId', isEqualTo: studentId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessAttendance.fromMap(d.data(), d.id)).toList());
  }

  /// Stream of today's total attendance list for active meal
  Stream<List<MessAttendance>> getTodayMealAttendanceStream(String dateStr, MessMealType mealType) {
    return _db
        .collection('mess_attendance')
        .where('date', isEqualTo: dateStr)
        .where('mealType', isEqualTo: mealType.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessAttendance.fromMap(d.data(), d.id)).toList());
  }

  /// Stream of all scan logs filterable by date
  Stream<List<MessScanLog>> getScanLogsStream(String dateStr) {
    return _db
        .collection('mess_scan_logs')
        .where('date', isEqualTo: dateStr)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessScanLog.fromMap(d.data(), d.id)).toList());
  }

  // ── FEEDBACK OPERATIONS ──────────────────────────────────────────────────

  /// Submit dish ratings and feedback
  Future<void> submitMealFeedback(MessFeedback feedback) async {
    final docId = "${feedback.date}_${feedback.studentId}_${feedback.mealType.name}";
    await _db.collection('mess_feedback').doc(docId).set(feedback.toMap(), SetOptions(merge: true));
  }

  /// Stream of feedback for a specific date and meal
  Stream<List<MessFeedback>> getMealFeedbackStream(String dateStr, MessMealType mealType) {
    return _db
        .collection('mess_feedback')
        .where('date', isEqualTo: dateStr)
        .where('mealType', isEqualTo: mealType.name)
        .snapshots()
        .map((snap) => snap.docs.map((d) => MessFeedback.fromMap(d.data(), d.id)).toList());
  }

  // ── CSV & EXCEL LOG EXPORTS ───────────────────────────────────────────────

  /// Generates CSV string for scan logs
  String exportScanLogsToCsv(List<MessScanLog> logs) {
    final List<List<dynamic>> rows = [
      ['Date', 'Time', 'Student Name', 'Roll No', 'Hostel', 'Meal', 'Scanner ID', 'Status', 'Failure Reason'],
    ];

    for (final log in logs) {
      rows.add([
        log.date,
        DateFormat('HH:mm:ss').format(log.timestamp),
        log.studentName,
        log.rollNo,
        log.hostel,
        log.mealType.displayName,
        log.scannerId,
        log.status,
      ]);
    }

    return rows
        .map((r) => r.map((cell) => '"${cell.toString().replaceAll('"', '""')}"').join(','))
        .join('\n');
  }

  /// Generates Excel binary bytes for scan logs
  List<int>? exportScanLogsToExcel(List<MessScanLog> logs) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Mess Scan Logs'];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Time'),
      TextCellValue('Student Name'),
      TextCellValue('Roll No'),
      TextCellValue('Hostel'),
      TextCellValue('Meal'),
      TextCellValue('Scanner ID'),
      TextCellValue('Status'),
      TextCellValue('Failure Reason'),
    ]);

    for (final log in logs) {
      sheet.appendRow([
        TextCellValue(log.date),
        TextCellValue(DateFormat('HH:mm:ss').format(log.timestamp)),
        TextCellValue(log.studentName),
        TextCellValue(log.rollNo),
        TextCellValue(log.hostel),
        TextCellValue(log.mealType.displayName),
        TextCellValue(log.scannerId),
        TextCellValue(log.status),
        TextCellValue(log.failureReason ?? ''),
      ]);
    }

    return excel.encode();
  }
}
