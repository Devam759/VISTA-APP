import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/export_helper.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../../../widgets/skeleton_loader.dart';

class ShortStaysTab extends StatefulWidget {
  final VistaUser warden;
  const ShortStaysTab({super.key, required this.warden});

  @override
  State<ShortStaysTab> createState() => _ShortStaysTabState();
}

class _ShortStaysTabState extends State<ShortStaysTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'Pending';
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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
          border: Border.all(color: isSelected ? kPrimary : Colors.grey.shade300),
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
    String? selectedHostel = widget.warden.hostel ?? 'BH1';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Approve Short Stay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assigning room for ${request.studentName}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedHostel,
                decoration: const InputDecoration(labelText: 'Allot Hostel', border: OutlineInputBorder()),
                items: ['BH1', 'BH2', 'GH1', 'GH2'].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (val) => setDialogState(() => selectedHostel = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(labelText: 'Room Number', hintText: 'e.g. 101 or 104-D', border: OutlineInputBorder()),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () {
                if (roomCtrl.text.trim().isEmpty || selectedHostel == null) return;
                FirebaseService().updateShortStayStatus(
                  request.id,
                  'Approved',
                  roomNumber: roomCtrl.text.trim(),
                  allotmentHostel: selectedHostel,
                  actionBy: widget.warden.name,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('APPROVE'),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimary, onPrimary: Colors.white, onSurface: Colors.black87),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing Export...')));
      final stays = await FirebaseService().getHostelShortStaysRange(widget.warden.hostel, range.start, range.end).first;
      await ExportHelper.exportShortStays(stays, widget.warden.hostel ?? 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wardenProv = Provider.of<WardenProvider>(context);

    if (wardenProv.isLoading && wardenProv.shortStays.isEmpty) {
      return const ShortStaySkeleton();
    }

    var list = wardenProv.shortStays;

    if (_statusFilter != 'All') {
      list = list.where((r) => r.status == _statusFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) =>
          r.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.seqId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (r.roomNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

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
                  hintText: 'Search by student or ID...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: kPrimary),
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
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
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const WardenEmptyState(
                  icon: Icons.hotel_outlined,
                  title: 'No Requests Found',
                  subtitle: 'Pending short stay requests will appear here.',
                )
              : ListView.builder(
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
                              const Icon(Icons.person, color: kPrimary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${r.seqId} - ${r.studentName}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              if (isExtending)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('EXTENSION PENDING', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (r.status == 'Approved' ? Colors.green : (r.status == 'Rejected' ? Colors.red : Colors.orange)).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        r.status.toUpperCase(),
                                        style: TextStyle(
                                          color: r.status == 'Approved' ? Colors.green : (r.status == 'Rejected' ? Colors.red : Colors.orange),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (r.approvedBy != null)
                                        Text('By ${r.approvedBy}', style: const TextStyle(fontSize: 8, color: Colors.black38, fontWeight: FontWeight.w600))
                                      else if (r.rejectedBy != null)
                                        Text('By ${r.rejectedBy}', style: const TextStyle(fontSize: 8, color: Colors.black38, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildReadOnlyInput('Student Details', '${r.programme} · ${r.rollNo} · ${r.gender}\nEmail: ${r.email}\nPhone: ${r.contactNo}', icon: Icons.info_outline),
                          _buildReadOnlyInput('Reason for Stay', r.reason, icon: Icons.description_outlined),
                          _buildReadOnlyInput('Duration', '${DateFormat("dd MMM yyyy hh:mm a").format(r.checkInDate)} to \n${DateFormat("dd MMM yyyy hh:mm a").format(r.checkOutDate)}', icon: Icons.date_range),
                          if (isExtending) _buildReadOnlyInput('Requested Extension', DateFormat("dd MMM yyyy hh:mm a").format(r.pendingToDate!), icon: Icons.more_time),
                          _buildReadOnlyInput('Parent', '${r.parentName} (${r.parentContact})', icon: Icons.family_restroom),
                          if (r.roomNumber != null) _buildReadOnlyInput('Room', r.roomNumber!, icon: Icons.room),
                          if (isPending) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => FirebaseService().updateShortStayStatus(r.id, 'Rejected', actionBy: widget.warden.name),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                    child: const Text('REJECT'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _showApproveDialog(r),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: const Text('APPROVE'),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isExtending) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => FirebaseService().approveShortStayExtension(r.id, r.pendingToDate!),
                              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                              child: const Text('APPROVE EXTENSION'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInput(String label, String value, {IconData? icon}) {
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
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary.withValues(alpha: 0.4), letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
