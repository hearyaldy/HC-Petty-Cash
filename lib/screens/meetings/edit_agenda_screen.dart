import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';
import '../../utils/responsive_helper.dart';

class EditAgendaScreen extends StatefulWidget {
  final String meetingId;

  const EditAgendaScreen({super.key, required this.meetingId});

  @override
  State<EditAgendaScreen> createState() => _EditAgendaScreenState();
}

class _EditAgendaScreenState extends State<EditAgendaScreen> {
  final MeetingService _meetingService = MeetingService();
  final _customHeadingController = TextEditingController();

  Meeting? _meeting;
  MeetingAgenda? _agenda;
  List<AgendaItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _customHeadingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final meeting = await _meetingService.getMeeting(widget.meetingId);
      final agenda = await _meetingService.getAgendaByMeetingId(
        widget.meetingId,
      );

      if (mounted) {
        setState(() {
          _meeting = meeting;
          _agenda = agenda;
          _items = agenda?.items ?? [];
          _customHeadingController.text = meeting?.customHeading ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading agenda: $e')));
      }
    }
  }

  Future<void> _saveAgenda() async {
    if (_agenda == null) return;

    setState(() => _isSaving = true);
    try {
      final updatedAgenda = _agenda!.copyWith(
        items: _items,
        updatedAt: DateTime.now(),
      );
      await _meetingService.updateAgenda(updatedAgenda);

      if (_meeting != null) {
        final heading = _customHeadingController.text.trim();
        final updatedMeeting = _meeting!.copyWith(
          customHeading: heading.isNotEmpty ? heading : null,
          updatedAt: DateTime.now(),
        );
        await _meetingService.updateMeeting(updatedMeeting);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agenda saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addItem() {
    final newOrder = _items.isEmpty ? 1 : _items.last.order + 1;
    final newItem = AgendaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: newOrder,
      title: '',
      type: 'discussion',
      timeAllocation: 10,
    );

    setState(() {
      _items.add(newItem);
    });

    _showEditItemDialog(newItem, _items.length - 1);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      // Reorder remaining items
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i + 1);
      }
    });
  }

  void _reorderItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      // Update order numbers
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i + 1);
      }
    });
  }

  void _showEditItemDialog(AgendaItem item, int index) {
    final titleController = TextEditingController(text: item.title);
    final descriptionController = TextEditingController(
      text: item.description ?? '',
    );
    final timeController = TextEditingController(
      text: item.timeAllocation.toString(),
    );
    final presenterController = TextEditingController(
      text: item.presenterName ?? '',
    );
    String selectedType = item.type;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                item.title.isEmpty ? 'Add Agenda Item' : 'Edit Agenda Item',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title *',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Item Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'opening',
                          child: Text('Opening'),
                        ),
                        DropdownMenuItem(
                          value: 'approval',
                          child: Text('Approval'),
                        ),
                        DropdownMenuItem(
                          value: 'report',
                          child: Text('Report'),
                        ),
                        DropdownMenuItem(
                          value: 'discussion',
                          child: Text('Discussion'),
                        ),
                        DropdownMenuItem(
                          value: 'action',
                          child: Text('Action Item'),
                        ),
                        DropdownMenuItem(
                          value: 'information',
                          child: Text('Information'),
                        ),
                        DropdownMenuItem(
                          value: 'closing',
                          child: Text('Closing'),
                        ),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value ?? 'discussion';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time Allocation (minutes)',
                        border: OutlineInputBorder(),
                        suffixText: 'min',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: presenterController,
                      decoration: const InputDecoration(
                        labelText: 'Presenter (optional)',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // If it's a new item with empty title, remove it
                    if (item.title.isEmpty) {
                      setState(() {
                        _items.removeAt(index);
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a title'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      _items[index] = item.copyWith(
                        title: titleController.text.trim(),
                        description:
                            descriptionController.text.trim().isNotEmpty
                            ? descriptionController.text.trim()
                            : null,
                        type: selectedType,
                        timeAllocation: int.tryParse(timeController.text) ?? 10,
                        presenterName:
                            presenterController.text.trim().isNotEmpty
                            ? presenterController.text.trim()
                            : null,
                      );
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_meeting == null || _agenda == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Agenda not found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalDuration = _items.fold<int>(
      0,
      (total, item) => total + item.timeAllocation,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: ResponsiveContainer(
                child: _buildWelcomeHeader(totalDuration),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ResponsiveContainer(child: _buildHeadingSection()),
            ),
            const SizedBox(height: 16),
            // Agenda Items List
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No agenda items yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Item'),
                          ),
                        ],
                      ),
                    )
                  : ResponsiveContainer(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        onReorder: _reorderItems,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildAgendaItemCard(item, index);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(int totalDuration) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade400, Colors.indigo.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.add,
                    tooltip: 'Add Item',
                    onPressed: _addItem,
                  ),
                  const SizedBox(width: 8),
                  if (!_isSaving)
                    _buildHeaderActionButton(
                      icon: Icons.save,
                      tooltip: 'Save',
                      onPressed: _saveAgenda,
                    )
                  else
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.list_alt,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Edit Agenda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_items.length} items • $totalDuration minutes total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildHeadingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Document Heading',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customHeadingController,
            decoration: const InputDecoration(
              labelText: 'Custom Heading (optional)',
              hintText:
                  'e.g. HC ADCOM AGENDA or HOPE CHANNEL SEA BOARD MEETING MINUTES',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This heading will be used for both Agenda and Minutes previews/PDF.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaItemCard(AgendaItem item, int index) {
    Color typeColor;
    switch (item.itemType) {
      case AgendaItemType.opening:
      case AgendaItemType.closing:
        typeColor = Colors.purple;
        break;
      case AgendaItemType.approval:
        typeColor = Colors.blue;
        break;
      case AgendaItemType.report:
        typeColor = Colors.green;
        break;
      case AgendaItemType.discussion:
        typeColor = Colors.orange;
        break;
      case AgendaItemType.action:
        typeColor = Colors.red;
        break;
      case AgendaItemType.information:
        typeColor = Colors.teal;
        break;
      default:
        typeColor = Colors.grey;
    }

    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: typeColor.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${item.order}',
                style: TextStyle(color: typeColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        title: Text(
          item.title.isEmpty ? '(Untitled)' : item.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: item.title.isEmpty ? Colors.grey : null,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.itemType.displayName,
                style: TextStyle(
                  fontSize: 10,
                  color: typeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.timer, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 2),
            Text(
              '${item.timeAllocation} min',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditItemDialog(item, index),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _removeItem(index),
              tooltip: 'Remove',
            ),
          ],
        ),
        onTap: () => _showEditItemDialog(item, index),
      ),
    );
  }
}
