import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/complaint_model.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/student_components.dart';
import '../../../widgets/vista_loader.dart';

class ComplaintsTab extends StatelessWidget {
  final VistaUser user;
  final FirebaseService fs;
  const ComplaintsTab({super.key, required this.user, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'complaintFAB',
        onPressed: () => _showComplaintDialog(context, user, fs),
        backgroundColor: kStudentPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: fs.getStudentComplaints(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ComplaintListSkeleton();
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const StudentEmptyState(
              icon: Icons.assignment_late_outlined,
              title: 'No Issues Raised',
              subtitle: 'Your complaint history will appear here once you raise any.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              final isResolved = c.status == 'Resolved' || c.status == 'Confirmed';
              Color statusColor = isResolved ? kStudentSuccess : kStudentWarning;
              if (!isResolved && c.isEscalated) {
                statusColor = Colors.redAccent;
              }

              return StudentCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_late_outlined,
                                size: 14,
                                color: kStudentPrimary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${c.seqId}: ${c.title}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'To: ${c.targetRoles.join(", ")} · ${DateFormat('dd MMM').format(c.createdAt)}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.status == 'Resolved' && c.studentConfirmed == null)
                      TextButton(
                        onPressed: () => _confirmResolution(context, c, fs),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: kStudentPrimary.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'VERIFY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else if (c.status == 'Pending' &&
                        DateTime.now().difference(c.createdAt).inDays >= 3 &&
                        !c.targetRoles.contains('Chief Warden'))
                      TextButton(
                        onPressed: () => _confirmEscalation(context, c, fs),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ESCALATE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          (!isResolved && c.isEscalated)
                              ? 'ESCALATED'
                              : (c.status == 'Confirmed' ? 'SOLVED' : c.status.toUpperCase()),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmEscalation(BuildContext context, Complaint c, FirebaseService fs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate Issue'),
        content: const Text(
          'It has been more than 3 days without a resolution. Do you want to escalate this issue to the higher authorities?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              fs.escalateComplaint(c);
              Navigator.pop(context);
            },
            child: const Text(
              'Yes, Escalate',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResolution(BuildContext context, Complaint c, FirebaseService fs) {
    final isChiefWarden = c.targetRoles.contains('Chief Warden');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Resolution'),
        content: Text(
          isChiefWarden
              ? 'Is the issue resolved to your satisfaction?'
              : 'Is the issue resolved to your satisfaction? Escalating will move it to the ${c.targetRoles.contains('Head Warden') ? 'Chief Warden' : 'Head Warden'}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              fs.updateComplaintStatus(c.id, 'Confirmed');
              Navigator.pop(context);
            },
            child: const Text('Yes, Solved'),
          ),
          if (!isChiefWarden)
            TextButton(
              onPressed: () {
                fs.escalateComplaint(c);
                Navigator.pop(context);
              },
              child: const Text(
                'No, Escalate',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, VistaUser user, FirebaseService fs) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Raise New Issue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: kStudentPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  StudentInput(
                    label: 'Title',
                    ctrl: titleController,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Detailed Description',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: kStudentBg.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) return;

                            setModalState(() => isSubmitting = true);
                            try {
                              final complaint = Complaint(
                                id: '',
                                studentId: user.uid,
                                studentName: user.name,
                                title: InputSanitizer.sanitize(titleController.text.trim()),
                                description: InputSanitizer.sanitize(descController.text.trim()),
                                hostel: user.hostel!,
                                targetRoles: ['Warden'],
                                status: 'Pending',
                                isAnonymous: true,
                                createdAt: DateTime.now(),
                              );
                              await fs.submitComplaint(complaint);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Issue reported successfully. Authorities notified.'),
                                    backgroundColor: kStudentSuccess,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to report issue'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => isSubmitting = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kStudentPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isSubmitting
                        ? const VISTALoader(size: 20, color: Colors.white)
                        : const Text(
                            'SUBMIT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.black26,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
