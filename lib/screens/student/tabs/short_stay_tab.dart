import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/short_stay_model.dart';
import '../../../models/vista_user.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/firebase_service.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/student_components.dart';
import '../../../widgets/vista_loader.dart';
import '../../../widgets/vista_date_picker.dart';

class ShortStayTab extends StatelessWidget {
  final VistaUser user;
  final FirebaseService fs;
  const ShortStayTab({super.key, required this.user, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StudentTabHeader(
          title: 'Hostel Stays',
          subtitle: 'Apply for short stay',
          onAction: () => _showShortStayDialog(context),
          actionLabel: 'Apply Now',
          actionIcon: Icons.add_home_work_rounded,
        ),
        Expanded(
          child: StreamBuilder<List<ShortStayRequest>>(
            stream: fs.getStudentShortStays(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ShortStaySkeleton();
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const StudentEmptyState(
                  icon: Icons.hotel_rounded,
                  title: 'No Stay Requests',
                  subtitle: 'Your approved hostel stays will appear here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, i) => ShortStayCard(request: list[i], fs: fs),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showShortStayDialog(BuildContext context) {
    final checkInCtrl = TextEditingController();
    final checkOutCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: user.address ?? '');
    final parentNameCtrl = TextEditingController(text: user.parentName ?? '');
    final parentContactCtrl = TextEditingController(text: user.parentContact ?? '');
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Short Stay (Annexure-F)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: kStudentPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StudentInput(
                    label: 'Check-in Date & Time',
                    ctrl: checkInCtrl,
                    icon: Icons.login_rounded,
                    readOnly: true,
                    onTap: () async {
                      final date = await showVistaDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        primaryColor: kStudentPrimary,
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          checkInCtrl.text = DateFormat('dd/MM/yyyy hh:mm a').format(
                            DateTime(date.year, date.month, date.day, time.hour, time.minute),
                          );
                        }
                      }
                    },
                  ),
                  StudentInput(
                    label: 'Check-out Date & Time',
                    ctrl: checkOutCtrl,
                    icon: Icons.logout_rounded,
                    readOnly: true,
                    onTap: () async {
                      final fromStr = checkInCtrl.text;
                      DateTime initialDate = DateTime.now();
                      if (fromStr.isNotEmpty) {
                        try {
                          initialDate = DateFormat('dd/MM/yyyy hh:mm a').parse(fromStr);
                        } catch (_) {}
                      }

                      final date = await showVistaDatePicker(
                        context: context,
                        initialDate: initialDate,
                        firstDate: initialDate,
                        primaryColor: kStudentPrimary,
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          checkOutCtrl.text = DateFormat('dd/MM/yyyy hh:mm a').format(
                            DateTime(date.year, date.month, date.day, time.hour, time.minute),
                          );
                        }
                      }
                    },
                  ),
                  StudentInput(label: 'Address', ctrl: addressCtrl, icon: Icons.home_outlined),
                  StudentInput(label: 'Parent Name', ctrl: parentNameCtrl, icon: Icons.person_outline),
                  StudentInput(
                    label: 'Parent Contact',
                    ctrl: parentContactCtrl,
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  StudentInput(label: 'Reason for Stay', ctrl: reasonCtrl, icon: Icons.description_outlined),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (checkInCtrl.text.isEmpty || checkOutCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please fill all fields')),
                              );
                              return;
                            }
                            setDialogState(() => isSubmitting = true);
                            try {
                              final req = ShortStayRequest(
                                id: '',
                                seqId: '',
                                studentId: user.uid,
                                studentName: user.name,
                                rollNo: user.rollNo ?? '',
                                programme: user.programme ?? '',
                                gender: user.gender ?? '',
                                email: user.email,
                                contactNo: user.phoneNumber ?? '',
                                address: addressCtrl.text,
                                reason: reasonCtrl.text,
                                parentName: parentNameCtrl.text,
                                parentContact: parentContactCtrl.text,
                                checkInDate: DateFormat('dd/MM/yyyy hh:mm a').parse(checkInCtrl.text),
                                checkOutDate: DateFormat('dd/MM/yyyy hh:mm a').parse(checkOutCtrl.text),
                                status: 'Pending',
                                appliedHostel: 'Pending',
                                createdAt: DateTime.now(),
                              );
                              await fs.submitShortStayRequest(req);

                              if (!context.mounted) return;
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              Map<String, dynamic> updates = {};
                              if (addressCtrl.text != user.address) updates['address'] = addressCtrl.text;
                              if (parentNameCtrl.text != user.parentName) updates['parentName'] = parentNameCtrl.text;
                              if (parentContactCtrl.text != user.parentContact) {
                                updates['parentContact'] = parentContactCtrl.text;
                              }

                              if (updates.isNotEmpty) {
                                await authProvider.updateUserProfile(updates);
                              }
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request submitted!', style: TextStyle(color: Colors.white)),
                                    backgroundColor: kStudentSuccess,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            } finally {
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const VISTALoader(size: 20, color: Colors.white)
                        : const Text('Submit Application'),
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

class ShortStayCard extends StatelessWidget {
  final ShortStayRequest request;
  final FirebaseService fs;
  const ShortStayCard({super.key, required this.request, required this.fs});

  @override
  Widget build(BuildContext context) {
    final isActive = request.status == 'Approved';
    final isPending = request.status == 'Pending';
    final isExtensionPending = request.pendingToDate != null;

    Color statusColor = isPending ? kStudentWarning : (isActive ? kStudentSuccess : Colors.grey);
    if (request.status == 'Rejected') statusColor = Colors.redAccent;

    return StudentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                request.seqId,
                style: const TextStyle(fontSize: 10, color: Colors.black26, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            request.appliedHostel,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kStudentPrimary),
          ),
          if (request.roomNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Room: ${request.roomNumber}',
                style: const TextStyle(color: kStudentAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          const SizedBox(height: 16),
          _row(Icons.login_rounded, 'Check-in', DateFormat('MMM d, hh:mm a').format(request.checkInDate)),
          const SizedBox(height: 8),
          _row(Icons.logout_rounded, 'Check-out', DateFormat('MMM d, hh:mm a').format(request.checkOutDate)),
          if (isExtensionPending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kStudentWarning.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kStudentWarning.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 16, color: kStudentWarning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Extension requested until ${DateFormat('MMM d').format(request.pendingToDate!)}',
                        style: const TextStyle(fontSize: 12, color: kStudentWarning, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isActive) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kStudentPrimary.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _showExtensionDialog(context),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Extend'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kStudentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () => _handleCheckOut(context),
                    child: const Text('Check-out'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black26),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: Colors.black45, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _handleCheckOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Check-out'),
        content: const Text('Are you sure you want to end your hostel stay?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Check-out')),
        ],
      ),
    );
    if (confirmed == true) {
      await fs.checkOutFromShortStay(request.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked out successfully!')));
      }
    }
  }

  void _showExtensionDialog(BuildContext context) async {
    final date = await showVistaDatePicker(
      context: context,
      initialDate: request.checkOutDate.add(const Duration(days: 1)),
      firstDate: request.checkOutDate,
      lastDate: request.checkOutDate.add(const Duration(days: 7)),
      primaryColor: kStudentPrimary,
    );
    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(request.checkOutDate),
      );
      if (time != null) {
        final newDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        await fs.requestShortStayExtension(request.id, newDate);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Extension request sent!')));
        }
      }
    }
  }
}
