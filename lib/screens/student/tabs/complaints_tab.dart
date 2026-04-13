import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../../models/complaint_model.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/student_components.dart';
import '../../../widgets/hover_effect.dart';
import '../../../widgets/vista_loader.dart';

class ComplaintsTab extends StatefulWidget {
  final VistaUser user;
  final FirebaseService fs;
  const ComplaintsTab({super.key, required this.user, required this.fs});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: HoverEffect(
        child: FloatingActionButton.extended(
          heroTag: 'complaintFAB',
          onPressed: () => _showRaiseComplaintSheet(context),
          backgroundColor: kStudentPrimary,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('RAISE ISSUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: widget.fs.getStudentComplaints(widget.user.uid),
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

          // Sort by creation date
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: StudentSectionLabel("COMPLAINTS"),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Extra bottom padding for FAB
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return StudentExpandableComplaintCard(
                      complaint: c,
                      fs: widget.fs,
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


  void _showRaiseComplaintSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RaiseComplaintSheet(user: widget.user, fs: widget.fs),
    );
  }
}


class _RaiseComplaintSheet extends StatefulWidget {
  final VistaUser user;
  final FirebaseService fs;
  const _RaiseComplaintSheet({required this.user, required this.fs});

  @override
  State<_RaiseComplaintSheet> createState() => _RaiseComplaintSheetState();
}

class _RaiseComplaintSheetState extends State<_RaiseComplaintSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Uint8List? _pickedImage;
  bool _isSubmitting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, imageQuality: 70);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _pickedImage = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Raise New Issue',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kStudentPrimary, letterSpacing: -0.5),
            ),
            const Text(
              'Provide details about the problem you are facing.',
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
            const SizedBox(height: 32),
            StudentInput(label: 'Issue Title', ctrl: _titleCtrl, icon: Icons.title_rounded),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Detailed Description',
                alignLabelWithHint: true,
                filled: true,
                fillColor: kStudentBg.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            const StudentSectionLabel('Attachment (Optional)'),
            if (_pickedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_pickedImage!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: () => setState(() => _pickedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildImageSourceBtn(Icons.camera_alt_outlined, 'Camera', () => _pickImage(ImageSource.camera)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildImageSourceBtn(Icons.image_outlined, 'Gallery', () => _pickImage(ImageSource.gallery)),
                  ),
                ],
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kStudentPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const VISTALoader(size: 20, color: Colors.white)
                  : const Text('SUBMIT REPORT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceBtn(IconData icon, String label, VoidCallback onTap) {
    return HoverEffect(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: kStudentBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kStudentPrimary.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: kStudentPrimary, size: 24),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: kStudentPrimary, fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    if (widget.user.hostel == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hostel not assigned')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? imageUrl;
      if (_pickedImage != null) {
        imageUrl = await widget.fs.uploadComplaintImage(_pickedImage!, widget.user.uid);
      }

      final complaint = Complaint(
        id: '',
        studentId: widget.user.uid,
        studentName: widget.user.name,
        title: InputSanitizer.sanitize(_titleCtrl.text.trim()),
        description: InputSanitizer.sanitize(_descCtrl.text.trim()),
        hostel: widget.user.hostel ?? 'Unassigned',
        targetRoles: ['Warden'],
        status: 'Pending',
        isAnonymous: true,
        createdAt: DateTime.now(),
        imageUrl: imageUrl,
      );

      await widget.fs.submitComplaint(complaint);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complaint submitted!'), backgroundColor: kStudentSuccess, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

