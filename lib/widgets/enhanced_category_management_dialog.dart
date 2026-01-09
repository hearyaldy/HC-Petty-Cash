import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import 'icon_picker_dialog.dart';

class EnhancedCategoryManagementDialog extends StatefulWidget {
  const EnhancedCategoryManagementDialog({super.key});

  @override
  State<EnhancedCategoryManagementDialog> createState() =>
      _EnhancedCategoryManagementDialogState();
}

class _EnhancedCategoryManagementDialogState
    extends State<EnhancedCategoryManagementDialog> {
  final SettingsService _settingsService = SettingsService();
  List<CustomCategory> _customCategories = [];
  bool _isLoading = true;

  final Map<ExpenseCategory, bool> _defaultCategories = {
    ExpenseCategory.office: true,
    ExpenseCategory.travel: true,
    ExpenseCategory.meals: true,
    ExpenseCategory.utilities: true,
    ExpenseCategory.maintenance: true,
    ExpenseCategory.supplies: true,
    ExpenseCategory.other: true,
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _settingsService.getCustomCategories();
      setState(() {
        _customCategories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
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
              'Manage default and custom expense categories',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    // Default Categories Section
                    _buildSectionHeader('Default Categories'),
                    ..._defaultCategories.keys.map((category) {
                      final enabled = _defaultCategories[category]!;
                      return _buildDefaultCategoryTile(category, enabled);
                    }),
                    const SizedBox(height: 24),

                    // Custom Categories Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Custom Categories'),
                        TextButton.icon(
                          onPressed: () => _showAddCategoryDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Category'),
                        ),
                      ],
                    ),
                    if (_customCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.category_outlined,
                                  size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text(
                                'No custom categories yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showAddCategoryDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Category'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._customCategories.map((category) {
                        return _buildCustomCategoryTile(category);
                      }),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildDefaultCategoryTile(ExpenseCategory category, bool enabled) {
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
            _defaultCategories[category] = value;
          });
        },
      ),
    );
  }

  Widget _buildCustomCategoryTile(CustomCategory category) {
    final iconData = IconData(
      int.parse(category.iconCodePoint),
      fontFamily: 'MaterialIcons',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          iconData,
          color: category.enabled ? Colors.purple : Colors.grey,
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: category.enabled ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          category.description.isNotEmpty
              ? category.description
              : 'Custom category',
          style: TextStyle(
            color: category.enabled ? Colors.grey[600] : Colors.grey[400],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: category.enabled,
              onChanged: (value) async {
                final updated = category.copyWith(enabled: value);
                await _settingsService.updateCustomCategory(updated);
                await _loadCategories();
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditCategoryDialog(category);
                } else if (value == 'delete') {
                  _confirmDeleteCategory(category);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
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

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    IconData? selectedIcon;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Custom Category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a category name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Office supplies and equipment',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final icon = await showDialog<IconData>(
                        context: context,
                        builder: (context) =>
                            IconPickerDialog(initialIcon: selectedIcon),
                      );
                      if (icon != null) {
                        setState(() {
                          selectedIcon = icon;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedIcon ?? Icons.category,
                            size: 32,
                            color: selectedIcon != null
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            selectedIcon != null
                                ? 'Icon Selected'
                                : 'Tap to select icon',
                            style: TextStyle(
                              color: selectedIcon != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedIcon != null) {
                  final category = CustomCategory(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    iconCodePoint: selectedIcon!.codePoint.toString(),
                    createdAt: DateTime.now(),
                  );
                  await _settingsService.addCustomCategory(category);
                  Navigator.pop(context);
                  await _loadCategories();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category added successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else if (selectedIcon == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an icon')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(CustomCategory category) {
    final nameController = TextEditingController(text: category.name);
    final descriptionController = TextEditingController(text: category.description);
    final formKey = GlobalKey<FormState>();
    IconData? selectedIcon = IconData(
      int.parse(category.iconCodePoint),
      fontFamily: 'MaterialIcons',
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Custom Category'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a category name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Office supplies and equipment',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final icon = await showDialog<IconData>(
                        context: context,
                        builder: (context) =>
                            IconPickerDialog(initialIcon: selectedIcon),
                      );
                      if (icon != null) {
                        setState(() {
                          selectedIcon = icon;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedIcon ?? Icons.category,
                            size: 32,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          const Text('Tap to change icon'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && selectedIcon != null) {
                  final updated = category.copyWith(
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    iconCodePoint: selectedIcon!.codePoint.toString(),
                  );
                  await _settingsService.updateCustomCategory(updated);
                  Navigator.pop(context);
                  await _loadCategories();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Category updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(CustomCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _settingsService.deleteCustomCategory(category.id);
              Navigator.pop(context);
              await _loadCategories();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Category deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
