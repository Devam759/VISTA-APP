import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/complaint_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/vista_date_picker.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STUDENT THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const kStudentPrimary = Color(0xFF1E3A8A);
const kStudentAccent = Color(0xFF2563EB);
const kStudentBg = Color(0xFFF0F4FF);
const kStudentSuccess = Color(0xFF10B981);
const kStudentWarning = Color(0xFFF59E0B);
const kStudentDanger = Color(0xFFEF4444);

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class StudentSectionLabel extends StatelessWidget {
  final String label;
  const StudentSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: kStudentPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class StudentCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  const StudentCard({super.key, required this.child, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kStudentPrimary.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );
  }
}

class StudentEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const StudentEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kStudentPrimary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: kStudentPrimary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class StudentInput extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final IconData? icon;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final int? maxLength;

  const StudentInput({
    super.key,
    required this.label,
    required this.ctrl,
    this.icon,
    this.readOnly = false,
    this.onTap,
    this.keyboardType,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: keyboardType,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          counterText: "",
          prefixIcon: icon != null ? Icon(icon, size: 20) : null,
          filled: true,
          fillColor: kStudentBg.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class StudentTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;
  final String actionLabel;
  final IconData actionIcon;

  const StudentTabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kStudentPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: kStudentPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPANDABLE LEAVE CARD (PORTED FROM WARDEN)
// ─────────────────────────────────────────────────────────────────────────────
class StudentExpandableLeaveCard extends StatefulWidget {
  final String seqId;
  final String status;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String address;
  final String parentName;
  final String parentRelation;
  final String parentContact;
  final DateTime? checkInTime;

  const StudentExpandableLeaveCard({
    super.key,
    required this.seqId,
    required this.status,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.address,
    required this.parentName,
    required this.parentRelation,
    required this.parentContact,
    this.checkInTime,
  });

  @override
  State<StudentExpandableLeaveCard> createState() =>
      _StudentExpandableLeaveCardState();
}

class _StudentExpandableLeaveCardState
    extends State<StudentExpandableLeaveCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.status == 'Approved';
    final isRejected = widget.status == 'Rejected';
    final statusColor = isApproved
        ? kStudentSuccess
        : (isRejected ? Colors.redAccent : kStudentWarning);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kStudentPrimary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // CONTRACTED VIEW
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (isApproved
                                  ? kStudentSuccess
                                  : (isRejected
                                        ? Colors.redAccent
                                        : kStudentPrimary))
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.seqId,
                      style: TextStyle(
                        color: isApproved
                            ? kStudentSuccess
                            : (isRejected ? Colors.redAccent : kStudentPrimary),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${DateFormat('dd MMM').format(widget.fromDate)} - ${DateFormat('dd MMM yyyy').format(widget.toDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                    child: const Icon(Icons.expand_more, color: Colors.black26),
                  ),
                ],
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
                  const StudentSectionLabel('Leave Duration'),
                  Row(
                    children: [
                      Expanded(
                        child: StudentReadOnlyInput(
                          label: 'From',
                          value: DateFormat(
                            'dd MMM, hh:mm a',
                          ).format(widget.fromDate),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StudentReadOnlyInput(
                          label: 'To',
                          value: DateFormat(
                            'dd MMM, hh:mm a',
                          ).format(widget.toDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const StudentSectionLabel('Leave Details'),
                  StudentReadOnlyInput(
                    label: 'Reason',
                    value: widget.reason,
                  ),
                  const SizedBox(height: 12),
                  StudentReadOnlyInput(
                    label: 'Address during leave',
                    value: widget.address,
                  ),
                  const SizedBox(height: 16),
                  const StudentSectionLabel('Parent Information'),
                  Row(
                    children: [
                      Expanded(
                        child: StudentReadOnlyInput(
                          label: 'Name',
                          value:
                              '${widget.parentName} (${widget.parentRelation})',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StudentReadOnlyInput(
                          label: 'Mobile',
                          value: widget.parentContact,
                        ),
                      ),
                    ],
                  ),
                  if (widget.checkInTime != null) ...[
                    const SizedBox(height: 16),
                    const StudentSectionLabel('Check-In Details'),
                    StudentReadOnlyInput(
                      label: 'Checked In At',
                      value: DateFormat(
                        'dd MMM, hh:mm a',
                      ).format(widget.checkInTime!),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class StudentReadOnlyInput extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const StudentReadOnlyInput({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kStudentBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: kStudentPrimary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: kStudentPrimary),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINT COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class StudentExpandableComplaintCard extends StatefulWidget {
  final Complaint complaint;
  final FirebaseService fs;

  const StudentExpandableComplaintCard({
    super.key,
    required this.complaint,
    required this.fs,
  });

  @override
  State<StudentExpandableComplaintCard> createState() =>
      _StudentExpandableComplaintCardState();
}

class _StudentExpandableComplaintCardState
    extends State<StudentExpandableComplaintCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = widget.complaint.status == 'Confirmed';
    final isResolved = widget.complaint.status == 'Resolved';
    final isEscalated = widget.complaint.isEscalated;

    Color statusColor;
    String statusText = widget.complaint.status.toUpperCase();

    if (isConfirmed) {
      statusColor = kStudentSuccess;
    } else if (isResolved) {
      statusColor = kStudentAccent; // Blue color to prompt action
      statusText = 'REVIEW NOW'; // Clearer call to action
    } else if (isEscalated) {
      statusColor = kStudentDanger;
    } else {
      statusColor = kStudentWarning;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kStudentPrimary.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // CONTRACTED VIEW
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kStudentPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.complaint.seqId,
                        style: const TextStyle(
                          color: kStudentPrimary,
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
                            widget.complaint.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat(
                              'dd MMM, hh:mm a',
                            ).format(widget.complaint.createdAt),
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.3),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
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

                  // DESCRIPTION SECTION
                  const Text(
                    'ISSUE DESCRIPTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.black38,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kStudentBg.withValues(alpha: 1.0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.complaint.description,
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
                    const Text(
                      'ATTACHMENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.complaint.imageUrl!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 240,
                            color: kStudentBg,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // RESOLUTION STATUS FOR STUDENT
                  if (widget.complaint.status == 'Resolved') ...[
                    const Divider(height: 32),
                    const Text(
                      'IS YOUR ISSUE RESOLVED?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              await widget.fs.updateComplaintStatus(
                                widget.complaint.id,
                                'Confirmed',
                              );
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Thank you for your feedback!',
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kStudentSuccess,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'YES, RESOLVED',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final scaffoldMessenger = ScaffoldMessenger.of(
                                context,
                              );
                              if (widget.complaint.targetRoles.contains(
                                'Chief Warden',
                              )) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Limit reached: Already escalated to Chief Warden.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              await widget.fs.escalateComplaint(
                                widget.complaint,
                              );
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Issue escalated further.'),
                                  ),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kStudentDanger,
                              side: const BorderSide(
                                color: kStudentDanger,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'NO, ESCALATE',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHORT STAY EXPANDABLE CARD
// ─────────────────────────────────────────────────────────────────────────────
class StudentExpandableShortStayCard extends StatefulWidget {
  final ShortStayRequest request;
  final FirebaseService fs;

  const StudentExpandableShortStayCard({
    super.key,
    required this.request,
    required this.fs,
  });

  @override
  State<StudentExpandableShortStayCard> createState() =>
      _StudentExpandableShortStayCardState();
}

class _StudentExpandableShortStayCardState
    extends State<StudentExpandableShortStayCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(widget.request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kStudentPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Contracted View
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.request.seqId.isNotEmpty
                                ? widget.request.seqId
                                : 'PENDING ID',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd MMM').format(widget.request.checkInDate)} - ${DateFormat('dd MMM').format(widget.request.checkOutDate)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(
                      status: widget.request.status,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              // Expanded View
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 24),
                      _DetailRow(
                        label: 'Address',
                        value: widget.request.address,
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        label: 'Parent Contact',
                        value:
                            '${widget.request.parentName} (${widget.request.parentContact})',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(label: 'Reason', value: widget.request.reason),
                      if ((widget.request.status == 'Approved' ||
                              widget.request.status == 'Completed') &&
                          widget.request.roomNumber != null) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          label: 'Allotted Room',
                          value:
                              '${widget.request.allotmentHostel ?? widget.request.appliedHostel} - ${widget.request.roomNumber}',
                        ),
                      ],
                      if (widget.request.pendingToDate != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kStudentWarning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: kStudentWarning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Extension requested until ${DateFormat('dd MMM yyyy, hh:mm a').format(widget.request.pendingToDate!)}',
                                  style: const TextStyle(
                                    color: Color(0xFF92400E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (widget.request.status == 'Approved') ...[
                        Row(
                          children: [
                            Expanded(
                              child: _PremiumButton(
                                label: 'Check-Out',
                                onPressed: () => _handleCheckOut(context),
                              ),
                            ),
                            if (widget.request.pendingToDate == null) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PremiumButton(
                                  label: 'Extend',
                                  onPressed: () =>
                                      _showExtensionDialog(context),
                                  isSecondary: true,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ] else if (widget.request.status == 'Pending') ...[
                        _PremiumButton(
                          label: 'Cancel Request',
                          onPressed: () async {
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            await widget.fs.updateShortStayStatus(
                              widget.request.id,
                              'Cancelled',
                            );
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Request cancelled.'),
                              ),
                            );
                          },
                          isDanger: true,
                        ),
                      ],
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return kStudentWarning;
      case 'Approved':
        return kStudentSuccess;
      case 'Completed':
        return Colors.grey;
      case 'Cancelled':
      case 'Rejected':
        return kStudentDanger;
      default:
        return Colors.blue;
    }
  }

  void _handleCheckOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Check-out'),
        content: const Text(
          'Are you sure you want to mark this short stay as completed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.fs.updateShortStayStatus(widget.request.id, 'Completed');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stay completed successfully!')),
        );
      }
    }
  }

  void _showExtensionDialog(BuildContext context) async {
    final DateTime? newDate = await showVistaDatePicker(
      context: context,
      initialDate: widget.request.checkOutDate.add(const Duration(days: 1)),
      firstDate: widget.request.checkOutDate,
      primaryColor: kStudentPrimary,
    );

    if (newDate != null && context.mounted) {
      final TimeOfDay? newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(widget.request.checkOutDate),
      );

      if (newTime != null && context.mounted) {
        final finalDate = DateTime(
          newDate.year,
          newDate.month,
          newDate.day,
          newTime.hour,
          newTime.minute,
        );
        await widget.fs.requestShortStayExtension(widget.request.id, finalDate);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Extension request sent to Warden.')),
          );
        }
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;
  final bool isDanger;

  const _PremiumButton({
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = isDanger ? kStudentDanger : kStudentPrimary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSecondary ? Colors.transparent : primaryColor,
        border: isSecondary
            ? Border.all(color: primaryColor.withValues(alpha: 0.3), width: 2)
            : null,
        boxShadow: isSecondary
            ? []
            : [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Center(
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isSecondary ? primaryColor : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
