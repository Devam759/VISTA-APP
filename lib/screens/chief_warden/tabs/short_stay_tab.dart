import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';

class ShortStayTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ShortStayTab({super.key, required this.warden, required this.fs});

  @override
  State<ShortStayTab> createState() => _ShortStayTabState();
}

class _ShortStayTabState extends State<ShortStayTab> {
  String _selectedHostel = 'All';

  @override
  Widget build(BuildContext context) {
    return WardenTabScaffold<ShortStayRequest>(
      title: 'Short Stays',
      sectionTitle: 'Short Stay Requests',
      tabs: const ['Pending', 'Approved', 'Completed', 'Rejected', 'All'],
      searchHint: 'Search student, ID, or room...',
      streamFactory: () => widget.fs.getUnifiedShortStaysStream(_selectedHostel == 'All' ? null : _selectedHostel),
      itemBuilder: (context, request) => WardenShortStayCard(
        request: request,
        onApprove: () => WardenUIUtils.showShortStayAssignmentDialog(
          context: context,
          request: request,
          fs: widget.fs,
          wardenName: widget.warden.name,
          currentHostel: request.appliedHostel,
        ),
        onDeny: () => widget.fs.updateShortStayStatus(request.id, 'Rejected', actionBy: widget.warden.name),
      ),
      filterLogic: (request, status, query) {
        if (status != 'All' && request.status != status) return false;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          return request.studentName.toLowerCase().contains(q) ||
              request.seqId.toLowerCase().contains(q) ||
              (request.roomNumber ?? '').toLowerCase().contains(q);
        }
        return true;
      },
      actionWidget: WardenSearchAction(
        onTap: () => WardenUIUtils.showHostelFilter(
          context: context,
          currentFilter: _selectedHostel == 'All' ? null : _selectedHostel,
          onSelected: (h) => setState(() => _selectedHostel = h ?? 'All'),
        ),
        child: Icon(
          Icons.apartment_rounded,
          color: _selectedHostel == 'All' ? Colors.black54 : kPrimary,
          size: 22,
        ),
      ),
      emptyIcon: Icons.hotel_rounded,
      emptyTitle: 'No Short Stay Requests',
      emptySubtitle: 'Student relocation or guest stay requests will appear here.',
    );
  }
}
