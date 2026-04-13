import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/student_components.dart';
import '../../../widgets/hover_effect.dart';
import '../../../widgets/vista_loader.dart';
import '../../../widgets/vista_date_picker.dart';

class LeaveTab extends StatefulWidget {
  final VistaUser user;
  final FirebaseService fs;
  const LeaveTab({super.key, required this.user, required this.fs});

  @override
  State<LeaveTab> createState() => _LeaveTabState();
}

class _LeaveTabState extends State<LeaveTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: HoverEffect(
        child: FloatingActionButton(
          heroTag: 'leaveFAB',
          onPressed: () => _showLeaveDialog(context),
          backgroundColor: kStudentPrimary,
          elevation: 4,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: widget.fs.getStudentLeaves(widget.user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LeaveListSkeleton();
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const StudentEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No Leaves Yet',
              subtitle: 'Your leave application history will appear here.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: StudentSectionLabel("LEAVES"),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final l = list[i];
                    return StudentExpandableLeaveCard(
                      seqId: l.seqId,
                      status: l.status,
                      fromDate: l.fromDate,
                      toDate: l.toDate,
                      reason: l.reason,
                      address: l.address,
                      parentName: l.parentName,
                      parentRelation: l.parentRelation,
                      parentContact: l.parentContact,
                      checkInTime: l.checkInTime,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLeaveDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    final fromController = TextEditingController(
      text: prefs.getString('leaveDraft_from') ?? '',
    );
    final toController = TextEditingController(
      text: prefs.getString('leaveDraft_to') ?? '',
    );
    final reasonController = TextEditingController(
      text: prefs.getString('leaveDraft_reason') ?? '',
    );
    final parentNameController = TextEditingController(
      text: prefs.getString('leaveDraft_parentName') ?? widget.user.parentName ?? '',
    );
    final parentContactController = TextEditingController(
      text: prefs.getString('leaveDraft_parentContact') ?? widget.user.parentContact ?? '',
    );
    final addressController = TextEditingController(
      text: prefs.getString('leaveDraft_address') ?? widget.user.address ?? '',
    );
    String? selectedRelation = prefs.getString('leaveDraft_relation') ?? 'Guardian';
    
    void saveDraft() {
      prefs.setString('leaveDraft_from', fromController.text);
      prefs.setString('leaveDraft_to', toController.text);
      prefs.setString('leaveDraft_reason', reasonController.text);
      prefs.setString('leaveDraft_parentName', parentNameController.text);
      prefs.setString('leaveDraft_parentContact', parentContactController.text);
      prefs.setString('leaveDraft_address', addressController.text);
      if (selectedRelation != null) {
        prefs.setString('leaveDraft_relation', selectedRelation!);
      }
    }

    fromController.addListener(saveDraft);
    toController.addListener(saveDraft);
    reasonController.addListener(saveDraft);
    parentNameController.addListener(saveDraft);
    parentContactController.addListener(saveDraft);
    addressController.addListener(saveDraft);

    bool isSubmitting = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          onPopInvokedWithResult: (didPop, result) {
            for (final key in prefs.getKeys()) {
              if (key.startsWith('leaveDraft_')) {
                prefs.remove(key);
              }
            }
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
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
                      'Apply for Leave',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: kStudentPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    StudentInput(
                      label: 'From Date & Time',
                      ctrl: fromController,
                      icon: Icons.access_time_rounded,
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
                            final fullDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            fromController.text = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(fullDateTime);
                          }
                        }
                      },
                    ),
                    StudentInput(
                      label: 'To Date & Time',
                      ctrl: toController,
                      icon: Icons.update_rounded,
                      readOnly: true,
                      onTap: () async {
                        final fromDateStr = fromController.text;
                        DateTime initialDate = DateTime.now();
                        if (fromDateStr.isNotEmpty) {
                          try {
                            initialDate = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).parse(fromDateStr);
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
                            final fullDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            toController.text = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(fullDateTime);
                          }
                        }
                      },
                    ),
                    StudentInput(
                      label: 'Reason',
                      ctrl: reasonController,
                      icon: Icons.edit_note_rounded,
                    ),
                    StudentInput(
                      label: 'Address during leave',
                      ctrl: addressController,
                      icon: Icons.home_work_outlined,
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: StudentInput(
                            label: 'Parent Name',
                            ctrl: parentNameController,
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedRelation,
                              decoration: InputDecoration(
                                labelText: 'Relation',
                                filled: true,
                                fillColor: kStudentBg.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: ['Father', 'Mother', 'Guardian']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setDialogState(() => selectedRelation = v);
                                saveDraft();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    StudentInput(
                      label: 'Parent Contact',
                      ctrl: parentContactController,
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextButton(
                              onPressed: () {
                                for (final key in prefs.getKeys()) {
                                  if (key.startsWith('leaveDraft_')) {
                                    prefs.remove(key);
                                  }
                                }
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.black38,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      final contact = parentContactController.text.trim();
                                      if (contact.length != 10 || double.tryParse(contact) == null) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Please enter a valid 10-digit number'),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      setDialogState(() => isSubmitting = true);
                                      try {
                                        final fromText = fromController.text.trim();
                                        final toText = toController.text.trim();
                                        final reasonText = reasonController.text.trim();

                                        if (fromText.isEmpty || toText.isEmpty) {
                                          throw 'Please select both From and To dates';
                                        }
                                        if (reasonText.isEmpty) {
                                          throw 'Please enter a reason';
                                        }

                                        final request = LeaveRequest(
                                          id: '',
                                          studentId: widget.user.uid,
                                          studentName: widget.user.name,
                                          hostel: widget.user.hostel ?? 'N/A',
                                          fromDate: DateFormat('dd/MM/yyyy hh:mm a').parse(fromText),
                                          toDate: DateFormat('dd/MM/yyyy hh:mm a').parse(toText),
                                          reason: InputSanitizer.sanitize(reasonText),
                                          address: InputSanitizer.sanitize(addressController.text),
                                          parentName: InputSanitizer.sanitize(parentNameController.text),
                                          parentRelation: selectedRelation ?? 'Guardian',
                                          parentContact: contact,
                                          studentContact: widget.user.phoneNumber ?? '',
                                          status: 'Pending',
                                          createdAt: DateTime.now(),
                                        );
                                        await widget.fs.submitLeaveRequest(request);

                                        // Clear draft on success
                                        for (var key in prefs.getKeys()) {
                                          if (key.startsWith('leaveDraft_')) {
                                            prefs.remove(key);
                                          }
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Leave request submitted successfully!'),
                                              backgroundColor: kStudentSuccess,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        debugPrint('Error submitting leave: $e');
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Submission failed: $e')),
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setDialogState(() => isSubmitting = false);
                                        }
                                      }
                                    },
                              child: isSubmitting
                                  ? const VISTALoader(size: 20, color: Colors.white)
                                  : const Text(
                                      'Submit Request',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
