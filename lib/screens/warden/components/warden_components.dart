import 'package:flutter/material.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/vista_loader.dart';
import '../../../widgets/hover_effect.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/firebase_service.dart';
import '../../../models/vista_user.dart';
import '../../../models/short_stay_model.dart';
import '../../../widgets/smooth_animations.dart';
import 'warden_attendance_calendar.dart';
import '../../../widgets/vista_date_picker.dart';
import '../../../models/complaint_model.dart';


// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFF1E3A8A);
const Color kAccent = Color(0xFF2563EB);
const Color kBg = Color(0xFFF0F4FF);

String shortHostelName(String? name) {
  if (name == null) return '';
  if (name == 'Short Stay') return 'SS';
  final n = name.toLowerCase();
  if (n.contains('boys hostel 1')) return 'BH1';
  if (n.contains('boys hostel 2')) return 'BH2';
  if (n.contains('girls hostel 1')) return 'GH1';
  if (n.contains('girls hostel 2')) return 'GH2';
  if (n.contains('staff')) return 'Staff';
  // Fallback: take first letters of each word
  return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO TITLE (MAIN PORTAL HEADING)
// ─────────────────────────────────────────────────────────────────────────────
class WardenHeroTitle extends StatelessWidget {
  final String title;
  const WardenHeroTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 32,
          color: Color(0xFF1E293B),
          letterSpacing: -1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class WardenSectionLabel extends StatelessWidget {
  final String text;
  final int? count;
  const WardenSectionLabel(this.text, {super.key, this.count});

  @override
  Widget build(BuildContext context) {
    return SmoothEntrance(
      key: ValueKey('section_$text'),
      delay: const Duration(milliseconds: 100),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                child: Center(
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING ATTENDANCE BANNER
// ─────────────────────────────────────────────────────────────────────────────
class PendingAttendanceBanner extends StatelessWidget {
  final int count;
  final VoidCallback onViewList;

  const PendingAttendanceBanner({
    super.key,
    required this.count,
    required this.onViewList,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count students pending attendance',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: onViewList,
              child: const Text(
                'View List',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class WardenEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const WardenEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SmoothEntrance(
      offset: const Offset(0, 50),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kPrimary.withValues(alpha: 0.08),
                    kAccent.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52,
                color: kPrimary.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPANDABLE LEAVE CARD
// ─────────────────────────────────────────────────────────────────────────────
class WardenExpandableLeaveCard extends StatefulWidget {
  final String seqId;
  final String studentName;
  final String status;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String address;
  final String parentName;
  final String parentRelation;
  final String parentContact;
  final Widget? actions; // Approved/Denied buttons

  const WardenExpandableLeaveCard({
    super.key,
    required this.seqId,
    required this.studentName,
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.address,
    required this.parentName,
    required this.parentRelation,
    required this.parentContact,
    this.actions,
  });

  @override
  State<WardenExpandableLeaveCard> createState() => _WardenExpandableLeaveCardState();
}

class _WardenExpandableLeaveCardState extends State<WardenExpandableLeaveCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.status == 'Approved';
    final isRejected = widget.status == 'Rejected';
    final isPending = widget.status == 'Pending';
    final statusColor = isApproved ? Colors.green : (isRejected ? Colors.redAccent : Colors.orange);

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // CONTRACTED VIEW
            HoverEffect(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isApproved ? Colors.green : (isRejected ? Colors.redAccent : kPrimary)).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.seqId,
                          style: TextStyle(
                            color: isApproved ? Colors.green : (isRejected ? Colors.redAccent : kPrimary),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.studentName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${DateFormat('dd MMM').format(widget.fromDate)} - ${DateFormat('dd MMM').format(widget.toDate)}',
                              style: const TextStyle(
                                color: Colors.black38,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _isExpanded ? 0.5 : 0,
                        child: const Icon(
                          Icons.expand_more,
                          color: Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // EXPANDED VIEW
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),
                    // DURATION SECTION
                    const WardenSubSectionLabel('Leave Duration'),
                    Row(
                      children: [
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'From',
                            value: DateFormat('dd MMM, hh:mm a').format(widget.fromDate),
                            icon: Icons.login_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'To',
                            value: DateFormat('dd MMM, hh:mm a').format(widget.toDate),
                            icon: Icons.logout_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // DETAILS SECTION
                    const WardenSubSectionLabel('Leave Details'),
                    WardenReadOnlyInput(
                      label: 'Reason for leave',
                      value: widget.reason,
                      icon: Icons.info_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                    WardenReadOnlyInput(
                      label: 'Address during leave',
                      value: widget.address,
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 16),
                    // CONTACT SECTION
                    const WardenSubSectionLabel('Parent Information'),
                    Row(
                      children: [
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'Name',
                            value: '${widget.parentName} (${widget.parentRelation})',
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'Mobile',
                            value: widget.parentContact,
                            icon: Icons.phone_android_rounded,
                            trailing: IconButton(
                              onPressed: () async {
                                final phone = widget.parentContact.replaceAll(RegExp(r'[^\d+]'), '');
                                final Uri telUri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                                }
                              },
                              icon: const Icon(Icons.call_rounded, color: Colors.green, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isPending && widget.actions != null) ...[
                      const SizedBox(height: 24),
                      widget.actions!,
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINT CARD (EXPANDABLE)
// ─────────────────────────────────────────────────────────────────────────────
class WardenExpandableComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final VistaUser warden; // To check role for resolution authority
  final FirebaseService fs;

  const WardenExpandableComplaintCard({
    super.key,
    required this.complaint,
    required this.warden,
    required this.fs,
  });

  @override
  State<WardenExpandableComplaintCard> createState() => _WardenExpandableComplaintCardState();
}

class _WardenExpandableComplaintCardState extends State<WardenExpandableComplaintCard> {
  bool _isExpanded = false;

  bool _canUserResolve() {
    final complaint = widget.complaint;
    final userRole = widget.warden.role;

    // RULE: If escalated to Chief Warden, only Chief Warden can resolve.
    if (complaint.targetRoles.contains('Chief Warden')) {
      return userRole == UserRole.chiefWarden;
    }

    // RULE: If escalated to Head Warden, only Head Warden or Chief Warden can resolve.
    if (complaint.targetRoles.contains('Head Warden')) {
      return userRole == UserRole.headWarden || userRole == UserRole.chiefWarden;
    }

    // Default: Warden can resolve if it's not escalated beyond them.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isResolved = widget.complaint.status == 'Resolved' || widget.complaint.status == 'Confirmed';
    final statusColor = isResolved ? Colors.green : (widget.complaint.isEscalated ? Colors.redAccent : Colors.orange);
    final canResolve = _canUserResolve();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // CONTRACTED VIEW
            HoverEffect(
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (widget.complaint.isEscalated ? Colors.redAccent : kPrimary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.complaint.seqId,
                          style: TextStyle(
                            color: widget.complaint.isEscalated ? Colors.redAccent : kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.complaint.studentName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.complaint.title,
                              style: const TextStyle(
                                color: Colors.black45,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.complaint.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: _isExpanded ? 0.5 : 0,
                        child: const Icon(
                          Icons.expand_more,
                          color: Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // EXPANDED VIEW
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, thickness: 0.5),
                    const SizedBox(height: 16),
                    
                    // DATE & STATUS ROW
                    Row(
                      children: [
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'Reported On',
                            value: DateFormat('dd MMM, hh:mm a').format(widget.complaint.createdAt),
                            icon: Icons.calendar_today_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: WardenReadOnlyInput(
                            label: 'Level',
                            value: widget.complaint.isEscalated ? 'ESCALATED' : 'STANDARD',
                            icon: Icons.shield_outlined,
                            color: widget.complaint.isEscalated ? Colors.redAccent : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // DESCRIPTION SECTION
                    const WardenSubSectionLabel('Issue Description'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.complaint.description.isEmpty ? 'No description provided.' : widget.complaint.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // ATTACHMENT SECTION
                    if (widget.complaint.imageUrl != null) ...[
                      const WardenSubSectionLabel('Attachment'),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WardenImageViewer(
                              imageUrl: widget.complaint.imageUrl!,
                              title: 'Attachment: Ticket #${widget.complaint.seqId}',
                            ),
                          ),
                        ),
                        child: Hero(
                          tag: widget.complaint.imageUrl!,
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: DecorationImage(
                                image: NetworkImage(widget.complaint.imageUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                                ),
                              ),
                              child: const Center(
                                child: Icon(Icons.fullscreen_rounded, color: Colors.white, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ACTIONS SECTION
                    if (!isResolved) ...[
                      if (canResolve)
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await widget.fs.updateComplaintStatus(widget.complaint.id, 'Resolved');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Issue marked as resolved.'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('MARK AS RESOLVED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.lock_clock_outlined, size: 16, color: Colors.black26),
                              const SizedBox(width: 8),
                              Text(
                                widget.complaint.targetRoles.contains('Chief Warden') 
                                  ? 'Awaiting Chief Warden Check' 
                                  : 'Awaiting Head Warden Check',
                                style: const TextStyle(
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// STYLED CARD
// ─────────────────────────────────────────────────────────────────────────────
class WardenCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const WardenCard({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverEffect(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ ONLY INPUT (For Details)
// ─────────────────────────────────────────────────────────────────────────────
class WardenReadOnlyInput extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;

  const WardenReadOnlyInput({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: kPrimary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color ?? const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class WardenSubSectionLabel extends StatelessWidget {
  final String label;
  const WardenSubSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: kPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE WRAPPER (For Web/Large Screens)
// ─────────────────────────────────────────────────────────────────────────────
class WardenResponsiveWrapper extends StatelessWidget {
  final Widget child;
  const WardenResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > 1100;

    if (!isLargeScreen) return child;

    return Scaffold(
      backgroundColor: const Color(0xFFE2E8F0), 
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// SEARCH HEADER
// ─────────────────────────────────────────────────────────────────────────────
class WardenSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String)? onChanged;
  final Widget? actionWidget;

  const WardenSearchHeader({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.actionWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: Colors.black26,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: kPrimary,
                    size: 24,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 17),
                ),
              ),
            ),
          ),
          if (actionWidget != null) ...[
            const SizedBox(width: 12),
            actionWidget!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH ACTION BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class WardenSearchAction extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const WardenSearchAction({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverEffect(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          constraints: const BoxConstraints(minWidth: 56),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────
class WardenFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const WardenFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverEffect(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? kPrimary : Colors.black.withValues(alpha: 0.08),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// GENERIC FILTERED LIST VIEW
// ─────────────────────────────────────────────────────────────────────────────
typedef WardenItemBuilder<T> = Widget Function(BuildContext context, T item);

class WardenListView<T> extends StatefulWidget {
  final Stream<List<T>> stream;
  final WardenItemBuilder<T> itemBuilder;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<T> Function(List<T>)? filter;
  final Widget? skeleton;

  const WardenListView({
    super.key,
    required this.stream,
    required this.itemBuilder,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.filter,
    this.skeleton,
  });

  @override
  State<WardenListView<T>> createState() => _WardenListViewState<T>();
}

class _WardenListViewState<T> extends State<WardenListView<T>>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<T>>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.skeleton ??
              const Center(
                child: CircularProgressIndicator(
                  color: kPrimary,
                  strokeWidth: 2,
                ),
              );
        }

        var data = snapshot.data ?? [];
        if (widget.filter != null) data = widget.filter!(data);

        if (data.isEmpty) {
          return WardenEmptyState(
            icon: widget.icon,
            title: widget.title,
            subtitle: widget.subtitle,
          );
        }

        return ListView.builder(
          itemCount: data.length,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemBuilder: (context, index) => SmoothEntrance(
            delay: Duration(milliseconds: 50 * index),
            duration: const Duration(milliseconds: 500),
            child: widget.itemBuilder(context, data[index]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED STUDENT DETAILS SHEET
// ─────────────────────────────────────────────────────────────────────────────
void showWardenStudentDetails({
  required BuildContext context,
  required dynamic student, // VistaUser
  required dynamic fs, // FirebaseService
  bool isChiefOrHead = false,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
              style: const TextStyle(
                color: kPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            student.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            student.email,
            style: const TextStyle(color: Colors.black45, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                WardenReadOnlyInput(
                  label: 'Roll Number',
                  value: student.rollNo ?? 'Not Assigned',
                  icon: Icons.badge_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Registration No',
                  value: student.registrationNo ?? 'Not Assigned',
                  icon: Icons.numbers_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Programme',
                  value: student.programme ?? 'Not Specified',
                  icon: Icons.school_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Hostel',
                  value: student.hostel ?? 'Not Assigned',
                  icon: Icons.apartment_rounded,
                ),
                WardenReadOnlyInput(
                  label: 'Room Number',
                  value: student.roomNumber ?? 'Not Assigned',
                  icon: Icons.meeting_room_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Phone',
                  value: student.phoneNumber ?? 'Not Provided',
                  icon: Icons.phone_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Parent Name',
                  value: student.parentName ?? 'Not Provided',
                  icon: Icons.family_restroom_outlined,
                ),
                WardenReadOnlyInput(
                  label: 'Parent Contact',
                  value: student.parentContact ?? 'Not Provided',
                  icon: Icons.contact_phone_outlined,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Attendance History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                Center(
                  child: HoverEffect(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => WardenStudentCalendar(student: student, fs: fs),
                        );
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('View Full Attendance Calendar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}



// ─────────────────────────────────────────────────────────────────────────────
// WARDEN REGISTRATION BANNER
// ─────────────────────────────────────────────────────────────────────────────
class WardenRegistrationBanner extends StatelessWidget {
  final List<VistaUser> pending;
  final bool isExpanded;
  final VoidCallback onTap;
  final Function(VistaUser) onDeny;
  final Function(VistaUser) onApprove;

  const WardenRegistrationBanner({
    super.key,
    required this.pending,
    required this.isExpanded,
    required this.onTap,
    required this.onDeny,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          HoverEffect(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pending.length} Registration Request${pending.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          Text(
                            isExpanded ? 'Tap to hide details' : 'Tap to review and approve',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: pending.map((s) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: kPrimary.withValues(alpha: 0.1),
                              child: Text(
                                s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text(s.email, style: const TextStyle(color: Colors.black45, fontSize: 11)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HoverEffect(
                                  child: GestureDetector(
                                    onTap: () => onDeny(s),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                                      ),
                                      child: const Text('Deny', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                HoverEffect(
                                  child: GestureDetector(
                                    onTap: () => onApprove(s),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
                                      ),
                                      child: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (s != pending.last) const Divider(height: 1, indent: 14, endIndent: 14),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WARDEN STUDENT LIST ITEM
// ─────────────────────────────────────────────────────────────────────────────
class WardenStudentListItem extends StatelessWidget {
  final VistaUser student;
  final bool onLeave;
  final bool onShortStay;
  final VoidCallback onTap;
  final bool showRoom;
  final bool showHostel;

  const WardenStudentListItem({
    super.key,
    required this.student,
    required this.onLeave,
    required this.onShortStay,
    required this.onTap,
    this.showRoom = true,
    this.showHostel = true,
  });

  @override
  Widget build(BuildContext context) {
    return WardenCard(
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimary.withValues(alpha: 0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: onLeave ? Colors.orange : (onShortStay ? Colors.blue : Colors.green),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
                ),
                Text(
                  student.rollNo != null && student.rollNo!.isNotEmpty
                      ? 'Roll: ${student.rollNo}'
                      : 'Reg: ${student.registrationNo ?? "N/A"}',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showRoom)
                Text(
                  student.roomNumber ?? 'No Room',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: kPrimary, fontSize: 13),
                ),
              if (showHostel)
                Text(
                  student.hostel ?? 'N/A',
                  style: const TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WARDEN UI UTILITIES
// ─────────────────────────────────────────────────────────────────────────────
class WardenUIUtils {
  /// Standardized Date Picker for all Warden views
  static Future<DateTime?> showWardenDatePicker(BuildContext context, {DateTime? initialDate}) async {
    return await showVistaDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now(),
      primaryColor: kPrimary,
    );
  }

  /// Standardized Room Assignment / Student Approval Dialog
  static Future<void> showRoomAssignmentDialog({
    required BuildContext context,
    required VistaUser student,
    required FirebaseService fs,
  }) async {
    final ctrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Assign Room Number', style: TextStyle(fontWeight: FontWeight.w900)),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Room Number',
              hintText: 'e.g. 101 or 104-D',
              prefixIcon: const Icon(Icons.meeting_room_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          actions: [
            HoverEffect(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            HoverEffect(
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setDialogState(() => isSubmitting = true);
                        try {
                          String sanitizedRoom = InputSanitizer.sanitize(ctrl.text);
                          await fs.approveStudent(student.uid, sanitizedRoom);
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (context.mounted) setDialogState(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting ? const VISTALoader(size: 20, color: Colors.white) : const Text('Approve'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Standardized Short Stay Approval Dialog
  static Future<void> showShortStayAssignmentDialog({
    required BuildContext context,
    required ShortStayRequest request,
    required FirebaseService fs,
    required String wardenName,
    String? currentHostel,
  }) async {
    final roomCtrl = TextEditingController();
    final hostels = ['BH1', 'BH2', 'GH1', 'GH2'];
    String selectedHostel = hostels.contains(currentHostel) ? currentHostel! : 'BH1';
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Approve Short Stay', style: TextStyle(fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assigning room for ${request.studentName}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedHostel,
                decoration: InputDecoration(
                  labelText: 'Allot Hostel',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: hostels.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (val) => setDialogState(() => selectedHostel = val!),
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
              ),
            ],
          ),
          actions: [
            HoverEffect(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            HoverEffect(
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (roomCtrl.text.trim().isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          await fs.updateShortStayStatus(
                            request.id,
                            'Approved',
                            roomNumber: roomCtrl.text.trim(),
                            allotmentHostel: selectedHostel,
                            actionBy: wardenName,
                          );
                          if (context.mounted) Navigator.pop(context);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (context.mounted) setDialogState(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSubmitting ? const VISTALoader(size: 20, color: Colors.white) : const Text('Approve'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified Hostel Filter Dialog
  static void showHostelFilter({
    required BuildContext context,
    required String? currentFilter,
    required Function(String?) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Filter by Hostel', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption(context, null, 'All Hostels', currentFilter == null, onSelected),
            _buildFilterOption(context, 'BH1', 'BH1 - Boys Hostel 1', currentFilter == 'BH1', onSelected),
            _buildFilterOption(context, 'BH2', 'BH2 - Boys Hostel 2', currentFilter == 'BH2', onSelected),
            _buildFilterOption(context, 'GH1', 'GH1 - Girls Hostel 1', currentFilter == 'GH1', onSelected),
            _buildFilterOption(context, 'GH2', 'GH2 - Girls Hostel 2', currentFilter == 'GH2', onSelected),
          ],
        ),
      ),
    );
  }

  static Widget _buildFilterOption(
    BuildContext context,
    String? value,
    String label,
    bool isSelected,
    Function(String?) onSelected,
  ) {
    return ListTile(
      onTap: () {
        onSelected(value);
        Navigator.pop(context);
      },
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? kPrimary : Colors.black26,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? kPrimary : Colors.black87,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  static void showPendingAttendanceList(BuildContext context, List<dynamic> defaulters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'Pending Attendance',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${defaulters.length}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: defaulters.length,
                  itemBuilder: (context, i) {
                    final record = defaulters[i];
                    final student = record.student;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        title: Text(
                          '${student.name} (${shortHostelName(student.hostel)} - ${student.roomNumber ?? "N/A"})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            student.phoneNumber ?? 'No Number',
                            style: const TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w600),
                          ),
                        ),
                        trailing: Material(
                          color: kPrimary.withValues(alpha: 0.1),
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(Icons.call_rounded, color: kPrimary, size: 20),
                            onPressed: () async {
                               final phone = (student.phoneNumber ?? '').replaceAll(RegExp(r'[^\d+]'), '');
                               final Uri telUri = Uri.parse('tel:$phone');
                               if (await canLaunchUrl(telUri)) await launchUrl(telUri, mode: LaunchMode.externalApplication);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable Card for Short Stay Requests
class WardenShortStayCard extends StatelessWidget {
  final ShortStayRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onDeny;

  const WardenShortStayCard({
    super.key,
    required this.request,
    this.onApprove,
    this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = request.status == 'Pending';
    final isExtending = request.pendingToDate != null;
    final statusColor = request.status == 'Approved' ? Colors.green : (request.status == 'Rejected' ? Colors.red : Colors.orange);

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
                  '${request.seqId} - ${request.studentName}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (isExtending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('EXTENSION PENDING', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          WardenReadOnlyInput(label: 'Reason', value: request.reason, icon: Icons.description_outlined),
          WardenReadOnlyInput(
            label: 'Duration',
            value: '${DateFormat("dd MMM").format(request.checkInDate)} - ${DateFormat("dd MMM").format(request.checkOutDate)}',
            icon: Icons.date_range,
          ),
          if (request.roomNumber != null)
            WardenReadOnlyInput(label: 'Room', value: '${request.allotmentHostel} / ${request.roomNumber}', icon: Icons.meeting_room_outlined),
          if (isPending && onApprove != null && onDeny != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: HoverEffect(
                    child: OutlinedButton(
                      onPressed: onDeny,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('REJECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoverEffect(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('APPROVE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class WardenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const WardenImageViewer({
    super.key,
    required this.imageUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: imageUrl,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


