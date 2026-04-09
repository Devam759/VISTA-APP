import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/complaint_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../warden/components/warden_components.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ComplaintsTab({super.key, required this.warden, required this.fs});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _hostelFilter = 'All';
  DateTime? _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _selectedDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final complaints = await widget.fs.getHostelComplaintsRange(_hostelFilter, range.start, range.end).first;
      await ExportHelper.exportComplaints(complaints, _hostelFilter);
    }
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
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = InputSanitizer.sanitize(v)),
                    decoration: const InputDecoration(
                      hintText: 'Search by title or ID (e.g. CA241)...',
                      hintStyle: TextStyle(color: Colors.black26, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: kPrimary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _selectedDate == null ? Colors.black.withValues(alpha: 0.1) : kPrimary.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 18, color: _selectedDate == null ? Colors.black38 : kPrimary),
                      const SizedBox(width: 8),
                      Text(_selectedDate == null ? 'Date' : DateFormat('MMM d').format(_selectedDate!), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _selectedDate == null ? Colors.black54 : kPrimary)),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 4),
                IconButton(onPressed: () => setState(() => _selectedDate = null), icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20)),
              ],
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.filter_list_rounded, color: _hostelFilter == 'All' ? Colors.black54 : kPrimary, size: 20),
                  tooltip: 'Filter by Hostel',
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All', child: Text('All Hostels')),
                    const PopupMenuItem(value: 'BH1', child: Text('BH1')),
                    const PopupMenuItem(value: 'BH2', child: Text('BH2')),
                    const PopupMenuItem(value: 'GH1', child: Text('GH1')),
                    const PopupMenuItem(value: 'GH2', child: Text('GH2')),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<Complaint>>(
            stream: widget.fs.getComplaintsForRole('Chief Warden', 'All'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const ComplaintListSkeleton();
              var list = snap.data ?? [];

              if (_searchQuery.isNotEmpty) {
                list = list.where((c) => c.title.toLowerCase().contains(_searchQuery.toLowerCase()) || c.seqId.toLowerCase().contains(_searchQuery.toLowerCase()) || c.studentName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }
              if (_selectedDate != null) {
                list = list.where((c) {
                  final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                  final created = DateTime(c.createdAt.year, c.createdAt.month, c.createdAt.day);
                  return target.isAtSameMomentAs(created);
                }).toList();
              }
              if (_hostelFilter != 'All') list = list.where((c) => c.hostel == _hostelFilter).toList();

              if (list.isEmpty) return const WardenEmptyState(icon: Icons.inbox_outlined, title: 'No Complaints Found', subtitle: 'Try adjusting your search or filters');

              list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WardenSectionLabel('All Complaints', count: list.length),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final resolved = c.status == 'Resolved' || c.status == 'Confirmed';
                        return WardenCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: resolved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: Icon(resolved ? Icons.check_circle_outline_rounded : Icons.assignment_late_outlined, color: resolved ? Colors.green : Colors.orange, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text('${c.seqId}: (${c.hostel}) ${c.title}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)))),
                                        Text(DateFormat('dd MMM').format(c.createdAt), style: TextStyle(fontSize: 11, color: kPrimary.withValues(alpha: 0.5), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(c.description, style: const TextStyle(color: Colors.black54, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: resolved ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                          child: Text((!resolved && c.isEscalated) ? 'ESCALATED' : (c.status == 'Confirmed' ? 'RESOLVED' : c.status.toUpperCase()), style: TextStyle(color: (!resolved && c.isEscalated) ? Colors.redAccent : (resolved ? Colors.green : Colors.orange), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                        ),
                                        if (!resolved) ...[
                                          const Spacer(),
                                          ElevatedButton(
                                            onPressed: () => widget.fs.updateComplaintStatus(c.id, 'Confirmed'),
                                            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                                            child: const Text('Resolve'),
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
            },
          ),
        ),
      ],
    );
  }
}
