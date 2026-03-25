import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/adcom_agenda.dart';
import '../../models/staff.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/staff_service.dart';
import '../../services/ai_text_service.dart';
import '../../utils/responsive_helper.dart';

class AdcomAgendaEditScreen extends StatefulWidget {
  final String agendaId;
  final String? returnToMeetingId;

  const AdcomAgendaEditScreen({
    super.key,
    required this.agendaId,
    this.returnToMeetingId,
  });

  @override
  State<AdcomAgendaEditScreen> createState() => _AdcomAgendaEditScreenState();
}

class _AdcomAgendaEditScreenState extends State<AdcomAgendaEditScreen> {
  final AdcomAgendaService _service = AdcomAgendaService();
  final AdcomMinutesService _minutesService = AdcomMinutesService();
  AdcomAgenda? _agenda;
  bool _isLoading = true;
  final dateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _openingPrayerController = TextEditingController();
  final TextEditingController _closingPrayerController = TextEditingController();
  final TextEditingController _adjournedAtController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    setState(() => _isLoading = true);
    try {
      final agenda = await _service.getAgendaById(widget.agendaId);
      setState(() {
        _agenda = agenda;
        _isLoading = false;
        _startTimeController.text = _agenda?.startTime ?? '';
        _openingPrayerController.text = _agenda?.openingPrayer ?? '';
        _closingPrayerController.text = _agenda?.closingPrayer ?? '';
        _adjournedAtController.text = _agenda?.meetingAdjournedAt ?? '';
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading agenda: $e')));
      }
    }
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _openingPrayerController.dispose();
    _closingPrayerController.dispose();
    _adjournedAtController.dispose();
    super.dispose();
  }

  Future<void> _openOrCreateMinutes() async {
    if (_agenda == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Check if minutes already exist for this agenda
      final existingMinutes = await _minutesService.getMinutesByAgendaId(
        widget.agendaId,
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (existingMinutes != null) {
        // Navigate to existing minutes
        if (mounted) {
          final meetingQuery = widget.returnToMeetingId != null
              ? '?meetingId=${widget.returnToMeetingId}'
              : '';
          context.push(
            '/admin/adcom-minutes/${existingMinutes.id}$meetingQuery',
          );
        }
      } else {
        // Create new minutes from agenda
        final minutesId = await _minutesService.createMinutesFromAgenda(
          _agenda!,
        );
        if (mounted) {
          final meetingQuery = widget.returnToMeetingId != null
              ? '?meetingId=${widget.returnToMeetingId}'
              : '';
          context.push('/admin/adcom-minutes/$minutesId$meetingQuery');
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _agenda == null
            ? _buildErrorState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Agenda not found'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _handleBack, child: const Text('Go Back')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: ResponsiveContainer(
        child: Padding(
          padding: ResponsiveHelper.getScreenPadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(),
              const SizedBox(height: 24),
              _buildMeetingDetailsCard(),
              const SizedBox(height: 24),
              _buildAttendanceCard(),
              const SizedBox(height: 24),
              _buildAgendaItemsCard(),
              const SizedBox(height: 24),
              _buildMeetingNotesCard(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to List',
                onPressed: _handleBack,
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.description,
                    tooltip: 'Create/Edit Minutes',
                    onPressed: _openOrCreateMinutes,
                  ),
                  if (_agenda!.status != 'finalized') ...[
                    const SizedBox(width: 8),
                    _buildHeaderActionButton(
                      icon: Icons.check_circle,
                      tooltip: 'Finalize Agenda',
                      onPressed: _finalizeAgenda,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.visibility,
                    tooltip: 'Preview',
                    onPressed: () => _openPreview(false),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.print,
                    tooltip: 'Print',
                    onPressed: () => _openPreview(true),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/admin-hub'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_note,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit ${_agenda!.organization} Agenda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(_agenda!.meetingDate),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _agenda!.status == 'finalized'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _agenda!.status.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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

  Future<void> _finalizeAgenda() async {
    if (_agenda == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize Agenda'),
        content: const Text(
          'Finalize this agenda? You can still edit items later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.finalizeAgenda(widget.agendaId);
      await _loadAgenda();
    }
  }

  void _handleBack() {
    if (widget.returnToMeetingId != null) {
      context.go('/meetings/${widget.returnToMeetingId}');
    } else {
      context.go('/admin/adcom-agendas');
    }
  }

  void _openPreview(bool isPrint) {
    final meetingQuery = widget.returnToMeetingId != null
        ? '?meetingId=${widget.returnToMeetingId}'
        : '';
    final path = isPrint
        ? '/admin/adcom-agenda/${widget.agendaId}/print$meetingQuery'
        : '/admin/adcom-agenda/${widget.agendaId}/view$meetingQuery';
    context.push(path);
  }

  Widget _buildMeetingDetailsCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.indigo.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Meeting Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _editMeetingDetails,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow('Organization', _agenda!.organization),
                _buildDetailRow(
                  'Date',
                  dateFormat.format(_agenda!.meetingDate),
                ),
                _buildDetailRow(
                  'Time',
                  _agenda!.meetingTime.isNotEmpty
                      ? _agenda!.meetingTime
                      : 'Not set',
                ),
                _buildDetailRow(
                  'Location',
                  _agenda!.location.isNotEmpty ? _agenda!.location : 'Not set',
                ),
                _buildDetailRow(
                  'Starting Item #',
                  '${_agenda!.startingItemSequence}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final presentMembers = _agenda!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _agenda!.attendanceMembers
        .where((m) => m.isAbsentWithApology)
        .toList();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: Colors.green.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _editAttendance,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_agenda!.attendanceMembers.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No attendance members added',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _editAttendance,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Members'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (presentMembers.isNotEmpty) ...[
                    Text(
                      'Present:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presentMembers
                          .map(
                            (m) => Chip(
                              avatar: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Text(
                                  m.affiliation.isNotEmpty
                                      ? m.affiliation[0]
                                      : 'M',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                              label: Text('${m.name} (${m.affiliation})'),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (absentMembers.isNotEmpty) ...[
                    Text(
                      'Absent with Apology:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: absentMembers
                          .map(
                            (m) => Chip(
                              avatar: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Text(
                                  m.affiliation.isNotEmpty
                                      ? m.affiliation[0]
                                      : 'M',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                              label: Text('${m.name} (${m.affiliation})'),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaItemsCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.orange.shade600),
                const SizedBox(width: 12),
                Text(
                  'Agenda Items (${_agenda!.agendaItems.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addAgendaItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_agenda!.agendaItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.playlist_add,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No agenda items yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add items to build your meeting agenda',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _agenda!.agendaItems.length,
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex--;
                await _service.reorderAgendaItems(
                  widget.agendaId,
                  oldIndex,
                  newIndex,
                );
                await _loadAgenda();
              },
              itemBuilder: (context, index) {
                final item = _agenda!.agendaItems[index];
                return _buildAgendaItemTile(item, index);
              },
            ),
        ],
      ),
    );
  }


  Widget _buildMeetingNotesCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event_note, color: Colors.blueGrey.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Meeting Notes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _saveMeetingNotes,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildNotesTextField(
                  label: 'Start Time',
                  controller: _startTimeController,
                ),
                const SizedBox(height: 12),
                _buildNotesTextField(
                  label: 'Opening Prayer',
                  controller: _openingPrayerController,
                ),
                const SizedBox(height: 12),
                _buildNotesTextField(
                  label: 'Closing Prayer',
                  controller: _closingPrayerController,
                ),
                const SizedBox(height: 12),
                _buildNotesTextField(
                  label: 'Meeting Adjourned At',
                  controller: _adjournedAtController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTextField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _saveMeetingNotes() async {
    if (_agenda == null) return;
    try {
      final updatedAgenda = _agenda!.copyWith(
        startTime: _startTimeController.text.trim(),
        openingPrayer: _openingPrayerController.text.trim(),
        closingPrayer: _closingPrayerController.text.trim(),
        meetingAdjournedAt: _adjournedAtController.text.trim(),
      );
      await _service.updateAgenda(updatedAgenda);
      await _loadAgenda();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Meeting notes saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving notes: $e')));
      }
    }
  }

  Widget _buildAgendaItemTile(AgendaItem item, int index) {
    final actionColor = _getActionColor(item.actionType);

    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Item number + Title + Action type + buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item number badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Item number text + Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemNumber,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.actionType.displayName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: actionColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Action buttons
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => _editAgendaItem(index, item),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red.shade400,
                  ),
                  onPressed: () => _deleteAgendaItem(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
                const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
              ],
            ),
            // Description aligned with title (with left padding to match)
            if (item.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: _buildDescriptionWidget(
                  item.description,
                  TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getActionColor(AgendaActionType type) {
    switch (type) {
      case AgendaActionType.recommended:
        return Colors.blue;
      case AgendaActionType.voted:
        return Colors.green;
      case AgendaActionType.information:
        return Colors.purple;
      case AgendaActionType.forDiscussion:
        return Colors.orange;
    }
  }

  Future<void> _editMeetingDetails() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditMeetingDetailsDialog(agenda: _agenda!),
    );

    if (result != null) {
      try {
        final updatedAgenda = _agenda!.copyWith(
          meetingDate: result['date'],
          meetingTime: result['time'],
          location: result['location'],
          organization: result['organization'],
          startingItemSequence: result['startingSequence'],
        );
        await _service.updateAgenda(updatedAgenda);
        await _loadAgenda();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
        }
      }
    }
  }

  Future<void> _editAttendance() async {
    final result = await showDialog<List<AttendanceMember>>(
      context: context,
      builder: (context) =>
          _EditAttendanceDialog(members: _agenda!.attendanceMembers),
    );

    if (result != null) {
      try {
        await _service.updateAttendance(widget.agendaId, result);
        await _loadAgenda();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating attendance: $e')),
          );
        }
      }
    }
  }

  Future<void> _addAgendaItem() async {
    final startingSeq = _agenda!.startingItemSequence;
    final nextSeq = startingSeq + _agenda!.agendaItems.length;
    final itemNumber = AdcomAgenda.generateItemNumber(
      _agenda!.meetingDate,
      nextSeq,
      organization: _agenda!.organization,
    );

    final result = await showModalBottomSheet<AgendaItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditAgendaItemDialog(
        itemNumber: itemNumber,
        order: _agenda!.agendaItems.length,
      ),
    );

    if (result != null) {
      try {
        await _service.addAgendaItem(widget.agendaId, result);
        await _loadAgenda();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error adding item: $e')));
        }
      }
    }
  }

  Future<void> _editAgendaItem(int index, AgendaItem item) async {
    final result = await showModalBottomSheet<AgendaItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _EditAgendaItemDialog(
        item: item,
        itemNumber: item.itemNumber,
        order: index,
      ),
    );

    if (result != null) {
      try {
        await _service.updateAgendaItem(widget.agendaId, index, result);
        await _loadAgenda();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating item: $e')));
        }
      }
    }
  }

  Future<void> _deleteAgendaItem(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text(
          'Are you sure you want to delete this agenda item?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.removeAgendaItem(widget.agendaId, index);
        await _loadAgenda();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting item: $e')));
        }
      }
    }
  }
}

// Dialog for editing meeting details
class _EditMeetingDetailsDialog extends StatefulWidget {
  final AdcomAgenda agenda;

  const _EditMeetingDetailsDialog({required this.agenda});

  @override
  State<_EditMeetingDetailsDialog> createState() =>
      _EditMeetingDetailsDialogState();
}

class _EditMeetingDetailsDialogState extends State<_EditMeetingDetailsDialog> {
  late DateTime _selectedDate;
  late TextEditingController _timeController;
  late TextEditingController _locationController;
  late TextEditingController _organizationController;
  late TextEditingController _startingSequenceController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.agenda.meetingDate;
    _timeController = TextEditingController(text: widget.agenda.meetingTime);
    _locationController = TextEditingController(text: widget.agenda.location);
    _organizationController = TextEditingController(
      text: widget.agenda.organization,
    );
    _startingSequenceController = TextEditingController(
      text: widget.agenda.startingItemSequence.toString(),
    );
  }

  @override
  void dispose() {
    _timeController.dispose();
    _locationController.dispose();
    _organizationController.dispose();
    _startingSequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Meeting Details'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Organization',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _organizationController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Meeting Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20),
                      const SizedBox(width: 12),
                      Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Meeting Time',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _timeController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Starting Item Sequence',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _startingSequenceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  hintText: 'e.g., 1',
                  helperText: 'First agenda item will start from this number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
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
          onPressed: () {
            Navigator.pop(context, {
              'date': _selectedDate,
              'time': _timeController.text,
              'location': _locationController.text,
              'organization': _organizationController.text,
              'startingSequence':
                  int.tryParse(_startingSequenceController.text) ?? 1,
            });
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// Dialog for editing attendance
class _EditAttendanceDialog extends StatefulWidget {
  final List<AttendanceMember> members;

  const _EditAttendanceDialog({required this.members});

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  late List<AttendanceMember> _members;
  final StaffService _staffService = StaffService();

  @override
  void initState() {
    super.initState();
    _members = List.from(widget.members);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Attendance'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _addMember,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Member'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addFromStaff,
                  icon: const Icon(Icons.badge, size: 18),
                  label: const Text('Add From Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _members.isEmpty
                  ? Center(
                      child: Text(
                        'No members added',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: member.isPresent
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                member.isPresent ? Icons.check : Icons.close,
                                color: member.isPresent
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                            title: Text(
                              member.name.isNotEmpty ? member.name : 'No name',
                            ),
                            subtitle: Text(member.affiliation),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editMember(index),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () {
                                    setState(() => _members.removeAt(index));
                                  },
                                ),
                              ],
                            ),
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
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _members),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _addMember() async {
    final result = await showDialog<AttendanceMember>(
      context: context,
      builder: (context) => const _EditMemberDialog(),
    );
    if (result != null) {
      setState(() => _members.add(result));
    }
  }

  Future<void> _editMember(int index) async {
    final result = await showDialog<AttendanceMember>(
      context: context,
      builder: (context) => _EditMemberDialog(member: _members[index]),
    );
    if (result != null) {
      setState(() => _members[index] = result);
    }
  }

  Future<void> _addFromStaff() async {
    final existingNames = _members.map((m) => m.name.trim()).toSet();
    final selected = await showDialog<List<AttendanceMember>>(
      context: context,
      builder: (context) => _SelectStaffDialog(
        staffService: _staffService,
        existingNames: existingNames,
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        for (final member in selected) {
          if (!_members.any((m) => m.name == member.name)) {
            _members.add(member);
          }
        }
      });
    }
  }
}

// Dialog for editing a single member
class _EditMemberDialog extends StatefulWidget {
  final AttendanceMember? member;

  const _EditMemberDialog({this.member});

  @override
  State<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends State<_EditMemberDialog> {
  late TextEditingController _nameController;
  late TextEditingController _affiliationController;
  late bool _isPresent;
  late bool _isAbsentWithApology;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.name ?? '');
    _affiliationController = TextEditingController(
      text: widget.member?.affiliation ?? 'HC',
    );
    _isPresent = widget.member?.isPresent ?? true;
    _isAbsentWithApology = widget.member?.isAbsentWithApology ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _affiliationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member == null ? 'Add Member' : 'Edit Member'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter member name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Affiliation',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _affiliationController,
              decoration: InputDecoration(
                hintText: 'e.g., HC, SEUM',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            RadioListTile<bool>(
              title: const Text('Present'),
              value: true,
              groupValue: _isPresent,
              onChanged: (value) {
                setState(() {
                  _isPresent = true;
                  _isAbsentWithApology = false;
                });
              },
            ),
            RadioListTile<bool>(
              title: const Text('Absent with Apology'),
              value: false,
              groupValue: _isPresent,
              onChanged: (value) {
                setState(() {
                  _isPresent = false;
                  _isAbsentWithApology = true;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              AttendanceMember(
                name: _nameController.text,
                affiliation: _affiliationController.text,
                isPresent: _isPresent,
                isAbsentWithApology: _isAbsentWithApology,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SelectStaffDialog extends StatefulWidget {
  final StaffService staffService;
  final Set<String> existingNames;

  const _SelectStaffDialog({
    required this.staffService,
    required this.existingNames,
  });

  @override
  State<_SelectStaffDialog> createState() => _SelectStaffDialogState();
}

class _SelectStaffDialogState extends State<_SelectStaffDialog> {
  final Set<String> _selectedStaffIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Staff'),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search staff',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Staff>>(
                stream: widget.staffService.getAllStaff(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final staff = snapshot.data ?? [];
                  final filtered = staff.where((member) {
                    if (_searchQuery.isEmpty) return true;
                    final q = _searchQuery.toLowerCase();
                    return member.fullName.toLowerCase().contains(q) ||
                        member.department.toLowerCase().contains(q) ||
                        member.position.toLowerCase().contains(q) ||
                        member.employeeId.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No staff found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final member = filtered[index];
                      final isSelected = _selectedStaffIds.contains(member.id);
                      final isDisabled = widget.existingNames.contains(
                        member.fullName,
                      );
                      return ListTile(
                        title: Text(member.fullName),
                        subtitle: Text(
                          '${member.department} • ${member.position}',
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: isDisabled
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedStaffIds.add(member.id);
                                    } else {
                                      _selectedStaffIds.remove(member.id);
                                    }
                                  });
                                },
                        ),
                        enabled: !isDisabled,
                        onTap: isDisabled
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStaffIds.remove(member.id);
                                  } else {
                                    _selectedStaffIds.add(member.id);
                                  }
                                });
                              },
                      );
                    },
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
        ElevatedButton(
          onPressed: () async {
            final staff = await widget.staffService.getAllStaff().first;
            final selected = staff
                .where((member) => _selectedStaffIds.contains(member.id))
                .map(
                  (member) => AttendanceMember(
                    name: member.fullName,
                    affiliation: member.department.isNotEmpty
                        ? member.department
                        : 'HC',
                  ),
                )
                .toList();
            if (!context.mounted) return;
            Navigator.pop(context, selected);
          },
          child: const Text('Add Selected'),
        ),
      ],
    );
  }
}

// ── Formatting helpers (used in both main state and dialog) ─────────────────

List<({String text, bool bold, bool italic, bool underline})> _parseFormatting(
  String text,
) {
  final result = <({String text, bool bold, bool italic, bool underline})>[];
  bool bold = false, italic = false, underline = false;
  int pos = 0;
  final markers = RegExp(r'\*\*|_|<u>|</u>');
  for (final match in markers.allMatches(text)) {
    if (match.start > pos) {
      result.add((
        text: text.substring(pos, match.start),
        bold: bold,
        italic: italic,
        underline: underline,
      ));
    }
    switch (match.group(0)) {
      case '**':
        bold = !bold;
      case '_':
        italic = !italic;
      case '<u>':
        underline = true;
      case '</u>':
        underline = false;
    }
    pos = match.end;
  }
  if (pos < text.length) {
    result.add((
      text: text.substring(pos),
      bold: bold,
      italic: italic,
      underline: underline,
    ));
  }
  return result;
}

/// Renders a description string that may be Delta JSON (from QuillEditor)
/// or legacy markdown-style text (**bold**, _italic_, <u>underline</u>).
Widget _buildDescriptionWidget(String text, TextStyle baseStyle) {
  if (text.startsWith('[')) {
    try {
      final List<dynamic> ops = jsonDecode(text) as List;
      final spans = <TextSpan>[];
      for (final op in ops) {
        if (op is! Map) continue;
        final insert = op['insert'];
        if (insert is! String) continue;
        final attrs = (op['attributes'] as Map?) ?? {};
        spans.add(TextSpan(
          text: insert,
          style: TextStyle(
            fontWeight: attrs['bold'] == true ? FontWeight.bold : FontWeight.normal,
            fontStyle: attrs['italic'] == true ? FontStyle.italic : FontStyle.normal,
            decoration: attrs['underline'] == true
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ));
      }
      if (spans.isNotEmpty) {
        return Text.rich(TextSpan(style: baseStyle, children: spans));
      }
    } catch (_) {}
  }
  final segments = _parseFormatting(text);
  return Text.rich(
    TextSpan(
      style: baseStyle,
      children: segments
          .map((seg) => TextSpan(
                text: seg.text,
                style: TextStyle(
                  fontWeight: seg.bold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: seg.italic ? FontStyle.italic : FontStyle.normal,
                  decoration: seg.underline
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ))
          .toList(),
    ),
  );
}

// Dialog for editing agenda item
class _EditAgendaItemDialog extends StatefulWidget {
  final AgendaItem? item;
  final String itemNumber;
  final int order;

  const _EditAgendaItemDialog({
    this.item,
    required this.itemNumber,
    required this.order,
  });

  @override
  State<_EditAgendaItemDialog> createState() => _EditAgendaItemDialogState();
}

class _EditAgendaItemDialogState extends State<_EditAgendaItemDialog> {
  late TextEditingController _titleController;
  late quill.QuillController _quillController;
  late AgendaActionType _actionType;
  final AITextService _aiService = AITextService();
  bool _isProcessingAI = false;

  final UndoHistoryController _titleUndoController = UndoHistoryController();
  final FocusNode _quillFocusNode = FocusNode();
  final ScrollController _quillScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _actionType = widget.item?.actionType ?? AgendaActionType.recommended;

    final desc = widget.item?.description ?? '';
    if (desc.isEmpty) {
      _quillController = quill.QuillController.basic();
    } else if (desc.startsWith('[')) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(desc) as List);
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        final doc = quill.Document()..insert(0, desc);
        _quillController = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      final doc = quill.Document()..insert(0, desc);
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _titleUndoController.dispose();
    _quillFocusNode.dispose();
    _quillScrollController.dispose();
    super.dispose();
  }

  Future<void> _enhanceDescription() async {
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter description text first')),
      );
      return;
    }

    setState(() => _isProcessingAI = true);
    final result = await _aiService.enhanceText(
      plainText,
      context: 'ADCOM agenda item description',
    );
    setState(() => _isProcessingAI = false);

    if (result.success && result.text != null) {
      final newDoc = quill.Document()..insert(0, result.text!);
      setState(() {
        _quillController.document = newDoc;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Description enhanced!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to enhance text'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _spellCheckTitle() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter title text first')),
      );
      return;
    }

    setState(() => _isProcessingAI = true);
    final result = await _aiService.checkSpelling(_titleController.text);
    setState(() => _isProcessingAI = false);

    if (result.success) {
      if (result.hasIssues) {
        _showSpellCheckResult(result, _titleController);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No spelling errors found! ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Spell check failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _spellCheckDescription() async {
    final plainText = _quillController.document.toPlainText().trim();
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter description text first')),
      );
      return;
    }

    setState(() => _isProcessingAI = true);
    final result = await _aiService.checkSpelling(plainText);
    setState(() => _isProcessingAI = false);

    if (result.success) {
      if (result.hasIssues) {
        _showSpellCheckResultForQuill(result);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No spelling errors found! ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Spell check failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSpellCheckResult(
    SpellCheckResult result,
    TextEditingController controller,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.spellcheck, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Spell Check Results'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${result.issues.length} issue(s):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...result.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Icon(
                        issue.type == 'spelling'
                            ? Icons.abc
                            : Icons.format_quote,
                        size: 16,
                        color: Colors.orange,
                      ),
                      Text(
                        '"${issue.original}"',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.red,
                        ),
                      ),
                      const Text(' → '),
                      Text(
                        '"${issue.correction}"',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Corrected text:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(result.correctedText ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Original'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(
                () => controller.text = result.correctedText ?? controller.text,
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Corrections'),
          ),
        ],
      ),
    );
  }

  void _showSpellCheckResultForQuill(SpellCheckResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.spellcheck, color: Colors.orange.shade600),
            const SizedBox(width: 8),
            const Text('Spell Check Results'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Found ${result.issues.length} issue(s):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...result.issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      Icon(
                        issue.type == 'spelling' ? Icons.abc : Icons.format_quote,
                        size: 16,
                        color: Colors.orange,
                      ),
                      Text(
                        '"${issue.original}"',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.red,
                        ),
                      ),
                      const Text(' → '),
                      Text(
                        '"${issue.correction}"',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (result.correctedText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Corrected text:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Text(result.correctedText!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Original'),
          ),
          ElevatedButton(
            onPressed: () {
              if (result.correctedText != null) {
                final newDoc = quill.Document()..insert(0, result.correctedText!);
                setState(() {
                  _quillController.document = newDoc;
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply Corrections'),
          ),
        ],
      ),
    );
  }

  Widget _buildAIButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _isProcessingAI ? null : onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Icon(icon, size: 18, color: Colors.purple.shade600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.edit_note, color: Colors.indigo.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item == null ? 'Add Agenda Item' : 'Edit Agenda Item',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isProcessingAI)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item number chip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 20,
                          color: Colors.indigo.shade600,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Item Number: ${widget.itemNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title label + AI spell check
                  Row(
                    children: [
                      const Text(
                        'Title',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_aiService.isAvailable)
                        _buildAIButton(
                          icon: Icons.spellcheck,
                          tooltip: 'AI Spell Check',
                          onPressed: _spellCheckTitle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title field with undo/redo
                  ValueListenableBuilder<UndoHistoryValue>(
                    valueListenable: _titleUndoController,
                    builder: (context, undoValue, _) {
                      return TextField(
                        controller: _titleController,
                        undoController: _titleUndoController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText:
                              'e.g., ACCEPTANCE OF TREASURER\'S REPORT',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.undo, size: 18),
                                tooltip: 'Undo',
                                onPressed: undoValue.canUndo
                                    ? () => _titleUndoController.undo()
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.redo, size: 18),
                                tooltip: 'Redo',
                                onPressed: undoValue.canRedo
                                    ? () => _titleUndoController.redo()
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Action type
                  const Text(
                    'Action Type',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<AgendaActionType>(
                    initialValue: _actionType,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: AgendaActionType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _actionType = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Description label + AI buttons
                  Row(
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      if (_aiService.isAvailable) ...[
                        _buildAIButton(
                          icon: Icons.auto_awesome,
                          tooltip: 'AI Enhance Text',
                          onPressed: _enhanceDescription,
                        ),
                        const SizedBox(width: 8),
                        _buildAIButton(
                          icon: Icons.spellcheck,
                          tooltip: 'AI Spell Check',
                          onPressed: _spellCheckDescription,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description rich text editor
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        quill.QuillSimpleToolbar(
                          controller: _quillController,
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
                            controller: _quillController,
                            focusNode: _quillFocusNode,
                            scrollController: _quillScrollController,
                            config: quill.QuillEditorConfig(
                              placeholder: 'Enter detailed description or recommendation...',
                              padding: const EdgeInsets.all(12),
                              autoFocus: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // AI hint if not configured
                  if (!_aiService.isAvailable)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 18,
                              color: Colors.purple.shade400,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Set AI_API_KEY in .env to enable spell check and text enhancement',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a title'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(
                        context,
                        AgendaItem(
                          id: widget.item?.id ?? 'item_${widget.order}',
                          itemNumber: widget.itemNumber,
                          title: _titleController.text.trim(),
                          actionType: _actionType,
                          description: jsonEncode(
                            _quillController.document.toDelta().toJson(),
                          ),
                          order: widget.order,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
