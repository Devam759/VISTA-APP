import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firebase_service.dart';
import '../../models/vista_user.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userProfile!;

    final List<Widget> pages = [
      _AttendanceHome(user: user, firebaseService: _firebaseService),
      _LeaveHistory(user: user, firebaseService: _firebaseService),
      _Complaints(user: user, firebaseService: _firebaseService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('VISTA - Student'),
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_takeoff_outlined),
            label: 'Leave',
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

class _AttendanceHome extends StatefulWidget {
  final VistaUser user;
  final FirebaseService firebaseService;
  const _AttendanceHome({required this.user, required this.firebaseService});

  @override
  State<_AttendanceHome> createState() => _AttendanceHomeState();
}

class _AttendanceHomeState extends State<_AttendanceHome> {
  bool _isMarking = false;

  bool _isWithinAttendanceWindow() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 22, 0); // 10:00 PM
    final end = DateTime(now.year, now.month, now.day, 22, 30); // 10:30 PM
    return now.isAfter(start) && now.isBefore(end);
  }

  void _markAttendance() async {
    if (!_isWithinAttendanceWindow()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Attendance can only be marked between 10:00 PM and 10:30 PM',
          ),
        ),
      );
      return;
    }

    setState(() => _isMarking = true);
    try {
      final attendance = Attendance(
        id: '',
        studentId: widget.user.uid,
        studentName: widget.user.name,
        hostel: widget.user.hostel!,
        roomNumber: widget.user.roomNumber ?? 'N/A',
        timestamp: DateTime.now(),
        status: 'Present',
      );
      await widget.firebaseService.markAttendance(attendance);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance marked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark attendance: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Assigned Room',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    widget.user.roomNumber ?? 'Awaiting Assignment',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hostel: ${widget.user.hostel}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 60),
          const Text(
            'Night Attendance (10:00 PM - 10:30 PM)',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            height: 200,
            child: ElevatedButton(
              onPressed: _isMarking ? null : _markAttendance,
              style: ElevatedButton.styleFrom(shape: const CircleBorder()),
              child: _isMarking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Mark\nAttendance',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveHistory extends StatelessWidget {
  final VistaUser user;
  final FirebaseService firebaseService;
  const _LeaveHistory({required this.user, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLeaveDialog(context, user, firebaseService),
        label: const Text('Apply Leave'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: firebaseService
            .getPendingLeaves(user.hostel!)
            .map((list) => list.where((l) => l.studentId == user.uid).toList()),
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
                  title: Text(
                    '${DateFormat('MMM d').format(l.fromDate)} to ${DateFormat('MMM d').format(l.toDate)}',
                  ),
                  subtitle: Text('Status: ${l.status}\nReason: ${l.reason}'),
                  trailing: const Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLeaveDialog(BuildContext context, user, FirebaseService fs) {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final reasonController = TextEditingController();
    final parentNameController = TextEditingController();
    final parentContactController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Leave'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fromController,
                decoration: const InputDecoration(
                  labelText: 'From Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: toController,
                decoration: const InputDecoration(
                  labelText: 'To Date (YYYY-MM-DD)',
                ),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
              TextField(
                controller: parentNameController,
                decoration: const InputDecoration(labelText: 'Parent Name'),
              ),
              TextField(
                controller: parentContactController,
                decoration: const InputDecoration(labelText: 'Parent Contact'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final request = LeaveRequest(
                  id: '',
                  studentId: user.uid,
                  studentName: user.name,
                  hostel: user.hostel,
                  fromDate: DateTime.parse(fromController.text),
                  toDate: DateTime.parse(toController.text),
                  reason: reasonController.text,
                  parentName: parentNameController.text,
                  parentContact: parentContactController.text,
                  studentContact: user.phoneNumber ?? '',
                  status: 'Pending',
                );
                await fs.submitLeaveRequest(request);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid date or data: $e')),
                  );
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _Complaints extends StatelessWidget {
  final VistaUser user;
  final FirebaseService firebaseService;
  const _Complaints({required this.user, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showComplaintDialog(context, user, firebaseService),
        label: const Text('New Complaint'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: firebaseService
            .getComplaintsForRole('Warden', user.hostel)
            .map((list) => list.where((c) => c.studentId == user.uid).toList()),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaints = snapshot.data ?? [];
          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints submitted'));
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
                    'Status: ${c.status}\nTarget: ${c.targetRole}',
                  ),
                  trailing: c.status == 'Resolved' && c.studentConfirmed == null
                      ? IconButton(
                          icon: const Icon(
                            Icons.rate_review,
                            color: Colors.blue,
                          ),
                          onPressed: () =>
                              _confirmResolution(context, c, firebaseService),
                        )
                      : Icon(
                          c.status == 'Resolved'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: c.status == 'Resolved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmResolution(
    BuildContext context,
    Complaint c,
    FirebaseService fs,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Issue Resolved?'),
        content: const Text(
          'Is the issue resolved to your satisfaction? Selecting "No" will escalate this to the Head Warden.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await fs.updateComplaintStatus(c.id, 'Resolved'); // Confirm
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Yes - Solved'),
          ),
          TextButton(
            onPressed: () async {
              await fs.escalateComplaint(c.id);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'No - Escalate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, user, FirebaseService fs) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String target = 'Warden';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Submit Complaint'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: target,
                isExpanded: true,
                items: ['Warden', 'Head Warden']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => setModalState(() => target = val!),
              ),
              const Text(
                'Complaints are anonymous by default.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final complaint = Complaint(
                  id: '',
                  studentId: user.uid, // Stored but hidden logic on warden side
                  title: titleController.text,
                  description: descController.text,
                  hostel: user.hostel,
                  targetRole: target,
                  status: 'Pending',
                  isAnonymous: true,
                  createdAt: DateTime.now(),
                );
                await fs.submitComplaint(complaint);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
