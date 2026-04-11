import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../../../widgets/hover_effect.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  const ComplaintsTab({super.key, required this.warden});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabController;
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
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
      children: [
        if (_selectedDate != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
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
          child: WardenTabScaffold(
            searchCtrl: _searchCtrl,
            searchHint: 'Search by title, ID, or student...',
            actionWidget: WardenSearchAction(
              onTap: () => _selectDate(context),
              child: HoverEffect(
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: _selectedDate != null ? kPrimary : Colors.black54,
                  size: 22,
                ),
              ),
            ),
            tabs: const ['Pending', 'Resolved', 'Escalated'],
            tabController: _tabController,
            children: [
              _FilteredComplaintList(status: 'Pending', searchQuery: _searchQuery, selectedDate: _selectedDate),
              _FilteredComplaintList(status: 'Resolved', searchQuery: _searchQuery, selectedDate: _selectedDate),
              _FilteredComplaintList(status: 'Escalated', searchQuery: _searchQuery, selectedDate: _selectedDate),
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

  const _FilteredComplaintList({
    required this.status,
    required this.searchQuery,
    this.selectedDate,
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
    final wardenProv = Provider.of<WardenProvider>(context);

    if (wardenProv.isLoading && wardenProv.complaints.isEmpty) {
      return const ComplaintListSkeleton();
    }

    var list = wardenProv.complaints;

    // Filters
    if (widget.searchQuery.isNotEmpty) {
      list = list.where((c) =>
          c.title.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
          c.seqId.toLowerCase().contains(widget.searchQuery.toLowerCase()) ||
          c.studentName.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    }

    if (widget.status == 'Pending') {
      list = list.where((c) => c.status == 'Pending' && !c.isEscalated).toList();
    } else if (widget.status == 'Resolved') {
      list = list.where((c) => c.status == 'Resolved' || c.status == 'Confirmed').toList();
    } else if (widget.status == 'Escalated') {
      list = list.where((c) => c.isEscalated).toList();
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

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WardenSectionLabel('Complaint Records', count: list.length),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, i) {
              final c = list[i];
              final resolved = c.status == 'Resolved' || c.status == 'Confirmed';
              return WardenCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: resolved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        resolved ? Icons.check_circle_outline : Icons.assignment_late_outlined,
                        color: resolved ? Colors.green : Colors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.seqId}: ${c.title}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM').format(c.createdAt),
                                style: TextStyle(fontSize: 10, color: kPrimary.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.description,
                            style: const TextStyle(color: Colors.black54, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: resolved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  (!resolved && c.isEscalated)
                                      ? 'ESCALATED'
                                      : (c.status == 'Confirmed' ? 'RESOLVED' : c.status.toUpperCase()),
                                  style: TextStyle(
                                    color: (!resolved && c.isEscalated) ? Colors.redAccent : (resolved ? Colors.green : Colors.orange),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (!resolved) ...[
                                const Spacer(),
                                if (c.targetRoles.contains('Head Warden') || c.isEscalated)
                                  const Text(
                                    'ESCALATED',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                  )
                                else
                                  HoverEffect(
                                    child: ElevatedButton(
                                      onPressed: () => FirebaseService().updateComplaintStatus(c.id, 'Resolved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: const Text('Resolve'),
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

