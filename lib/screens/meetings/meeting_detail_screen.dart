import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/adcom_agenda.dart' as adcom;
import '../../models/adcom_minutes.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/meeting_service.dart';
import '../../utils/responsive_helper.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String meetingId;
  final String? initialTab; // 'agenda', 'minutes', 'actions'

  const MeetingDetailScreen({
    super.key,
    required this.meetingId,
    this.initialTab,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen>
    with SingleTickerProviderStateMixin {
  final MeetingService _meetingService = MeetingService();
  final AdcomAgendaService _adcomAgendaService = AdcomAgendaService();
  final AdcomMinutesService _adcomMinutesService = AdcomMinutesService();
  late TabController _tabController;

  Meeting? _meeting;
  adcom.AdcomAgenda? _adcomAgenda;
  AdcomMinutes? _adcomMinutes;
  MeetingMinutes? _minutes;
  List<MeetingActionItem> _actionItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabIndexFor(widget.initialTab);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadMeeting();
  }

  @override
  void didUpdateWidget(covariant MeetingDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      final newIndex = _tabIndexFor(widget.initialTab);
      if (_tabController.index != newIndex) {
        _tabController.animateTo(newIndex);
      }
    }
  }

  int _tabIndexFor(String? tab) {
    switch (tab) {
      case 'agenda':
        return 1;
      case 'minutes':
        return 2;
      case 'actions':
        return 0;
      default:
        return 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMeeting() async {
    setState(() => _isLoading = true);
    try {
      final meeting = await _meetingService.getMeeting(widget.meetingId);
      MeetingMinutes? minutes;
      adcom.AdcomAgenda? adcomAgenda;
      AdcomMinutes? adcomMinutes;

      if (meeting != null) {
        minutes = await _meetingService.getMinutesByMeetingId(meeting.id);
        if (meeting.agendaId != null) {
          adcomAgenda = await _adcomAgendaService.getAgendaById(
            meeting.agendaId!,
          );
          if (adcomAgenda != null) {
            adcomMinutes = await _adcomMinutesService.getMinutesByAgendaId(
              adcomAgenda.id,
            );
          }
        }
      }

      // Load action items
      _meetingService.getActionItemsByMeetingId(widget.meetingId).listen((
        items,
      ) {
        if (mounted) {
          setState(() => _actionItems = items);
        }
      });

      if (mounted) {
        setState(() {
          _meeting = meeting;
          _adcomAgenda = adcomAgenda;
          _adcomMinutes = adcomMinutes;
          _minutes = minutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading meeting: $e')));
      }
    }
  }


  void _viewGeneratedMinutes() {
    if (_adcomMinutes == null) return;
    final meetingQuery =
        _meeting != null ? '?meetingId=${_meeting!.id}&tab=minutes' : '';
    context.push('/admin/adcom-minutes/${_adcomMinutes!.id}/view$meetingQuery');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_meeting == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Meeting not found'),
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
                children: [
                  _buildDetailsTab(),
                  _buildAgendaTab(),
                  _buildMinutesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  /// Renders a description that may be Delta JSON (from QuillEditor)
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
              decoration: attrs['underline'] == true ? TextDecoration.underline : TextDecoration.none,
            ),
          ));
        }
        if (spans.isNotEmpty) {
          return Text.rich(TextSpan(style: baseStyle, children: spans));
        }
      } catch (_) {}
    }
    // Legacy markdown markers: **bold**, _italic_, <u>underline</u>
    final result = <({String text, bool bold, bool italic, bool underline})>[];
    bool bold = false, italic = false, underline = false;
    int pos = 0;
    final markers = RegExp(r'\*\*|_|<u>|</u>');
    for (final match in markers.allMatches(text)) {
      if (match.start > pos) {
        result.add((text: text.substring(pos, match.start), bold: bold, italic: italic, underline: underline));
      }
      switch (match.group(0)) {
        case '**': bold = !bold;
        case '_': italic = !italic;
        case '<u>': underline = true;
        case '</u>': underline = false;
      }
      pos = match.end;
    }
    if (pos < text.length) {
      result.add((text: text.substring(pos), bold: bold, italic: italic, underline: underline));
    }
    if (result.isEmpty) return Text(text, style: baseStyle);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: result.map((seg) => TextSpan(
          text: seg.text,
          style: TextStyle(
            fontWeight: seg.bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: seg.italic ? FontStyle.italic : FontStyle.normal,
            decoration: seg.underline ? TextDecoration.underline : TextDecoration.none,
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final color = _meeting!.type == 'board' ? Colors.purple : Colors.blue;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.shade400, color.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.shade200,
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
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/meetings-dashboard');
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Home',
                    onPressed: () => context.go('/'),
                  ),
                ],
              ),
              _buildMenuButton(),
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
                child: const Icon(Icons.groups, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _meeting!.meetingType.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _meeting!.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(_meeting!.meetingStatus),
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

  Widget _buildMenuButton() {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      onSelected: (value) => _handleMenuAction(value),
      itemBuilder: (context) => [
        if (_meeting!.status == 'scheduled')
          const PopupMenuItem(
            value: 'start',
            child: Row(
              children: [
                Icon(Icons.play_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Start Meeting'),
              ],
            ),
          ),
        if (_meeting!.status == 'inProgress')
          const PopupMenuItem(
            value: 'complete',
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Complete Meeting'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text('Edit Meeting'),
            ],
          ),
        ),
        if (_meeting!.status != 'cancelled')
          const PopupMenuItem(
            value: 'cancel',
            child: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text('Cancel Meeting'),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete Meeting'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final color = _meeting!.type == 'board' ? Colors.purple : Colors.blue;

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
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Details'),
          Tab(text: 'Agenda'),
          Tab(text: 'Minutes'),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(MeetingStatus status) {
    Color bgColor;
    switch (status) {
      case MeetingStatus.scheduled:
        bgColor = Colors.blue;
        break;
      case MeetingStatus.inProgress:
        bgColor = Colors.orange;
        break;
      case MeetingStatus.completed:
        bgColor = Colors.green;
        break;
      case MeetingStatus.cancelled:
        bgColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return RefreshIndicator(
      onRefresh: _loadMeeting,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Time Card
              _buildInfoCard(
                'Date & Time',
                Icons.event,
                [
                _buildInfoRow(
                  Icons.calendar_today,
                  'Date',
                  dateFormat.format(_meeting!.dateTime),
                ),
                _buildInfoRow(
                  Icons.access_time,
                  'Time',
                  timeFormat.format(_meeting!.dateTime),
                ),
                ],
                trailing: TextButton.icon(
                  onPressed: () => context.push('/meetings/${_meeting!.id}/edit'),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(height: 16),

              // Location Card
              if (_meeting!.location != null || _meeting!.virtualLink != null)
                _buildInfoCard('Location', Icons.location_on, [
                  if (_meeting!.location != null)
                    _buildInfoRow(Icons.room, 'Physical', _meeting!.location!),
                  if (_meeting!.virtualLink != null)
                    _buildInfoRow(
                      Icons.videocam,
                      'Virtual',
                      _meeting!.virtualLink!,
                    ),
                ]),
              if (_meeting!.location != null || _meeting!.virtualLink != null)
                const SizedBox(height: 16),

              // Roles Card
              _buildInfoCard('Meeting Roles', Icons.people, [
                _buildInfoRow(
                  Icons.person,
                  'Chairperson',
                  _meeting!.chairpersonName ?? 'Not assigned',
                ),
                _buildInfoRow(
                  Icons.edit_note,
                  'Secretary',
                  _meeting!.secretaryName ?? 'Not assigned',
                ),
              ]),
              const SizedBox(height: 16),

              // Invited Members
              if (_meeting!.invitedMembers.isNotEmpty) _buildMembersCard(),
              if (_meeting!.invitedMembers.isNotEmpty)
                const SizedBox(height: 16),

              // Action Items Summary
              _buildActionItemsSummary(),
              const SizedBox(height: 16),

              // Notes
              if (_meeting!.notes != null && _meeting!.notes!.isNotEmpty)
                _buildInfoCard('Notes', Icons.notes, [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _meeting!.notes!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ]),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    IconData icon,
    List<Widget> children, {
    Widget? trailing,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(icon, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersCard() {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              const Icon(Icons.group, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              Text(
                'Invited Members (${_meeting!.invitedMembers.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _meeting!.invitedMembers.map((member) {
              return Chip(
                avatar: CircleAvatar(
                  backgroundColor: Colors.indigo.withValues(alpha: 0.2),
                  child: Text(
                    member.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: Colors.indigo),
                  ),
                ),
                label: Text(member.name),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemsSummary() {
    final pendingItems = _actionItems
        .where((i) => i.status == 'pending' || i.status == 'inProgress')
        .toList();
    final completedItems = _actionItems
        .where((i) => i.status == 'completed')
        .toList();

    return Container(
      width: double.infinity,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.assignment, color: Colors.indigo, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Action Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showAddActionItemDialog(),
                child: const Text('Add'),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionItemStat(
                  'Pending',
                  pendingItems.length,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionItemStat(
                  'Completed',
                  completedItems.length,
                  Colors.green,
                ),
              ),
            ],
          ),
          if (pendingItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...pendingItems.take(3).map((item) {
              return _buildActionItemTile(item);
            }),
            if (pendingItems.length > 3)
              TextButton(
                onPressed: () => context.push(
                  '/meetings/action-items?meetingId=${_meeting!.id}',
                ),
                child: Text('View all ${pendingItems.length} pending items'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionItemStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionItemTile(MeetingActionItem item) {
    final isOverdue = item.isOverdue;
    final dateFormat = DateFormat('MMM d');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isOverdue ? Icons.warning : Icons.assignment,
        color: isOverdue ? Colors.red : Colors.orange,
      ),
      title: Text(
        item.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Row(
        children: [
          if (item.assigneeName != null) ...[
            Text(
              item.assigneeName!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(width: 8),
          ],
          if (item.dueDate != null)
            Text(
              dateFormat.format(item.dueDate!),
              style: TextStyle(
                fontSize: 12,
                color: isOverdue ? Colors.red : Colors.grey[600],
              ),
            ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
        onSelected: (value) async {
          if (value == 'complete') {
            await _meetingService.updateActionItemStatus(item.id, 'completed');
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'complete', child: Text('Mark Complete')),
        ],
      ),
    );
  }

  Widget _buildAgendaTab() {
    // Use ADCOM-style agenda for both ADCOM and HC Board meetings
    if (_adcomAgenda == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No agenda created yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _createAgenda(),
              icon: const Icon(Icons.add),
              label: const Text('Create Agenda'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMeeting,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdcomAgendaStatusCard(),
              const SizedBox(height: 16),
              if (_adcomAgenda!.agendaItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
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
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.playlist_add,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No agenda items yet',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openAdcomAgendaEditor(),
                          icon: const Icon(Icons.edit),
                          label: const Text('Open Agenda Editor'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Agenda Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ..._adcomAgenda!.agendaItems.map(
                  (item) => _buildAdcomAgendaItemPreview(item),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAdcomAgendaEditor(),
                    icon: const Icon(Icons.edit),
                    label: const Text('Open Agenda Editor'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildAdcomAgendaStatusCard() {
    final status = _adcomAgenda!.status;
    Color statusColor;
    switch (status) {
      case 'finalized':
        statusColor = Colors.green;
        break;
      case 'draft':
      default:
        statusColor = Colors.grey;
        break;
    }

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_adcomAgenda!.agendaItems.length} items',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _openAdcomAgendaEditor(),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdcomAgendaItemPreview(adcom.AgendaItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item.itemNumber,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.actionType.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDescriptionWidget(
              item.description,
              TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMinutesTab() {
    // Use ADCOM-style minutes for both ADCOM and HC Board meetings
    if (_adcomAgenda == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Create an agenda first',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_adcomMinutes == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No minutes recorded yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _generateMinutesFromAgenda(),
              icon: const Icon(Icons.add),
              label: const Text('Generate Minutes from Agenda'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMeeting,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAdcomMinutesStatusCard(),
              const SizedBox(height: 16),
              if (_adcomMinutes!.minutesItems.isNotEmpty) ...[
                Text(
                  'Minutes Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                ..._adcomMinutes!.minutesItems.map(
                  (item) => _buildAdcomMinutesItemPreview(item),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdcomMinutesStatusCard() {
    final status = _adcomMinutes!.status;
    Color statusColor;
    switch (status) {
      case 'finalized':
        statusColor = Colors.green;
        break;
      case 'draft':
      default:
        statusColor = Colors.grey;
        break;
    }

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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_adcomMinutes!.minutesItems.length} items',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _viewGeneratedMinutes,
            icon: const Icon(Icons.visibility),
            label: const Text('View'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _openAdcomMinutesEditor(),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdcomMinutesItemPreview(MinutesItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                item.itemNumber,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildDescriptionWidget(
              item.description,
              TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (_tabController.index == 1 && _adcomAgenda != null) {
      return FloatingActionButton(
        onPressed: () => _openAdcomAgendaEditor(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.edit),
      );
    } else if (_tabController.index == 2 && _adcomMinutes != null) {
      return FloatingActionButton(
        onPressed: () => _openAdcomMinutesEditor(),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.edit),
      );
    }
    return null;
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'start':
        await _meetingService.updateMeetingStatus(_meeting!.id, 'inProgress');
        _loadMeeting();
        break;
      case 'complete':
        await _meetingService.updateMeetingStatus(_meeting!.id, 'completed');
        _loadMeeting();
        break;
      case 'cancel':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Meeting'),
            content: const Text(
              'Are you sure you want to cancel this meeting?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _meetingService.updateMeetingStatus(_meeting!.id, 'cancelled');
          _loadMeeting();
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Meeting'),
            content: const Text(
              'Are you sure you want to delete this meeting? This will also delete the agenda, minutes, and action items.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await _meetingService.deleteMeeting(_meeting!.id);
          if (mounted) {
            context.go('/meetings-dashboard');
          }
        }
        break;
      case 'edit':
        context.push('/meetings/${_meeting!.id}/edit');
        break;
    }
  }

  Future<void> _createAgenda() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    final meeting = _meeting!;
    final now = DateTime.now();

    // Use ADCOM-style agenda for both ADCOM and HC Board meetings
    final attendanceMembers = meeting.invitedMembers.map((member) {
      return adcom.AttendanceMember(
        name: member.name,
        affiliation: member.organization ?? 'HC',
        isPresent: true,
        isAbsentWithApology: false,
      );
    }).toList();

    // Determine organization name for item number format
    final organizationLabel = meeting.type == 'adcom'
        ? 'ADCOM'
        : 'HC Board';

    final agenda = adcom.AdcomAgenda(
      id: '',
      organization: organizationLabel,
      meetingDate: meeting.dateTime,
      meetingTime: DateFormat('h:mm a').format(meeting.dateTime),
      location: meeting.locationDescription,
      attendanceMembers: attendanceMembers,
      agendaItems: const [],
      status: 'draft',
      startingItemSequence: 1,
      createdAt: now,
      updatedAt: now,
      createdBy: user?.id ?? '',
    );

    final agendaId = await _adcomAgendaService.createAgenda(agenda);
    await _meetingService.updateMeeting(
      meeting.copyWith(agendaId: agendaId, updatedAt: now),
    );
    await _loadMeeting();
    if (mounted) {
      await _openAdcomAgendaEditor(agendaId: agendaId);
    }
  }

  Future<void> _openAdcomAgendaEditor({String? agendaId}) async {
    final id = agendaId ?? _adcomAgenda?.id;
    if (id == null) return;

    final meetingId = _meeting!.id;
    await context.push('/admin/adcom-agenda/$id?meetingId=$meetingId');
    if (mounted) {
      _loadMeeting();
    }
  }

  Future<void> _generateMinutesFromAgenda() async {
    if (_adcomAgenda == null) return;
    try {
      final minutesId = await _adcomMinutesService.createMinutesFromAgenda(
        _adcomAgenda!,
      );
      if (mounted) {
        await context.push(
          '/admin/adcom-minutes/$minutesId?meetingId=${_meeting!.id}',
        );
        _loadMeeting();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating minutes: $e')));
      }
    }
  }

  Future<void> _openAdcomMinutesEditor() async {
    final minutes = _adcomMinutes;
    if (minutes == null) return;
    await context.push(
      '/admin/adcom-minutes/${minutes.id}?meetingId=${_meeting!.id}',
    );
    if (mounted) {
      _loadMeeting();
    }
  }

  void _showAddActionItemDialog() {
    final descriptionController = TextEditingController();
    String? assigneeId;
    String? assigneeName;
    DateTime? dueDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Action Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: assigneeId,
                      decoration: const InputDecoration(
                        labelText: 'Assignee',
                        border: OutlineInputBorder(),
                      ),
                      items: _availableUsers.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['id'] as String,
                          child: Text(user['name'] as String),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          assigneeId = value;
                          assigneeName =
                              _availableUsers.firstWhere(
                                    (u) => u['id'] == value,
                                  )['name']
                                  as String?;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event),
                      title: Text(
                        dueDate != null
                            ? DateFormat('MMM d, yyyy').format(dueDate!)
                            : 'Select Due Date',
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 7),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
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
                  onPressed: () async {
                    if (descriptionController.text.trim().isEmpty) return;

                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final user = authProvider.currentUser;

                    final actionItem = MeetingActionItem(
                      id: '',
                      meetingId: _meeting!.id,
                      description: descriptionController.text.trim(),
                      assigneeId: assigneeId,
                      assigneeName: assigneeName,
                      dueDate: dueDate,
                      status: 'pending',
                      createdBy: user?.id ?? '',
                      createdAt: DateTime.now(),
                    );

                    await _meetingService.createActionItem(actionItem);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> get _availableUsers {
    final members = _meeting?.invitedMembers ?? [];
    return members.map((m) {
      return {'id': m.oderId, 'name': m.name, 'email': m.email ?? ''};
    }).toList();
  }
}
