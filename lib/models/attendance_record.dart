import 'vista_user.dart';
import 'attendance_model.dart';

class AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final String status;

  AttendanceRecord(this.student, this.attendance, {bool onLeave = false})
      : status = attendance != null
            ? ((attendance.timestamp.hour == 22 && attendance.timestamp.minute >= 30) || attendance.timestamp.hour == 23
                ? 'Late'
                : 'Marked')
            : (onLeave ? 'On Leave' : 'Absent');
}
