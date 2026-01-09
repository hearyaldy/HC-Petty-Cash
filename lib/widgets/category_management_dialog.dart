import 'package:flutter/material.dart';
import '../models/enums.dart';

class CategoryManagementDialog extends StatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  State<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<CategoryManagementDialog> {
  final List<Map<String, dynamic>> _categories = [
    {
      'category': ExpenseCategory.office,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.travel,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.meals,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.utilities,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.maintenance,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.supplies,
      'enabled': true,
    },
    {
      'category': ExpenseCategory.other,
      'enabled': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Manage Expense Categories',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enable or disable expense categories for your organization',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final item = _categories[index];
                  final category = item['category'] as ExpenseCategory;
                  final enabled = item['enabled'] as bool;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      secondary: Icon(
                        _getCategoryIcon(category),
                        color: enabled ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        category.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: enabled ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        _getCategoryDescription(category),
                        style: TextStyle(
                          color: enabled ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                      value: enabled,
                      onChanged: (value) {
                        setState(() {
                          _categories[index]['enabled'] = value;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category settings saved'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.office:
        return Icons.business;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.meals:
        return Icons.restaurant;
      case ExpenseCategory.supplies:
        return Icons.shopping_cart;
      case ExpenseCategory.utilities:
        return Icons.bolt;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  String _getCategoryDescription(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.office:
        return 'Office supplies, equipment, and workspace expenses';
      case ExpenseCategory.travel:
        return 'Travel, transportation, fuel, and parking expenses';
      case ExpenseCategory.meals:
        return 'Food, beverages, and dining expenses';
      case ExpenseCategory.supplies:
        return 'Materials, inventory, and supply purchases';
      case ExpenseCategory.utilities:
        return 'Electricity, water, internet, and utility bills';
      case ExpenseCategory.maintenance:
        return 'Repairs, upkeep, and maintenance costs';
      case ExpenseCategory.other:
        return 'Miscellaneous and uncategorized expenses';
    }
  }
}
