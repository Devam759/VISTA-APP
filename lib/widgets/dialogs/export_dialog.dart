import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../common/hover_effect.dart';

enum ExportType {
  attendance,
  students,
  leaveRequests,
  complaints,
  shortStays,
}

class ExportOption {
  final ExportType type;
  final String title;
  final IconData icon;

  const ExportOption({
    required this.type,
    required this.title,
    required this.icon,
  });
}

class ExportDialogResult {
  final ExportType exportType;
  final DateTime startDate;
  final DateTime endDate;

  ExportDialogResult({
    required this.exportType,
    required this.startDate,
    required this.endDate,
  });
}

class ExportDialog extends StatefulWidget {
  final String hostel;

  const ExportDialog({
    super.key,
    required this.hostel,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportType? _selectedType;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  final List<ExportOption> _options = const [
    ExportOption(
      type: ExportType.attendance,
      title: 'Attendance Report',
      icon: Icons.assignment_ind,
    ),
    ExportOption(
      type: ExportType.students,
      title: 'Students List',
      icon: Icons.groups,
    ),
    ExportOption(
      type: ExportType.leaveRequests,
      title: 'Leave Requests',
      icon: Icons.event_note,
    ),
    ExportOption(
      type: ExportType.complaints,
      title: 'Complaints',
      icon: Icons.assignment_late,
    ),
    ExportOption(
      type: ExportType.shortStays,
      title: 'Short Stay Forms',
      icon: Icons.hotel,
    ),
  ];

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  void _onExport() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an export type')),
      );
      return;
    }

    Navigator.of(context).pop(
      ExportDialogResult(
        exportType: _selectedType!,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.file_download_outlined,
                    color: Color(0xFF1E3A8A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export Data',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Export Options
            Flexible(
              child: RadioGroup<ExportType>(
                groupValue: _selectedType,
                onChanged: (ExportType? value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _options.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final isSelected = _selectedType == option.type;

                    return HoverEffect(
                      child: InkWell(
                        onTap: () => setState(() => _selectedType = option.type),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.08)
                                : Colors.grey.withValues(alpha: 0.05),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  option.icon,
                                  size: 20,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E3A8A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF1E3A8A)
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              Radio<ExportType>(
                                value: option.type,
                                activeColor: const Color(0xFF1E3A8A),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date Range Section
            Row(
              children: [
                Expanded(
                  child: _DateRangeButton(
                    label: 'From',
                    date: _startDate,
                    onTap: _pickStartDate,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.black38,
                  ),
                ),
                Expanded(
                  child: _DateRangeButton(
                    label: 'To',
                    date: _endDate,
                    onTap: _pickEndDate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: HoverEffect(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: HoverEffect(
                    child: ElevatedButton.icon(
                      onPressed: _onExport,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
    );
  }
}

class _DateRangeButton extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateRangeButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverEffect(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: Color(0xFF1E3A8A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
