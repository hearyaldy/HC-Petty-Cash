import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/adcom_agenda.dart';
import '../../models/adcom_minutes.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/ai_text_service.dart';
import '../../utils/responsive_helper.dart';

class AdcomMinutesEditScreen extends StatefulWidget {
  final String minutesId;
  final String? returnToMeetingId;

  const AdcomMinutesEditScreen({
    super.key,
    required this.minutesId,
    this.returnToMeetingId,
  });

  @override
  State<AdcomMinutesEditScreen> createState() => _AdcomMinutesEditScreenState();
}

class _AdcomMinutesEditScreenState extends State<AdcomMinutesEditScreen> {
  final AdcomMinutesService _service = AdcomMinutesService();
  final AdcomAgendaService _agendaService = AdcomAgendaService();
  final AITextService _aiService = AITextService();
  AdcomMinutes? _minutes;
  AdcomAgenda? _agenda;
  StreamSubscription<AdcomAgenda?>? _agendaSubscription;
  bool _isLoading = true;
  final dateFormat = DateFormat('dd MMM yyyy');
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _openingPrayerController = TextEditingController();
  final TextEditingController _closingPrayerController = TextEditingController();
  final TextEditingController _adjournedAtController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMinutes();
  }

  Future<void> _loadMinutes() async {
    setState(() => _isLoading = true);
    try {
      final minutes = await _service.getMinutesById(widget.minutesId);
      _agendaSubscription?.cancel();
      AdcomAgenda? agenda;
      if (minutes != null && minutes.agendaId.isNotEmpty) {
        agenda = await _agendaService.getAgendaById(minutes.agendaId);
        _agendaSubscription = _agendaService
            .streamAgendaById(minutes.agendaId)
            .listen((updatedAgenda) {
              if (!mounted) return;
              setState(() {
                _agenda = updatedAgenda;
              });
              if (updatedAgenda != null) {
                _syncMinutesFromAgenda(updatedAgenda);
              }
            });
      }
      setState(() {
        _minutes = minutes;
        _agenda = agenda;
        _isLoading = false;
        _startTimeController.text = _minutes?.startTime ?? '';
        _openingPrayerController.text = _minutes?.openingPrayer ?? '';
        _closingPrayerController.text = _minutes?.closingPrayer ?? '';
        _adjournedAtController.text = _minutes?.meetingAdjournedAt ?? '';
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading minutes: $e')));
      }
    }
  }

  @override
  void dispose() {
    _agendaSubscription?.cancel();
    _startTimeController.dispose();
    _openingPrayerController.dispose();
    _closingPrayerController.dispose();
    _adjournedAtController.dispose();
    super.dispose();
  }

  bool _attendanceEquals(
    List<AttendanceMember> a,
    List<AttendanceMember> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].name != b[i].name ||
          a[i].affiliation != b[i].affiliation ||
          a[i].isPresent != b[i].isPresent ||
          a[i].isAbsentWithApology != b[i].isAbsentWithApology) {
        return false;
      }
    }
    return true;
  }

  Future<void> _syncMinutesFromAgenda(AdcomAgenda agenda) async {
    final minutes = _minutes;
    if (minutes == null) return;
    if (minutes.status == 'finalized') return;

    final attendanceChanged = !_attendanceEquals(
      minutes.attendanceMembers,
      agenda.attendanceMembers,
    );
    final notesChanged =
        (minutes.startTime ?? '') != (agenda.startTime ?? '') ||
        (minutes.openingPrayer ?? '') != (agenda.openingPrayer ?? '') ||
        (minutes.closingPrayer ?? '') != (agenda.closingPrayer ?? '') ||
        (minutes.meetingAdjournedAt ?? '') != (agenda.meetingAdjournedAt ?? '');

    if (!attendanceChanged && !notesChanged) return;

    final updatedMinutes = minutes.copyWith(
      attendanceMembers:
          attendanceChanged ? agenda.attendanceMembers : minutes.attendanceMembers,
      startTime: agenda.startTime ?? '',
      openingPrayer: agenda.openingPrayer ?? '',
      closingPrayer: agenda.closingPrayer ?? '',
      meetingAdjournedAt: agenda.meetingAdjournedAt ?? '',
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    setState(() {
      _minutes = updatedMinutes;
      if (notesChanged) {
        _startTimeController.text = agenda.startTime ?? '';
        _openingPrayerController.text = agenda.openingPrayer ?? '';
        _closingPrayerController.text = agenda.closingPrayer ?? '';
        _adjournedAtController.text = agenda.meetingAdjournedAt ?? '';
      }
    });

    await _service.updateMinutes(updatedMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _minutes == null
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
          const Text('Minutes not found'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleBack,
            child: const Text('Go Back'),
          ),
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
              _buildMeetingInfoCard(),
              const SizedBox(height: 24),
              _buildAttendanceCard(),
              const SizedBox(height: 24),
              _buildMinutesItemsCard(),
              const SizedBox(height: 32),
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
          colors: [Colors.teal.shade700, Colors.cyan.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
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
                tooltip: 'Back to Agenda',
                onPressed: _handleBack,
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.visibility,
                    tooltip: 'Preview Minutes',
                    onPressed: () => _openPreview(false),
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.print,
                    tooltip: 'Print Minutes',
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
                  color: Colors.white.withOpacity(0.2),
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
                    Text(
                      'ADCOM Meeting Minutes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(_minutes!.meetingDate),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
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
                  color: _minutes!.status == 'finalized'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _minutes!.status.toUpperCase(),
                  style: const TextStyle(
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _handleBack() {
    if (widget.returnToMeetingId != null) {
      context.go('/meetings/${widget.returnToMeetingId}');
    } else if (_minutes != null) {
      context.go('/admin/adcom-agenda/${_minutes!.agendaId}');
    } else {
      context.go('/admin/adcom-agendas');
    }
  }

  void _openPreview(bool isPrint) {
    final meetingQuery = widget.returnToMeetingId != null
        ? '?meetingId=${widget.returnToMeetingId}'
        : '';
    final path = isPrint
        ? '/admin/adcom-minutes/${widget.minutesId}/print$meetingQuery'
        : '/admin/adcom-minutes/${widget.minutesId}/view$meetingQuery';
    context.push(path);
  }

  Widget _buildMeetingInfoCard() {
    final organization = _agenda?.organization ?? _minutes!.organization;
    final meetingDate = _agenda?.meetingDate ?? _minutes!.meetingDate;
    final meetingTime = _agenda?.meetingTime ?? _minutes!.meetingTime;
    final location = _agenda?.location ?? _minutes!.location;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Meeting Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow('Organization', organization),
                _buildDetailRow('Date', dateFormat.format(meetingDate)),
                _buildDetailRow(
                  'Time',
                  meetingTime.isNotEmpty ? meetingTime : 'Not set',
                ),
                _buildDetailRow(
                  'Location',
                  location.isNotEmpty ? location : 'Not set',
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
    final presentMembers = _minutes!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _minutes!.attendanceMembers
        .where((m) => m.isAbsentWithApology)
        .toList();

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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_minutes!.attendanceMembers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No attendance recorded',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else ...[
                  if (presentMembers.isNotEmpty) ...[
                    Text(
                      'Present (${presentMembers.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presentMembers.map((m) {
                        return Chip(
                          label: Text('${m.name} (${m.affiliation})'),
                          backgroundColor: Colors.green.shade50,
                          labelStyle: const TextStyle(fontSize: 12),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (absentMembers.isNotEmpty) ...[
                    Text(
                      'Absent with Apology (${absentMembers.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: absentMembers.map((m) {
                        return Chip(
                          label: Text('${m.name} (${m.affiliation})'),
                          backgroundColor: Colors.orange.shade50,
                          labelStyle: const TextStyle(fontSize: 12),
                        );
                      }).toList(),
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

  Widget _buildMinutesItemsCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.list_alt, color: Colors.purple.shade600),
                const SizedBox(width: 12),
                const Text(
                  'Agenda Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _addAgendaItems,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add From Agenda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_minutes!.minutesItems.isEmpty)
            const Center(
                child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  'No items yet. Add items from the agenda to start minutes.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _minutes!.minutesItems.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _minutes!.minutesItems[index];
                return _buildMinutesItemTile(item, index);
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
            color: Colors.black.withOpacity(0.05),
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
                _buildTextField(
                  label: 'Start Time',
                  controller: _startTimeController,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Opening Prayer',
                  controller: _openingPrayerController,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  label: 'Closing Prayer',
                  controller: _closingPrayerController,
                ),
                const SizedBox(height: 12),
                _buildTextField(
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

  Widget _buildTextField({
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
    if (_minutes == null) return;
    try {
      final updatedMinutes = _minutes!.copyWith(
        startTime: _startTimeController.text.trim(),
        openingPrayer: _openingPrayerController.text.trim(),
        closingPrayer: _closingPrayerController.text.trim(),
        meetingAdjournedAt: _adjournedAtController.text.trim(),
      );
      await _service.updateMinutes(updatedMinutes);
      await _loadMinutes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving notes: $e')),
        );
      }
    }
  }

  Widget _buildMinutesItemTile(MinutesItem item, int index) {
    Color statusColor;
    IconData statusIcon;

    switch (item.status) {
      case MinutesItemStatus.voted:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case MinutesItemStatus.tabled:
        statusColor = Colors.orange;
        statusIcon = Icons.pause_circle;
        break;
      case MinutesItemStatus.discussed:
        statusColor = Colors.blue;
        statusIcon = Icons.chat_bubble;
        break;
      case MinutesItemStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.pending;
        break;
    }

    return InkWell(
      onTap: () => _editMinutesItem(item, index),
      child: Container(
        padding: const EdgeInsets.all(16),
        color: item.isNewItem ? Colors.purple.shade50.withOpacity(0.3) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item number
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.itemNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Action type
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.actionType.displayName,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.isNewItem) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              item.title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            // Description
            Text(
              item.description,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Resolution if voted
            if (item.status == MinutesItemStatus.voted &&
                item.resolution != null &&
                item.resolution!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.gavel, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.resolution!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade800,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Notes if any
            if (item.notes != null && item.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editMinutesItem(MinutesItem item, int index) async {
    final resolutionController = TextEditingController(
      text: item.resolution ?? '',
    );
    final notesController = TextEditingController(text: item.notes ?? '');
    final allowedStatuses = _allowedStatusesFor(item.actionType);
    MinutesItemStatus selectedStatus = allowedStatuses.contains(item.status)
        ? item.status
        : MinutesItemStatus.pending;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_note),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.itemNumber,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      item.title.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Status selection
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allowedStatuses.map((status) {
                        final isSelected = selectedStatus == status;
                        Color color;
                        switch (status) {
                          case MinutesItemStatus.voted:
                            color = Colors.green;
                            break;
                          case MinutesItemStatus.tabled:
                            color = Colors.orange;
                            break;
                          case MinutesItemStatus.discussed:
                            color = Colors.blue;
                            break;
                          case MinutesItemStatus.pending:
                            color = Colors.grey;
                            break;
                        }
                        return ChoiceChip(
                          label: Text(status.displayName),
                          selected: isSelected,
                          selectedColor: color.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? color : Colors.grey.shade700,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedStatus = status;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Resolution (shown when Voted)
                    if (selectedStatus == MinutesItemStatus.voted) ...[
                      Row(
                        children: [
                          const Text(
                            'Resolution',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          _buildAIButton(
                            icon: Icons.auto_fix_high,
                            label: 'Generate',
                            tooltip: 'AI Generate Resolution',
                            onPressed: () async {
                              setDialogState(() {});
                              final result = await _aiService
                                  .generateResolution(
                                    item.title,
                                    item.description,
                                  );
                              if (result.success && result.text != null) {
                                resolutionController.text = result.text!;
                                setDialogState(() {});
                              } else {
                                _showAIError(result.error ?? 'Unknown error');
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildAIButton(
                            icon: Icons.auto_awesome,
                            label: 'Enhance',
                            tooltip: 'AI Enhance Text',
                            onPressed: () async {
                              if (resolutionController.text.isEmpty) return;
                              final result = await _aiService.enhanceText(
                                resolutionController.text,
                                context: 'ADCOM meeting resolution',
                              );
                              if (result.success && result.text != null) {
                                resolutionController.text = result.text!;
                                setDialogState(() {});
                              } else {
                                _showAIError(result.error ?? 'Unknown error');
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          _buildAIButton(
                            icon: Icons.spellcheck,
                            label: 'Spell',
                            tooltip: 'Spell Check',
                            onPressed: () async {
                              if (resolutionController.text.isEmpty) return;
                              final result = await _aiService.checkSpelling(
                                resolutionController.text,
                              );
                              if (result.success) {
                                if (result.hasIssues) {
                                  _showSpellCheckResult(result, (corrected) {
                                    resolutionController.text = corrected;
                                    setDialogState(() {});
                                  });
                                } else {
                                  _showNoSpellingErrors();
                                }
                              } else {
                                _showAIError(result.error ?? 'Unknown error');
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: resolutionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter the resolution...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Notes
                    Row(
                      children: [
                        const Text(
                          'Notes / Discussion Points',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        _buildAIButton(
                          icon: Icons.auto_awesome,
                          label: 'Enhance',
                          tooltip: 'AI Enhance Text',
                          onPressed: () async {
                            if (notesController.text.isEmpty) return;
                            final result = await _aiService.enhanceText(
                              notesController.text,
                              context: 'ADCOM meeting discussion notes',
                            );
                            if (result.success && result.text != null) {
                              notesController.text = result.text!;
                              setDialogState(() {});
                            } else {
                              _showAIError(result.error ?? 'Unknown error');
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        _buildAIButton(
                          icon: Icons.spellcheck,
                          label: 'Spell',
                          tooltip: 'Spell Check',
                          onPressed: () async {
                            if (notesController.text.isEmpty) return;
                            final result = await _aiService.checkSpelling(
                              notesController.text,
                            );
                            if (result.success) {
                              if (result.hasIssues) {
                                _showSpellCheckResult(result, (corrected) {
                                  notesController.text = corrected;
                                  setDialogState(() {});
                                });
                              } else {
                                _showNoSpellingErrors();
                              }
                            } else {
                              _showAIError(result.error ?? 'Unknown error');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Add any notes or discussion points...',
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
              TextButton(
                onPressed: () => _confirmDeleteItem(index),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'status': selectedStatus,
                    'resolution': resolutionController.text,
                    'notes': notesController.text,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      final updatedItem = item.copyWith(
        status: result['status'] as MinutesItemStatus,
        resolution: result['resolution'] as String?,
        notes: result['notes'] as String?,
      );

      final updatedItems = List<MinutesItem>.from(_minutes!.minutesItems);
      updatedItems[index] = updatedItem;

      setState(() {
        _minutes = _minutes!.copyWith(
          minutesItems: updatedItems,
          updatedAt: DateTime.now(),
        );
      });

      await _service.updateMinutes(_minutes!);
    }
  }

  List<MinutesItemStatus> _allowedStatusesFor(AgendaActionType actionType) {
    return const [MinutesItemStatus.voted, MinutesItemStatus.tabled];
  }

  Future<void> _confirmDeleteItem(int index) async {
    Navigator.pop(context); // Close edit dialog first

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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

    if (confirm == true) {
      final updatedItems = List<MinutesItem>.from(_minutes!.minutesItems);
      updatedItems.removeAt(index);

      // Reorder remaining items
      for (int i = 0; i < updatedItems.length; i++) {
        updatedItems[i] = updatedItems[i].copyWith(order: i);
      }

      setState(() {
        _minutes = _minutes!.copyWith(
          minutesItems: updatedItems,
          updatedAt: DateTime.now(),
        );
      });

      await _service.updateMinutes(_minutes!);
    }
  }

  List<AgendaItem> _availableAgendaItems() {
    if (_agenda == null || _minutes == null) return [];
    final existingNumbers = _minutes!.minutesItems
        .map((item) => item.itemNumber)
        .toSet();
    final available = _agenda!.agendaItems
        .where((item) => !existingNumbers.contains(item.itemNumber))
        .toList();
    available.sort((a, b) => a.order.compareTo(b.order));
    return available;
  }

  Future<void> _addAgendaItems() async {
    if (_minutes == null) return;
    if (_agenda == null) {
      _showAIError('Agenda data not available yet.');
      return;
    }

    final availableItems = _availableAgendaItems();
    if (availableItems.isEmpty) {
      _showAIError('All agenda items are already in the minutes.');
      return;
    }

    final selected = List<bool>.filled(availableItems.length, false);
    final selectedItems = await showDialog<List<AgendaItem>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canAdd = selected.any((value) => value);
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.playlist_add),
                SizedBox(width: 8),
                Text('Add Agenda Items'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...availableItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return CheckboxListTile(
                        value: selected[index],
                        onChanged: (value) {
                          setDialogState(() {
                            selected[index] = value ?? false;
                          });
                        },
                        title: Text(item.title),
                        subtitle: Text(
                          '${item.itemNumber} • ${item.actionType.displayName}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }),
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
                onPressed: canAdd
                    ? () {
                        final picked = <AgendaItem>[];
                        for (int i = 0; i < availableItems.length; i++) {
                          if (selected[i]) {
                            picked.add(availableItems[i]);
                          }
                        }
                        Navigator.pop(context, picked);
                      }
                    : null,
                child: const Text('Add Selected'),
              ),
            ],
          );
        },
      ),
    );

    if (selectedItems == null || selectedItems.isEmpty) return;

    final updatedItems = List<MinutesItem>.from(_minutes!.minutesItems);
    for (final agendaItem in selectedItems) {
      final newOrder = updatedItems.length;
      final newItem = MinutesItem.fromAgendaItem(agendaItem).copyWith(
        order: newOrder,
        isNewItem: false,
      );
      updatedItems.add(newItem);
    }

    setState(() {
      _minutes = _minutes!.copyWith(
        minutesItems: updatedItems,
        updatedAt: DateTime.now(),
      );
    });

    await _service.updateMinutes(_minutes!);
  }

  Widget _buildAIButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.purple.shade700),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.purple.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAIError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showNoSpellingErrors() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('No spelling or grammar errors found!'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSpellCheckResult(
    SpellCheckResult result,
    Function(String) onApply,
  ) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.spellcheck, color: Colors.purple),
            SizedBox(width: 8),
            Text('Spell Check Results'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Found ${result.issues.length} issue(s):',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...result.issues.map(
                  (issue) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            issue.original,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            issue.correction,
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            issue.type,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Corrected Text:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    result.correctedText ?? '',
                    style: const TextStyle(fontSize: 13),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onApply(result.correctedText ?? '');
            },
            icon: const Icon(Icons.check),
            label: const Text('Apply Corrections'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
