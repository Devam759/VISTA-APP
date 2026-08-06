import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/mess_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/mess_service.dart';
import '../common/vista_loader.dart';
import 'mess_dish_editor_dialog.dart';
import 'mess_staples_configurator.dart';

const List<String> _kDayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

class MessWeeklyEditorTab extends StatefulWidget {
  const MessWeeklyEditorTab({super.key});

  @override
  State<MessWeeklyEditorTab> createState() => _MessWeeklyEditorTabState();
}

class _MessWeeklyEditorTabState extends State<MessWeeklyEditorTab> {
  final MessService _messService = MessService();
  int _selectedDayIndex = 0; // 0 = Mon, 6 = Sun
  late DateTime _weekMondayDate;
  bool _isSavingWeek = false;
  bool _hasChanges = false; // true once any day item is edited

  // Stream Subscriptions
  StreamSubscription? _staplesSub;
  final List<StreamSubscription> _menuSubs = [];

  // Permanent Daily Essentials fetched dynamically from Firestore DB
  final Map<MessMealType, List<String>> _permanentStaples = {};

  // Daily Specials fetched dynamically from Firestore DB
  final Map<int, Map<MessMealType, List<String>>> _dailySpecials = {};

  // Weekly PDF URL Input Controllers
  final TextEditingController _pdfUrlController = TextEditingController();
  final TextEditingController _pdfTitleController =
      TextEditingController(text: 'Weekly Mess Menu');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekMondayDate = now.subtract(Duration(days: now.weekday - 1));

    for (int day = 0; day < 7; day++) {
      _dailySpecials[day] = {};
      for (final meal in MessMealType.values) {
        _dailySpecials[day]![meal] = [];
      }
    }

    _listenToFirestoreData();
  }

  @override
  void dispose() {
    _staplesSub?.cancel();
    for (final sub in _menuSubs) {
      sub.cancel();
    }
    _pdfUrlController.dispose();
    _pdfTitleController.dispose();
    super.dispose();
  }

  void _listenToFirestoreData() {
    _staplesSub?.cancel();
    for (final sub in _menuSubs) {
      sub.cancel();
    }
    _menuSubs.clear();

    // Reset daily specials so target week starts completely blank if no Firestore data exists
    for (int day = 0; day < 7; day++) {
      _dailySpecials[day] = {};
      for (final meal in MessMealType.values) {
        _dailySpecials[day]![meal] = [];
      }
    }

    // 1. Listen to Permanent Staples Stream from Firestore (/mess_staples)
    _staplesSub = _messService.getPermanentStaplesStream().listen((staplesMap) {
      if (!mounted) return;
      setState(() {
        staplesMap.forEach((meal, list) {
          _permanentStaples[meal] = List<String>.from(list);
        });
      });
    });

    // 2. Listen to 7 Days of Daily Menus Stream from Firestore (/mess_menu)
    for (int day = 0; day < 7; day++) {
      final date = _weekMondayDate.add(Duration(days: day));
      final sub = _messService.getMenuForDateStream(date).listen((menuList) {
        if (!mounted) return;
        final Map<MessMealType, List<String>> newSpecials = {};
        for (final meal in MessMealType.values) {
          newSpecials[meal] = [];
        }
        for (final item in menuList) {
          final staples = _permanentStaples[item.mealType] ?? [];
          final specialsOnly = item.items
              .where((dish) => !staples.contains(dish))
              .toList();

          newSpecials[item.mealType] = specialsOnly.isNotEmpty
              ? specialsOnly
              : List<String>.from(item.items);
        }

        bool hasChanged = false;
        for (final meal in MessMealType.values) {
          if (!listEquals(_dailySpecials[day]![meal], newSpecials[meal])) {
            hasChanged = true;
            break;
          }
        }

        if (hasChanged) {
          setState(() {
            _dailySpecials[day] = newSpecials;
          });
        }
      });
      _menuSubs.add(sub);
    }
  }

  Future<void> _saveMealForDay(int dayIndex, MessMealType meal) async {
    final specials = _dailySpecials[dayIndex]?[meal] ?? [];
    final staples = _permanentStaples[meal] ?? [];
    final combinedItems = [...specials, ...staples];

    if (combinedItems.isEmpty) return;

    final targetDate = _weekMondayDate.add(Duration(days: dayIndex));
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await _messService.updateDailyMenu(
      date: targetDate,
      mealType: meal,
      items: combinedItems,
      updatedBy: authProvider.userProfile?.name ?? 'Mess Manager',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_kDayNames[dayIndex]} ${meal.displayName} saved.'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );
  }

  Future<void> _saveEntireWeek() async {
    // Confirmation dialog before publishing
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Publish Week Menu',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
        ),
        content: const Text(
          'This will update the menu for all 7 days and all 4 meals. Students will see the changes immediately.\n\nAre you sure you want to publish?',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Publish', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isSavingWeek = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final String updater = authProvider.userProfile?.name ?? 'Mess Manager';

    final List<MessMenuItem> menuBatch = [];
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    for (int day = 0; day < 7; day++) {
      final targetDate = _weekMondayDate.add(Duration(days: day));
      final dateStr = formatter.format(targetDate);

      for (final meal in MessMealType.values) {
        final specials = _dailySpecials[day]?[meal] ?? [];
        final staples = _permanentStaples[meal] ?? [];
        final combined = [...specials, ...staples];
        final docId = "${dateStr}_${meal.name}";

        menuBatch.add(MessMenuItem(
          id: docId,
          date: dateStr,
          mealType: meal,
          items: combined,
          updatedBy: updater,
          updatedAt: DateTime.now(),
        ));
      }
    }

    try {
      await _messService.updateWeeklyMenuBatch(menuBatch);
      if (mounted) {
        setState(() => _hasChanges = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Weekly menu published successfully.'),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing weekly menu: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingWeek = false);
    }
  }

  bool _isUploadingPdf = false;

  Future<void> _pickAndUploadPdf() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final updaterName = authProvider.userProfile?.name ?? 'Mess Manager';

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read file contents. Please try selecting the PDF again.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
        return;
      }

      setState(() => _isUploadingPdf = true);

      await _messService.uploadWeeklyPdfBytes(
        bytes: bytes,
        fileName: file.name,
        title: 'Weekly Mess Menu',
        uploadedBy: updaterName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weekly menu PDF uploaded successfully.'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload PDF: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPdf = false);
    }
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

  Widget _buildWeekNavigator() {
    final now = DateTime.now();
    final currentWeekMonday = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = _weekMondayDate.add(const Duration(days: 6));

    final isCurrentWeek = _weekMondayDate.year == currentWeekMonday.year &&
        _weekMondayDate.month == currentWeekMonday.month &&
        _weekMondayDate.day == currentWeekMonday.day;

    final weekLabel = isCurrentWeek ? 'THIS WEEK' : 'NEXT WEEK';
    final badgeColor = isCurrentWeek ? const Color(0xFF16A34A) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          weekLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${DateFormat('MMM dd').format(_weekMondayDate)} – ${DateFormat('MMM dd, yyyy').format(weekEnd)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isCurrentWeek ? 'Editing current week\'s menu' : 'Editing next week\'s menu',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),

              // 2 Week Navigation Buttons: Prev Week & Next Week
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _weekMondayDate = _weekMondayDate.subtract(const Duration(days: 7));
                        _hasChanges = false;
                      });
                      _listenToFirestoreData();
                    },
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    label: const Text('Prev Week'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      foregroundColor: const Color(0xFF334155),
                    ),
                  ),

                  const SizedBox(width: 10),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _weekMondayDate = _weekMondayDate.add(const Duration(days: 7));
                        _hasChanges = false;
                      });
                      _listenToFirestoreData();
                    },
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    label: const Text('Next Week'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFmt = DateFormat('dd MMM');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekNavigator(),

          // 7-Day Selector Bar (Mon to Sun)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final dayDate = _weekMondayDate.add(Duration(days: index));
                final isSelected = _selectedDayIndex == index;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _kDayNames[index].substring(0, 3).toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFmt.format(dayDate),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Selected Day Title Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: Color(0xFF1E3A8A)),
                const SizedBox(width: 8),
                Text(
                  '${_kDayNames[_selectedDayIndex]} Menu (${dateFmt.format(_weekMondayDate.add(Duration(days: _selectedDayIndex)))})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Meal Cards for Selected Day (Breakfast, Lunch, High Tea, Dinner)
          ...MessMealType.values.map((meal) {
            final specials = _dailySpecials[_selectedDayIndex]?[meal] ?? [];
            final staples = _permanentStaples[meal] ?? [];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getMealIcon(meal),
                              size: 18, color: const Color(0xFF1E3A8A)),
                          const SizedBox(width: 8),
                          Text(
                            meal.displayName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        meal.timeRangeText,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Daily items row (similar pattern to permanent items)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: specials.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  'No items added for this day.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: specials.map((dish) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      dish,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF1E40AF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF1E3A8A)),
                        tooltip:
                            'Edit ${_kDayNames[_selectedDayIndex]} ${meal.displayName}',
                        onPressed: () {
                          showMessDishEditorDialog(
                            context: context,
                            title:
                                '${_kDayNames[_selectedDayIndex]} — ${meal.displayName}',
                            subtitle:
                                '${_kDayNames[_selectedDayIndex]}-specific items for ${meal.displayName}',
                            initialDishes: specials,
                            onSave: (updatedSpecials) async {
                              setState(() {
                                _dailySpecials[_selectedDayIndex]![meal] =
                                    updatedSpecials;
                                _hasChanges = true;
                              });
                              await _saveMealForDay(_selectedDayIndex, meal);
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  // Fixed items — shown below a subtle divider, greyed out
                  if (staples.isNotEmpty) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: staples.map((staple) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            staple,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Publish Button — disabled until changes are made
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: (_isSavingWeek || !_hasChanges) ? null : _saveEntireWeek,
              icon: _isSavingWeek
                  ? const VISTALoader(size: 18, color: Colors.white)
                  : const Icon(Icons.published_with_changes_rounded, size: 20),
              label: Text(
                _isSavingWeek ? 'Publishing...' : 'Publish',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasChanges
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                disabledForegroundColor: const Color(0xFF94A3B8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // 📌 Permanent Daily Essentials Configurator (Database Synced Component)
          MessStaplesConfigurator(permanentStaples: _permanentStaples),

          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // Upload Weekly PDF Section
          const Text(
            'Upload Weekly Menu PDF',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A)),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isUploadingPdf ? null : _pickAndUploadPdf,
                icon: _isUploadingPdf
                    ? const VISTALoader(size: 18, color: Colors.white)
                    : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: Text(
                  _isUploadingPdf ? 'Uploading PDF...' : 'Choose & Upload PDF Document',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
