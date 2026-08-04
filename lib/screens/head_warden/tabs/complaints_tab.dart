import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/common/skeleton_loader.dart';
import '../../warden/components/warden_components.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ComplaintsTab({super.key, required this.warden, required this.fs});

  @override
  State<ComplaintsTab> createState() => ComplaintsTabState();
}

class ComplaintsTabState extends State<ComplaintsTab> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _selectedDate;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = InputSanitizer.sanitize(_searchCtrl.text));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WardenSearchHeader(
          controller: _searchCtrl,
          hintText: 'Search by title or ID (e.g. CA241)...',
          actionWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              WardenSearchAction(
                onTap: () => _selectDate(context),
                child: const Icon(Icons.calendar_today_rounded, color: Colors.black54, size: 22),
              ),
              const SizedBox(width: 8),
        ],
      ),
    ),
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: ['Pending', 'Resolved', 'Escalated', 'Closed'].asMap().entries.map((entry) {
              return WardenFilterChip(
                label: entry.value,
                isSelected: _tabController.index == entry.key,
                onTap: () {
                  _tabController.animateTo(entry.key);
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _FilteredComplaintList(status: 'Pending', searchQuery: _searchQuery, selectedDate: _selectedDate, fs: widget.fs, warden: widget.warden),
              _FilteredComplaintList(status: 'Resolved', searchQuery: _searchQuery, selectedDate: _selectedDate, fs: widget.fs, warden: widget.warden),
              _FilteredComplaintList(status: 'Escalated', searchQuery: _searchQuery, selectedDate: _selectedDate, fs: widget.fs, warden: widget.warden),
              _FilteredComplaintList(status: 'Closed', searchQuery: _searchQuery, selectedDate: _selectedDate, fs: widget.fs, warden: widget.warden),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilteredComplaintList extends StatefulWidget {
  final String status;
  final String searchQuery;
  final DateTime? selectedDate;
  final FirebaseService fs;
  final VistaUser warden;

  const _FilteredComplaintList({
    required this.status,
    required this.searchQuery,
    this.selectedDate,
    required this.fs,
    required this.warden,
  });

  @override
  State<_FilteredComplaintList> createState() => _FilteredComplaintListState();
}

class _FilteredComplaintListState extends State<_FilteredComplaintList> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wp = Provider.of<WardenProvider>(context);
    final hostelFilter = wp.currentHostelFilter ?? 'All';

    return StreamBuilder<List<Complaint>>(
      stream: widget.fs.getComplaintsForRole('Head Warden', hostelFilter),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const ComplaintListSkeleton();
        var list = snap.data ?? [];

        // Apply Local Filters
        if (widget.searchQuery.isNotEmpty) {
          list = list.where((c) =>
              c.title.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
              c.seqId.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
        }

        if (widget.status == 'Pending') {
          list = list.where((c) => c.status == 'Pending').toList();
        } else if (widget.status == 'Resolved') {
          // Resolved = awaiting student confirmation
          list = list.where((c) => c.status == 'Resolved').toList();
        } else if (widget.status == 'Escalated') {
          list = list.where((c) => c.isEscalated && !c.isClosed && c.status != 'ClosedByStudent' && c.status != 'AutoClosed').toList();
        } else if (widget.status == 'Closed') {
          list = list.where((c) => c.status == 'Confirmed' || c.status == 'ClosedByStudent' || c.status == 'AutoClosed').toList();
        }

        if (hostelFilter != 'All') {
          list = list.where((c) => c.hostel == hostelFilter).toList();
        }

        if (widget.selectedDate != null) {
          list = list.where((c) {
            final target = DateTime(widget.selectedDate!.year, widget.selectedDate!.month, widget.selectedDate!.day);
            final created = DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day);
            return target.isAtSameMomentAs(created);
          }).toList();
        }

        if (list.isEmpty) {
          return const WardenEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No Complaints Found',
            subtitle: 'Try adjusting your search or filters',
          );
        }

        // Sort by date descending
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WardenSectionLabel('Complaint Records', count: list.length),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return WardenExpandableComplaintCard(
                    complaint: c,
                    warden: widget.warden,
                    fs: widget.fs,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
