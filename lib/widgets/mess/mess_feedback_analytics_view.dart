import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';
import '../common/vista_loader.dart';

class MessFeedbackAnalyticsView extends StatefulWidget {
  const MessFeedbackAnalyticsView({super.key});

  @override
  State<MessFeedbackAnalyticsView> createState() => _MessFeedbackAnalyticsViewState();
}

class _MessFeedbackAnalyticsViewState extends State<MessFeedbackAnalyticsView> {
  final MessService _messService = MessService();
  DateTime _selectedDate = DateTime.now();
  MessMealType _selectedMeal = MessMealType.breakfast;
  late Stream<List<MessFeedback>> _feedbackStream;

  @override
  void initState() {
    super.initState();
    _updateFeedbackStream();
  }

  void _updateFeedbackStream() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _feedbackStream = _messService.getMealFeedbackStream(dateStr, _selectedMeal);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Meal Filter Header (Common Campus Feedback)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Food Feedback Analytics',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Combined Campus Meal Feedback',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF1E3A8A)),
                      label: Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF0F4FF),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _updateFeedbackStream();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Meal Selector Tabs
                Row(
                  children: MessMealType.values.map((m) {
                    final selected = _selectedMeal == m;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedMeal != m) {
                            setState(() {
                              _selectedMeal = m;
                              _updateFeedbackStream();
                            });
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            m.displayName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                              color: selected ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Feedback Stream & Rating Averages
          StreamBuilder<List<MessFeedback>>(
            stream: _feedbackStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: VISTALoader(size: 32)),
                );
              }

              final feedbacks = snapshot.data ?? [];

              if (feedbacks.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 44, color: Color(0xFF94A3B8)),
                        SizedBox(height: 12),
                        Text(
                          'No student feedback submitted for this meal yet.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Compute dish rating averages
              final Map<String, List<double>> dishRatingsMap = {};
              double totalSum = 0;
              int totalCount = 0;

              for (final fb in feedbacks) {
                fb.itemRatings.forEach((dish, rating) {
                  dishRatingsMap.putIfAbsent(dish, () => []).add(rating);
                  totalSum += rating;
                  totalCount++;
                });
              }

              final overallAvg = totalCount > 0 ? (totalSum / totalCount) : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Satisfaction Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                              const SizedBox(width: 6),
                              Text(
                                overallAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Overall Meal Rating',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Based on ${feedbacks.length} student ratings',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Per-Dish Rating Progress Bars
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dish Rating Breakdown',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 12),
                        if (dishRatingsMap.isEmpty)
                          const Text('No individual dish ratings submitted.', style: TextStyle(color: Color(0xFF64748B)))
                        else
                          ...dishRatingsMap.entries.map((entry) {
                            final dish = entry.key;
                            final ratings = entry.value;
                            final avg = ratings.reduce((a, b) => a + b) / ratings.length;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dish,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${avg.toStringAsFixed(1)} (${ratings.length})",
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: avg / 5.0,
                                      minHeight: 8,
                                      backgroundColor: const Color(0xFFF0F4FF),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        avg >= 4.0
                                            ? const Color(0xFF16A34A)
                                            : avg >= 3.0
                                                ? Colors.amber
                                                : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Student Comments Feed
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Comments & Feedback',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(height: 12),
                        ...feedbacks.where((f) => f.comment != null && f.comment!.isNotEmpty).map((fb) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${fb.studentName} (${fb.rollNo})",
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(fb.timestamp),
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fb.comment!,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
