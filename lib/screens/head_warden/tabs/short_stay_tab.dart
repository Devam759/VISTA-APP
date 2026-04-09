import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';

import '../../../widgets/skeleton_loader.dart';
import '../../../utils/export_helper.dart';
import '../../warden/components/warden_components.dart';

class ShortStayTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ShortStayTab({super.key, required this.warden, required this.fs});

  @override
  State<ShortStayTab> createState() => ShortStayTabState();
}

class ShortStayTabState extends State<ShortStayTab> {
  String _statusFilter = 'Pending';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? kPrimary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  void _showApproveDialog(ShortStayRequest request) {
    final roomCtrl = TextEditingController();
    String? selectedHostel = 'BH1'; // Default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Approve Short Stay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Hostel and Room'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedHostel,
                decoration: const InputDecoration(
                  labelText: 'Allot Hostel',
                  border: OutlineInputBorder(),
                ),
                items: ['BH1', 'BH2', 'GH1', 'GH2']
                    .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedHostel = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room Number',
                  hintText: 'e.g. 101 or 104-D',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
              ElevatedButton(
              onPressed: () {
                if (roomCtrl.text.trim().isEmpty || selectedHostel == null) {
                  return;
                }
                widget.fs.updateShortStayStatus(
                  request.id,
                  'Approved',
                  roomNumber: roomCtrl.text.trim(),
                  allotmentHostel: selectedHostel,
                  actionBy: widget.warden.name,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('APPROVE'),
            ),
          ],
        ),
      ),
    );
  }

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A), // kPrimary
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

      final stays = await widget.fs
          .getHostelShortStaysRange(
            widget.warden.hostel ?? 'All', // Head Warden can export 'All'
            range.start,
            range.end,
          )
          .first;

      await ExportHelper.exportShortStays(stays, widget.warden.hostel ?? 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by student or ID (e.g. SS241)...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ShortStayRequest>>(
            stream: widget.fs.getHostelShortStays('All'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ShortStaySkeleton();
              }
              var list = snap.data ?? [];

              // Apply filters
              if (_statusFilter != 'All') {
                list = list.where((r) => r.status == _statusFilter).toList();
              }
              if (_searchQuery.isNotEmpty) {
                list = list
                    .where(
                      (r) =>
                          r.studentName.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                          r.seqId.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                          (r.roomNumber ?? '').toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ),
                    )
                    .toList();
              }

              if (list.isEmpty) {
                return const WardenEmptyState(
                  icon: Icons.hotel_outlined,
                  title: 'No Requests Found',
                  subtitle: 'Pending short stay requests will appear here.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final isPending = r.status == 'Pending';
                  final isExtending = r.pendingToDate != null;

                  return WardenCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: kPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${r.seqId} - ${r.studentName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isExtending)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'EXTENSION PENDING',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (r.status == 'Approved'
                                              ? Colors.green
                                              : (r.status == 'Rejected'
                                                    ? Colors.red
                                                    : Colors.orange))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      r.status.toUpperCase(),
                                      style: TextStyle(
                                        color:
                                            r.status == 'Approved'
                                                ? Colors.green
                                                : (r.status == 'Rejected'
                                                      ? Colors.red
                                                      : Colors.orange),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (r.approvedBy != null)
                                      Text(
                                        'By ${r.approvedBy}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else if (r.rejectedBy != null)
                                      Text(
                                        'By ${r.rejectedBy}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          color: Colors.black38,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyInput(
                          'Student Details',
                          '${r.programme} · ${r.rollNo} · ${r.gender}\nEmail: ${r.email}\nPhone: ${r.contactNo}',
                          icon: Icons.info_outline,
                        ),
                        _buildReadOnlyInput(
                          'Reason for Stay',
                          r.reason,
                          icon: Icons.description_outlined,
                        ),
                        _buildReadOnlyInput(
                          'Duration',
                          '${DateFormat('dd MMM yyyy hh:mm a').format(r.checkInDate)} to \n${DateFormat('dd MMM yyyy hh:mm a').format(r.checkOutDate)}',
                          icon: Icons.date_range,
                        ),
                        if (isExtending)
                          _buildReadOnlyInput(
                            'Requested Extension',
                            DateFormat(
                              'dd MMM yyyy hh:mm a',
                            ).format(r.pendingToDate!),
                            icon: Icons.more_time,
                          ),
                        _buildReadOnlyInput(
                          'Parent',
                          '${r.parentName} (${r.parentContact})',
                          icon: Icons.family_restroom,
                        ),
                        if (r.roomNumber != null)
                          _buildReadOnlyInput(
                            'Room',
                            r.roomNumber!,
                            icon: Icons.room,
                          ),
                        if (isPending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => widget.fs
                                      .updateShortStayStatus(r.id, 'Rejected', actionBy: widget.warden.name),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text('REJECT'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showApproveDialog(r),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('APPROVE'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isExtending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      widget.fs.approveShortStayExtension(
                                        r.id,
                                        r.pendingToDate!,
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('APPROVE EXTENSION'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
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
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

