import 'vista_user.dart';
import 'attendance_model.dart';

class AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final String status;

  AttendanceRecord(this.student, this.attendance, {bool onLeave = false})
      : status = attendance != null
            ? attendance.status
            : (onLeave ? 'On Leave' : 'Absent');
}
