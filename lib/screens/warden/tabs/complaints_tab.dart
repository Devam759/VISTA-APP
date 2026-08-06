import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../../../widgets/common/skeleton_loader.dart';
import '../../../widgets/common/hover_effect.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  const ComplaintsTab({super.key, required this.warden});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> {
  final FirebaseService _fs = FirebaseService();
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              onSurface: kPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine role string for Firestore query
    String roleStr = 'Warden';
    if (widget.warden.role == UserRole.headWarden) roleStr = 'Head Warden';
    if (widget.warden.role == UserRole.chiefWarden) roleStr = 'Chief Warden';

    return Column(
      children: [
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        style: const TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w700),
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
          ),
            Expanded(
              child: Consumer<WardenProvider>(
                builder: (context, wp, _) {
                  return WardenTabScaffold<Complaint>(
                    title: 'Complaints',
                    searchCtrl: _searchCtrl,
                    searchHint: 'Search ID, title...',
                    tabs: const ['Pending', 'Resolved', 'Escalated', 'Closed'],
                    actionWidget: WardenSearchAction(
                      onTap: () => _selectDate(context),
                      child: HoverEffect(
                        child: Icon(
                          Icons.calendar_today_rounded,
                          color: _selectedDate != null ? kPrimary : Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),
                    streamFactory: () => _fs.getComplaintsForRole(roleStr, wp.currentHostelFilter),
                    loadingWidget: const ComplaintListSkeleton(),
                    itemBuilder: (context, complaint) {
                      return WardenExpandableComplaintCard(
                        complaint: complaint,
                        warden: widget.warden,
                        fs: _fs,
                      );
                    },
                    filterLogic: (complaint, tab, query) {
                      // 1. Status Filter
                      bool matchesStatus = false;
                      if (tab == 'Pending') {
                        matchesStatus = complaint.status == 'Pending';
                      } else if (tab == 'Resolved') {
                        // Resolved = awaiting student confirmation
                        matchesStatus = complaint.status == 'Resolved';
                      } else if (tab == 'Escalated') {
                        matchesStatus = complaint.isEscalated && !complaint.isClosed && complaint.status != 'ClosedByStudent' && complaint.status != 'AutoClosed';
                      } else if (tab == 'Closed') {
                        matchesStatus = complaint.status == 'Confirmed' ||
                            complaint.status == 'ClosedByStudent' ||
                            complaint.status == 'AutoClosed';
                      }

                      if (!matchesStatus) return false;

                      // 2. Date Filter
                      if (_selectedDate != null) {
                        final cDate = complaint.createdAt;
                        if (cDate.year != _selectedDate!.year ||
                            cDate.month != _selectedDate!.month ||
                            cDate.day != _selectedDate!.day) {
                          return false;
                        }
                      }

                      // 3. Search Filter
                      if (query.isEmpty) return true;
                      final q = query.toLowerCase();
                      return complaint.title.toLowerCase().contains(q) ||
                          complaint.seqId.toLowerCase().contains(q);
                    },
                    emptyIcon: Icons.assignment_outlined,
                    emptyTitle: wp.currentHostelFilter == null ? 'No complaints in any hostel' : 'No complaints in ${wp.currentHostelFilter}',
                    emptySubtitle: 'Try adjusting your filters or search query',
                    sectionTitle: 'Complaint Records',
                  );
                }
              ),
            ),
      ],
    );
  }
}


