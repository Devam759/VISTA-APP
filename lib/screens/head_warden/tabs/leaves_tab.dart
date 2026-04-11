import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';

class LeavesTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const LeavesTab({super.key, required this.warden, required this.fs});

  @override
  State<LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<LeavesTab> {
  DateTime? _selectedDate;
  String _hostelFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return WardenTabScaffold<LeaveRequest>(
      sectionTitle: 'Leave Management',
      tabs: const ['All', 'Pending', 'Approved', 'Rejected'],
      searchQueryPlaceholder: 'Search student or ID...',
      actionWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WardenSearchAction(
            onTap: () async {
              final picked = await WardenUIUtils.showWardenDatePicker(context, initialDate: _selectedDate);
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Icon(
              Icons.calendar_today_rounded,
              color: _selectedDate == null ? Colors.black54 : kPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          WardenSearchAction(
            onTap: () => WardenUIUtils.showHostelFilter(
              context: context,
              currentFilter: _hostelFilter == 'All' ? null : _hostelFilter,
              onSelected: (val) => setState(() => _hostelFilter = val ?? 'All'),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: _hostelFilter == 'All' ? Colors.black54 : kPrimary,
              size: 22,
            ),
          ),
        ],
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
        if (_hostelFilter != 'All' && leave.hostel != _hostelFilter) return false;
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
