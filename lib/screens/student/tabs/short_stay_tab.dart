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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
          heroTag: 'shortStayFAB',
          onPressed: () => _showShortStayDialog(context),
          backgroundColor: kStudentPrimary,
          elevation: 4,
          label: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('APPLY NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ),
      body: StreamBuilder<List<ShortStayRequest>>(
        stream: fs.getStudentShortStays(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShortStaySkeleton();
          }
          final list = snapshot.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: StudentSectionLabel("SHORT STAYS"),
              ),
              Expanded(
                child: list.isEmpty
                    ? const StudentEmptyState(
                        icon: Icons.hotel_rounded,
                        title: 'No Stay Requests',
                        subtitle: 'Your short stay requests will appear here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: list.length,
                        itemBuilder: (context, i) => StudentExpandableShortStayCard(request: list[i], fs: fs),
                      ),
              ),
            ],
          );
        },
      ),
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


