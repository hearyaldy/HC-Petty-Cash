import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/equipment.dart';
import '../../services/equipment_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/dashboard_section.dart';
import '../../utils/responsive_helper.dart';

enum ViewType { card, table, list }

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
  ViewType _viewType = ViewType.card;
  bool _isLoading = true;
  List<Equipment> _equipment = [];
  String? _errorMessage;
  bool _showFilters = true;

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
      final snapshot = await _equipmentService.getAllEquipmentOnce(
        forceRefresh: forceRefresh,
      );
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
    if (!authProvider.canManageUsers()) {
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
    return '$_selectedCategory|$_selectedStatus|$_selectedCondition|$_selectedLocation|$_searchQuery';
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
    final isAdmin = authProvider.canManageUsers();
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildResponsiveAppBar(context, isAdmin),
      drawer: isDesktop ? null : const AppDrawer(),
      body: Row(
        children: [
          if (isDesktop) const AppDrawer(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshEquipment,
              child: ResponsiveBuilder(
                mobile: _buildMobileLayout(),
                tablet: _buildTabletLayout(),
                desktop: _buildDesktopLayout(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/inventory/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildResponsiveAppBar(
    BuildContext context,
    bool isAdmin,
  ) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return AppBar(
      elevation: ResponsiveHelper.isDesktop(context) ? 1 : 0,
      title: Text(
        'Equipment Inventory',
        style: ResponsiveHelper.getResponsiveTextTheme(
          context,
        ).titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.grey[800],
      surfaceTintColor: Colors.white,
      actions: [
        if (!isMobile) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewToggle(
                  ViewType.card,
                  Icons.grid_view_rounded,
                  'Cards',
                ),
                _buildViewToggle(
                  ViewType.table,
                  Icons.table_chart_rounded,
                  'Table',
                ),
                _buildViewToggle(
                  ViewType.list,
                  Icons.view_list_rounded,
                  'List',
                ),
              ],
            ),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshEquipment,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.find_replace),
          onPressed: _showDuplicatesDialog,
          tooltip: 'Check Duplicates',
        ),
        if (isAdmin && !isMobile)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/inventory/add'),
            tooltip: 'Add Equipment',
          ),
        IconButton(
          icon: const Icon(Icons.home_outlined),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'Dashboard',
        ),
      ],
    );
  }

  Widget _buildViewToggle(ViewType type, IconData icon, String tooltip) {
    final isSelected = _viewType == type;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _viewType = type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
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
              iconColor: Colors.indigo,
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
              iconColor: Colors.indigo,
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
              iconColor: Colors.indigo,
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
    final stats = _getStats(_equipment);

    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.isMobile(context) ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipment Inventory',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 14 : 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats['total']} Total Items',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Managed by $userName',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.isMobile(context) ? 12 : 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(
              ResponsiveHelper.isMobile(context) ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2,
              size: ResponsiveHelper.isMobile(context) ? 36 : 48,
              color: Colors.white,
            ),
          ),
        ],
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
            color: Colors.black.withOpacity(0.05),
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
            color: isSelected ? Colors.indigo : Colors.grey[100],
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
              color: Colors.indigo.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
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
                color: Colors.red.withOpacity(0.1),
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
                backgroundColor: Colors.indigo,
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
        gradient: [Colors.indigo, Colors.indigo.shade700],
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
            color: stat.gradient.last.withOpacity(0.3),
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
              color: Colors.white.withOpacity(0.2),
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
                    color: Colors.white.withOpacity(0.9),
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
        _searchQuery.isNotEmpty;

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
        _searchQuery.isNotEmpty;

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
        color: isActive ? Colors.indigo.withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.indigo : Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: isActive ? Colors.indigo : Colors.grey[600],
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
                    color: isActive ? Colors.indigo : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item == 'All' ? '$label: All' : item,
                    style: TextStyle(
                      fontSize: 13,
                      color: isActive ? Colors.indigo : Colors.grey[700],
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
    final crossAxisCount = ResponsiveHelper.isDesktop(context)
        ? 4
        : (ResponsiveHelper.isTablet(context) ? 3 : 2);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.85,
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
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
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
                headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
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
                      activeColor: Colors.indigo,
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
                        return Colors.indigo.withOpacity(0.08);
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleSelection(item.id),
                          activeColor: Colors.indigo,
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
                                  ).withOpacity(0.1),
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
                            color: statusColor.withOpacity(0.1),
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
                            color: conditionColor.withOpacity(0.1),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                          ).withOpacity(0.7),
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
                      color: statusColor.withOpacity(0.1),
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
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: conditionColor.withOpacity(0.1),
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
                    color: Colors.orange.withOpacity(0.1),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                _getCategoryColor(equipment.category).withOpacity(0.7),
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
                Text(
                  equipment.category,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (equipment.location != null) ...[
                  Text(' • ', style: TextStyle(color: Colors.grey[400])),
                  Expanded(
                    child: Text(
                      equipment.location!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (equipment.isCheckedOut && equipment.currentHolderName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      equipment.currentHolderName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
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
                color: statusColor.withOpacity(0.1),
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
                color: conditionColor.withOpacity(0.1),
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
    final isAdmin = context.read<AuthProvider>().canManageUsers();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.indigo[300],
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
            'Add your first equipment to get started',
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/inventory/add'),
              icon: const Icon(Icons.add),
              label: const Text('Add Equipment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
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
