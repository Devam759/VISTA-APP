import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../../../models/vista_user.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';
import '../../../widgets/skeleton_loader.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ComplaintsTab({super.key, required this.warden, required this.fs});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return Consumer<WardenProvider>(
      builder: (context, wp, _) {
        final hostelFilter = wp.currentHostelFilter ?? 'All';

        return WardenTabScaffold<Complaint>(
          title: 'Complaints',
          sectionTitle: 'Complaint Records',
          tabs: const ['Pending', 'Resolved', 'Escalated', 'All'],
          searchHint: 'Search ID, title...',
          searchQueryPlaceholder: 'Search ID, title...',
          actionWidget: WardenSearchAction(
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
          streamFactory: () => widget.fs.getComplaintsForRole('Chief Warden', hostelFilter),
          loadingWidget: const ComplaintListSkeleton(),
          itemBuilder: (context, complaint) => WardenExpandableComplaintCard(
            complaint: complaint,
            warden: widget.warden,
            fs: widget.fs,
          ),
          filterLogic: (complaint, tab, query) {
            // 1. Status Filter
            if (tab == 'Pending' && complaint.status != 'Pending') return false;
            if (tab == 'Resolved' && !(complaint.status == 'Resolved' || complaint.status == 'Confirmed')) return false;
            if (tab == 'Escalated' && !complaint.isEscalated) return false;

            // 2. Date Filter
            if (_selectedDate != null) {
              final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
              final created = DateTime(complaint.createdAt.year, complaint.createdAt.month, complaint.createdAt.day);
              if (!target.isAtSameMomentAs(created)) return false;
            }

            // 3. Search Filter
            if (query.isNotEmpty) {
              final q = query.toLowerCase();
              return complaint.title.toLowerCase().contains(q) || complaint.seqId.toLowerCase().contains(q);
            }

            return true;
          },
          emptyIcon: Icons.inbox_outlined,
          emptyTitle: 'No Complaints Found',
          emptySubtitle: _selectedDate != null ? 'No complaints recorded for this specific date.' : 'Try adjusting your search or filters.',
          extraHeader: _selectedDate != null ? Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 14, color: kPrimary),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, yyyy').format(_selectedDate!),
                        style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDate = null),
                        child: const Icon(Icons.close_rounded, size: 14, color: kPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ) : null,
        );
      },
    );
  }
}
