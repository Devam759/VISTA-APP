import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/mess_model.dart';
import '../../models/vista_user.dart';
import '../../services/mess_service.dart';

class MessFeedbackDialog extends StatefulWidget {
  final VistaUser student;
  final DateTime date;
  final MessMealType mealType;
  final List<String> dishes;

  const MessFeedbackDialog({
    super.key,
    required this.student,
    required this.date,
    required this.mealType,
    required this.dishes,
  });

  static void show(
    BuildContext context, {
    required VistaUser student,
    required DateTime date,
    required MessMealType mealType,
    required List<String> dishes,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MessFeedbackDialog(
        student: student,
        date: date,
        mealType: mealType,
        dishes: dishes,
      ),
    );
  }

  @override
  State<MessFeedbackDialog> createState() => _MessFeedbackDialogState();
}

class _MessFeedbackDialogState extends State<MessFeedbackDialog> {
  final Map<String, double> _ratings = {};
  final TextEditingController _commentController = TextEditingController();
  final MessService _messService = MessService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Default initial ratings (optional)
    for (final d in widget.dishes) {
      _ratings[d] = 0.0;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    setState(() {
      _isSubmitting = true;
    });

    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    // Filter out unrated items
    final Map<String, double> finalRatings = {};
    _ratings.forEach((dish, rating) {
      if (rating > 0) {
        finalRatings[dish] = rating;
      }
    });

    final feedback = MessFeedback(
      id: '',
      studentId: widget.student.uid,
      studentName: widget.student.name,
      rollNo: widget.student.rollNo ?? 'N/A',
      hostel: widget.student.hostel ?? 'Day Scholar',
      date: dateStr,
      mealType: widget.mealType,
      itemRatings: finalRatings,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      timestamp: DateTime.now(),
    );

    try {
      await _messService.submitMealFeedback(feedback);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you! Your meal feedback has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit feedback: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM dd, yyyy').format(widget.date);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate ${widget.mealType.displayName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Optional Ratings',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF145AF2)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'Dish Ratings (Optional):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Per-dish 5-star rating bars
            if (widget.dishes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No specific dish items listed for this meal.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...widget.dishes.map((dish) {
                final currentRating = _ratings[dish] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dish,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        children: List.generate(5, (starIndex) {
                          final starVal = starIndex + 1.0;
                          final isFilled = starVal <= currentRating;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _ratings[dish] = (currentRating == starVal) ? 0.0 : starVal;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                isFilled ? Icons.star : Icons.star_border,
                                color: isFilled ? Colors.amber : Colors.grey.shade400,
                                size: 24,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 16),
            const Text(
              'Additional Comments (Optional):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your feedback about taste, quality, or portion...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Submit Feedback', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
