import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/kanban_board.dart';
import '../models/user.dart' as app_user;

/// Bottom sheet for viewing/editing one Kanban card: title, description,
/// assignees (drawn from the board's members), due date, labels and a
/// checklist. Opened from the board view; writes go through the caller's
/// [onSave] so this widget stays free of Firestore/provider concerns.
Future<void> showKanbanCardDetailSheet(
  BuildContext context, {
  required KanbanCard card,
  required List<app_user.User> boardMembers,
  required bool canEdit,
  required Future<void> Function(KanbanCard updated) onSave,
  required Future<void> Function() onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _KanbanCardDetailSheet(
        card: card,
        boardMembers: boardMembers,
        canEdit: canEdit,
        onSave: onSave,
        onDelete: onDelete,
      ),
    ),
  );
}

class _KanbanCardDetailSheet extends StatefulWidget {
  final KanbanCard card;
  final List<app_user.User> boardMembers;
  final bool canEdit;
  final Future<void> Function(KanbanCard updated) onSave;
  final Future<void> Function() onDelete;

  const _KanbanCardDetailSheet({
    required this.card,
    required this.boardMembers,
    required this.canEdit,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_KanbanCardDetailSheet> createState() => _KanbanCardDetailSheetState();
}

class _KanbanCardDetailSheetState extends State<_KanbanCardDetailSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _newLabelController;
  late final TextEditingController _newChecklistController;

  late List<String> _assigneeIds;
  late List<String> _labels;
  late List<KanbanChecklistItem> _checklist;
  DateTime? _dueDate;
  bool _isSaving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descController = TextEditingController(text: widget.card.description);
    _newLabelController = TextEditingController();
    _newChecklistController = TextEditingController();
    _assigneeIds = List.of(widget.card.assigneeIds);
    _labels = List.of(widget.card.labels);
    _checklist = List.of(widget.card.checklist);
    _dueDate = widget.card.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _newLabelController.dispose();
    _newChecklistController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = widget.card.copyWith(
      title: _titleController.text.trim().isEmpty ? widget.card.title : _titleController.text.trim(),
      description: _descController.text.trim(),
      assigneeIds: _assigneeIds,
      labels: _labels,
      checklist: _checklist,
      dueDate: _dueDate,
      clearDueDate: _dueDate == null,
    );
    await widget.onSave(updated);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _dirty = false;
      });
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete card?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDelete();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
      _markDirty();
    }
  }

  void _toggleAssignee(String userId) {
    setState(() {
      if (_assigneeIds.contains(userId)) {
        _assigneeIds.remove(userId);
      } else {
        _assigneeIds.add(userId);
      }
    });
    _markDirty();
  }

  void _addLabel() {
    final text = _newLabelController.text.trim();
    if (text.isEmpty || _labels.contains(text)) return;
    setState(() {
      _labels.add(text);
      _newLabelController.clear();
    });
    _markDirty();
  }

  void _addChecklistItem() {
    final text = _newChecklistController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checklist.add(KanbanChecklistItem(text: text));
      _newChecklistController.clear();
    });
    _markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = !widget.canEdit;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    enabled: !readOnly,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    onChanged: (_) => _markDirty(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descController,
                    enabled: !readOnly,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => _markDirty(),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Due date'),
                  Row(
                    children: [
                      Chip(
                        avatar: const Icon(Icons.event, size: 18),
                        label: Text(_dueDate == null ? 'None' : DateFormat('MMM d, yyyy').format(_dueDate!)),
                        onDeleted: (!readOnly && _dueDate != null)
                            ? () {
                                setState(() => _dueDate = null);
                                _markDirty();
                              }
                            : null,
                      ),
                      if (!readOnly) ...[
                        const SizedBox(width: 8),
                        TextButton(onPressed: _pickDueDate, child: const Text('Set date')),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Assignees'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.boardMembers.map((member) {
                      final selected = _assigneeIds.contains(member.id);
                      return FilterChip(
                        label: Text(member.name),
                        selected: selected,
                        onSelected: readOnly ? null : (_) => _toggleAssignee(member.id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Labels'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final label in _labels)
                        Chip(
                          label: Text(label),
                          onDeleted: readOnly
                              ? null
                              : () {
                                  setState(() => _labels.remove(label));
                                  _markDirty();
                                },
                        ),
                    ],
                  ),
                  if (!readOnly) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newLabelController,
                            decoration: const InputDecoration(hintText: 'Add label', isDense: true),
                            onSubmitted: (_) => _addLabel(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add), onPressed: _addLabel),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionLabel('Checklist'),
                  for (var i = 0; i < _checklist.length; i++)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _checklist[i].done,
                      title: Text(
                        _checklist[i].text,
                        style: _checklist[i].done
                            ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                            : null,
                      ),
                      secondary: readOnly
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() => _checklist.removeAt(i));
                                _markDirty();
                              },
                            ),
                      onChanged: (value) {
                        setState(() => _checklist[i] = _checklist[i].copyWith(done: value ?? false));
                        _markDirty();
                      },
                    ),
                  if (!readOnly)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newChecklistController,
                            decoration: const InputDecoration(hintText: 'Add checklist item', isDense: true),
                            onSubmitted: (_) => _addChecklistItem(),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.add), onPressed: _addChecklistItem),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (!readOnly) _buildFooter(),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          const Expanded(child: Text('Card details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          if (widget.canEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete card',
              onPressed: _confirmDelete,
            ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_dirty && !_isSaving) ? _save : null,
            child: _isSaving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ),
      ),
    );
  }
}
