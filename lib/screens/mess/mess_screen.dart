import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/mess_model.dart';
import '../../models/vista_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/mess_service.dart';
import '../../widgets/mess/mess_feedback_dialog.dart';
import '../../widgets/mess/mess_pdf_viewer.dart';
import '../../widgets/mess/mess_qr_widget.dart';

class MessScreen extends StatefulWidget {
  const MessScreen({super.key});

  @override
  State<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends State<MessScreen> {
  static const _channel = MethodChannel('com.ashish.vista.jklu/debug_token');
  final MessService _messService = MessService();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
    super.dispose();
  }

  Future<void> _enableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {}
  }

  Future<void> _disableScreenshotProtection() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userProfile;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final now = DateTime.now();
    final activeMeal = MessTimings.getCurrentMeal(now);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Label matching other tabs
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 4, 12),
              child: Text(
                "MESS",
                style: TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),

            // Dynamic QR Code Card (For Students)
            if (user.role == UserRole.student) ...[
              MessQrWidget(student: user),
              const SizedBox(height: 20),
            ],

            // Today's Menu Header & Date Picker Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TODAY'S MENU",
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 16, color: Color(0xFF1E3A8A)),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Color(0xFF1E3A8A)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Menu & Staples Stream
            StreamBuilder<List<MessAttendance>>(
              stream: _messService.getStudentMealHistoryStream(user.uid),
              builder: (context, historySnap) {
                final claimedHistory = historySnap.data ?? [];

                return StreamBuilder<Map<MessMealType, List<String>>>(
                  stream: _messService.getPermanentStaplesStream(),
                  builder: (context, staplesSnap) {
                    final staplesMap = staplesSnap.data ?? {};

                    return StreamBuilder<List<MessMenuItem>>(
                      stream: _messService.getMenuForDateStream(_selectedDate),
                      builder: (context, snapshot) {
                        final menuList = snapshot.data ?? [];

                        return Column(
                          children: MessMealType.values.map((meal) {
                            final item = menuList.firstWhere(
                              (m) => m.mealType == meal,
                              orElse: () => MessMenuItem(
                                id: '',
                                date: dateStr,
                                mealType: meal,
                                items: [],
                              ),
                            );

                            final staples = staplesMap[meal] ?? [];
                            final dailyItems = item.items
                                .where((dish) => !staples.contains(dish))
                                .toList();

                            final isActive = activeMeal == meal;
                            final canRate = MessTimings.isFeedbackWindowOpen(meal, _selectedDate, now);

                            // Check if student has actually eaten/claimed this specific meal on _selectedDate
                            final hasEatenMeal = claimedHistory.any((rec) =>
                                rec.date == dateStr && rec.mealType == meal);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: isActive ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: isActive
                                    ? const BorderSide(color: Color(0xFF145AF2), width: 2)
                                    : BorderSide.none,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _getMealIcon(meal),
                                              color: isActive ? const Color(0xFF145AF2) : Colors.black54,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              meal.displayName,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isActive ? const Color(0xFF145AF2) : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF145AF2).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'SERVED NOW',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF145AF2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      meal.timeRangeText,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    const Divider(height: 20),

                                    // 1. Current Meal / Daily Items (Top)
                                    if (dailyItems.isEmpty && staples.isEmpty)
                                      const Text(
                                        'Menu not updated yet',
                                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                                      )
                                    else ...[
                                      if (dailyItems.isNotEmpty)
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: dailyItems.map((dish) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF0F4FF),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                dish,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                                              ),
                                            );
                                          }).toList(),
                                        ),

                                      // 2. Fixed Daily Items (Below after a space)
                                      if (staples.isNotEmpty) ...[
                                        if (dailyItems.isNotEmpty) const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: staples.map((staple) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF8FAFC),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: Text(
                                                staple,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],

                                    const SizedBox(height: 12),

                                    // Rate Meal Action Button (Only for students who have actually eaten/claimed the meal)
                                    if (user.role == UserRole.student && canRate && hasEatenMeal && item.items.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.star_outline, size: 16, color: Color(0xFF145AF2)),
                                          label: const Text('Rate Meal', style: TextStyle(color: Color(0xFF145AF2), fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF145AF2)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: () {
                                            MessFeedbackDialog.show(
                                              context,
                                              student: user,
                                              date: _selectedDate,
                                              mealType: meal,
                                              dishes: item.items,
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            // Weekly Menu PDF Button (Positioned at bottom)
            StreamBuilder<MessWeeklyPdf?>(
              stream: _messService.getActiveWeeklyPdfStream(),
              builder: (context, snapshot) {
                final weeklyPdf = snapshot.data;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF1E3A8A)),
                    label: const Text(
                      'View Complete Weekly Menu (PDF)',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (weeklyPdf != null && weeklyPdf.pdfUrl.isNotEmpty) {
                        MessPdfViewerDialog.show(context, weeklyPdf);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Weekly Menu PDF has not been uploaded yet.')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  IconData _getMealIcon(MessMealType meal) {
    switch (meal) {
      case MessMealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MessMealType.lunch:
        return Icons.wb_sunny_rounded;
      case MessMealType.snacks:
        return Icons.coffee_rounded;
      case MessMealType.dinner:
        return Icons.nights_stay_outlined;
    }
  }
}
