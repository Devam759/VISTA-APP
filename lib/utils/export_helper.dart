import 'package:intl/intl.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';

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
    String hostel,
  ) async {
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
        s.phoneNumber ?? '',
        s.email,
      ];

      for (var d in dates) {
        final dateStr = "${d.year}-${d.month}-${d.day}";
        final att = attendance.firstWhere(
          (a) =>
              a.studentId == s.uid &&
              "${a.timestamp.year}-${a.timestamp.month}-${a.timestamp.day}" ==
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
      'Attendance_Summary_${hostel}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  static Future<void> exportAttendance(
    List<Attendance> data,
    String hostel,
  ) async {
    List<List<dynamic>> rows = [
      [
        'Date',
        'Student ID',
        'Student Name',
        'Hostel',
        'Status',
        'In Time',
        'Gate Pass',
      ],
    ];

    for (var a in data) {
      rows.add([
        DateFormat('dd/MM/yyyy').format(a.timestamp),
        a.studentId,
        a.studentName,
        a.hostel,
        a.status,
      ]);
    }

    await _saveAndShare(
      rows,
      'Attendance_Report_${hostel}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  static Future<void> exportLeaves(
    List<LeaveRequest> data,
    List<VistaUser> students,
    String hostel,
  ) async {
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

    for (var l in data) {
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
        DateFormat('dd/MM/yyyy').format(l.createdAt),
        l.studentName,
        student.roomNumber ?? '',
        student.phoneNumber ?? l.studentContact,
        student.email,
        DateFormat('dd/MM/yyyy').format(l.fromDate),
        DateFormat('dd/MM/yyyy').format(l.toDate),
        l.reason,
        l.status,
        l.address,
        l.parentContact,
      ]);
    }

    await _saveAndShare(
      rows,
      'Leaves_Report_${hostel}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  static Future<void> exportStudents(
    List<VistaUser> data,
    String hostel,
  ) async {
    List<List<dynamic>> rows = [
      ['Student Name', 'Room No', 'Contact', 'Email', 'Hostel', 'Status'],
    ];

    for (var s in data) {
      rows.add([
        s.name,
        s.roomNumber ?? '',
        s.phoneNumber ?? '',
        s.email,
        s.hostel ?? '',
        s.isApproved ? 'Approved' : 'Pending',
      ]);
    }

    await _saveAndShare(
      rows,
      'Students_List_${hostel}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  static Future<void> exportComplaints(
    List<Complaint> data,
    String hostel,
  ) async {
    List<List<dynamic>> rows = [
      [
        'Date',
        'Student',
        'Title',
        'Description',
        'Status',
        'Escalated',
        'Hostel',
      ],
    ];

    for (var c in data) {
      rows.add([
        DateFormat('dd/MM/yyyy').format(c.createdAt),
        c.isAnonymous ? 'Anonymous' : c.studentName,
        c.title,
        c.description,
        c.status,
        c.isEscalated ? 'YES' : 'NO',
        c.hostel,
      ]);
    }

    await _saveAndShare(
      rows,
      'Complaints_Report_${hostel}_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  static Future<void> _saveAndShare(
    List<List<dynamic>> rows,
    String fileName,
  ) async {
    await saveAndShare(rows, fileName);
  }
}
