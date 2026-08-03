import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../../../widgets/common/skeleton_loader.dart';
import '../../../widgets/common/hover_effect.dart';

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
    return Consumer<WardenProvider>(
      builder: (context, wp, _) {
        return WardenTabScaffold<LeaveRequest>(
          title: 'Leave Requests',
          sectionTitle: 'Leave Requests',
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
          streamFactory: () => widget.fs.getUnifiedLeavesStream(wp.currentHostelFilter),
          loadingWidget: const LeaveListSkeleton(),
          emptyIcon: Icons.beach_access_rounded,
          emptyTitle: wp.currentHostelFilter == null ? 'No Leave Requests (All)' : 'No Leaves in ${wp.currentHostelFilter}',
          emptySubtitle: 'Student leave requests will appear here once submitted.',
          itemBuilder: (context, leave) => WardenExpandableLeaveCard(
            seqId: leave.seqId,
            studentName: leave.studentName,
            status: leave.status,
            fromDate: leave.fromDate,
            toDate: leave.toDate,
            reason: leave.reason,
            address: leave.address,
            parentName: leave.parentName,
            parentRelation: leave.parentRelation,
            parentContact: leave.parentContact,
            actions: Row(
              children: [
                Expanded(
                  child: HoverEffect(
                    child: OutlinedButton(
                      onPressed: () => widget.fs.updateLeaveStatus(leave.id, 'Rejected', actionUid: widget.warden.uid),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('REJECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoverEffect(
                    child: ElevatedButton(
                      onPressed: () => widget.fs.updateLeaveStatus(leave.id, 'Approved', actionUid: widget.warden.uid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('APPROVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
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
    );
  }
}

