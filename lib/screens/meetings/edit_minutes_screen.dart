import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import '../../models/meeting.dart';
import '../../services/meeting_service.dart';
import '../../utils/responsive_helper.dart';

class EditMinutesScreen extends StatefulWidget {
  final String meetingId;

  const EditMinutesScreen({super.key, required this.meetingId});

  @override
  State<EditMinutesScreen> createState() => _EditMinutesScreenState();
}

class _EditMinutesScreenState extends State<EditMinutesScreen>
    with SingleTickerProviderStateMixin {
  final MeetingService _meetingService = MeetingService();
  late TabController _tabController;
  final _customHeadingController = TextEditingController();

  Meeting? _meeting;
  MeetingMinutes? _minutes;
  List<AttendanceRecord> _attendance = [];
  List<MinutesItemRecord> _itemRecords = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customHeadingController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final meeting = await _meetingService.getMeeting(widget.meetingId);
      final minutes = await _meetingService.getMinutesByMeetingId(
        widget.meetingId,
      );

      if (mounted) {
        // Seed attendance from invited members if no existing records
        List<AttendanceRecord> attendance = minutes?.attendance ?? [];
        if (attendance.isEmpty && meeting != null && meeting.invitedMembers.isNotEmpty) {
          attendance = meeting.invitedMembers.map((member) {
            return AttendanceRecord(
              oderId: member.oderId,
              name: member.name,
              status: 'present',
            );
          }).toList();
        }

        setState(() {
          _meeting = meeting;
          _minutes = minutes;
          _attendance = attendance;
          _itemRecords = minutes?.itemRecords ?? [];
          _customHeadingController.text = meeting?.customHeading ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading minutes: $e')));
      }
    }
  }

  Future<void> _saveMinutes() async {
    if (_minutes == null) return;

    setState(() => _isSaving = true);
    try {
      final updatedMinutes = _minutes!.copyWith(
        attendance: _attendance,
        itemRecords: _itemRecords,
        updatedAt: DateTime.now(),
      );
      await _meetingService.updateMinutes(updatedMinutes);

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
            content: Text('Minutes saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving minutes: $e'),
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

  void _addAttendee() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Attendee'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  setState(() {
                    _attendance.add(
                      AttendanceRecord(
                        oderId:
                            'manual_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameController.text.trim(),
                        status: 'present',
                      ),
                    );
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _updateAttendanceStatus(int index, String status) {
    setState(() {
      _attendance[index] = AttendanceRecord(
        oderId: _attendance[index].oderId,
        name: _attendance[index].name,
        status: status,
        notes: _attendance[index].notes,
      );
    });
  }

  void _showEditRecordDialog(MinutesItemRecord record, int index) {
    showDialog(
      context: context,
      builder: (context) => _EditRecordDialog(
        record: record,
        onSave: (discussion, decisions) {
          setState(() {
            _itemRecords[index] = MinutesItemRecord(
              agendaItemId: record.agendaItemId,
              agendaItemTitle: record.agendaItemTitle,
              discussion: discussion,
              decisions: decisions,
              motions: record.motions,
            );
          });
        },
      ),
    );
  }

  String _discussionPreview(String? discussion) {
    if (discussion == null || discussion.isEmpty) return '';
    if (discussion.startsWith('[')) {
      try {
        final ops = jsonDecode(discussion) as List;
        return ops
            .where((op) => op is Map && op['insert'] is String)
            .map((op) => (op as Map)['insert'] as String)
            .join()
            .trim();
      } catch (_) {}
    }
    return discussion;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_meeting == null || _minutes == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Minutes not found'),
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

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: ResponsiveContainer(child: _buildWelcomeHeader()),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ResponsiveContainer(child: _buildTabBar()),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildAttendanceTab(), _buildRecordsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
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
              if (!_isSaving)
                _buildHeaderActionButton(
                  icon: Icons.save,
                  tooltip: 'Save',
                  onPressed: _saveMinutes,
                )
              else
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
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
                  Icons.description,
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
                      'Edit Minutes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _meeting?.title ?? 'Meeting Minutes',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildTabBar() {
    return Container(
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.indigo,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Attendance'),
          Tab(text: 'Meeting Records'),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final presentCount = _attendance
        .where((a) => a.status == 'present' || a.status == 'late')
        .length;
    final absentCount = _attendance.where((a) => a.status == 'absent').length;
    final excusedCount = _attendance.where((a) => a.status == 'excused').length;

    return Column(
      children: [
        // Summary Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              _buildAttendanceStat('Present', presentCount, Colors.green),
              const SizedBox(width: 12),
              _buildAttendanceStat('Absent', absentCount, Colors.red),
              const SizedBox(width: 12),
              _buildAttendanceStat('Excused', excusedCount, Colors.orange),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addAttendee,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              ),
            ],
          ),
        ),
        // Attendance List
        Expanded(
          child: _attendance.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance records yet',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _addAttendee,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Add Attendee'),
                      ),
                    ],
                  ),
                )
              : ResponsiveContainer(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attendance.length,
                    itemBuilder: (context, index) {
                      return _buildAttendanceCard(_attendance[index], index);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAttendanceStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record, int index) {
    Color statusColor;
    switch (record.attendanceStatus) {
      case AttendanceStatus.present:
        statusColor = Colors.green;
        break;
      case AttendanceStatus.late:
        statusColor = Colors.orange;
        break;
      case AttendanceStatus.excused:
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Text(
            record.name[0].toUpperCase(),
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(record.name),
        subtitle: Text(
          record.attendanceStatus.displayName,
          style: TextStyle(color: statusColor),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _updateAttendanceStatus(index, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'present',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Present'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'late',
              child: Row(
                children: [
                  Icon(Icons.access_time, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Late'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'absent',
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Absent'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'excused',
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Excused'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordsTab() {
    return ResponsiveContainer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeadingFieldCard(),
          const SizedBox(height: 16),
          if (_itemRecords.isEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No meeting records yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Records are created from agenda items',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            )
          else
            ..._itemRecords.asMap().entries.map(
              (entry) => _buildRecordCard(entry.value, entry.key),
            ),
        ],
      ),
    );
  }

  Widget _buildHeadingFieldCard() {
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
          const Text(
            'Document Heading',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _customHeadingController,
            decoration: const InputDecoration(
              labelText: 'Custom Heading (optional)',
              hintText:
                  'e.g. HC ADCOM MINUTES or HOPE CHANNEL SEA BOARD MEETING MINUTES',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Used for both Agenda and Minutes previews/PDF.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(MinutesItemRecord record, int index) {
    final hasContent =
        (record.discussion != null && record.discussion!.isNotEmpty) ||
        record.decisions.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditRecordDialog(record, index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.agendaItemTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    hasContent ? Icons.check_circle : Icons.edit,
                    color: hasContent ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                ],
              ),
              if (record.discussion != null &&
                  record.discussion!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _discussionPreview(record.discussion),
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (record.decisions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    Icon(Icons.check, size: 14, color: Colors.green[600]),
                    Text(
                      '${record.decisions.length} decision(s)',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (!hasContent)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap to add notes and decisions',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rich-text edit dialog for a single meeting record item ──────────────────

class _EditRecordDialog extends StatefulWidget {
  final MinutesItemRecord record;
  final void Function(String? discussion, List<String> decisions) onSave;

  const _EditRecordDialog({required this.record, required this.onSave});

  @override
  State<_EditRecordDialog> createState() => _EditRecordDialogState();
}

class _EditRecordDialogState extends State<_EditRecordDialog> {
  late quill.QuillController _discussionController;
  late List<String> _decisions;
  final TextEditingController _decisionInputController =
      TextEditingController();
  final FocusNode _quillFocusNode = FocusNode();
  final ScrollController _quillScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _decisions = List.from(widget.record.decisions);
    _discussionController =
        _buildQuillController(widget.record.discussion ?? '');
  }

  quill.QuillController _buildQuillController(String text) {
    if (text.isEmpty) return quill.QuillController.basic();
    if (text.startsWith('[')) {
      try {
        final doc =
            quill.Document.fromJson(jsonDecode(text) as List);
        return quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {}
    }
    final doc = quill.Document()..insert(0, text);
    return quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _discussionController.dispose();
    _decisionInputController.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    super.dispose();
  }

  void _save() {
    final delta = _discussionController.document.toDelta().toJson();
    final plainText =
        _discussionController.document.toPlainText().trim();
    final discussion =
        plainText.isEmpty ? null : jsonEncode(delta);
    Navigator.pop(context);
    widget.onSave(discussion, _decisions);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.record.agendaItemTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Discussion rich-text editor ────────────────────────────
              const Text(
                'Discussion Notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUndoRedoBar(_discussionController),
                    const Divider(height: 1),
                    quill.QuillSimpleToolbar(
                      controller: _discussionController,
                      config: const quill.QuillSimpleToolbarConfig(
                        showFontFamily: false,
                        showFontSize: false,
                        showBackgroundColorButton: false,
                        showColorButton: false,
                        showAlignmentButtons: false,
                        showDirection: false,
                        showDividers: true,
                        showHeaderStyle: false,
                        showIndent: false,
                        showLink: false,
                        showSearchButton: false,
                        showSubscript: false,
                        showSuperscript: false,
                        showCodeBlock: false,
                        showInlineCode: false,
                        showQuote: false,
                        showSmallButton: false,
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 160,
                      child: quill.QuillEditor(
                        controller: _discussionController,
                        focusNode: _quillFocusNode,
                        scrollController: _quillScrollController,
                        config: const quill.QuillEditorConfig(
                          placeholder: 'Enter discussion points...',
                          padding: EdgeInsets.all(12),
                          autoFocus: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Decisions ──────────────────────────────────────────────
              const Text(
                'Decisions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._decisions.asMap().entries.map((entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  title: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() => _decisions.removeAt(entry.key));
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _decisionInputController,
                      decoration: const InputDecoration(
                        labelText: 'Add Decision',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addDecision(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: _addDecision,
                  ),
                ],
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _addDecision() {
    final text = _decisionInputController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _decisions.add(text);
        _decisionInputController.clear();
      });
    }
  }

  Widget _buildUndoRedoBar(quill.QuillController controller) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.format_color_text,
              size: 13,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              'Rich text',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.undo),
              iconSize: 18,
              onPressed: () => controller.undo(),
              tooltip: 'Undo (Ctrl+Z)',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              iconSize: 18,
              onPressed: () => controller.redo(),
              tooltip: 'Redo (Ctrl+Y)',
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(4),
            ),
          ],
        ),
      ),
    );
  }
}
