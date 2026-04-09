import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../warden/components/warden_components.dart';

class LeavesTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const LeavesTab({super.key, required this.warden, required this.fs});

  @override
  State<LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<LeavesTab> with AutomaticKeepAliveClientMixin {
  String _searchQuery = '';
  String _hostelFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _selectedDate ?? DateTime.now(),
        end: (_selectedDate ?? DateTime.now()).add(const Duration(days: 7)),
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

      final students = await widget.fs.getHostelStudents(_hostelFilter).first;
      final leaves = await widget.fs.getHostelLeavesRange(_hostelFilter, range.start, range.end).first;

      await ExportHelper.exportLeaves(leaves, students, _hostelFilter);
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
                      hintText: 'Search student or ID (e.g. LA241)...',
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
              _filterMenu(Icons.apartment_rounded, _hostelFilter, (v) => setState(() => _hostelFilter = v), ['All', 'BH1', 'BH2', 'GH1', 'GH2']),
              const SizedBox(width: 8),
              _filterMenu(Icons.segment_rounded, _statusFilter, (v) => setState(() => _statusFilter = v), ['All', 'Pending', 'Approved', 'Rejected']),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<LeaveRequest>>(
            stream: widget.fs.getHostelLeaves('All'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LeaveListSkeleton();
              var list = snap.data ?? [];

              if (_searchQuery.isNotEmpty) {
                list = list.where((l) => l.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) || l.seqId.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }
              if (_selectedDate != null) {
                list = list.where((l) {
                  final start = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
                  final end = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
                  final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                  return !target.isBefore(start) && !target.isAfter(end);
                }).toList();
              }
              if (_hostelFilter != 'All') list = list.where((l) => l.hostel == _hostelFilter).toList();
              if (_statusFilter != 'All') list = list.where((l) => l.status == _statusFilter).toList();

              if (list.isEmpty) return const WardenEmptyState(icon: Icons.event_note_outlined, title: 'No Leaves Found', subtitle: 'Try adjusting your search or filters');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WardenSectionLabel('Leave Oversight', count: list.length),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final l = list[i];
                        final isApp = l.status == 'Approved';
                        final isRej = l.status == 'Rejected';
                        final color = isApp ? Colors.green : (isRej ? Colors.redAccent : Colors.orange);

                        return WardenCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(isApp ? Icons.check_circle_rounded : (isRej ? Icons.cancel_rounded : Icons.pending_actions_rounded), color: color, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text('${l.seqId} • ${l.studentName.toUpperCase()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5, color: color), overflow: TextOverflow.ellipsis)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                    child: Text(l.status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              WardenReadOnlyInput(label: 'Duration', value: '${DateFormat('dd MMM, hh:mm a').format(l.fromDate)} → ${DateFormat('dd MMM, hh:mm a').format(l.toDate)}', icon: Icons.timer_outlined),
                              WardenReadOnlyInput(label: 'Reason', value: l.reason, icon: Icons.notes_rounded),
                              WardenReadOnlyInput(
                                label: 'Parent Contact',
                                value: '${l.parentName} (${l.parentRelation}): ${l.parentContact}',
                                icon: Icons.contact_phone_outlined,
                                trailing: IconButton(
                                  onPressed: () async {
                                    final p = l.parentContact.replaceAll(RegExp(r'[^\d+]'), '');
                                    final u = Uri.parse('tel:$p');
                                    if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
                                  },
                                  icon: const Icon(Icons.call_rounded, color: Colors.green, size: 20),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
                                child: Center(child: Text(isApp ? 'LEAVE APPROVED' : (isRej ? 'LEAVE REJECTED' : 'PENDING WARDEN REVIEW'), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.0))),
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

  Widget _filterMenu(IconData icon, String current, Function(String) onSel, List<String> opts) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: PopupMenuButton<String>(
        icon: Icon(icon, color: current == 'All' ? Colors.black45 : kPrimary, size: 20),
        onSelected: onSel,
        itemBuilder: (context) => opts.map((o) => PopupMenuItem(value: o, child: Text(o == 'All' ? 'All' : o))).toList(),
      ),
    );
  }
}
