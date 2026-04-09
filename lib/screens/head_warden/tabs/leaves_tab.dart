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
  State<LeavesTab> createState() => LeavesTabState();
}

class LeavesTabState extends State<LeavesTab> {
  String _searchQuery = '';
  String _hostelFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _selectedDate = DateTime.now();

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final students = await widget.fs.getHostelStudents(_hostelFilter).first;
      final leaves = await widget.fs
          .getHostelLeavesRange(_hostelFilter, range.start, range.end)
          .first;

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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(
                      () => _searchQuery = InputSanitizer.sanitize(v),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by student or ID (e.g. LA241)...',
                      hintStyle: const TextStyle(
                        color: Colors.black26,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: kPrimary,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                    border: Border.all(
                      color: _selectedDate == null
                          ? Colors.black.withValues(alpha: 0.1)
                          : kPrimary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: _selectedDate == null
                            ? Colors.black38
                            : kPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate == null
                            ? 'Date'
                            : DateFormat('MMM d').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedDate == null
                              ? Colors.black54
                              : kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  tooltip: 'Clear Date Filter',
                ),
              ],
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _hostelFilter == 'All' ? Colors.black54 : kPrimary,
                  ),
                  tooltip: 'Filter by Hostel',
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Hostels'),
                    ),
                    const PopupMenuItem(value: 'BH1', child: Text('BH1')),
                    const PopupMenuItem(value: 'BH2', child: Text('BH2')),
                    const PopupMenuItem(value: 'GH1', child: Text('GH1')),
                    const PopupMenuItem(value: 'GH2', child: Text('GH2')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.segment_rounded,
                    color: _statusFilter == 'All' ? Colors.black54 : kPrimary,
                  ),
                  tooltip: 'Filter by Status',
                  onSelected: (val) => setState(() => _statusFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Status'),
                    ),
                    const PopupMenuItem(
                      value: 'Pending',
                      child: Text('Pending'),
                    ),
                    const PopupMenuItem(
                      value: 'Approved',
                      child: Text('Approved'),
                    ),
                    const PopupMenuItem(
                      value: 'Rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<LeaveRequest>>(
            stream: widget.fs.getHostelLeaves(widget.warden.hostel),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LeaveListSkeleton();
              }

              var list = snap.data ?? [];

              // Apply Local Filters
              if (_searchQuery.isNotEmpty) {
                list = list
                    .where(
                      (l) =>
                          l.studentName.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                          l.seqId.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                    )
                    .toList();
              }

              if (_selectedDate != null) {
                list = list.where((l) {
                  final start = DateTime(
                    l.fromDate.year,
                    l.fromDate.month,
                    l.fromDate.day,
                  );
                  final end = DateTime(
                    l.toDate.year,
                    l.toDate.month,
                    l.toDate.day,
                  );
                  final target = DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                  );
                  return !target.isBefore(start) && !target.isAfter(end);
                }).toList();
              }

              if (_hostelFilter != 'All') {
                list = list.where((l) => l.hostel == _hostelFilter).toList();
              }

              if (_statusFilter != 'All') {
                list = list.where((l) => l.status == _statusFilter).toList();
              }

              if (list.isEmpty) {
                return const WardenEmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'No Leaves Found',
                  subtitle: 'Try adjusting your search or filters',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WardenSectionLabel('Leave History', count: list.length),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final l = list[i];
                        final isApproved = l.status == 'Approved';
                        final isRejected = l.status == 'Rejected';

                        return WardenCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isApproved
                                        ? Icons.check_circle
                                        : (isRejected
                                              ? Icons.cancel
                                              : Icons.description_outlined),
                                    color: isApproved
                                        ? Colors.green
                                        : (isRejected
                                              ? Colors.redAccent
                                              : kPrimary),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.seqId} - ${l.studentName.toUpperCase()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                        color: isApproved
                                            ? Colors.green
                                            : (isRejected
                                                  ? Colors.redAccent
                                                  : kPrimary),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isApproved
                                                  ? Colors.green
                                                  : (isRejected
                                                        ? Colors.redAccent
                                                        : Colors.orange))
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      l.status.toUpperCase(),
                                      style: TextStyle(
                                        color: isApproved
                                            ? Colors.green
                                            : (isRejected
                                                  ? Colors.redAccent
                                                  : Colors.orange),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildReadOnlyInput(
                                'From Date & Time',
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(l.fromDate),
                                icon: Icons.access_time_rounded,
                              ),
                              _buildReadOnlyInput(
                                'To Date & Time',
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(l.toDate),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isApproved
                                              ? Colors.green
                                              : (isRejected
                                                    ? Colors.redAccent
                                                    : Colors.orange))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        (isApproved
                                                ? Colors.green
                                                : (isRejected
                                                      ? Colors.redAccent
                                                      : Colors.orange))
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    isApproved
                                        ? 'LEAVE APPROVED'
                                        : (isRejected
                                              ? 'LEAVE REJECTED'
                                              : 'PENDING WARDEN APPROVAL'),
                                    style: TextStyle(
                                      color: isApproved
                                          ? Colors.green
                                          : (isRejected
                                                ? Colors.redAccent
                                                : Colors.orange),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
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
          color: kBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kPrimary.withValues(alpha: 0.5)),
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
                      color: kPrimary.withValues(alpha: 0.4),
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

