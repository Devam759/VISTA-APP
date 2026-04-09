import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../warden/components/warden_components.dart';

class ShortStayTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ShortStayTab({super.key, required this.warden, required this.fs});

  @override
  State<ShortStayTab> createState() => _ShortStayTabState();
}

class _ShortStayTabState extends State<ShortStayTab> with AutomaticKeepAliveClientMixin {
  String _statusFilter = 'Pending';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimary : Colors.black.withValues(alpha: 0.1)),
          boxShadow: isSelected ? [BoxShadow(color: kPrimary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _showApproveDialog(ShortStayRequest request) {
    final roomCtrl = TextEditingController();
    String? selectedHostel = 'BH1';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Approve Short Stay', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Hostel and Room', style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedHostel,
                decoration: InputDecoration(
                  labelText: 'Allot Hostel',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['BH1', 'BH2', 'GH1', 'GH2'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (val) => setDialogState(() => selectedHostel = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roomCtrl,
                decoration: InputDecoration(
                  labelText: 'Room Number',
                  hintText: 'e.g. 101 or 104-D',
                  prefixIcon: const Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              onPressed: () {
                if (roomCtrl.text.trim().isEmpty || selectedHostel == null) return;
                widget.fs.updateShortStayStatus(
                  request.id,
                  'Approved',
                  roomNumber: roomCtrl.text.trim(),
                  allotmentHostel: selectedHostel,
                  actionBy: widget.warden.name,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
      final stays = await widget.fs.getHostelShortStaysRange('All', range.start, range.end).first;
      await ExportHelper.exportShortStays(stays, 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by student or ID (e.g. SS241)...',
                hintStyle: TextStyle(color: Colors.black26, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: kPrimary, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (v) => setState(() => _searchQuery = InputSanitizer.sanitize(v)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        Expanded(
          child: StreamBuilder<List<ShortStayRequest>>(
            stream: widget.fs.getHostelShortStays('All'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const ShortStaySkeleton();
              var list = snap.data ?? [];

              if (_statusFilter != 'All') list = list.where((r) => r.status == _statusFilter).toList();
              if (_searchQuery.isNotEmpty) {
                list = list.where((r) => r.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) || r.seqId.toLowerCase().contains(_searchQuery.toLowerCase()) || (r.roomNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
              }

              if (list.isEmpty) return const WardenEmptyState(icon: Icons.hotel_outlined, title: 'No Requests Found', subtitle: 'Short stay requests will appear here.');

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            const Icon(Icons.person_rounded, color: kPrimary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text('${r.seqId} - ${r.studentName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            if (isExtending)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: const Text('EXTENSION PENDING', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: (r.status == 'Approved' || r.status == 'Completed' ? Colors.green : (r.status == 'Rejected' ? Colors.redAccent : Colors.orange)).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(r.status.toUpperCase(), style: TextStyle(color: r.status == 'Approved' || r.status == 'Completed' ? Colors.green : (r.status == 'Rejected' ? Colors.redAccent : Colors.orange), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        WardenReadOnlyInput(label: 'Student Details', value: '${r.programme} · ${r.rollNo} · ${r.gender}\nEmail: ${r.email}\nPhone: ${r.contactNo}', icon: Icons.info_outline_rounded),
                        WardenReadOnlyInput(label: 'Reason for Stay', value: r.reason, icon: Icons.description_outlined),
                        WardenReadOnlyInput(label: 'Duration', value: '${DateFormat('dd MMM yyyy hh:mm a').format(r.checkInDate)} to \n${DateFormat('dd MMM yyyy hh:mm a').format(r.checkOutDate)}', icon: Icons.date_range_rounded),
                        if (isExtending) WardenReadOnlyInput(label: 'Requested Extension', value: DateFormat('dd MMM yyyy hh:mm a').format(r.pendingToDate!), icon: Icons.more_time_rounded),
                        WardenReadOnlyInput(label: 'Parent', value: '${r.parentName} (${r.parentContact})', icon: Icons.family_restroom_rounded),
                        if (r.roomNumber != null) WardenReadOnlyInput(label: 'Allotted Room', value: r.roomNumber!, icon: Icons.room_rounded),
                        if (isPending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => widget.fs.updateShortStayStatus(r.id, 'Rejected', actionBy: widget.warden.name),
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text('REJECT'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showApproveDialog(r),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: const Text('APPROVE'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isExtending) ...[
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => widget.fs.approveShortStayExtension(r.id, r.pendingToDate!),
                            style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('APPROVE EXTENSION'),
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
}
