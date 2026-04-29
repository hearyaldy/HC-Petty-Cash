import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/adcom_agenda.dart' as adcom;
import '../../models/adcom_minutes.dart';
import '../../models/meeting.dart';
import '../../providers/auth_provider.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/meeting_email_service.dart';
import '../../services/meeting_service.dart';
import '../../utils/rich_html_clipboard.dart';
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
  static const String _publicVoteBaseUrl =
      'https://hc-petty-cash-report.web.app';
  static const String _emailHeaderLogoUrl =
      '$_publicVoteBaseUrl/assets/assets/images/hope_channel_logo.png';
  final MeetingService _meetingService = MeetingService();
  final MeetingEmailService _meetingEmailService = MeetingEmailService();
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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
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
    final meetingQuery = _meeting != null
        ? '?meetingId=${_meeting!.id}&tab=minutes'
        : '';
    context.push('/admin/adcom-minutes/${_adcomMinutes!.id}/view$meetingQuery');
  }

  String _buildVoteUrl(String token) {
    return '$_publicVoteBaseUrl/meeting-vote/$token';
  }

  String? _resolveMemberEmail(MeetingVoteToken tokenRecord) {
    final tokenEmail = tokenRecord.memberEmail?.trim();
    if (tokenEmail != null && tokenEmail.isNotEmpty) {
      return tokenEmail;
    }

    final meeting = _meeting;
    if (meeting == null) return null;

    for (final member in meeting.invitedMembers) {
      final memberEmail = member.invitationEmail;
      if (memberEmail == null || memberEmail.isEmpty) continue;

      final matchesId = member.oderId.trim() == tokenRecord.memberId.trim();
      final matchesName =
          member.name.trim().toLowerCase() ==
          tokenRecord.memberName.trim().toLowerCase();
      if (matchesId || matchesName) {
        return memberEmail;
      }
    }

    return null;
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _descriptionToHtml(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('[')) {
      try {
        final List<dynamic> ops = jsonDecode(trimmed) as List;
        final buffer = StringBuffer();
        for (final op in ops) {
          if (op is! Map) continue;
          final insert = op['insert'];
          if (insert is! String || insert.isEmpty) continue;
          final attrs = (op['attributes'] as Map?) ?? {};
          var segment = _escapeHtml(insert).replaceAll('\n', '<br />');
          if (attrs['underline'] == true) segment = '<u>$segment</u>';
          if (attrs['italic'] == true) segment = '<em>$segment</em>';
          if (attrs['bold'] == true) segment = '<strong>$segment</strong>';
          buffer.write(segment);
        }
        final html = buffer.toString().trim();
        if (html.isNotEmpty) return html;
      } catch (_) {}
    }

    if (trimmed.contains('<')) {
      return _plainTextToHtml(_stripHtmlMarkup(trimmed));
    }

    return _escapeHtml(trimmed)
        .replaceAllMapped(
          RegExp(r'\*\*(.+?)\*\*'),
          (m) => '<strong>${m[1]}</strong>',
        )
        .replaceAllMapped(RegExp(r'_(.+?)_'), (m) => '<em>${m[1]}</em>')
        .replaceAll('\n', '<br />');
  }

  String _plainTextToHtml(String text) {
    return _escapeHtml(text).replaceAll('\n', '<br />');
  }

  String _stripHtmlMarkup(String text) {
    if (!text.contains('<')) return text;
    return text
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li\s*>', caseSensitive: false), '- ')
        .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _buildVoteInvitationHtml(MeetingVoteToken tokenRecord) {
    final meeting = _meeting!;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final deadlineFormat = DateFormat('EEEE, MMMM d, yyyy h:mm a');
    final link = _buildVoteUrl(tokenRecord.token);
    final purpose = meeting.notes?.trim();
    final agendaItems = _adcomAgenda?.agendaItems ?? const <adcom.AgendaItem>[];

    final purposeBlock = purpose != null && purpose.isNotEmpty
        ? '''
        <div style="margin-top:16px;padding:16px;border-radius:12px;background:#eef2ff;border:1px solid #c7d2fe;">
          <div style="font-size:12px;font-weight:700;letter-spacing:0.08em;color:#4338ca;text-transform:uppercase;">Purpose / Explanation</div>
          <div style="margin-top:8px;font-size:14px;line-height:1.6;color:#334155;">${_descriptionToHtml(purpose)}</div>
        </div>
        '''
        : '';
    final agendaBlock = agendaItems.isEmpty
        ? '''
        <div style="margin-top:16px;padding:16px;border-radius:12px;background:#fff7ed;border:1px solid #fed7aa;">
          <div style="font-size:12px;font-weight:700;letter-spacing:0.08em;color:#c2410c;text-transform:uppercase;">Agenda</div>
          <div style="margin-top:8px;font-size:14px;line-height:1.6;color:#7c2d12;">No agenda items are attached yet. Please open the vote page to check the latest details.</div>
        </div>
        '''
        : '''
        <div style="margin-top:16px;padding:16px;border-radius:12px;background:#f8fafc;border:1px solid #cbd5e1;">
          <div style="font-size:12px;font-weight:700;letter-spacing:0.08em;color:#334155;text-transform:uppercase;">Agenda Items</div>
          <div style="margin-top:12px;">
            ${agendaItems.map((item) {
            final itemNumber = item.itemNumber.trim().isNotEmpty ? '${_escapeHtml(item.itemNumber)} ' : '';
            final descriptionHtml = _descriptionToHtml(item.description);
            final description = descriptionHtml.isNotEmpty ? '<div style="margin-top:4px;font-size:13px;line-height:1.55;color:#475569;">$descriptionHtml</div>' : '';
            return '''
              <div style="padding:12px 0;border-top:1px solid #e2e8f0;">
                <div style="font-size:14px;font-weight:700;color:#0f172a;">$itemNumber${_escapeHtml(item.title.trim())}</div>
                $description
              </div>
              ''';
          }).join('')}
          </div>
        </div>
        ''';

    return '''
<div style="background:#eef4f8;padding:32px 18px;font-family:Helvetica,Arial,sans-serif;color:#0f172a;">
  <div style="max-width:680px;margin:0 auto;background:#ffffff;border:1px solid #d9e5ee;border-radius:24px;overflow:hidden;box-shadow:0 18px 40px rgba(15,23,42,0.08);">
    <div style="padding:36px 32px 30px;background:#0f4c5c;color:#ffffff;">
      <table role="presentation" style="border-collapse:collapse;margin:0 0 18px 0;">
        <tr>
          <td style="vertical-align:middle;padding:0 12px 0 0;">
            <div style="display:inline-block;padding:8px 12px;border-radius:14px;background:#ffffff;">
              <img src="$_emailHeaderLogoUrl" alt="Hope Channel SEA" width="72" style="display:block;width:72px;max-width:100%;height:auto;border:0;outline:none;text-decoration:none;" />
            </div>
          </td>
          <td style="vertical-align:middle;">
            <div style="display:inline-block;padding:7px 12px;border-radius:999px;background:rgba(255,255,255,0.18);font-size:11px;font-weight:800;letter-spacing:0.14em;text-transform:uppercase;">HCSEA E-VOTE</div>
          </td>
        </tr>
      </table>
      <div style="margin-top:18px;font-size:30px;font-weight:800;line-height:1.2;">${_escapeHtml(meeting.title)}</div>
      <div style="margin-top:12px;font-size:16px;line-height:1.65;max-width:520px;color:rgba(255,255,255,0.92);">Dear ${_escapeHtml(tokenRecord.memberName)}, you are invited to review the board materials and cast your vote securely online.</div>
    </div>
    <div style="padding:30px 32px 34px;">
      <div style="padding:18px 20px;border-radius:18px;background:#f8fbfd;border:1px solid #d9e5ee;">
        <table role="presentation" style="width:100%;border-collapse:collapse;">
          <tr>
            <td style="width:50%;padding:0 12px 14px 0;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Meeting Date</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(dateFormat.format(meeting.dateTime))}</div>
            </td>
            <td style="width:50%;padding:0 0 14px 12px;vertical-align:top;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Meeting Time</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(timeFormat.format(meeting.dateTime))}</div>
            </td>
          </tr>
          <tr>
            <td colspan="2" style="padding:0;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Voting PIN</div>
              <div style="margin-top:8px;display:inline-block;padding:10px 14px;border-radius:14px;background:#0f4c5c;color:#ffffff;font-size:22px;font-weight:800;letter-spacing:0.16em;">${_escapeHtml(tokenRecord.pin)}</div>
            </td>
          </tr>
          <tr>
            <td colspan="2" style="padding:16px 0 0 0;">
              <div style="font-size:11px;font-weight:800;letter-spacing:0.12em;text-transform:uppercase;color:#5c7c8a;">Voting Deadline</div>
              <div style="margin-top:6px;font-size:15px;font-weight:700;color:#12303b;">${_escapeHtml(deadlineFormat.format(tokenRecord.expiresAt))}</div>
            </td>
          </tr>
        </table>
      </div>
      $purposeBlock
      $agendaBlock
      <div style="margin-top:24px;padding:18px 20px;border-radius:18px;background:#fff8e8;border:1px solid #f4d58d;">
        <div style="font-size:12px;font-weight:800;letter-spacing:0.1em;text-transform:uppercase;color:#9a6700;">Action Required</div>
        <div style="margin-top:8px;font-size:14px;line-height:1.7;color:#5a4300;">Please review the attached details and submit your vote using the secure button below. You may update your response until the voting window closes.</div>
      </div>
      <div style="margin-top:28px;text-align:center;">
        <a href="$link" style="display:inline-block;padding:15px 28px;border-radius:999px;background:#0f4c5c;color:#ffffff;text-decoration:none;font-size:14px;font-weight:800;letter-spacing:0.08em;text-transform:uppercase;">Open Voting Page</a>
      </div>
      <div style="margin-top:22px;font-size:13px;line-height:1.7;color:#5c6f7a;">
        This private link is intended only for ${_escapeHtml(tokenRecord.memberName)}. Please do not forward it.
      </div>
      <div style="margin-top:16px;padding-top:16px;border-top:1px solid #e2e8f0;font-size:12px;line-height:1.7;color:#7c8c96;word-break:break-all;">
        If the button above does not open, use this secure voting link:<br />
        <a href="$link" style="color:#0f4c5c;text-decoration:none;font-weight:700;">$link</a>
      </div>
    </div>
  </div>
</div>
''';
  }

  String _buildVoteInvitationHtmlDocument(MeetingVoteToken tokenRecord) {
    return '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>E-Vote Invitation</title>
  </head>
  <body style="margin:0;padding:0;background:#f8fafc;">
    ${_buildVoteInvitationHtml(tokenRecord)}
  </body>
</html>
''';
  }

  Future<void> _generateVoteInvitations() async {
    if (_meeting == null) return;

    // Ask for voting deadline before generating tokens
    final deadline = await _pickVoteDeadline(
      initialDate: _meeting!.dateTime.isAfter(DateTime.now())
          ? _meeting!.dateTime.add(const Duration(days: 14))
          : DateTime.now().add(const Duration(days: 14)),
    );
    if (deadline == null || !mounted) return;

    final tokens = await _meetingService.ensureVoteTokensForMeeting(
      _meeting!,
      customExpiry: deadline,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Generated ${tokens.length} private vote link${tokens.length == 1 ? '' : 's'} — deadline ${DateFormat('dd MMM yyyy').format(deadline)}.',
        ),
      ),
    );
    setState(() {});
  }

  /// Shows a date (and optional time) picker and returns the chosen deadline,
  /// or null if the user cancelled.
  Future<DateTime?> _pickVoteDeadline({required DateTime initialDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select Voting Deadline',
      confirmText: 'Set Deadline',
    );
    if (picked == null) return null;

    // Also ask for an end-of-day time (default 23:59)
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      helpText: 'Voting closes at (local time)',
    );
    if (time == null) return null;

    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _resetVoteInvitations() async {
    if (_meeting == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Reset E-Vote Links?'),
              content: const Text(
                'This will revoke all current e-vote links and create a fresh link and PIN for each invited member. Older copied invitations will stop working.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Reset Links'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed || !mounted) return;

    // Ask for the new voting deadline
    final deadline = await _pickVoteDeadline(
      initialDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (deadline == null || !mounted) return;

    final tokens = await _meetingService.resetVoteTokensForMeeting(
      _meeting!,
      customExpiry: deadline,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created ${tokens.length} fresh vote link${tokens.length == 1 ? '' : 's'} — deadline ${DateFormat('dd MMM yyyy').format(deadline)}. Older links are now inactive.',
        ),
      ),
    );
    setState(() {});
  }

  Future<void> _resetSingleVote(MeetingVoteToken tokenRecord) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Vote?'),
        content: Text(
          'This will delete ${tokenRecord.memberName}\'s submitted vote. Their link and PIN will remain valid so they can vote again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Vote'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _meetingService.resetVoteForToken(tokenRecord.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vote reset for ${tokenRecord.memberName}.')),
    );
  }

  Future<void> _resetAllVotes() async {
    if (_meeting == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Votes?'),
        content: const Text(
          'This will delete every submitted vote for this meeting. All members will need to vote again. Links and PINs are NOT changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset All Votes'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _meetingService.resetAllVotesForMeeting(_meeting!.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All votes have been reset.')));
  }

  Future<void> _copyVoteInvitationHtml(MeetingVoteToken tokenRecord) async {
    final html = _buildVoteInvitationHtml(tokenRecord);
    final copiedRichHtml = await copyRichHtmlToClipboard(html);
    if (!copiedRichHtml) {
      await Clipboard.setData(ClipboardData(text: html));
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copiedRichHtml
              ? 'Styled email copied for ${tokenRecord.memberName}.'
              : 'Styled email HTML copied for ${tokenRecord.memberName}.',
        ),
      ),
    );
  }

  String _buildVoteInvitationSubject(MeetingVoteToken tokenRecord) {
    final meeting = _meeting!;
    return 'E-Vote Invitation: ${meeting.title}';
  }

  Future<void> _sendStyledVoteInvitation({
    required MeetingVoteToken tokenRecord,
    required String recipientEmail,
    required String recipientName,
    required String successMessage,
  }) async {
    if (recipientEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient email address is missing.')),
      );
      return;
    }

    try {
      await _meetingEmailService.sendStyledInvitation(
        recipientEmail: recipientEmail,
        recipientName: recipientName,
        subject: _buildVoteInvitationSubject(tokenRecord),
        htmlBody: _buildVoteInvitationHtml(tokenRecord),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send styled invitation: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _sendStyledVoteInvitationToInvitee(
    MeetingVoteToken tokenRecord,
  ) async {
    final recipientEmail = _resolveMemberEmail(tokenRecord);
    if (recipientEmail == null || recipientEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No email address saved for ${tokenRecord.memberName}.',
          ),
        ),
      );
      return;
    }

    await _sendStyledVoteInvitation(
      tokenRecord: tokenRecord,
      recipientEmail: recipientEmail,
      recipientName: tokenRecord.memberName,
      successMessage: 'Styled invitation sent to ${tokenRecord.memberName}.',
    );
  }

  Future<void> _sendStyledVoteInvitationToMyMailbox(
    MeetingVoteToken tokenRecord,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final currentUserEmail = currentUser?.email.trim() ?? '';
    if (currentUserEmail.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account does not have an email address to receive the preview.',
          ),
        ),
      );
      return;
    }

    await _sendStyledVoteInvitation(
      tokenRecord: tokenRecord,
      recipientEmail: currentUserEmail,
      recipientName: currentUser?.name ?? 'Team Member',
      successMessage: 'Styled preview email sent to your mailbox.',
    );
  }

  Future<void> _openVoteInvitationPreview(MeetingVoteToken tokenRecord) async {
    if (_meeting == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 860),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Styled Email Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildStyledInvitationPreviewCard(tokenRecord),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyVoteInvitationHtml(tokenRecord),
                      icon: const Icon(Icons.html),
                      label: const Text('Copy Styled'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          _sendStyledVoteInvitationToMyMailbox(tokenRecord),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('Send to Me'),
                    ),
                    FilledButton.icon(
                      onPressed: () =>
                          _sendStyledVoteInvitationToInvitee(tokenRecord),
                      icon: const Icon(Icons.mark_email_read_outlined),
                      label: const Text('Send to Invitee'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledInvitationPreviewCard(MeetingVoteToken tokenRecord) {
    final meeting = _meeting!;
    final recipientEmail = _resolveMemberEmail(tokenRecord);
    final purpose = meeting.notes?.trim();
    final agendaItems = _adcomAgenda?.agendaItems ?? const <adcom.AgendaItem>[];
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final deadlineFormat = DateFormat('EEEE, MMMM d, yyyy h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD9E5EE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F4C5C),
                  Color(0xFF1F7A8C),
                  Color(0xFFBFDBF7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Image.asset(
                          'assets/images/hope_channel_logo.png',
                          height: 17,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'HCSEA E-VOTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  meeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Dear ${tokenRecord.memberName}, you are invited to review the board materials and cast your vote securely online.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
                if (recipientEmail != null && recipientEmail.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    recipientEmail,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBFD),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD9E5EE)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildPreviewInfoBlock(
                              'Meeting Date',
                              dateFormat.format(meeting.dateTime),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildPreviewInfoBlock(
                              'Meeting Time',
                              timeFormat.format(meeting.dateTime),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildPreviewPinBlock(tokenRecord.pin),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildPreviewInfoBlock(
                          'Voting Deadline',
                          deadlineFormat.format(tokenRecord.expiresAt),
                        ),
                      ),
                    ],
                  ),
                ),
                if (purpose != null && purpose.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _buildPreviewSection(
                    title: 'Purpose / Explanation',
                    titleColor: const Color(0xFF4338CA),
                    background: const Color(0xFFEEF2FF),
                    border: const Color(0xFFC7D2FE),
                    child: _buildDescriptionWidget(
                      purpose,
                      const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                        height: 1.65,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _buildPreviewSection(
                  title: 'Agenda Items',
                  titleColor: agendaItems.isEmpty
                      ? const Color(0xFFC2410C)
                      : const Color(0xFF334155),
                  background: agendaItems.isEmpty
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFF8FAFC),
                  border: agendaItems.isEmpty
                      ? const Color(0xFFFED7AA)
                      : const Color(0xFFCBD5E1),
                  child: agendaItems.isEmpty
                      ? const Text(
                          'No agenda items are attached yet. Please open the vote page to check the latest details.',
                          style: TextStyle(
                            color: Color(0xFF7C2D12),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        )
                      : Column(
                          children: agendaItems.map((item) {
                            final itemNumber = item.itemNumber.trim().isNotEmpty
                                ? '${item.itemNumber} '
                                : '';
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 12),
                              padding: const EdgeInsets.only(top: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$itemNumber${item.title.trim()}',
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (item.description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    _buildDescriptionWidget(
                                      item.description.trim(),
                                      const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                        height: 1.55,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 20),
                _buildPreviewSection(
                  title: 'Action Required',
                  titleColor: const Color(0xFF9A6700),
                  background: const Color(0xFFFFF8E8),
                  border: const Color(0xFFF4D58D),
                  child: const Text(
                    'Please review the attached details and submit your vote using the secure link below. You may update your response until the voting window closes.',
                    style: TextStyle(
                      color: Color(0xFF5A4300),
                      fontSize: 14,
                      height: 1.65,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F4C5C),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'OPEN VOTING PAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'This private link is intended only for ${tokenRecord.memberName}. Please do not forward it.',
                  style: const TextStyle(
                    color: Color(0xFF5C6F7A),
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: SelectableText(
                    _buildVoteUrl(tokenRecord.token),
                    style: const TextStyle(
                      color: Color(0xFF0F4C5C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewInfoBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF5C7C8A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF12303B),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewPinBlock(String pin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VOTING PIN',
          style: TextStyle(
            color: Color(0xFF5C7C8A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F4C5C),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            pin,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewSection({
    required String title,
    required Color titleColor,
    required Color background,
    required Color border,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: titleColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Future<void> _copyAllVoteLinks(List<MeetingVoteToken> tokens) async {
    if (_meeting == null) return;

    final buffer = StringBuffer();
    buffer.writeln('E-Vote links for ${_meeting!.title}');
    buffer.writeln();
    for (final token in tokens) {
      buffer.writeln(
        '${token.memberName}${token.memberEmail != null ? ' <${token.memberEmail}>' : ''}',
      );
      buffer.writeln('PIN: ${token.pin}');
      buffer.writeln(_buildVoteUrl(token.token));
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('All vote links copied.')));
  }

  Future<void> _copyAllVoteLinksHtml(List<MeetingVoteToken> tokens) async {
    if (_meeting == null) return;

    final sections = tokens
        .map((token) => _buildVoteInvitationHtml(token))
        .join(
          '\n<hr style="margin:32px 0;border:none;border-top:1px solid #e2e8f0;" />\n',
        );

    final copiedRichHtml = await copyRichHtmlToClipboard(sections);
    if (!copiedRichHtml) {
      await Clipboard.setData(ClipboardData(text: sections));
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copiedRichHtml
              ? 'All styled emails copied for pasting into Outlook or another rich email editor.'
              : 'All styled email HTML copied. Paste into an HTML-capable email editor.',
        ),
      ),
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

  List<TextSpan> _markdownToSpans(String text) {
    if (text.isEmpty) return [];
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
    if (result.isEmpty) return [TextSpan(text: text)];
    return result
        .map(
          (seg) => TextSpan(
            text: seg.text,
            style: TextStyle(
              fontWeight: seg.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: seg.italic ? FontStyle.italic : FontStyle.normal,
              decoration: seg.underline
                  ? TextDecoration.underline
                  : TextDecoration.none,
            ),
          ),
        )
        .toList();
  }

  /// Renders a description that may be Delta JSON (from QuillEditor),
  /// HTML, or plain/markdown text. AI-generated markdown inside delta ops
  /// (e.g. **bold**) is rendered as formatting, not shown literally.
  Widget _buildDescriptionWidget(String text, TextStyle baseStyle) {
    final normalized = text.trim();
    if (normalized.isEmpty) return const SizedBox.shrink();

    // ── Quill delta JSON ─────────────────────────────────────────────────────
    if (normalized.startsWith('[') || normalized.startsWith('{')) {
      try {
        List<dynamic> ops;
        if (normalized.startsWith('[')) {
          ops = jsonDecode(normalized) as List;
        } else {
          final map = jsonDecode(normalized) as Map;
          ops = map['ops'] as List? ?? [];
        }
        final spans = <TextSpan>[];
        for (final op in ops) {
          if (op is! Map) continue;
          final insert = op['insert'];
          if (insert is! String || insert.isEmpty) continue;
          final attrs = (op['attributes'] as Map?) ?? {};
          final bool hasBold = attrs['bold'] == true;
          final bool hasItalic = attrs['italic'] == true;
          final bool hasUnderline = attrs['underline'] == true;
          if (hasBold || hasItalic || hasUnderline) {
            spans.add(TextSpan(
              text: insert,
              style: TextStyle(
                fontWeight: hasBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: hasItalic ? FontStyle.italic : FontStyle.normal,
                decoration: hasUnderline
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ));
          } else {
            // No Quill attributes — process inline markdown (AI output).
            spans.addAll(_markdownToSpans(insert));
          }
        }
        if (spans.isNotEmpty) {
          return Text.rich(TextSpan(style: baseStyle, children: spans));
        }
      } catch (_) {}
    }

    // ── HTML ─────────────────────────────────────────────────────────────────
    if (normalized.contains('<')) {
      final stripped = _stripHtmlMarkup(normalized);
      return Text.rich(TextSpan(style: baseStyle, children: _markdownToSpans(stripped)));
    }

    // ── Plain text / markdown ─────────────────────────────────────────────────
    return Text.rich(TextSpan(style: baseStyle, children: _markdownToSpans(normalized)));
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
                  onPressed: () =>
                      context.push('/meetings/${_meeting!.id}/edit'),
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

              if (_meeting!.meetingMode == MeetingMode.evote) _buildEvoteCard(),
              if (_meeting!.meetingMode == MeetingMode.evote)
                const SizedBox(height: 16),

              // Action Items Summary
              _buildActionItemsSummary(),
              const SizedBox(height: 16),

              // Notes
              if (_meeting!.notes != null && _meeting!.notes!.isNotEmpty)
                _buildInfoCard(
                  _meeting!.meetingMode == MeetingMode.evote
                      ? 'E-Vote Purpose'
                      : 'Notes',
                  Icons.notes,
                  [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _buildDescriptionWidget(
                        _meeting!.notes!,
                        TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),

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
              if (trailing != null) ...[const Spacer(), trailing],
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

  Widget _buildEvoteCard() {
    return StreamBuilder<List<MeetingVoteToken>>(
      stream: _meetingService.streamVoteTokensForMeeting(_meeting!.id),
      builder: (context, tokenSnapshot) {
        final allTokens = tokenSnapshot.data ?? const <MeetingVoteToken>[];
        final tokens = allTokens.where((token) => !token.revoked).toList();

        return StreamBuilder<List<MeetingVote>>(
          stream: _meetingService.streamVotesForMeeting(_meeting!.id),
          builder: (context, voteSnapshot) {
            final activeTokenIds = tokens.map((token) => token.id).toSet();
            final votes = (voteSnapshot.data ?? const <MeetingVote>[])
                .where((vote) => activeTokenIds.contains(vote.tokenId))
                .toList();
            final approveCount = votes
                .where((vote) => vote.choice == MeetingVoteChoice.approve.value)
                .length;
            final rejectCount = votes
                .where((vote) => vote.choice == MeetingVoteChoice.reject.value)
                .length;
            final abstainCount = votes
                .where((vote) => vote.choice == MeetingVoteChoice.abstain.value)
                .length;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.how_to_vote,
                        color: Colors.indigo,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'E-Vote Invitations',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create one private link per invited member. Voters will see the attached agenda items and the e-vote purpose/explanation on their vote page.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildEvoteStat('Invited', tokens.length, Colors.indigo),
                      _buildEvoteStat(
                        'Voted',
                        tokens.where((token) => token.hasVoted).length,
                        Colors.green,
                      ),
                      _buildEvoteStat('Approve', approveCount, Colors.green),
                      _buildEvoteStat('Reject', rejectCount, Colors.red),
                      _buildEvoteStat('Abstain', abstainCount, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _generateVoteInvitations,
                        icon: const Icon(Icons.link),
                        label: Text(
                          tokens.isEmpty ? 'Generate Links' : 'Refresh Links',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: tokens.isEmpty
                            ? null
                            : _resetVoteInvitations,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset Links'),
                      ),
                      OutlinedButton.icon(
                        onPressed: tokens.isEmpty
                            ? null
                            : () => _copyAllVoteLinks(tokens),
                        icon: const Icon(Icons.copy_all),
                        label: const Text('Copy All Links'),
                      ),
                      OutlinedButton.icon(
                        onPressed: tokens.isEmpty
                            ? null
                            : () => _copyAllVoteLinksHtml(tokens),
                        icon: const Icon(Icons.html),
                        label: const Text('Copy All Styled'),
                      ),
                      OutlinedButton.icon(
                        onPressed: votes.isEmpty ? null : _resetAllVotes,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Reset All Votes'),
                      ),
                    ],
                  ),
                  if (tokens.isEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'No vote links generated yet. Create the private links first, then copy them into your email invitations.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      'Only the active links and PINs shown below should be used for voting.',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...tokens.map((tokenRecord) {
                      final recipientEmail = _resolveMemberEmail(tokenRecord);
                      final vote = votes.cast<MeetingVote?>().firstWhere(
                        (item) => item?.tokenId == tokenRecord.id,
                        orElse: () => null,
                      );
                      final statusColor = tokenRecord.hasVoted
                          ? Colors.green
                          : Colors.orange;
                      final statusLabel = tokenRecord.hasVoted
                          ? 'Voted'
                          : 'Pending';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tokenRecord.memberName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (recipientEmail != null &&
                                          recipientEmail.isNotEmpty)
                                        Text(
                                          recipientEmail,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13,
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
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              'PIN: ${tokenRecord.pin}',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              _buildVoteUrl(tokenRecord.token),
                              style: TextStyle(
                                color: Colors.indigo[700],
                                fontSize: 13,
                              ),
                            ),
                            if (vote != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Vote: ${vote.voteChoice.displayName}'
                                '${vote.comment != null && vote.comment!.isNotEmpty ? ' • ${vote.comment}' : ''}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.icon(
                                  onPressed: () =>
                                      _openVoteInvitationPreview(tokenRecord),
                                  icon: const Icon(Icons.mark_email_read_outlined),
                                  label: const Text('Email Invitation'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    final url =
                                        '${_buildVoteUrl(tokenRecord.token)}?pin=${tokenRecord.pin}';
                                    html.window.open(url, '_blank');
                                  },
                                  icon: Icon(
                                    Icons.how_to_vote_outlined,
                                    color: Colors.indigo.shade600,
                                  ),
                                  label: Text(
                                    'Open Voting Page',
                                    style: TextStyle(
                                      color: Colors.indigo.shade600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.indigo.shade200,
                                    ),
                                  ),
                                ),
                                if (vote != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        _resetSingleVote(tokenRecord),
                                    icon: Icon(
                                      Icons.restart_alt,
                                      color: Colors.red.shade400,
                                    ),
                                    label: Text(
                                      'Reset Vote',
                                      style: TextStyle(
                                        color: Colors.red.shade400,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEvoteStat(String label, int count, Color color) {
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 12),
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
    final organizationLabel = meeting.type == 'adcom' ? 'ADCOM' : 'HC Board';

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
