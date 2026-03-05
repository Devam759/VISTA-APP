import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/vista_user.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firebase_service.dart';

class WardenDashboard extends StatefulWidget {
  const WardenDashboard({super.key});

  @override
  State<WardenDashboard> createState() => _WardenDashboardState();
}

class _WardenDashboardState extends State<WardenDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final warden = Provider.of<AuthProvider>(context).userProfile!;

    final List<Widget> pages = [
      _RegistrationRequests(warden: warden, firebaseService: _firebaseService),
      _AttendanceView(warden: warden, firebaseService: _firebaseService),
      _LeaveManagement(warden: warden, firebaseService: _firebaseService),
      _ComplaintManagement(warden: warden, firebaseService: _firebaseService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('VISTA - Warden (${warden.hostel})'),
        actions: [
          IconButton(
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            label: 'Register',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_outlined),
            label: 'Leaves',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feedback_outlined),
            label: 'Complaints',
          ),
        ],
      ),
    );
  }
}

class _RegistrationRequests extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService firebaseService;
  const _RegistrationRequests({
    required this.warden,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VistaUser>>(
      stream: firebaseService.getPendingRegistrations(warden.hostel!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snapshot.data ?? [];
        if (pending.isEmpty) {
          return const Center(child: Text('No pending registration requests'));
        }
        return ListView.builder(
          itemCount: pending.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final student = pending[index];
            return Card(
              child: ListTile(
                title: Text(student.name),
                subtitle: Text(student.email),
                trailing: ElevatedButton(
                  onPressed: () => _approveDialog(context, student),
                  child: const Text('Approve'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _approveDialog(BuildContext context, VistaUser student) {
    final roomController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Room Number'),
        content: TextField(
          controller: roomController,
          decoration: const InputDecoration(
            labelText: 'Room Number (e.g. 101)',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await firebaseService.approveStudent(
                student.uid,
                roomController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Assign & Approve'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService firebaseService;
  const _AttendanceView({required this.warden, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    final todayStr =
        "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    return StreamBuilder<List<Attendance>>(
      stream: firebaseService.getHostelAttendance(warden.hostel!, todayStr),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data ?? [];
        if (records.isEmpty) {
          return const Center(child: Text('No attendance records for today'));
        }
        return ListView.builder(
          itemCount: records.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final a = records[index];
            return Card(
              child: ListTile(
                title: Text(a.studentName),
                subtitle: Text(
                  'Room: ${a.roomNumber} - ${DateFormat('HH:mm').format(a.timestamp)}',
                ),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }
}

class _LeaveManagement extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService firebaseService;
  const _LeaveManagement({required this.warden, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequest>>(
      stream: firebaseService.getPendingLeaves(warden.hostel!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final leaves = snapshot.data ?? [];
        if (leaves.isEmpty) {
          return const Center(child: Text('No pending leave requests'));
        }
        return ListView.builder(
          itemCount: leaves.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final l = leaves[index];
            return Card(
              child: ListTile(
                title: Text(l.studentName),
                subtitle: Text(
                  'Reason: ${l.reason}\nFrom: ${DateFormat('MMM d').format(l.fromDate)} To: ${DateFormat('MMM d').format(l.toDate)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () =>
                          firebaseService.updateLeaveStatus(l.id, 'Approved'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          firebaseService.updateLeaveStatus(l.id, 'Rejected'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ComplaintManagement extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService firebaseService;
  const _ComplaintManagement({
    required this.warden,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Complaint>>(
      stream: firebaseService.getComplaintsForRole('Warden', warden.hostel),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final complaints = snapshot.data ?? [];
        if (complaints.isEmpty) {
          return const Center(child: Text('No complaints received'));
        }
        return ListView.builder(
          itemCount: complaints.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final c = complaints[index];
            return Card(
              child: ListTile(
                title: Text(c.title),
                subtitle: Text(
                  'Description: ${c.description}\nStudent: Anonymous',
                ),
                trailing: c.status == 'Pending'
                    ? ElevatedButton(
                        onPressed: () => firebaseService.updateComplaintStatus(
                          c.id,
                          'Resolved',
                        ),
                        child: const Text('Resolve'),
                      )
                    : Icon(
                        c.status == 'Resolved'
                            ? Icons.check_circle
                            : Icons.warning,
                        color: c.status == 'Resolved'
                            ? Colors.green
                            : Colors.red,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
