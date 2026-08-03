import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../../../widgets/common/skeleton_loader.dart';

class ShortStaysTab extends StatefulWidget {
  final VistaUser warden;
  const ShortStaysTab({super.key, required this.warden});

  @override
  State<ShortStaysTab> createState() => _ShortStaysTabState();
}

class _ShortStaysTabState extends State<ShortStaysTab> {
  final FirebaseService _fs = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Consumer<WardenProvider>(
      builder: (context, wp, _) {
        return WardenTabScaffold<ShortStayRequest>(
          title: 'Short Stays',
          sectionTitle: 'Short Stay Requests',
          tabs: const ['Pending', 'Approved', 'Completed', 'Rejected', 'All'],
          searchHint: 'Search student, ID, or room...',
          streamFactory: () => _fs.getUnifiedShortStaysStream(wp.currentHostelFilter),
          loadingWidget: const ShortStaySkeleton(),
          itemBuilder: (context, request) => WardenExpandableShortStayCard(
            request: request,
            onApprove: () => WardenUIUtils.showShortStayAssignmentDialog(
              context: context,
              request: request,
              fs: _fs,
              wardenUid: widget.warden.uid,
              wardenName: widget.warden.name,
              currentHostel: widget.warden.hostel,
            ),
            onDeny: () => _fs.updateShortStayStatus(request.id, 'Rejected', actionUid: widget.warden.uid, actionByName: widget.warden.name),
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
          emptyIcon: Icons.hotel_rounded,
          emptyTitle: 'No Short Stay Requests',
          emptySubtitle: 'Short Stay Requests appear here',
        );
      }
    );
  }
}
