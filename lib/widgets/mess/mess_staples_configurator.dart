import 'package:flutter/material.dart';
import '../../models/mess_model.dart';
import '../../services/mess_service.dart';
import 'mess_dish_editor_dialog.dart';

/// Collapsible panel to manage permanent daily staples stored in Firestore (/mess_staples)
class MessStaplesConfigurator extends StatefulWidget {
  final Map<MessMealType, List<String>> permanentStaples;

  const MessStaplesConfigurator({
    super.key,
    required this.permanentStaples,
  });

  @override
  State<MessStaplesConfigurator> createState() => _MessStaplesConfiguratorState();
}

class _MessStaplesConfiguratorState extends State<MessStaplesConfigurator> {
  bool _isExpanded = false;
  final MessService _messService = MessService();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: ExpansionTile(
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (val) => setState(() => _isExpanded = val),
        leading: const Icon(Icons.push_pin_outlined, color: Color(0xFF1E3A8A)),
        title: const Text(
          'Manage Fixed Daily Items',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: MessMealType.values.map((meal) {
                final staplesList = widget.permanentStaples[meal] ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.displayName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (staplesList.isEmpty)
                              const Text(
                                'None added',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              )
                            else
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: staplesList.map((s) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      s,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF334155)),
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF1E3A8A)),
                        tooltip: 'Edit ${meal.displayName}',
                        onPressed: () {
                          showMessDishEditorDialog(
                            context: context,
                            title: '${meal.displayName} — Fixed Items',
                            subtitle:
                                'Items served every day for ${meal.displayName}',
                            initialDishes: staplesList,
                            onSave: (updatedStaples) async {
                              await _messService.updatePermanentStaples(
                                  meal, updatedStaples);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '${meal.displayName} fixed items updated.'),
                                    backgroundColor: const Color(0xFF16A34A),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
