import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../models/vista_user.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1E3A8A);
const _kAccent = Color(0xFF2563EB);
const _kBg = Color(0xFFF0F4FF);

class HeadWardenDashboard extends StatefulWidget {
  const HeadWardenDashboard({super.key});

  @override
  State<HeadWardenDashboard> createState() => _HeadWardenDashboardState();
}

class _HeadWardenDashboardState extends State<HeadWardenDashboard> {
  final FirebaseService _fs = FirebaseService();
  int _selectedIndex = 0;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final warden = Provider.of<AuthProvider>(context).userProfile!;

    final pages = [
      _StudentsTab(warden: warden, fs: _fs),
      _AttendanceTab(warden: warden, fs: _fs),
      _LeavesTab(warden: warden, fs: _fs),
      _ComplaintsTab(warden: warden, fs: _fs),
    ];

    const labels = ['Students', 'Attendance', 'Leaves', 'Complaints'];
    const icons = [
      (off: Icons.groups_outlined, on: Icons.groups),
      (off: Icons.assignment_ind_outlined, on: Icons.assignment_ind),
      (off: Icons.event_note_outlined, on: Icons.event_note),
      (off: Icons.assignment_late_outlined, on: Icons.assignment_late),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(4, (i) {
                final selected = _selectedIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kPrimary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? icons[i].on : icons[i].off,
                          size: 22,
                          color: selected ? _kPrimary : Colors.black38,
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(
                            labels[i],
                            style: const TextStyle(
                              color: _kPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ─────────── HEADER ───────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2460), _kPrimary, _kAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hPad = constraints.maxWidth > 900
                      ? (constraints.maxWidth - 900) / 2
                      : 16.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/jklu_logo_darkbg_bgremove.png',
                              height: 40,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'VISTA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'ALL HOSTELS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => FirebaseService().signOut(),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white60,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_greeting, ${warden.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ─────────── CONTENT ───────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hPad = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 900) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeInOutCubic,
                    switchOutCurve: Curves.easeInOutCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      key: ValueKey(_selectedIndex),
                      child: pages[_selectedIndex],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER CHIP
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
// QUICK STAT CARD (in header)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final int? count;
  const _SectionLabel(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withOpacity(0.08),
                  _kAccent.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: _kPrimary.withOpacity(0.35)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STYLED CARD
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENTS TAB — shows hostel students + pending-registration alert banner
// ─────────────────────────────────────────────────────────────────────────────
class _StudentsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _StudentsTab({required this.warden, required this.fs});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  bool _showRequests = false;
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'In Campus', 'On Leave'

  void _approveDialog(BuildContext context, VistaUser s) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Assign Room Number',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Student: ${s.name}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Room Number',
            hintText: 'e.g. 101',
            prefixIcon: const Icon(
              Icons.meeting_room_outlined,
              color: _kPrimary,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _kPrimary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.fs.approveStudent(s.uid, ctrl.text);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Approve',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.black.withOpacity(0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPrimary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isStudentOnLeave(String uid, List<LeaveRequest> approvedLeaves) {
    final now = DateTime.now();
    return approvedLeaves.any(
      (l) =>
          l.studentId == uid &&
          l.fromDate.isBefore(now) &&
          l.toDate.isAfter(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<VistaUser>>(
      stream: widget.fs.getPendingRegistrations(widget.warden.hostel),
      builder: (context, pendingSnap) {
        final pending = pendingSnap.data ?? [];

        return StreamBuilder<List<VistaUser>>(
          stream: widget.fs.getHostelStudents(widget.warden.hostel),
          builder: (context, memberSnap) {
            return StreamBuilder<List<LeaveRequest>>(
              stream: widget.fs.getApprovedLeaves(widget.warden.hostel),
              builder: (context, leaveSnap) {
                if (memberSnap.connectionState == ConnectionState.waiting &&
                    pendingSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kPrimary),
                  );
                }

                final allMembers = memberSnap.data ?? [];
                final approvedLeaves = leaveSnap.data ?? [];

                // Filtering logic
                var filtered = allMembers.where((m) {
                  final matchesSearch = m.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
                  bool matchesFilter = true;
                  if (_statusFilter == 'On Leave') {
                    matchesFilter = _isStudentOnLeave(m.uid, approvedLeaves);
                  } else if (_statusFilter == 'In Campus') {
                    matchesFilter = !_isStudentOnLeave(m.uid, approvedLeaves);
                  }
                  return matchesSearch && matchesFilter;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Pending Alert Banner ──
                    if (pending.isNotEmpty)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(
                                  () => _showRequests = !_showRequests,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kPrimary,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kPrimary.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.notifications_active_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${pending.length} Registration Request${pending.length > 1 ? 's' : ''}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              _showRequests
                                                  ? 'Tap to hide detail'
                                                  : 'Tap to review and approve',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.7,
                                                ),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        _showRequests
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_showRequests)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _kPrimary.withOpacity(0.1),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: pending.map((s) {
                                      return Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: _kPrimary
                                                      .withOpacity(0.1),
                                                  child: Text(
                                                    s.name.isNotEmpty
                                                        ? s.name[0]
                                                              .toUpperCase()
                                                        : 'S',
                                                    style: const TextStyle(
                                                      color: _kPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        s.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      Text(
                                                        s.email,
                                                        style: const TextStyle(
                                                          color: Colors.black45,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () async => widget
                                                          .fs
                                                          .denyStudent(s.uid),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red
                                                              .withOpacity(
                                                                0.08,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors.red
                                                                .withOpacity(
                                                                  0.15,
                                                                ),
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.close_rounded,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _approveDialog(
                                                            context,
                                                            s,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green
                                                              .withOpacity(
                                                                0.08,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors.green
                                                                .withOpacity(
                                                                  0.15,
                                                                ),
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.check_rounded,
                                                          color: Colors.green,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (s != pending.last)
                                            const Divider(
                                              height: 1,
                                              indent: 14,
                                              endIndent: 14,
                                            ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),

                    // ── Search & Filter ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Column(
                        children: [
                          Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Search by student name...',
                                hintStyle: TextStyle(
                                  color: Colors.black26,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: _kPrimary,
                                  size: 22,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All'),
                                const SizedBox(width: 8),
                                _buildFilterChip('In Campus'),
                                const SizedBox(width: 8),
                                _buildFilterChip('On Leave'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Hostel Students List ──
                    _SectionLabel('Hostel Students', count: filtered.length),

                    if (filtered.isEmpty)
                      Expanded(
                        child: _EmptyState(
                          icon: Icons.people_outline,
                          title: _searchQuery.isEmpty
                              ? 'No Students Yet'
                              : 'No Results Found',
                          subtitle: _searchQuery.isEmpty
                              ? 'Approve registration requests to add students'
                              : 'Try searching with a different name',
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, i) {
                            final m = filtered[i];
                            final onLeave = _isStudentOnLeave(
                              m.uid,
                              approvedLeaves,
                            );
                            return _Card(
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 24,
                                            backgroundColor: _kPrimary
                                                .withOpacity(0.1),
                                            child: Text(
                                              m.name.isNotEmpty
                                                  ? m.name[0].toUpperCase()
                                                  : 'S',
                                              style: const TextStyle(
                                                color: _kPrimary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: onLeave
                                                    ? Colors.orange
                                                    : Colors.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: Color(0xFF1E293B),
                                              ),
                                            ),
                                            Text(
                                              m.email,
                                              style: const TextStyle(
                                                color: Colors.black45,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 11,
                                                  color: Colors.black38,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  m.phoneNumber ?? 'No Phone',
                                                  style: const TextStyle(
                                                    color: Colors.black38,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (m.roomNumber != null &&
                                              m.roomNumber!.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _kPrimary.withOpacity(
                                                  0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.meeting_room_outlined,
                                                    size: 13,
                                                    color: _kPrimary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Room ${m.roomNumber}',
                                                    style: const TextStyle(
                                                      color: _kPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Text(
                                            onLeave ? 'ON LEAVE' : 'IN CAMPUS',
                                            style: TextStyle(
                                              color: onLeave
                                                  ? Colors.orange
                                                  : Colors.green,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .fadeIn(delay: (i * 50).ms)
                                .slideX(begin: 0.1);
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final String status;

  _AttendanceRecord(this.student, this.attendance)
    : status = attendance == null
          ? 'Absent'
          : (attendance.timestamp.hour >= 22 ? 'Late' : 'Marked');
}

class _AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _AttendanceTab({required this.warden, required this.fs});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Marked', 'Late', 'Absent'

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showDefaultersList(List<_AttendanceRecord> defaulters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Pending Attendance List',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: defaulters.isEmpty
                    ? const Center(
                        child: Text(
                          'All records completed.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: defaulters.length,
                        itemBuilder: (context, i) {
                          final student = defaulters[i].student;
                          return ListTile(
                            title: Text(
                              student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Room ${student.roomNumber ?? 'N/A'} [${student.hostel ?? ''}]',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            trailing: OutlinedButton.icon(
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kPrimary,
                                side: const BorderSide(color: _kPrimary),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              onPressed: () async {
                                final phoneStr = student.phoneNumber ?? '';
                                final phone = phoneStr.replaceAll(
                                  RegExp(r'[^\d+]'),
                                  '',
                                );
                                final Uri telUri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(
                                    telUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isLateWindow = now.hour >= 22 && now.hour < 24;
    final todayStr = '${now.year}-${now.month}-${now.day}';

    return StreamBuilder<List<VistaUser>>(
      stream: widget.fs.getHostelStudents(widget.warden.hostel),
      builder: (context, studentSnap) {
        return StreamBuilder<List<Attendance>>(
          stream: widget.fs.getHostelAttendance(widget.warden.hostel, todayStr),
          builder: (context, attendanceSnap) {
            if (studentSnap.connectionState == ConnectionState.waiting &&
                attendanceSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _kPrimary,
                  strokeWidth: 2,
                ),
              );
            }

            final students = studentSnap.data ?? [];
            final attendanceLists = attendanceSnap.data ?? [];

            final Map<String, Attendance> attendanceMap = {
              for (var a in attendanceLists) a.studentId: a,
            };

            List<_AttendanceRecord> records = students.map((s) {
              return _AttendanceRecord(s, attendanceMap[s.uid]);
            }).toList();

            final defaulters = records
                .where((r) => r.status == 'Absent')
                .toList();

            if (_statusFilter != 'All') {
              records = records
                  .where((r) => r.status == _statusFilter)
                  .toList();
            }

            if (_searchQuery.isNotEmpty) {
              records = records
                  .where(
                    (r) =>
                        r.student.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        (r.student.roomNumber ?? '').toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        (r.student.hostel ?? '').toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLateWindow && defaulters.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${defaulters.length} students pending attendance',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showDefaultersList(defaulters),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View List',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name, room, or hostel...',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: Colors.black45,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _kPrimary),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Marked'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Late'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Absent'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    "DAILY LOG (${records.length})",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.8,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                Expanded(
                  child: records.isEmpty
                      ? Center(
                          child: Text(
                            'No records found.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: records.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final r = records[i];
                            final isAbsent = r.status == 'Absent';
                            final isLate = r.status == 'Late';

                            Color statusColor = Colors.green.shade600;
                            if (isAbsent) {
                              statusColor = Colors.red.shade600;
                            } else if (isLate) {
                              statusColor = Colors.orange.shade700;
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.student.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '(${r.student.hostel ?? 'N/A'}) Room ${r.student.roomNumber ?? 'N/A'}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        r.status.toUpperCase(),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      if (r.attendance != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'HH:mm',
                                          ).format(r.attendance!.timestamp),
                                          style: const TextStyle(
                                            color: Colors.black45,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAVES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _LeavesTab extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _LeavesTab({required this.warden, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequest>>(
      stream: fs.getPendingLeaves(warden.hostel),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPrimary),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No Pending Leaves',
            subtitle: 'All leave requests have been processed',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Pending Leave Requests', count: list.length),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, i) {
                  final l = list[i];
                  return _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              color: _kPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'LEAVE REQUEST: ${l.studentName.toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                  color: _kPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildReadOnlyInput(
                          'From Date & Time',
                          DateFormat('dd/MM/yyyy hh:mm a').format(l.fromDate),
                          icon: Icons.access_time_rounded,
                        ),
                        _buildReadOnlyInput(
                          'To Date & Time',
                          DateFormat('dd/MM/yyyy hh:mm a').format(l.toDate),
                          icon: Icons.update_rounded,
                        ),
                        _buildReadOnlyInput(
                          'Reason',
                          l.reason,
                          icon: Icons.edit_note_rounded,
                        ),
                        _buildReadOnlyInput(
                          'Address during leave',
                          l.address,
                          icon: Icons.home_work_outlined,
                        ),
                        _buildReadOnlyInput(
                          'Parent Name',
                          '${l.parentName} (${l.parentRelation})',
                          icon: Icons.person_outline,
                        ),
                        _buildReadOnlyInput(
                          'Contact',
                          l.parentContact,
                          icon: Icons.phone_android_rounded,
                          trailing: IconButton(
                            onPressed: () async {
                              final phone = l.parentContact.replaceAll(
                                RegExp(r'[^\d+]'),
                                '',
                              );
                              final Uri telUri = Uri.parse('tel:$phone');
                              try {
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(
                                    telUri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.call_rounded,
                              color: Colors.green,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'PENDING WARDEN APPROVAL',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReadOnlyInput(
    String label,
    String value, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: _kPrimary.withOpacity(0.5)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary.withOpacity(0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ComplaintsTab extends StatelessWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _ComplaintsTab({required this.warden, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Complaint>>(
      stream: fs.getComplaintsForRole('Head Warden', warden.hostel),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _kPrimary),
          );
        }
        final list = snap.data ?? [];
        if (list.isEmpty) {
          return const _EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Complaints',
            subtitle: "Students haven't raised any complaints",
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Complaints', count: list.length),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final resolved = c.status == 'Resolved';
                  return _Card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: resolved
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            resolved
                                ? Icons.check_circle_outline
                                : Icons.assignment_late_outlined,
                            color: resolved ? Colors.green : Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '(${c.hostel}) ${c.title}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.description,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: resolved
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      (!resolved && c.isEscalated)
                                          ? 'ESCALATED'
                                          : c.status.toUpperCase(),
                                      style: TextStyle(
                                        color: (!resolved && c.isEscalated)
                                            ? Colors.redAccent
                                            : (resolved
                                                  ? Colors.green
                                                  : Colors.orange),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  if (!resolved) ...[
                                    const Spacer(),
                                    ElevatedButton(
                                      onPressed: () => fs.updateComplaintStatus(
                                        c.id,
                                        'Resolved',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _kPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: const Text('Mark Resolved'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (i * 50).ms).slideX(begin: 0.1);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
