import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/equipment.dart';
import '../../services/equipment_service.dart';
import '../../services/inventory_import_service.dart';
import '../../services/pdf_export_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/dashboard_section.dart';
import '../../utils/responsive_helper.dart';

enum ViewType { card, table, list }
enum ImportAction { create, update, skip }
enum PrintSortOption {
  none,
  assetTagNumberAsc,
  assetTagNumberDesc,
  assetTagAsc,
  assetTagDesc,
  assetCodeAsc,
  assetCodeDesc,
  itemStickerTagAsc,
  itemStickerTagDesc,
}

class _ImportPlanItem {
  _ImportPlanItem({
    required this.row,
    required this.action,
    this.match,
    this.matchReason,
  });

  final InventoryImportRow row;
  final Equipment? match;
  final String? matchReason;
  ImportAction action;
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final EquipmentService _equipmentService = EquipmentService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _selectedCondition = 'All';
  String _selectedLocation = 'All';
  String _searchQuery = '';
  bool _showPrintReady = false; // Filter for items ready for sticker printing
  ViewType _viewType = ViewType.card;
  bool _isLoading = true;
  List<Equipment> _equipment = [];
  String? _errorMessage;
  final bool _showFilters = true;

  // Selection state for table view
  final Set<String> _selectedEquipmentIds = {};

  // Cached filtered results and stats
  List<Equipment>? _cachedFilteredEquipment;
  String? _lastFilterKey;
  Map<String, int>? _cachedStats;
  List<String>? _cachedLocations;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEquipment({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      final isAdmin = user?.role == 'admin';
      final organizationId = user?.organizationId;

      List<Equipment> snapshot;

      // Admins see all equipment, others see only their organization's equipment
      if (isAdmin || organizationId == null) {
        snapshot = await _equipmentService.getAllEquipmentOnce(
          forceRefresh: forceRefresh,
        );
      } else {
        snapshot = await _equipmentService.getEquipmentByOrganizationOnce(
          organizationId,
          forceRefresh: forceRefresh,
        );
      }

      if (mounted) {
        setState(() {
          _equipment = snapshot;
          _isLoading = false;
          // Clear local cache when data is reloaded
          _invalidateCache();
        });
      }
    } catch (e) {
      debugPrint('Error loading equipment: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Force refresh from server (e.g., on pull-to-refresh)
  Future<void> _refreshEquipment() async {
    await _loadEquipment(forceRefresh: true);
  }

  void _invalidateCache() {
    _cachedFilteredEquipment = null;
    _lastFilterKey = null;
    _cachedStats = null;
    _cachedLocations = null;
  }

  // Selection methods
  void _toggleSelection(String equipmentId) {
    setState(() {
      if (_selectedEquipmentIds.contains(equipmentId)) {
        _selectedEquipmentIds.remove(equipmentId);
      } else {
        _selectedEquipmentIds.add(equipmentId);
      }
    });
  }

  void _selectAll(List<Equipment> equipment) {
    setState(() {
      _selectedEquipmentIds.addAll(equipment.map((e) => e.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedEquipmentIds.clear();
    });
  }

  Future<void> _deleteSelectedEquipment() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.canDeleteInventory()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to delete equipment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final count = _selectedEquipmentIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Equipment'),
        content: Text(
          'Are you sure you want to delete $count selected equipment item${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final id in _selectedEquipmentIds.toList()) {
          await _equipmentService.deleteEquipment(id);
        }
        _clearSelection();
        // Cache is already invalidated by deleteEquipment, just reload
        await _loadEquipment();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Successfully deleted $count equipment item${count > 1 ? 's' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting equipment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getFilterKey() {
    return '$_selectedCategory|$_selectedStatus|$_selectedCondition|$_selectedLocation|$_searchQuery|$_showPrintReady';
  }

  /// Show print field selection dialog
  Future<void> _showPrintDialog() async {
    final filteredEquipment = _filterEquipment(_equipment);

    if (filteredEquipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No equipment to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Default selected fields
    final selectedFields = Set<EquipmentPrintField>.from(
      EquipmentPrintField.defaultFields,
    );
    PrintSortOption sortOption = PrintSortOption.none;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.print, color: Colors.purple.shade600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Print Equipment List'),
                      Text(
                        '${filteredEquipment.length} items | ${selectedFields.length} fields selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 450,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick selection buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              selectedFields.addAll(EquipmentPrintField.allFields);
                            });
                          },
                          icon: const Icon(Icons.select_all, size: 18),
                          label: const Text('All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.purple,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              selectedFields.clear();
                              selectedFields.addAll(
                                EquipmentPrintField.defaultFields,
                              );
                            });
                          },
                          icon: const Icon(Icons.restore, size: 18),
                          label: const Text('Default'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.teal,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              selectedFields.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'Sort by:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<PrintSortOption>(
                          initialValue: sortOption,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PrintSortOption.none,
                              child: Text('No Sorting'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetTagNumberAsc,
                              child: Text('Asset Tag Number (Asc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetTagNumberDesc,
                              child: Text('Asset Tag Number (Desc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetTagAsc,
                              child: Text('Asset Tag (Asc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetTagDesc,
                              child: Text('Asset Tag (Desc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetCodeAsc,
                              child: Text('Asset Code (Asc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.assetCodeDesc,
                              child: Text('Asset Code (Desc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.itemStickerTagAsc,
                              child: Text('Item Sticker Tag (Asc)'),
                            ),
                            DropdownMenuItem(
                              value: PrintSortOption.itemStickerTagDesc,
                              child: Text('Item Sticker Tag (Desc)'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => sortOption = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Field groups
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldGroup(
                            'Basic Info',
                            [
                              EquipmentPrintField.assetCode,
                              EquipmentPrintField.itemStickerTag,
                              EquipmentPrintField.name,
                              EquipmentPrintField.description,
                              EquipmentPrintField.category,
                              EquipmentPrintField.brand,
                              EquipmentPrintField.model,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Identification',
                            [
                              EquipmentPrintField.serialNumber,
                              EquipmentPrintField.assetTag,
                              EquipmentPrintField.assetTagQr,
                              EquipmentPrintField.assetTagBarcode,
                              EquipmentPrintField.accountingPeriod,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Location & Assignment',
                            [
                              EquipmentPrintField.location,
                              EquipmentPrintField.assignedTo,
                              EquipmentPrintField.currentHolder,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Status & Condition',
                            [
                              EquipmentPrintField.status,
                              EquipmentPrintField.condition,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Purchase & Value',
                            [
                              EquipmentPrintField.purchaseYear,
                              EquipmentPrintField.purchaseDate,
                              EquipmentPrintField.purchasePrice,
                              EquipmentPrintField.quantity,
                              EquipmentPrintField.unitCost,
                              EquipmentPrintField.supplier,
                              EquipmentPrintField.warrantyExpiry,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Depreciation',
                            [
                              EquipmentPrintField.depreciationPercentage,
                              EquipmentPrintField.assetAge,
                              EquipmentPrintField.monthlyDepreciation,
                              EquipmentPrintField.totalDepreciation,
                              EquipmentPrintField.currentBookValue,
                            ],
                            selectedFields,
                            setDialogState,
                          ),
                          _buildFieldGroup(
                            'Other',
                            [EquipmentPrintField.notes],
                            selectedFields,
                            setDialogState,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: selectedFields.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Print Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && selectedFields.isNotEmpty) {
      final sortedEquipment = _sortEquipmentForPrint(
        filteredEquipment,
        sortOption,
      );
      await _generateAndOpenPdf(
        sortedEquipment,
        selectedFields.toList()..sort((a, b) => a.index.compareTo(b.index)),
      );
    }
  }

  Future<void> _showStickerPrintDialog({bool selectedOnly = false}) async {
    List<Equipment> equipmentToPrint;

    if (selectedOnly && _selectedEquipmentIds.isNotEmpty) {
      // Print only selected equipment
      equipmentToPrint = _equipment
          .where((e) => _selectedEquipmentIds.contains(e.id))
          .toList();
    } else {
      // Print all filtered equipment
      equipmentToPrint = _filterEquipment(_equipment);
    }

    final stickerItems =
        equipmentToPrint.where((e) => e.itemStickerTag != null).toList();

    if (stickerItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No items with sticker tags to print'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Default sticker size: 70x37mm, 8 rows, 3 columns (8×37=296mm fits A4 297mm)
    final widthController = TextEditingController(text: '70');
    final heightController = TextEditingController(text: '37');
    final sheetWidthController = TextEditingController(text: '210');
    final sheetHeightController = TextEditingController(text: '297');
    final rowsController = TextEditingController(text: '8');
    final colsController = TextEditingController(text: '3');
    final marginController = TextEditingController(text: '0');
    final hGapController = TextEditingController(text: '0');
    final vGapController = TextEditingController(text: '0');
    final offsetLeftController = TextEditingController(text: '0');
    final offsetRightController = TextEditingController(text: '0');
    final stickerLeftPaddingController = TextEditingController(text: '0');
    // Start position (1-indexed for user-friendliness)
    final startRowController = TextEditingController(text: '1');
    final startColumnController = TextEditingController(text: '1');

    // Built-in sticker presets
    final builtInPresets = <String, Map<String, dynamic>>{
      'Default (70x37mm, 8x3)': {
        'width': '70',
        'height': '37',
        'rows': '8',
        'cols': '3',
      },
      '70x29.7mm (10x3)': {
        'width': '70',
        'height': '29.7',
        'rows': '10',
        'cols': '3',
      },
      '63.5x38.1mm (7x3)': {
        'width': '63.5',
        'height': '38.1',
        'rows': '7',
        'cols': '3',
      },
      '52.5x29.7mm (10x4)': {
        'width': '52.5',
        'height': '29.7',
        'rows': '10',
        'cols': '4',
      },
      '38.1x21.2mm (13x5)': {
        'width': '38.1',
        'height': '21.2',
        'rows': '13',
        'cols': '5',
      },
      '25.4x10mm (27x7)': {
        'width': '25.4',
        'height': '10',
        'rows': '27',
        'cols': '7',
      },
    };

    // Load saved presets from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedPresetsJson = prefs.getString('sticker_presets') ?? '{}';
    final savedPresets = Map<String, dynamic>.from(jsonDecode(savedPresetsJson));

    // Merge built-in and saved presets
    final stickerPresets = <String, Map<String, dynamic>>{
      ...builtInPresets,
      ...savedPresets.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value))),
      'Custom': {'width': '', 'height': '', 'rows': '', 'cols': ''},
    };
    String selectedPreset = 'Default (70x37mm, 8x3)';

    // Function to save a new preset
    Future<void> savePreset(String name, StateSetter setDialogState) async {
      final newPreset = {
        'width': widthController.text,
        'height': heightController.text,
        'rows': rowsController.text,
        'cols': colsController.text,
      };
      savedPresets[name] = newPreset;
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      stickerPresets[name] = newPreset;
      setDialogState(() {
        selectedPreset = name;
      });
    }

    // Function to delete a saved preset
    Future<void> deletePreset(String name, StateSetter setDialogState) async {
      savedPresets.remove(name);
      stickerPresets.remove(name);
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      setDialogState(() {
        selectedPreset = 'Default (70x37mm, 8x3)';
        final preset = stickerPresets[selectedPreset]!;
        widthController.text = preset['width']!;
        heightController.text = preset['height']!;
        rowsController.text = preset['rows']!;
        colsController.text = preset['cols']!;
      });
    }

    // Function to rename a saved preset
    Future<void> renamePreset(String oldName, String newName, StateSetter setDialogState) async {
      if (oldName == newName || newName.isEmpty) return;
      final presetData = savedPresets[oldName];
      if (presetData == null) return;

      savedPresets.remove(oldName);
      savedPresets[newName] = presetData;
      stickerPresets.remove(oldName);
      stickerPresets[newName] = Map<String, dynamic>.from(presetData);
      await prefs.setString('sticker_presets', jsonEncode(savedPresets));
      setDialogState(() {
        selectedPreset = newName;
      });
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code_2, color: Colors.purple.shade600),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Print Stickers')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preset dropdown
                  const Text(
                    'Sticker Preset',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPreset,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: stickerPresets.keys.map((preset) {
                      return DropdownMenuItem(
                        value: preset,
                        child: Text(preset, style: const TextStyle(fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && value != 'Custom') {
                        final preset = stickerPresets[value]!;
                        setDialogState(() {
                          selectedPreset = value;
                          widthController.text = preset['width']!;
                          heightController.text = preset['height']!;
                          rowsController.text = preset['rows']!;
                          colsController.text = preset['cols']!;
                        });
                      } else {
                        setDialogState(() {
                          selectedPreset = value!;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Save/Delete preset buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final nameController = TextEditingController();
                            final presetName = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Save Preset'),
                                content: TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Preset Name',
                                    hintText: 'e.g., My Custom Label',
                                    border: OutlineInputBorder(),
                                  ),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, nameController.text),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (presetName != null && presetName.trim().isNotEmpty) {
                              await savePreset(presetName.trim(), setDialogState);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Preset "$presetName" saved'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Save Preset'),
                        ),
                      ),
                      if (savedPresets.containsKey(selectedPreset)) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final nameController = TextEditingController(text: selectedPreset);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Rename Preset'),
                                  content: TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'New Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    autofocus: true,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, nameController.text),
                                      child: const Text('Rename'),
                                    ),
                                  ],
                                ),
                              );
                              if (newName != null && newName.trim().isNotEmpty && newName.trim() != selectedPreset) {
                                await renamePreset(selectedPreset, newName.trim(), setDialogState);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Preset renamed to "$newName"'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Rename'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Preset'),
                                  content: Text('Delete "$selectedPreset"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await deletePreset(selectedPreset, setDialogState);
                              }
                            },
                            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sticker Size (mm)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widthController,
                          onChanged: (_) => setDialogState(() {
                            selectedPreset = 'Custom';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Width',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          onChanged: (_) => setDialogState(() {
                            selectedPreset = 'Custom';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'Height',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Sheet Size (mm)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sheetWidthController,
                        decoration: const InputDecoration(
                          labelText: 'Sheet Width',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: sheetHeightController,
                        decoration: const InputDecoration(
                          labelText: 'Sheet Height',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Layout',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rowsController,
                        decoration: const InputDecoration(
                          labelText: 'Rows',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: colsController,
                        decoration: const InputDecoration(
                          labelText: 'Columns',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Margins & Gaps (mm)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: marginController,
                        decoration: const InputDecoration(
                          labelText: 'Margin',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: hGapController,
                        decoration: const InputDecoration(
                          labelText: 'H Gap',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: vGapController,
                        decoration: const InputDecoration(
                          labelText: 'V Gap',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Alignment',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: offsetLeftController,
                        decoration: const InputDecoration(
                          labelText: 'Left Offset (mm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: offsetRightController,
                        decoration: const InputDecoration(
                          labelText: 'Right Offset (mm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sticker Content',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: stickerLeftPaddingController,
                        decoration: const InputDecoration(
                          labelText: 'Sticker Left Padding (mm)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Start Position',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Skip stickers that are already used on the sheet',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startRowController,
                        decoration: const InputDecoration(
                          labelText: 'Start Row',
                          helperText: '1 = first row',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: startColumnController,
                        decoration: const InputDecoration(
                          labelText: 'Start Column',
                          helperText: '1 = first column',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('Print Stickers'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final config = StickerPrintConfig(
      stickerWidthMm: double.tryParse(widthController.text) ?? 70,
      stickerHeightMm: double.tryParse(heightController.text) ?? 37,
      sheetWidthMm: double.tryParse(sheetWidthController.text) ?? 210,
      sheetHeightMm: double.tryParse(sheetHeightController.text) ?? 297,
      rows: int.tryParse(rowsController.text) ?? 8,
      columns: int.tryParse(colsController.text) ?? 3,
      marginMm: double.tryParse(marginController.text) ?? 0,
      horizontalGapMm: double.tryParse(hGapController.text) ?? 0,
      verticalGapMm: double.tryParse(vGapController.text) ?? 0,
      offsetLeftMm: double.tryParse(offsetLeftController.text) ?? 0,
      offsetRightMm: double.tryParse(offsetRightController.text) ?? 0,
      stickerLeftPaddingMm:
          double.tryParse(stickerLeftPaddingController.text) ?? 0,
      startRow: int.tryParse(startRowController.text) ?? 1,
      startColumn: int.tryParse(startColumnController.text) ?? 1,
    );

    await _generateAndOpenStickerPdf(stickerItems, config);
  }

  Future<void> _generateAndOpenStickerPdf(
    List<Equipment> equipment,
    StickerPrintConfig config,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );

      final pdfService = PdfExportService();
      final pdfBytes =
          await pdfService.exportEquipmentStickerSheetBytes(
        equipment,
        config,
      );

      if (mounted) {
        Navigator.pop(context);
        await Printing.layoutPdf(
          onLayout: (format) async => Uint8List.fromList(pdfBytes),
          name: 'Equipment_Sticker_Sheet',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating sticker PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Equipment> _sortEquipmentForPrint(
    List<Equipment> equipment,
    PrintSortOption sortOption,
  ) {
    if (sortOption == PrintSortOption.none) return equipment;

    final sorted = [...equipment];
    if (sortOption == PrintSortOption.assetTagNumberAsc ||
        sortOption == PrintSortOption.assetTagNumberDesc) {
      final isDesc = sortOption == PrintSortOption.assetTagNumberDesc;
      sorted.sort((a, b) {
        final aKey = _assetTagSortKey(a.assetTag);
        final bKey = _assetTagSortKey(b.assetTag);
        return isDesc ? bKey.compareTo(aKey) : aKey.compareTo(bKey);
      });
    } else if (sortOption == PrintSortOption.assetTagAsc ||
        sortOption == PrintSortOption.assetTagDesc) {
      final isDesc = sortOption == PrintSortOption.assetTagDesc;
      sorted.sort((a, b) {
        final aKey = _stringSortKey(a.assetTag);
        final bKey = _stringSortKey(b.assetTag);
        return isDesc ? bKey.compareTo(aKey) : aKey.compareTo(bKey);
      });
    } else if (sortOption == PrintSortOption.assetCodeAsc ||
        sortOption == PrintSortOption.assetCodeDesc) {
      final isDesc = sortOption == PrintSortOption.assetCodeDesc;
      sorted.sort((a, b) {
        final aPrefix = _assetCodePrefixKey(a.assetCode);
        final bPrefix = _assetCodePrefixKey(b.assetCode);
        if (aPrefix != bPrefix) {
          return isDesc
              ? bPrefix.compareTo(aPrefix)
              : aPrefix.compareTo(bPrefix);
        }
        final aNum = _assetCodeNumberKey(a.assetCode);
        final bNum = _assetCodeNumberKey(b.assetCode);
        return isDesc ? bNum.compareTo(aNum) : aNum.compareTo(bNum);
      });
    } else if (sortOption == PrintSortOption.itemStickerTagAsc ||
        sortOption == PrintSortOption.itemStickerTagDesc) {
      final isDesc = sortOption == PrintSortOption.itemStickerTagDesc;
      sorted.sort((a, b) {
        final aKey = _stringSortKey(a.itemStickerTag);
        final bKey = _stringSortKey(b.itemStickerTag);
        return isDesc ? bKey.compareTo(aKey) : aKey.compareTo(bKey);
      });
    }
    return sorted;
  }

  int _assetTagSortKey(String? assetTag) {
    if (assetTag == null || assetTag.trim().isEmpty) return 1 << 30;
    final match = RegExp(r'\d+').firstMatch(assetTag);
    if (match == null) return 1 << 29;
    return int.tryParse(match.group(0)!) ?? (1 << 29);
  }

  int _assetCodeNumberKey(String? assetCode) {
    if (assetCode == null || assetCode.trim().isEmpty) return 1 << 30;
    final match = RegExp(r'\d+').firstMatch(assetCode);
    if (match == null) return 1 << 29;
    return int.tryParse(match.group(0)!) ?? (1 << 29);
  }

  String _assetCodePrefixKey(String? assetCode) {
    if (assetCode == null || assetCode.trim().isEmpty) return '\u{10FFFF}';
    final match = RegExp(r'^[A-Za-z]+').firstMatch(assetCode.trim());
    if (match == null) return '\u{10FFFF}';
    return match.group(0)!.toUpperCase();
  }

  String _stringSortKey(String? value) {
    if (value == null || value.trim().isEmpty) return '\u{10FFFF}';
    return value.trim().toUpperCase();
  }

  Future<void> _importInventory() async {
    final authProvider = context.read<AuthProvider>();
    final canAdd = authProvider.canAddInventory();
    final canEdit = authProvider.canEditInventory();
    if (!canAdd && !canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to import inventory'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: InventoryImportService.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    InventoryImportResult parsed;
    try {
      parsed = await InventoryImportService().parseFile(file);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) Navigator.pop(context);

    if (parsed.rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rows found to import'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final plan = _buildImportPlan(parsed.rows, canAdd: canAdd, canEdit: canEdit);
    await _showImportPreviewDialog(plan, parsed.warnings);
  }

  List<_ImportPlanItem> _buildImportPlan(
    List<InventoryImportRow> rows, {
    required bool canAdd,
    required bool canEdit,
  }) {
    final byAssetCode = <String, Equipment>{};
    final bySerial = <String, Equipment>{};
    final byAssetTag = <String, Equipment>{};
    final byNameBrandModel = <String, Equipment>{};

    String norm(String? value) => (value ?? '').trim().toLowerCase();
    String keyForName(Equipment equipment) {
      return '${norm(equipment.name)}|${norm(equipment.brand)}|${norm(equipment.model)}';
    }

    for (final equipment in _equipment) {
      final assetCode = norm(equipment.assetCode);
      final serial = norm(equipment.serialNumber);
      final assetTag = norm(equipment.assetTag);
      if (assetCode.isNotEmpty) byAssetCode.putIfAbsent(assetCode, () => equipment);
      if (serial.isNotEmpty) bySerial.putIfAbsent(serial, () => equipment);
      if (assetTag.isNotEmpty) byAssetTag.putIfAbsent(assetTag, () => equipment);
      byNameBrandModel.putIfAbsent(keyForName(equipment), () => equipment);
    }

    final plan = <_ImportPlanItem>[];
    for (final row in rows) {
      Equipment? match;
      String? reason;
      final assetCode = norm(row.assetCode);
      final serial = norm(row.serialNumber);
      final assetTag = norm(row.assetTag);
      final nameKey =
          '${norm(row.name)}|${norm(row.brand)}|${norm(row.model)}';

      if (assetCode.isNotEmpty && byAssetCode.containsKey(assetCode)) {
        match = byAssetCode[assetCode];
        reason = 'Matched by assetCode';
      } else if (serial.isNotEmpty && bySerial.containsKey(serial)) {
        match = bySerial[serial];
        reason = 'Matched by serialNumber';
      } else if (assetTag.isNotEmpty && byAssetTag.containsKey(assetTag)) {
        match = byAssetTag[assetTag];
        reason = 'Matched by assetTag';
      } else if (nameKey != '||' && byNameBrandModel.containsKey(nameKey)) {
        match = byNameBrandModel[nameKey];
        reason = 'Matched by name/brand/model';
      }

      ImportAction action = match != null ? ImportAction.update : ImportAction.create;
      if (action == ImportAction.create && !canAdd) {
        action = ImportAction.skip;
      }
      if (action == ImportAction.update && !canEdit) {
        action = ImportAction.skip;
      }
      if (match == null && (row.name == null || row.name!.trim().isEmpty)) {
        action = ImportAction.skip;
        reason = reason ?? 'Missing name for new item';
      }

      plan.add(
        _ImportPlanItem(
          row: row,
          match: match,
          matchReason: reason,
          action: action,
        ),
      );
    }

    return plan;
  }

  Future<void> _showImportPreviewDialog(
    List<_ImportPlanItem> plan,
    List<String> warnings,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final canAdd = authProvider.canAddInventory();
    final canEdit = authProvider.canEditInventory();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final actionable = plan.where((p) => p.action != ImportAction.skip).length;
          return AlertDialog(
            title: const Text('Import Inventory Preview'),
            content: SizedBox(
              width: double.maxFinite,
              height: 520,
              child: Column(
                children: [
                  if (warnings.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: warnings
                            .map(
                              (w) => Row(
                                children: [
                                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(w)),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: plan.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = plan[index];
                        final row = item.row;
                        final displayName = row.name ?? item.match?.name ?? '(Unnamed)';
                        final subtitle = item.matchReason ?? (item.match != null ? 'Matched' : 'New item');

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            'Row ${row.index} • $subtitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: DropdownButton<ImportAction>(
                            value: item.action,
                            onChanged: (value) {
                              if (value == null) return;
                              if (value == ImportAction.create && !canAdd) return;
                              if (value == ImportAction.update && !canEdit) return;
                              setDialogState(() => item.action = value);
                            },
                            items: [
                              DropdownMenuItem(
                                value: ImportAction.create,
                                enabled: canAdd,
                                child: const Text('Create'),
                              ),
                              DropdownMenuItem(
                                value: ImportAction.update,
                                enabled: canEdit && item.match != null,
                                child: const Text('Update'),
                              ),
                              const DropdownMenuItem(
                                value: ImportAction.skip,
                                child: Text('Skip'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: actionable == 0
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _applyImportPlan(plan);
                      },
                icon: const Icon(Icons.upload),
                label: Text('Import $actionable'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyImportPlan(List<_ImportPlanItem> plan) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    int created = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;

    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    for (final item in plan) {
      try {
        if (item.action == ImportAction.skip) {
          skipped++;
          continue;
        }
        if (item.action == ImportAction.create) {
          final equipment = _buildNewEquipment(item.row, userId);
          await _equipmentService.createEquipment(equipment);
          created++;
        } else if (item.action == ImportAction.update) {
          if (item.match == null) {
            failed++;
            continue;
          }
          final equipment = _mergeEquipment(item.match!, item.row);
          await _equipmentService.updateEquipment(equipment);
          updated++;
        }
      } catch (e) {
        failed++;
        debugPrint('Import error for row ${item.row.index}: $e');
      }
    }

    if (mounted) Navigator.pop(context);
    await _loadEquipment(forceRefresh: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import complete: $created created, $updated updated, $skipped skipped${failed > 0 ? ', $failed failed' : ''}.',
          ),
          backgroundColor: failed > 0 ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Equipment _buildNewEquipment(InventoryImportRow row, String? userId) {
    final now = DateTime.now();
    final purchaseDate = parseDate(row.purchaseDate);
    final purchaseYear = parseInt(row.purchaseYear) ?? purchaseDate?.year;
    return Equipment(
      id: '',
      name: row.name ?? row.assetCode ?? 'Unnamed Equipment',
      description: row.description,
      category: row.category ?? 'Other',
      brand: row.brand,
      model: row.model,
      serialNumber: row.serialNumber,
      assetTag: row.assetTag,
      assetCode: row.assetCode,
      accountingPeriod: row.accountingPeriod,
      location: row.location,
      status: parseStatus(row.status) ?? EquipmentStatus.available,
      condition: parseCondition(row.condition) ?? EquipmentCondition.good,
      purchasePrice: parseDouble(row.purchasePrice),
      purchaseDate: purchaseDate,
      purchaseYear: purchaseYear,
      supplier: row.supplier,
      warrantyExpiry: parseDate(row.warrantyExpiry),
      notes: row.notes,
      assignedToId: row.assignedToId,
      assignedToName: row.assignedToName,
      currentHolderId: row.currentHolderId,
      currentHolderName: row.currentHolderName,
      quantity: parseInt(row.quantity) ?? 1,
      unitCost: parseDouble(row.unitCost),
      depreciationPercentage: parseDouble(row.depreciationPercentage),
      monthsDepreciated: parseInt(row.monthsDepreciated),
      createdAt: now,
      updatedAt: now,
      createdBy: userId,
    );
  }

  Equipment _mergeEquipment(Equipment existing, InventoryImportRow row) {
    String? pickString(String? value) =>
        value != null && value.trim().isNotEmpty ? value.trim() : null;

    final purchaseDate = parseDate(row.purchaseDate) ?? existing.purchaseDate;
    final purchaseYear =
        parseInt(row.purchaseYear) ?? purchaseDate?.year ?? existing.purchaseYear;

    return existing.copyWith(
      name: pickString(row.name) ?? existing.name,
      description: pickString(row.description) ?? existing.description,
      category: pickString(row.category) ?? existing.category,
      brand: pickString(row.brand) ?? existing.brand,
      model: pickString(row.model) ?? existing.model,
      serialNumber: pickString(row.serialNumber) ?? existing.serialNumber,
      assetTag: pickString(row.assetTag) ?? existing.assetTag,
      assetCode: pickString(row.assetCode) ?? existing.assetCode,
      accountingPeriod:
          pickString(row.accountingPeriod) ?? existing.accountingPeriod,
      location: pickString(row.location) ?? existing.location,
      status: parseStatus(row.status) ?? existing.status,
      condition: parseCondition(row.condition) ?? existing.condition,
      purchasePrice: parseDouble(row.purchasePrice) ?? existing.purchasePrice,
      purchaseDate: purchaseDate,
      purchaseYear: purchaseYear,
      supplier: pickString(row.supplier) ?? existing.supplier,
      warrantyExpiry: parseDate(row.warrantyExpiry) ?? existing.warrantyExpiry,
      notes: pickString(row.notes) ?? existing.notes,
      assignedToId: pickString(row.assignedToId) ?? existing.assignedToId,
      assignedToName: pickString(row.assignedToName) ?? existing.assignedToName,
      currentHolderId:
          pickString(row.currentHolderId) ?? existing.currentHolderId,
      currentHolderName:
          pickString(row.currentHolderName) ?? existing.currentHolderName,
      quantity: parseInt(row.quantity) ?? existing.quantity,
      unitCost: parseDouble(row.unitCost) ?? existing.unitCost,
      depreciationPercentage: parseDouble(row.depreciationPercentage) ??
          existing.depreciationPercentage,
      monthsDepreciated:
          parseInt(row.monthsDepreciated) ?? existing.monthsDepreciated,
      updatedAt: DateTime.now(),
    );
  }

  Widget _buildFieldGroup(
    String title,
    List<EquipmentPrintField> fields,
    Set<EquipmentPrintField> selectedFields,
    StateSetter setDialogState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setDialogState(() {
                    if (fields.every((f) => selectedFields.contains(f))) {
                      selectedFields.removeAll(fields);
                    } else {
                      selectedFields.addAll(fields);
                    }
                  });
                },
                child: Text(
                  fields.every((f) => selectedFields.contains(f))
                      ? 'Deselect all'
                      : 'Select all',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[400],
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: fields.map((field) {
            final isSelected = selectedFields.contains(field);
            return FilterChip(
              label: Text(
                field.displayName,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setDialogState(() {
                  if (selected) {
                    selectedFields.add(field);
                  } else {
                    selectedFields.remove(field);
                  }
                });
              },
              selectedColor: Colors.purple,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _generateAndOpenPdf(
    List<Equipment> equipment,
    List<EquipmentPrintField> selectedFields,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                'Generating PDF for ${equipment.length} items...',
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final pdfService = PdfExportService();

      // Get PDF bytes directly (works on web)
      final pdfBytes = await pdfService.exportEquipmentListBytes(
        equipment,
        selectedFields,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show print preview with sharing options
        await Printing.layoutPdf(
          onLayout: (format) async => Uint8List.fromList(pdfBytes),
          name: 'Equipment_Inventory_List',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('PDF ready for printing/sharing'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> _getUniqueLocations(List<Equipment> equipment) {
    if (_cachedLocations != null) return _cachedLocations!;

    final locations = equipment
        .map((e) => e.location)
        .where((loc) => loc != null && loc.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    locations.sort();
    _cachedLocations = ['All', ...locations];
    return _cachedLocations!;
  }

  Map<String, int> _getStats(List<Equipment> equipment) {
    if (_cachedStats != null) return _cachedStats!;

    _cachedStats = {
      'total': equipment.length,
      'available': equipment
          .where((e) => e.status == EquipmentStatus.available)
          .length,
      'checkedOut': equipment
          .where((e) => e.status == EquipmentStatus.checkedOut)
          .length,
      'maintenance': equipment
          .where((e) => e.status == EquipmentStatus.maintenance)
          .length,
    };
    return _cachedStats!;
  }

  /// Find duplicate equipment based on serial number, asset tag, or name+brand+model
  Map<String, List<Equipment>> _findDuplicates(List<Equipment> equipment) {
    final duplicates = <String, List<Equipment>>{};

    // Group by serial number (if exists)
    final serialMap = <String, List<Equipment>>{};
    for (final item in equipment) {
      if (item.serialNumber != null && item.serialNumber!.isNotEmpty) {
        final key = item.serialNumber!.toLowerCase().trim();
        serialMap.putIfAbsent(key, () => []).add(item);
      }
    }
    for (final entry in serialMap.entries) {
      if (entry.value.length > 1) {
        duplicates['Serial: ${entry.key}'] = entry.value;
      }
    }

    // Group by asset tag (if exists)
    final assetTagMap = <String, List<Equipment>>{};
    for (final item in equipment) {
      if (item.assetTag != null && item.assetTag!.isNotEmpty) {
        final key = item.assetTag!.toLowerCase().trim();
        assetTagMap.putIfAbsent(key, () => []).add(item);
      }
    }
    for (final entry in assetTagMap.entries) {
      if (entry.value.length > 1) {
        duplicates['Asset Tag: ${entry.key}'] = entry.value;
      }
    }

    // Group by name + brand + model combination
    final nameComboMap = <String, List<Equipment>>{};
    for (final item in equipment) {
      final key =
          '${item.name.toLowerCase().trim()}|${(item.brand ?? '').toLowerCase().trim()}|${(item.model ?? '').toLowerCase().trim()}';
      nameComboMap.putIfAbsent(key, () => []).add(item);
    }
    for (final entry in nameComboMap.entries) {
      if (entry.value.length > 1) {
        final parts = entry.key.split('|');
        final displayKey =
            'Name: ${parts[0]}${parts[1].isNotEmpty ? ', Brand: ${parts[1]}' : ''}${parts[2].isNotEmpty ? ', Model: ${parts[2]}' : ''}';
        duplicates[displayKey] = entry.value;
      }
    }

    return duplicates;
  }

  /// Show duplicates dialog with selection capability
  void _showDuplicatesDialog() {
    var duplicates = _findDuplicates(_equipment);

    if (duplicates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No duplicates found in inventory'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    // Track selected items for deletion (by ID)
    final Set<String> selectedForDeletion = {};
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Recalculate duplicates based on current _equipment
          duplicates = _findDuplicates(_equipment);

          if (duplicates.isEmpty) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  const Text('All Duplicates Removed'),
                ],
              ),
              content: const Text(
                'All duplicate items have been successfully removed.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          }

          // Get all duplicate IDs (excluding first item of each group - the "original")
          final allDuplicateIds = <String>{};
          for (final entry in duplicates.entries) {
            // Skip the first item (original), add rest as duplicates
            for (int i = 1; i < entry.value.length; i++) {
              allDuplicateIds.add(entry.value[i].id);
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duplicates Found (${duplicates.length} groups)'),
                      if (selectedForDeletion.isNotEmpty)
                        Text(
                          '${selectedForDeletion.length} selected for deletion',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[400],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: Column(
                children: [
                  // Select all duplicates button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value:
                              allDuplicateIds.isNotEmpty &&
                              selectedForDeletion.length ==
                                  allDuplicateIds.length,
                          tristate:
                              selectedForDeletion.isNotEmpty &&
                              selectedForDeletion.length <
                                  allDuplicateIds.length,
                          onChanged: (value) {
                            setDialogState(() {
                              if (selectedForDeletion.length ==
                                  allDuplicateIds.length) {
                                selectedForDeletion.clear();
                              } else {
                                selectedForDeletion.addAll(allDuplicateIds);
                              }
                            });
                          },
                          activeColor: Colors.red,
                        ),
                        Expanded(
                          child: Text(
                            'Select all duplicates (keeps first item as original)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: duplicates.length,
                      itemBuilder: (context, index) {
                        final entry = duplicates.entries.elementAt(index);
                        return ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Text(
                              '${entry.value.length}',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          children: entry.value.asMap().entries.map((
                            itemEntry,
                          ) {
                            final itemIndex = itemEntry.key;
                            final item = itemEntry.value;
                            final isOriginal = itemIndex == 0;
                            final isSelected = selectedForDeletion.contains(
                              item.id,
                            );

                            return ListTile(
                              dense: true,
                              leading: isOriginal
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'KEEP',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    )
                                  : Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        setDialogState(() {
                                          if (isSelected) {
                                            selectedForDeletion.remove(item.id);
                                          } else {
                                            selectedForDeletion.add(item.id);
                                          }
                                        });
                                      },
                                      activeColor: Colors.red,
                                    ),
                              title: Text(
                                item.name,
                                style: TextStyle(
                                  decoration: isSelected
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isSelected ? Colors.grey : null,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${item.id.substring(0, 8)}... | ${item.status.displayName}${isOriginal ? ' (Original)' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOriginal
                                      ? Colors.green[700]
                                      : Colors.grey[600],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new, size: 18),
                                tooltip: 'View Details',
                                onPressed: () {
                                  Navigator.pop(context);
                                  this.context.push('/inventory/${item.id}');
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (selectedForDeletion.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Selected Duplicates?'),
                              content: Text(
                                'Are you sure you want to delete ${selectedForDeletion.length} duplicate item(s)?\n\nThe original items will be kept. This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Delete All Selected'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            setDialogState(() => isDeleting = true);

                            int deleted = 0;
                            int failed = 0;
                            final idsToDelete = selectedForDeletion.toList();

                            for (final id in idsToDelete) {
                              try {
                                await _equipmentService.deleteEquipment(id);
                                deleted++;
                                // Update local state
                                setState(() {
                                  _equipment.removeWhere((e) => e.id == id);
                                  _invalidateCache();
                                });
                                selectedForDeletion.remove(id);
                              } catch (e) {
                                failed++;
                                debugPrint('Error deleting $id: $e');
                              }
                            }

                            setDialogState(() => isDeleting = false);

                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Deleted $deleted item(s)${failed > 0 ? ', $failed failed' : ''}',
                                  ),
                                  backgroundColor: failed > 0
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              );
                            }
                          }
                        },
                  icon: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.delete, size: 18),
                  label: Text(
                    isDeleting
                        ? 'Deleting...'
                        : 'Delete ${selectedForDeletion.length} Selected',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Equipment> _filterEquipment(List<Equipment> equipment) {
    // Check if we can use cached result
    final filterKey = _getFilterKey();
    if (_cachedFilteredEquipment != null && _lastFilterKey == filterKey) {
      return _cachedFilteredEquipment!;
    }

    final result = equipment.where((item) {
      if (_selectedCategory != 'All' && item.category != _selectedCategory) {
        return false;
      }
      if (_selectedStatus != 'All') {
        final status = EquipmentStatus.values.firstWhere(
          (s) => s.displayName == _selectedStatus,
          orElse: () => EquipmentStatus.available,
        );
        if (item.status != status) return false;
      }
      if (_selectedCondition != 'All') {
        final condition = EquipmentCondition.values.firstWhere(
          (c) => c.displayName == _selectedCondition,
          orElse: () => EquipmentCondition.good,
        );
        if (item.condition != condition) return false;
      }
      if (_selectedLocation != 'All' && item.location != _selectedLocation) {
        return false;
      }
      // Filter for print-ready items (has sticker tag, location, and purchase year)
      if (_showPrintReady) {
        final hasTag = item.itemStickerTag != null || item.assetTag != null;
        final hasLocation = item.location != null && item.location!.isNotEmpty;
        final hasPurchaseYear = item.purchaseYear != null;
        if (!hasTag || !hasLocation || !hasPurchaseYear) {
          return false;
        }
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return item.name.toLowerCase().contains(query) ||
            (item.brand?.toLowerCase().contains(query) ?? false) ||
            (item.model?.toLowerCase().contains(query) ?? false) ||
            (item.serialNumber?.toLowerCase().contains(query) ?? false) ||
            (item.assetTag?.toLowerCase().contains(query) ?? false) ||
            (item.currentHolderName?.toLowerCase().contains(query) ?? false);
      }
      return true;
    }).toList();

    // Cache the result
    _cachedFilteredEquipment = result;
    _lastFilterKey = filterKey;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Check if user has view permission
    if (!authProvider.canViewInventory()) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Access Denied',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You do not have permission to view the inventory.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact an administrator to request access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin-hub'),
                    icon: const Icon(Icons.home),
                    label: const Text('Back to Dashboard'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshEquipment,
          child: ResponsiveBuilder(
            mobile: _buildMobileLayout(),
            tablet: _buildTabletLayout(),
            desktop: _buildDesktopLayout(),
          ),
        ),
      ),
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/inventory/scan'),
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan'),
            )
          : null,
    );
  }

  // ==================== MOBILE LAYOUT ====================
  Widget _buildMobileLayout() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    final filteredEquipment = _filterEquipment(_equipment);
    final spacing = ResponsiveHelper.getSpacing(context);

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Welcome Header
            _buildWelcomeHeader(),
            SizedBox(height: spacing),

            // Stats Cards
            _buildStatsSection(_equipment),
            SizedBox(height: spacing),

            // View Type Selector (Mobile only)
            _buildMobileViewSelector(),
            SizedBox(height: spacing),

            // Filters Section
            DashboardSection(
              title: 'Filters',
              icon: Icons.filter_list,
              iconColor: Colors.purple,
              initiallyExpanded: _showFilters,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _buildFiltersContent(),
              ),
            ),
            SizedBox(height: spacing),

            // Equipment Content
            if (_equipment.isEmpty)
              _buildEmptyState()
            else if (filteredEquipment.isEmpty)
              _buildNoResultsState()
            else
              _buildEquipmentContent(filteredEquipment),
          ],
        ),
      ),
    );
  }

  // ==================== TABLET LAYOUT ====================
  Widget _buildTabletLayout() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    final filteredEquipment = _filterEquipment(_equipment);
    final spacing = ResponsiveHelper.getSpacing(context);

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Welcome Header
            _buildWelcomeHeader(),
            SizedBox(height: spacing),

            // Stats Cards
            _buildStatsSection(_equipment),
            SizedBox(height: spacing),

            // Filters Section
            DashboardSection(
              title: 'Search & Filters',
              icon: Icons.filter_list,
              iconColor: Colors.purple,
              initiallyExpanded: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildFiltersContent(),
              ),
            ),
            SizedBox(height: spacing),

            // Equipment Section
            DashboardSection(
              title: 'Equipment List',
              icon: Icons.inventory_2,
              iconColor: Colors.blue,
              showBadge: true,
              badgeCount: filteredEquipment.length,
              initiallyExpanded: true,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _equipment.isEmpty
                    ? _buildEmptyState()
                    : filteredEquipment.isEmpty
                    ? _buildNoResultsState()
                    : _buildEquipmentContent(filteredEquipment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DESKTOP LAYOUT ====================
  Widget _buildDesktopLayout() {
    if (_isLoading) return _buildLoadingState();
    if (_errorMessage != null) return _buildErrorState();

    final filteredEquipment = _filterEquipment(_equipment);
    final spacing = ResponsiveHelper.getSpacing(context);

    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            _buildWelcomeHeader(),
            SizedBox(height: spacing),

            // Stats Cards Row
            _buildStatsSection(_equipment),
            SizedBox(height: spacing),

            // Filters Section (Desktop - always visible, horizontal)
            DashboardSection(
              title: 'Search & Filters',
              icon: Icons.filter_list,
              iconColor: Colors.purple,
              initiallyExpanded: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _buildDesktopFiltersContent(),
              ),
            ),
            SizedBox(height: spacing),

            // Equipment Section
            DashboardSection(
              title: 'Equipment Inventory',
              icon: Icons.inventory_2,
              iconColor: Colors.blue,
              showBadge: true,
              badgeCount: filteredEquipment.length,
              initiallyExpanded: true,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _equipment.isEmpty
                    ? _buildEmptyState()
                    : filteredEquipment.isEmpty
                    ? _buildNoResultsState()
                    : _buildEquipmentContent(filteredEquipment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final authProvider = context.read<AuthProvider>();
    final userName = authProvider.currentUser?.name ?? 'User';
    final organizationName = authProvider.currentUser?.organizationName;
    final canAdd = authProvider.canAddInventory();
    final stats = _getStats(_equipment);
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade400,
            Colors.purple.shade600,
            Colors.purple.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade300,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              children: [
                // Top action bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back/Home button
                    _buildHeaderActionButton(
                      icon: Icons.arrow_back,
                      tooltip: 'Back to Inventory Hub',
                      onPressed: () => context.go('/inventory-dashboard'),
                    ),
                    // Action buttons
                    Row(
                      children: [
                        if (!isMobile) ...[
                          // View toggles
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeaderViewToggle(
                                  ViewType.card,
                                  Icons.grid_view_rounded,
                                  'Cards',
                                ),
                                _buildHeaderViewToggle(
                                  ViewType.table,
                                  Icons.table_chart_rounded,
                                  'Table',
                                ),
                                _buildHeaderViewToggle(
                                  ViewType.list,
                                  Icons.view_list_rounded,
                                  'List',
                                ),
                              ],
                            ),
                          ),
                        ],
                        // QR/Barcode scan button - prominent on mobile
                        if (isMobile)
                          _buildScanButton(),
                        _buildHeaderActionButton(
                          icon: Icons.refresh,
                          tooltip: 'Refresh',
                          onPressed: _refreshEquipment,
                        ),
                        if (!isMobile) ...[
                          _buildHeaderActionButton(
                            icon: Icons.find_replace,
                            tooltip: 'Check Duplicates',
                            onPressed: _showDuplicatesDialog,
                          ),
                          _buildHeaderActionButton(
                            icon: Icons.print,
                            tooltip: 'Print Equipment List',
                            onPressed: _showPrintDialog,
                          ),
                          _buildHeaderActionButton(
                            icon: Icons.qr_code_2,
                            tooltip: 'Print Stickers',
                            onPressed: _showStickerPrintDialog,
                          ),
                          _buildHeaderActionButton(
                            icon: Icons.upload_file,
                            tooltip: 'Import Inventory (CSV/XLSX)',
                            onPressed: _importInventory,
                          ),
                        ],
                        if (canAdd)
                          _buildHeaderActionButton(
                            icon: Icons.add_circle_outline,
                            tooltip: 'Add Equipment',
                            onPressed: () => context.push('/inventory/add'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Content row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Equipment Inventory',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(1, 1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            organizationName != null
                                ? '$organizationName Inventory'
                                : 'All Organizations - Equipment Tracking',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: isMobile ? 12 : 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _buildBannerStat('${stats['total']}', 'Items'),
                              _buildBannerStat(
                                '${stats['checkedOut']}',
                                'Checked Out',
                              ),
                              _buildBannerStat(
                                '${stats['available']}',
                                'Available',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: Colors.white,
                        size: isMobile ? 36 : 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Tooltip(
      message: 'Scan QR/Barcode',
      child: InkWell(
        onTap: () => context.push('/inventory/scan'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.purple.shade600, size: 18),
              const SizedBox(width: 4),
              Text(
                'Scan',
                style: TextStyle(
                  color: Colors.purple.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderViewToggle(ViewType type, IconData icon, String tooltip) {
    final isSelected = _viewType == type;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewType = type),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? Colors.purple.shade600
                : Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileViewSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.view_module, color: Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Text(
            'View:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                _buildMobileViewButton(
                  ViewType.card,
                  Icons.grid_view_rounded,
                  'Cards',
                ),
                const SizedBox(width: 8),
                _buildMobileViewButton(
                  ViewType.table,
                  Icons.table_chart_rounded,
                  'Table',
                ),
                const SizedBox(width: 8),
                _buildMobileViewButton(
                  ViewType.list,
                  Icons.view_list_rounded,
                  'List',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileViewButton(ViewType type, IconData icon, String label) {
    final isSelected = _viewType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _viewType = type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.purple : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading equipment...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading equipment',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshEquipment,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(List<Equipment> equipment) {
    final stats = _getStats(equipment);
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    final statCards = [
      _StatCardData(
        title: 'Total Equipment',
        value: stats['total'].toString(),
        icon: Icons.inventory_2,
        gradient: [Colors.purple, Colors.purple.shade700],
      ),
      _StatCardData(
        title: 'Available',
        value: stats['available'].toString(),
        icon: Icons.check_circle,
        gradient: [Colors.green, Colors.green.shade700],
      ),
      _StatCardData(
        title: 'Checked Out',
        value: stats['checkedOut'].toString(),
        icon: Icons.output,
        gradient: [Colors.orange, Colors.orange.shade700],
      ),
      _StatCardData(
        title: 'Maintenance',
        value: stats['maintenance'].toString(),
        icon: Icons.build,
        gradient: [Colors.red, Colors.red.shade700],
      ),
    ];

    if (isMobile) {
      // Mobile: 2x2 grid
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: statCards.map((stat) => _buildStatCard(stat)).toList(),
      );
    } else if (isTablet) {
      // Tablet: 4 columns
      return GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: statCards.map((stat) => _buildStatCard(stat)).toList(),
      );
    } else {
      // Desktop: horizontal row
      return Row(
        children: statCards
            .map(
              (stat) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildStatCard(stat),
                ),
              ),
            )
            .toList(),
      );
    }
  }

  Widget _buildStatCard(_StatCardData stat) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: stat.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: stat.gradient.last.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
              ResponsiveHelper.isMobile(context) ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              stat.icon,
              color: Colors.white,
              size: ResponsiveHelper.isMobile(context) ? 20 : 24,
            ),
          ),
          SizedBox(width: ResponsiveHelper.isMobile(context) ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stat.value,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  stat.title,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 11 : 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersContent() {
    final locations = _getUniqueLocations(_equipment);
    final hasActiveFilters =
        _selectedCategory != 'All' ||
        _selectedStatus != 'All' ||
        _selectedCondition != 'All' ||
        _selectedLocation != 'All' ||
        _searchQuery.isNotEmpty ||
        _showPrintReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name, brand, serial, asset tag...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 16),

        // Filter Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterDropdown(
              label: 'Category',
              value: _selectedCategory,
              items: ['All', ...EquipmentCategories.categories],
              icon: Icons.category,
              onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
            ),
            _buildFilterDropdown(
              label: 'Status',
              value: _selectedStatus,
              items: [
                'All',
                ...EquipmentStatus.values.map((s) => s.displayName),
              ],
              icon: Icons.info_outline,
              onChanged: (v) => setState(() => _selectedStatus = v ?? 'All'),
            ),
            _buildFilterDropdown(
              label: 'Condition',
              value: _selectedCondition,
              items: [
                'All',
                ...EquipmentCondition.values.map((c) => c.displayName),
              ],
              icon: Icons.star_outline,
              onChanged: (v) => setState(() => _selectedCondition = v ?? 'All'),
            ),
            _buildFilterDropdown(
              label: 'Location',
              value: _selectedLocation,
              items: locations,
              icon: Icons.location_on_outlined,
              onChanged: (v) => setState(() => _selectedLocation = v ?? 'All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Print-ready filter checkbox
        InkWell(
          onTap: () => setState(() => _showPrintReady = !_showPrintReady),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _showPrintReady ? Colors.purple.shade50 : Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showPrintReady ? Colors.purple : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showPrintReady ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: _showPrintReady ? Colors.purple : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Print Ready Only',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _showPrintReady ? FontWeight.w600 : FontWeight.normal,
                    color: _showPrintReady ? Colors.purple.shade700 : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Show only items with:\n• Asset Tag or Sticker Tag\n• Location\n• Purchase Year',
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (hasActiveFilters) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear All Filters'),
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopFiltersContent() {
    final locations = _getUniqueLocations(_equipment);
    final hasActiveFilters =
        _selectedCategory != 'All' ||
        _selectedStatus != 'All' ||
        _selectedCondition != 'All' ||
        _selectedLocation != 'All' ||
        _searchQuery.isNotEmpty ||
        _showPrintReady;

    return Column(
      children: [
        // Search Field - Full width
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText:
                'Search by name, brand, model, serial, asset tag, or holder...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 12),

        // Filter Dropdowns - Scrollable row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterDropdown(
                label: 'Category',
                value: _selectedCategory,
                items: ['All', ...EquipmentCategories.categories],
                icon: Icons.category,
                onChanged: (v) =>
                    setState(() => _selectedCategory = v ?? 'All'),
              ),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                label: 'Status',
                value: _selectedStatus,
                items: [
                  'All',
                  ...EquipmentStatus.values.map((s) => s.displayName),
                ],
                icon: Icons.info_outline,
                onChanged: (v) => setState(() => _selectedStatus = v ?? 'All'),
              ),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                label: 'Condition',
                value: _selectedCondition,
                items: [
                  'All',
                  ...EquipmentCondition.values.map((c) => c.displayName),
                ],
                icon: Icons.star_outline,
                onChanged: (v) =>
                    setState(() => _selectedCondition = v ?? 'All'),
              ),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                label: 'Location',
                value: _selectedLocation,
                items: locations,
                icon: Icons.location_on_outlined,
                onChanged: (v) =>
                    setState(() => _selectedLocation = v ?? 'All'),
              ),
              const SizedBox(width: 12),
              // Print-ready filter checkbox
              InkWell(
                onTap: () => setState(() => _showPrintReady = !_showPrintReady),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _showPrintReady ? Colors.purple.shade50 : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _showPrintReady ? Colors.purple : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showPrintReady ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 20,
                        color: _showPrintReady ? Colors.purple : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Print Ready',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _showPrintReady ? FontWeight.w600 : FontWeight.normal,
                          color: _showPrintReady ? Colors.purple.shade700 : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Show only items with:\n• Asset Tag or Sticker Tag\n• Location\n• Purchase Year',
                        child: Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final isActive = value != 'All';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.purple.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.purple : Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: isActive ? Colors.purple : Colors.grey[600],
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isActive ? Colors.purple : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item == 'All' ? '$label: All' : item,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? Colors.purple : Colors.grey[700],
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedStatus = 'All';
      _selectedCondition = 'All';
      _selectedLocation = 'All';
      _searchController.clear();
      _searchQuery = '';
      _showPrintReady = false;
    });
  }

  Widget _buildEquipmentContent(List<Equipment> equipment) {
    switch (_viewType) {
      case ViewType.card:
        return _buildCardGridView(equipment);
      case ViewType.table:
        return _buildTableView(equipment);
      case ViewType.list:
        return _buildListView(equipment);
    }
  }

  Widget _buildCardGridView(List<Equipment> equipment) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final crossAxisCount = ResponsiveHelper.isDesktop(context)
        ? 4
        : (ResponsiveHelper.isTablet(context) ? 3 : 2);
    // Use smaller aspect ratio on mobile for taller cards to fit QR codes
    final aspectRatio = isMobile ? 0.62 : 0.75;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: aspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: equipment.length,
      itemBuilder: (context, index) => _buildEquipmentCard(equipment[index]),
    );
  }

  Widget _buildListView(List<Equipment> equipment) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: equipment.length,
      itemBuilder: (context, index) =>
          _buildEquipmentListItem(equipment[index]),
    );
  }

  Widget _buildTableView(List<Equipment> equipment) {
    final bool allSelected =
        equipment.isNotEmpty &&
        equipment.every((e) => _selectedEquipmentIds.contains(e.id));
    final bool someSelected = _selectedEquipmentIds.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Selection action bar
        if (someSelected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedEquipmentIds.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const Spacer(),
                // Action buttons
                ElevatedButton.icon(
                  onPressed: () => _showStickerPrintDialog(
                    selectedOnly: true,
                  ),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Print Stickers'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _deleteSelectedEquipment,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(someSelected ? 0 : 12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(someSelected ? 0 : 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.purple.shade50),
                dataRowMinHeight: 60,
                dataRowMaxHeight: 70,
                columnSpacing: 24,
                horizontalMargin: 20,
                showCheckboxColumn: true,
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: allSelected,
                      tristate: someSelected && !allSelected,
                      onChanged: (value) {
                        if (allSelected) {
                          _clearSelection();
                        } else {
                          _selectAll(equipment);
                        }
                      },
                      activeColor: Colors.purple,
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Condition',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Location',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Holder',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Asset Tag',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const DataColumn(
                    label: Text(
                      'Serial #',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                rows: equipment.map((item) {
                  final statusColor = _getStatusColor(item.status);
                  final conditionColor = _getConditionColor(item.condition);
                  final isSelected = _selectedEquipmentIds.contains(item.id);

                  return DataRow(
                    selected: isSelected,
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.purple.withValues(alpha: 0.08);
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(item.id),
                          activeColor: Colors.purple,
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => context.push('/inventory/${item.id}'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(
                                    item.category,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(item.category),
                                  size: 18,
                                  color: _getCategoryColor(item.category),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.brand != null)
                                    Text(
                                      item.brand!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(item.category)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.status.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: conditionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.condition.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: conditionColor,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(item.location ?? '-')),
                      DataCell(
                        item.currentHolderName != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.currentHolderName!,
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                ],
                              )
                            : const Text('-'),
                      ),
                      DataCell(Text(item.assetTag ?? '-')),
                      DataCell(Text(item.serialNumber ?? '-')),
                    ],
                    onSelectChanged: (selected) {
                      _toggleSelection(item.id);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    final statusColor = _getStatusColor(equipment.status);
    final conditionColor = _getConditionColor(equipment.condition);
    final stickerTag = equipment.itemStickerTag?.trim();
    final assetTag = equipment.assetTag?.trim();
    final qrData = stickerTag ?? assetTag;
    final hasQrData = qrData != null && qrData.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/inventory/${equipment.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(equipment.category),
                          _getCategoryColor(
                            equipment.category,
                          ).withValues(alpha: 0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(equipment.category),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      equipment.status.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                equipment.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (equipment.brand != null)
                Text(
                  equipment.brand!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (stickerTag != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.label, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stickerTag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (hasQrData) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      QrImageView(
                        data: qrData,
                        size: 56,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Organization Name
                            if (equipment.organizationName != null &&
                                equipment.organizationName!.isNotEmpty)
                              Text(
                                equipment.organizationName!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const SizedBox(height: 2),
                            // Item Sticker Tag
                            Text(
                              qrData,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Barcode
                            BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: qrData,
                              height: 32,
                              drawText: false,
                              color: Colors.black87,
                            ),
                            const SizedBox(height: 2),
                            // Item Name
                            Text(
                              equipment.name,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: conditionColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      equipment.condition.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: conditionColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (equipment.location != null)
                    Expanded(
                      child: Text(
                        equipment.location!,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (equipment.isCheckedOut &&
                  equipment.currentHolderName != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          equipment.currentHolderName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentListItem(Equipment equipment) {
    final statusColor = _getStatusColor(equipment.status);
    final conditionColor = _getConditionColor(equipment.condition);
    final stickerTag = equipment.itemStickerTag;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getCategoryColor(equipment.category),
                _getCategoryColor(equipment.category).withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(equipment.category),
            color: Colors.white,
          ),
        ),
        title: Text(
          equipment.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(
                  child: Text(
                    equipment.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (equipment.location != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[400])),
                  Flexible(
                    child: Text(
                      equipment.location!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (stickerTag != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.label, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      stickerTag,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (equipment.isCheckedOut && equipment.currentHolderName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        equipment.currentHolderName!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                equipment.status.displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: conditionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                equipment.condition.displayName,
                style: TextStyle(fontSize: 10, color: conditionColor),
              ),
            ),
          ],
        ),
        onTap: () => context.push('/inventory/${equipment.id}'),
      ),
    );
  }

  Widget _buildEmptyState() {
    final canAdd = context.read<AuthProvider>().canAddInventory();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.purple[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Equipment in Inventory',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canAdd
                ? 'Add your first equipment to get started'
                : 'No equipment has been added yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          if (canAdd) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/inventory/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No equipment matches your filters',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedCategory = 'All';
                _selectedStatus = 'All';
                _selectedCondition = 'All';
                _selectedLocation = 'All';
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.available:
        return Colors.green;
      case EquipmentStatus.checkedOut:
        return Colors.orange;
      case EquipmentStatus.maintenance:
        return Colors.red;
      case EquipmentStatus.retired:
        return Colors.grey;
    }
  }

  Color _getConditionColor(EquipmentCondition condition) {
    switch (condition) {
      case EquipmentCondition.excellent:
        return Colors.green;
      case EquipmentCondition.good:
        return Colors.blue;
      case EquipmentCondition.fair:
        return Colors.orange;
      case EquipmentCondition.poor:
        return Colors.red;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Colors.blue;
      case 'lens':
        return Colors.purple;
      case 'audio':
        return Colors.pink;
      case 'lighting':
        return Colors.amber.shade700;
      case 'tripod & support':
        return Colors.brown;
      case 'computer':
        return Colors.indigo;
      case 'monitor & display':
        return Colors.cyan.shade700;
      case 'storage & media':
        return Colors.teal;
      case 'cables & accessories':
        return Colors.blueGrey;
      case 'grip equipment':
        return Colors.deepOrange;
      case 'power & battery':
        return Colors.green.shade700;
      case 'teleprompter':
        return Colors.deepPurple;
      case 'streaming equipment':
        return Colors.red;
      case 'furniture':
        return Colors.brown.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'camera':
        return Icons.camera_alt;
      case 'lens':
        return Icons.camera;
      case 'audio':
        return Icons.mic;
      case 'lighting':
        return Icons.light_mode;
      case 'tripod & support':
        return Icons.control_camera;
      case 'computer':
        return Icons.computer;
      case 'monitor & display':
        return Icons.monitor;
      case 'storage & media':
        return Icons.sd_card;
      case 'cables & accessories':
        return Icons.cable;
      case 'grip equipment':
        return Icons.handyman;
      case 'power & battery':
        return Icons.battery_charging_full;
      case 'teleprompter':
        return Icons.auto_stories;
      case 'streaming equipment':
        return Icons.live_tv;
      case 'furniture':
        return Icons.chair;
      default:
        return Icons.inventory_2;
    }
  }
}

// Data class for stat cards
class _StatCardData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  _StatCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}
