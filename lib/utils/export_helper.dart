import 'package:intl/intl.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import 'sanitizer.dart';

// Conditional imports for platform-specific saving
import 'save_helper_stub.dart'
    if (dart.library.io) 'save_helper_mobile.dart'
    if (dart.library.html) 'save_helper_web.dart';

class ExportHelper {
  static Future<void> exportAttendanceSummary(
    List<VistaUser> students,
    List<Attendance> attendance,
    List<LeaveRequest> leaves,
    List<DateTime> dates,
    String hostel, {
    bool sortByRoomNumber = false,
  }) async {
    // Sort students by room number if requested
    if (sortByRoomNumber) {
      students = List<VistaUser>.from(students);
      students.sort((a, b) {
        final roomA = a.roomNumber ?? '';
        final roomB = b.roomNumber ?? '';
        // Try to parse as numbers for proper numeric sorting
        final numA = int.tryParse(roomA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(roomB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (numA != numB) return numA.compareTo(numB);
        return roomA.compareTo(roomB);
      });
    }

    List<List<dynamic>> rows = [
      [
        'Student Name',
        'Room No',
        'Contact',
        'Email',
        ...dates.map((d) => DateFormat('MMM d').format(d)),
      ],
    ];

    for (var s in students) {
      List<dynamic> row = [
        s.name,
        s.roomNumber ?? '',
        InputSanitizer.formatPhoneWithCountryCode(s.phoneNumber ?? ''),
        s.email,
      ];

      for (var d in dates) {
        final dateStr = "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
        final att = attendance.firstWhere(
          (a) =>
              a.studentId == s.uid &&
              "${a.timestamp.day.toString().padLeft(2, '0')}-${a.timestamp.month.toString().padLeft(2, '0')}-${a.timestamp.year}" ==
                  dateStr,
          orElse: () => Attendance(
            id: 'absent',
            timestamp: d,
            studentId: s.uid,
            studentName: s.name,
            roomNumber: s.roomNumber ?? '',
            hostel: s.hostel ?? '',
            status: 'Absent',
          ),
        );

        final onLeave = leaves.any(
          (l) =>
              l.studentId == s.uid &&
              l.status == 'Approved' &&
              !d.isBefore(
                DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day),
              ) &&
              !d.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)),
        );

        if (onLeave) {
          row.add('On Leave');
        } else {
          row.add(att.status);
        }
      }
      rows.add(row);
    }

    await _saveAndShare(
      rows,
      'Attendance_Summary_${hostel}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
  }

  /// Export attendance summary with separate sheets for each hostel (Head Warden)
  static Future<void> exportAttendanceSummaryMultiHostel(
    Map<String, List<VistaUser>> hostelStudents,
    Map<String, List<Attendance>> hostelAttendance,
    Map<String, List<LeaveRequest>> hostelLeaves,
    List<DateTime> dates,
  ) async {
    final hostelNames = ['BH1', 'BH2', 'GH1', 'GH2'];

    await _saveAndShareMultiSheet(
      hostelNames,
      (hostel) {
        final students = hostelStudents[hostel] ?? [];
        final attendance = hostelAttendance[hostel] ?? [];
        final leaves = hostelLeaves[hostel] ?? [];

        // Sort students by room number
        final sortedStudents = List<VistaUser>.from(students);
        sortedStudents.sort((a, b) {
          final roomA = a.roomNumber ?? '';
          final roomB = b.roomNumber ?? '';
          final numA = int.tryParse(roomA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final numB = int.tryParse(roomB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (numA != numB) return numA.compareTo(numB);
          return roomA.compareTo(roomB);
        });

        List<List<dynamic>> rows = [
          [
            'Student Name',
            'Room No',
            'Contact',
            'Email',
            ...dates.map((d) => DateFormat('MMM d').format(d)),
          ],
        ];

        for (var s in sortedStudents) {
          List<dynamic> row = [
            s.name,
            s.roomNumber ?? '',
            InputSanitizer.formatPhoneWithCountryCode(s.phoneNumber ?? ''),
            s.email,
          ];

          for (var d in dates) {
            final dateStr = "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";
            final att = attendance.firstWhere(
              (a) =>
                  a.studentId == s.uid &&
                  "${a.timestamp.day.toString().padLeft(2, '0')}-${a.timestamp.month.toString().padLeft(2, '0')}-${a.timestamp.year}" ==
                      dateStr,
              orElse: () => Attendance(
                id: 'absent',
                timestamp: d,
                studentId: s.uid,
                studentName: s.name,
                roomNumber: s.roomNumber ?? '',
                hostel: s.hostel ?? '',
                status: 'Absent',
              ),
            );

            final onLeave = leaves.any(
              (l) =>
                  l.studentId == s.uid &&
                  l.status == 'Approved' &&
                  !d.isBefore(
                    DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day),
                  ) &&
                  !d.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)),
            );

            if (onLeave) {
              row.add('On Leave');
            } else {
              row.add(att.status);
            }
          }
          rows.add(row);
        }

        return rows;
      },
      'Attendance_Summary_All_Hostels_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
  }

  static Future<void> exportAttendance(
    List<Attendance> data,
    String hostel, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Filter by date range if provided
    var filteredData = data;
    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filteredData = data.where((a) {
        return !a.timestamp.isBefore(start) && !a.timestamp.isAfter(end);
      }).toList();
    }

    List<List<dynamic>> rows = [
      [
        'Date',
        'Student ID',
        'Student Name',
        'Hostel',
        'Room Number',
        'Status',
        'Timestamp',
      ],
    ];

    for (var a in filteredData) {
      rows.add([
        DateFormat('dd-MM-yyyy').format(a.timestamp),
        a.studentId,
        a.studentName,
        a.hostel,
        a.roomNumber,
        a.status,
        DateFormat('HH:mm:ss').format(a.timestamp),
      ]);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _saveAndShare(
      rows,
      'Attendance_Report_${hostel}_$dateRangeStr.xlsx',
    );
  }

  static Future<void> exportLeaves(
    List<LeaveRequest> data,
    List<VistaUser> students,
    String hostel, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Filter by date range if provided (based on created date)
    var filteredData = data;
    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filteredData = data.where((l) {
        return !l.createdAt.isBefore(start) && !l.createdAt.isAfter(end);
      }).toList();
    }
    List<List<dynamic>> rows = [
      [
        'Applied Date',
        'Student Name',
        'Room No',
        'Contact',
        'Email',
        'From',
        'To',
        'Reason',
        'Status',
        'Address',
        'Parent Contact',
      ],
    ];

    for (var l in filteredData) {
      final student = students.firstWhere(
        (s) => s.uid == l.studentId,
        orElse: () => VistaUser(
          uid: l.studentId,
          name: l.studentName,
          email: '',
          role: UserRole.student,
        ),
      );

      rows.add([
        DateFormat('dd-MM-yyyy').format(l.createdAt),
        l.studentName,
        student.roomNumber ?? '',
        InputSanitizer.formatPhoneWithCountryCode(student.phoneNumber ?? l.studentContact),
        student.email,
        DateFormat('dd-MM-yyyy').format(l.fromDate),
        DateFormat('dd-MM-yyyy').format(l.toDate),
        l.reason,
        l.status,
        l.address,
        InputSanitizer.formatPhoneWithCountryCode(l.parentContact),
      ]);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _saveAndShare(
      rows,
      'Leaves_Report_${hostel}_$dateRangeStr.xlsx',
    );
  }

  static Future<void> exportStudents(
    List<VistaUser> data,
    String hostel, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Note: Students list doesn't have a created date in the model,
    // so we export all students regardless of date range.
    // The date range parameters are kept for API consistency.
    List<List<dynamic>> rows = [
      ['Student Name', 'Room No', 'Contact', 'Email', 'Hostel', 'Status'],
    ];

    for (var s in data) {
      rows.add([
        s.name,
        s.roomNumber ?? '',
        InputSanitizer.formatPhoneWithCountryCode(s.phoneNumber ?? ''),
        s.email,
        s.hostel ?? '',
        s.isApproved ? 'Approved' : 'Pending',
      ]);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _saveAndShare(
      rows,
      'Students_List_${hostel}_$dateRangeStr.xlsx',
    );
  }

  static Future<void> exportComplaints(
    List<Complaint> data,
    String hostel, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Filter by date range if provided
    var filteredData = data;
    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filteredData = data.where((c) {
        return !c.createdAt.isBefore(start) && !c.createdAt.isAfter(end);
      }).toList();
    }
    List<List<dynamic>> rows = [
      [
        'Ticket ID',
        'Date',
        'Title',
        'Description',
        'Status',
        'Escalated',
        'Hostel',
      ],
    ];

    for (var c in filteredData) {
      rows.add([
        c.seqId,
        DateFormat('dd-MM-yyyy').format(c.createdAt),
        c.title,
        c.description,
        c.status,
        c.isEscalated ? 'YES' : 'NO',
        c.hostel,
      ]);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _saveAndShare(
      rows,
      'Complaints_Report_${hostel}_$dateRangeStr.xlsx',
    );
  }

  static Future<void> exportShortStays(
    List<ShortStayRequest> data,
    String hostel, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Filter by date range if provided (based on created date)
    var filteredData = data;
    if (startDate != null && endDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filteredData = data.where((s) {
        return !s.createdAt.isBefore(start) && !s.createdAt.isAfter(end);
      }).toList();
    }
    List<List<dynamic>> rows = [
      [
        'SEQ ID',
        'Student Name',
        'Roll No',
        'Programme',
        'Gender',
        'Email',
        'Contact No',
        'Address',
        'Reason',
        'Parent Name',
        'Parent Contact',
        'Check-in',
        'Check-out',
        'Status',
        'Hostel',
        'Room',
        'Applied At',
      ],
    ];

    for (var r in filteredData) {
      rows.add([
        r.seqId,
        r.studentName,
        r.rollNo,
        r.programme,
        r.gender,
        r.email,
        InputSanitizer.formatPhoneWithCountryCode(r.contactNo),
        r.address,
        r.reason,
        r.parentName,
        InputSanitizer.formatPhoneWithCountryCode(r.parentContact),
        DateFormat('dd-MM-yyyy HH:mm').format(r.checkInDate),
        DateFormat('dd-MM-yyyy HH:mm').format(r.checkOutDate),
        r.status,
        r.appliedHostel,
        r.roomNumber ?? '',
        DateFormat('dd-MM-yyyy HH:mm').format(r.createdAt),
      ]);
    }

    final dateRangeStr = (startDate != null && endDate != null)
        ? '${DateFormat('yyyyMMdd').format(startDate)}-${DateFormat('yyyyMMdd').format(endDate)}'
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _saveAndShare(
      rows,
      'ShortStay_Report_${hostel}_$dateRangeStr.xlsx',
    );
  }

  static Future<void> saveRawCsv(String csvString, String fileName) async {
    final List<List<dynamic>> rows = csvString
        .split('\n')
        .map((line) => line.split(','))
        .toList();
    await saveAndShare(rows, fileName);
  }

  static Future<void> _saveAndShare(
    List<List<dynamic>> rows,
    String fileName,
  ) async {
    await saveAndShare(rows, fileName);
  }

  static Future<void> _saveAndShareMultiSheet(
    List<String> sheetNames,
    List<List<dynamic>> Function(String) getRowsForSheet,
    String fileName,
  ) async {
    await saveAndShareMultiSheet(sheetNames, getRowsForSheet, fileName);
  }
}
