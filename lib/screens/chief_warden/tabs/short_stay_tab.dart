import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';
import '../../../widgets/common/skeleton_loader.dart';

class ShortStayTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const ShortStayTab({super.key, required this.warden, required this.fs});

  @override
  State<ShortStayTab> createState() => _ShortStayTabState();
}

class _ShortStayTabState extends State<ShortStayTab> {

  @override
  Widget build(BuildContext context) {
    final wp = Provider.of<WardenProvider>(context);
    final hostelFilter = wp.currentHostelFilter ?? 'All';

    return WardenTabScaffold<ShortStayRequest>(
      title: 'Short Stays',
      sectionTitle: 'Short Stay Requests',
      tabs: const ['Pending', 'Approved', 'Completed', 'Rejected', 'All'],
      searchHint: 'Search student, ID, or room...',
      streamFactory: () => widget.fs.getUnifiedShortStaysStream(hostelFilter == 'All' ? null : hostelFilter),
      loadingWidget: const ShortStaySkeleton(),
      itemBuilder: (context, request) => WardenExpandableShortStayCard(
        request: request,
        onApprove: () => WardenUIUtils.showShortStayAssignmentDialog(
          context: context,
          request: request,
          fs: widget.fs,
          wardenUid: widget.warden.uid,
          wardenName: widget.warden.name,
          currentHostel: request.appliedHostel,
        ),
        onDeny: () => widget.fs.updateShortStayStatus(request.id, 'Rejected', actionUid: widget.warden.uid, actionByName: widget.warden.name),
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
      actionWidget: const SizedBox.shrink(),
      emptyIcon: Icons.hotel_rounded,
      emptyTitle: 'No Short Stay Requests',
      emptySubtitle: 'Short Stay Requests appear here',
    );
  }
}
