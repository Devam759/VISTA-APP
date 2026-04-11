import 'package:flutter/material.dart';
import '../screens/warden/components/warden_components.dart';

Future<DateTime?> showVistaDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  DateTime? lastDate,
  Color? primaryColor,
}) async {
  DateTime tempDate = initialDate;
  final themeColor = primaryColor ?? kPrimary;
  final finalLastDate = lastDate ?? DateTime.now().add(const Duration(days: 90));

  return showDialog<DateTime>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Select Date',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: themeColor,
              ),
            ),
          ),
          SizedBox(
            height: 320,
            width: 320,
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: themeColor,
                  onPrimary: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: finalLastDate,
                onDateChanged: (date) => tempDate = date,
              ),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.black38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, tempDate),
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
