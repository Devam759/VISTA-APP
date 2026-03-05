import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/complaint_model.dart';

class HeadWardenDashboard extends StatefulWidget {
  const HeadWardenDashboard({super.key});

  @override
  State<HeadWardenDashboard> createState() => _HeadWardenDashboardState();
}

class _HeadWardenDashboardState extends State<HeadWardenDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _SystemStats(firebaseService: _firebaseService),
      _FullAttendanceLogs(firebaseService: _firebaseService),
      _EscalatedComplaints(firebaseService: _firebaseService),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('VISTA - Head Warden'),
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
            icon: Icon(Icons.analytics_outlined),
            label: 'Stats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            label: 'Logs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.priority_high_outlined),
            label: 'Escalations',
          ),
        ],
      ),
    );
  }
}

class _SystemStats extends StatelessWidget {
  final FirebaseService firebaseService;
  const _SystemStats({required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildStatCard('Total Students', '258', Colors.blue),
          _buildStatCard('BH1 Attendance', '92%', Colors.green),
          _buildStatCard('Pending Leaves', '12', Colors.orange),
          _buildStatCard('Resolved Today', '8', Colors.teal),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullAttendanceLogs extends StatelessWidget {
  final FirebaseService firebaseService;
  const _FullAttendanceLogs({required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'Full Attendance Logs across all hostels',
            style: TextStyle(color: Colors.grey),
          ),
          Text(
            'Wait for student data to populate.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _EscalatedComplaints extends StatelessWidget {
  final FirebaseService firebaseService;
  const _EscalatedComplaints({required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Complaint>>(
      stream: firebaseService.getComplaintsForRole('Head Warden', null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final complaints = snapshot.data ?? [];
        if (complaints.isEmpty) {
          return const Center(child: Text('No escalated complaints'));
        }
        return ListView.builder(
          itemCount: complaints.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final c = complaints[index];
            return Card(
              color: c.isEscalated ? Colors.red.shade50 : null,
              child: ListTile(
                title: Text(c.title),
                subtitle: Text(
                  'Reason: Student rejected warden solution\nDescription: ${c.description}',
                ),
                trailing: c.status == 'Pending' || c.isEscalated
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => firebaseService.updateComplaintStatus(
                          c.id,
                          'Resolved',
                        ),
                        child: const Text('Resolve Now'),
                      )
                    : const Icon(Icons.check_circle, color: Colors.green),
              ),
            );
          },
        );
      },
    );
  }
}
