import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/equipment.dart';
import '../../providers/auth_provider.dart';
import '../../services/equipment_service.dart';

/// Opens the Location Abbreviations reference as a modal bottom sheet —
/// matches the rounded-top-sheet pattern used elsewhere in this module
/// (e.g. add_edit_equipment_screen.dart's image-source picker) instead of
/// pushing a full page with a plain AppBar.
Future<void> showLocationAbbreviationsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _LocationAbbreviationsSheet(),
  );
}

/// Read-only reference (plus a rename action) for the sticker-tag
/// abbreviation each distinct Location value currently in use would
/// produce. There is no settings page for this — the abbreviation is
/// derived algorithmically by Equipment.abbreviateLocation (first 3
/// letters of the first word, plus a trailing number if the location
/// string has one), so this sheet exists to let staff check what code a
/// location maps to, and to fix a typo/inconsistent spelling across every
/// item sharing it, without opening each equipment item individually.
class _LocationAbbreviationsSheet extends StatefulWidget {
  const _LocationAbbreviationsSheet();

  @override
  State<_LocationAbbreviationsSheet> createState() =>
      _LocationAbbreviationsSheetState();
}

class _LocationAbbreviationsSheetState
    extends State<_LocationAbbreviationsSheet> {
  final EquipmentService _equipmentService = EquipmentService();
  bool _isLoading = true;
  bool _isRenaming = false;
  String? _errorMessage;
  List<_LocationAbbreviation> _rows = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      final isAdmin = user?.role == 'admin';
      final organizationId = user?.organizationId;

      final equipment = (isAdmin || organizationId == null)
          ? await _equipmentService.getAllEquipmentOnce()
          : await _equipmentService.getEquipmentByOrganizationOnce(
              organizationId,
            );

      final counts = <String, int>{};
      for (final item in equipment) {
        final loc = item.location?.trim();
        if (loc == null || loc.isEmpty) continue;
        counts[loc] = (counts[loc] ?? 0) + 1;
      }

      final rows =
          counts.entries
              .map(
                (e) => _LocationAbbreviation(
                  location: e.key,
                  abbreviation: Equipment.abbreviateLocation(e.key),
                  itemCount: e.value,
                ),
              )
              .toList()
            ..sort(
              (a, b) =>
                  a.location.toLowerCase().compareTo(b.location.toLowerCase()),
            );

      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyAbbreviation(String abbreviation) {
    Clipboard.setData(ClipboardData(text: abbreviation));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied "$abbreviation"')),
    );
  }

  Future<void> _editLocation(_LocationAbbreviation row) async {
    final controller = TextEditingController(text: row.location);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Renames this location on all ${row.itemCount} item${row.itemCount == 1 ? '' : 's'} currently using it.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == row.location) return;

    setState(() => _isRenaming = true);
    try {
      final count = await _equipmentService.renameLocation(
        row.location,
        newName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Renamed "${row.location}" to "$newName" on $count item${count == 1 ? '' : 's'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error renaming location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRenaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchQuery.isEmpty
        ? _rows
        : _rows
              .where(
                (r) =>
                    r.location.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ||
                    r.abbreviation.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.tag, color: Colors.purple.shade600),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Location Abbreviations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh',
                    onPressed: _isLoading ? null : _load,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Text('Error loading equipment: $_errorMessage'),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search location or abbreviation',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.purple.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Abbreviation is auto-generated from each '
                                'item\'s Location text and is what appears '
                                'on the printed sticker tag. Use Edit to '
                                'rename a location across every item that '
                                'uses it.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                _rows.isEmpty
                                    ? 'No locations found on any equipment yet'
                                    : 'No locations match "$_searchQuery"',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(20),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final row = filtered[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              row.location,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${row.itemCount} item${row.itemCount == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.purple.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          row.abbreviation,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 18),
                                        tooltip: 'Copy abbreviation',
                                        onPressed: () =>
                                            _copyAbbreviation(row.abbreviation),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: 'Edit location',
                                        onPressed: _isRenaming
                                            ? null
                                            : () => _editLocation(row),
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
          ],
        );
      },
    );
  }
}

class _LocationAbbreviation {
  final String location;
  final String abbreviation;
  final int itemCount;

  _LocationAbbreviation({
    required this.location,
    required this.abbreviation,
    required this.itemCount,
  });
}
