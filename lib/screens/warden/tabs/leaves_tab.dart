import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../services/firebase_service.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';

class LeavesTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const LeavesTab({super.key, required this.warden, required this.fs});

  @override
  State<LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<LeavesTab> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return WardenTabScaffold<LeaveRequest>(
      sectionTitle: 'Leave Management',
      tabs: const ['All', 'Pending', 'Approved', 'Rejected'],
      searchQueryPlaceholder: 'Search student or room...',
      actionWidget: WardenSearchAction(
        onTap: () async {
          final picked = await WardenUIUtils.showWardenDatePicker(context, initialDate: _selectedDate);
          if (picked != null) setState(() => _selectedDate = picked);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_rounded, size: 18, color: _selectedDate == null ? Colors.black54 : kPrimary),
            if (_selectedDate != null) ...[
              const SizedBox(width: 8),
              Text(
                DateFormat('MMM d').format(_selectedDate!),
                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _selectedDate = null),
                child: const Icon(Icons.close_rounded, size: 14, color: kPrimary),
              ),
            ],
          ],
        ),
      ),
      streamFactory: () => widget.fs.getUnifiedLeavesStream(widget.warden.hostel),
      emptyIcon: Icons.beach_access_rounded,
      emptyTitle: 'No Leave Requests',
      emptySubtitle: 'Student leave requests will appear here once submitted.',
      itemBuilder: (context, leave) => WardenLeaveCard(
        leave: leave,
        currentWarden: widget.warden,
        onApprove: (l) => widget.fs.updateLeaveStatus(l.id, 'Approved', actorUid: widget.warden.uid),
        onDeny: (l) => widget.fs.updateLeaveStatus(l.id, 'Rejected', actorUid: widget.warden.uid),
      ),
      filterLogic: (leave, tab, query) {
        if (tab != 'All' && leave.status != tab) return false;
        if (_selectedDate != null) {
          final d = _selectedDate!;
          if (leave.fromDate.isAfter(d) || leave.toDate.isBefore(d)) return false;
        }
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          return leave.studentName.toLowerCase().contains(q) || leave.seqId.toLowerCase().contains(q);
        }
        return true;
      },
    );
  }
}

