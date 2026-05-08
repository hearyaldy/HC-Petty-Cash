import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/adcom_agenda.dart' as adcom;
import '../../models/meeting.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/meeting_service.dart';
import '../../utils/responsive_helper.dart';

class MeetingVoteScreen extends StatefulWidget {
  final String token;
  /// Optional PIN pre-filled for admin preview (passed via ?pin= query param).
  final String? adminPin;

  const MeetingVoteScreen({super.key, required this.token, this.adminPin});

  @override
  State<MeetingVoteScreen> createState() => _MeetingVoteScreenState();
}

class _MeetingVoteScreenState extends State<MeetingVoteScreen> {
  final MeetingService _meetingService = MeetingService();
  final AdcomAgendaService _agendaService = AdcomAgendaService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  MeetingVoteSession? _session;
  MeetingVoteToken? _tokenRecord;
  adcom.AdcomAgenda? _agenda;

  // Per-item vote state: agendaItemId -> choice
  Map<String, MeetingVoteChoice> _itemVotes = {};
  // Fallback single overall choice (used when no agenda / no votable items)
  MeetingVoteChoice _selectedChoice = MeetingVoteChoice.approve;

  bool _isLoading = true;
  bool _isVerifyingPin = false;
  bool _isPinVerified = false;
  bool _isSubmitting = false;
  String? _error;
  String? _pinError;

  // Votable action types
  static const _votableTypes = {
    adcom.AgendaActionType.recommended,
    adcom.AgendaActionType.voted,
  };

  @override
  void initState() {
    super.initState();
    if (widget.adminPin != null && widget.adminPin!.isNotEmpty) {
      _pinController.text = widget.adminPin!;
    }
    _loadSession();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  List<adcom.AgendaItem> get _votableItems =>
      _agenda?.agendaItems
          .where((item) => _votableTypes.contains(item.actionType))
          .toList() ??
      [];

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tokenRecord = await _meetingService.getVoteToken(widget.token);
      if (tokenRecord == null) {
        setState(() {
          _error =
              'This voting link is invalid or has expired. Please contact the meeting organizer.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _tokenRecord = tokenRecord;
        _session = null;
        _agenda = null;
        _isPinVerified = false;
        _pinError = null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load this vote right now.';
        _isLoading = false;
      });
    }
  }

  Map<String, MeetingVoteChoice> _buildItemVotes(
    adcom.AdcomAgenda? agenda,
    MeetingVote? existingVote,
  ) {
    if (agenda == null) return {};
    final result = <String, MeetingVoteChoice>{};
    for (final item in agenda.agendaItems) {
      if (!_votableTypes.contains(item.actionType)) continue;
      if (existingVote?.itemVotes != null &&
          existingVote!.itemVotes!.containsKey(item.id)) {
        result[item.id] = MeetingVoteChoiceExtension.fromString(
          existingVote.itemVotes![item.id],
        );
      } else if (existingVote != null) {
        // Legacy: apply existing overall vote to all items
        result[item.id] = existingVote.voteChoice;
      } else {
        result[item.id] = MeetingVoteChoice.approve;
      }
    }
    return result;
  }

  Future<void> _verifyPin() async {
    final tokenRecord = _tokenRecord;
    if (tokenRecord == null) return;

    final submittedPin = _pinController.text.trim();
    if (submittedPin.isEmpty) {
      setState(() => _pinError = 'Enter the PIN from the email invitation.');
      return;
    }

    if (submittedPin != tokenRecord.pin) {
      setState(() => _pinError = 'That PIN does not match this voting link.');
      return;
    }

    setState(() {
      _isVerifyingPin = true;
      _pinError = null;
    });

    try {
      final session = await _meetingService.getVoteSessionByToken(widget.token);
      if (session == null) {
        setState(() {
          _error =
              'This voting link is invalid or has expired. Please contact the meeting organizer.';
          _isLoading = false;
          _isVerifyingPin = false;
        });
        return;
      }

      adcom.AdcomAgenda? agenda;
      if (session.meeting.agendaId != null &&
          session.meeting.agendaId!.isNotEmpty) {
        agenda = await _agendaService.getAgendaById(session.meeting.agendaId!);
      }

      setState(() {
        _session = session;
        _agenda = agenda;
        _isPinVerified = true;
        _itemVotes = _buildItemVotes(agenda, session.existingVote);
        _selectedChoice =
            session.existingVote?.voteChoice ?? MeetingVoteChoice.approve;
        _commentController.text = session.existingVote?.comment ?? '';
        _isVerifyingPin = false;
      });
    } catch (e) {
      setState(() {
        _pinError = 'Unable to verify this PIN right now.';
        _isVerifyingPin = false;
      });
    }
  }

  void _applyVoteToAll(MeetingVoteChoice choice) {
    setState(() {
      for (final key in _itemVotes.keys) {
        _itemVotes[key] = choice;
      }
    });
  }

  Future<void> _submitVote() async {
    final session = _session;
    if (session == null) return;

    setState(() => _isSubmitting = true);
    try {
      // Per-item voting payload
      final Map<String, String>? itemVotesPayload = _itemVotes.isNotEmpty
          ? {for (final e in _itemVotes.entries) e.key: e.value.value}
          : null;

      // Overall choice: derived from item votes, or fallback single choice
      final MeetingVoteChoice overallChoice;
      if (_itemVotes.isNotEmpty) {
        final values = _itemVotes.values.toSet();
        overallChoice = values.length == 1
            ? values.first
            : MeetingVoteChoice.abstain;
      } else {
        overallChoice = _selectedChoice;
      }

      await _meetingService.submitVote(
        tokenRecord: session.tokenRecord,
        choice: overallChoice,
        comment: _commentController.text,
        itemVotes: itemVotesPayload,
      );

      if (!mounted) return;
      // Refresh only the vote record — do NOT call _loadSession() which
      // resets _isPinVerified and kicks the user back to PIN entry.
      await _refreshSession();
      if (!mounted) return;

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your vote has been recorded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit your vote right now.')),
      );
      setState(() => _isSubmitting = false);
    }
  }

  /// Reload the session data without resetting PIN state or agenda.
  Future<void> _refreshSession() async {
    try {
      final updated = await _meetingService.getVoteSessionByToken(widget.token);
      if (updated != null && mounted) {
        setState(() => _session = updated);
      }
    } catch (_) {}
  }

  Future<void> _openAttachment(String url) async {
    if (url.trim().isEmpty) return;
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F9FD), Color(0xFFE8EEF8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildMessageState('Voting Unavailable', _error!)
              : !_isPinVerified
              ? _buildPinEntry()
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildShell({
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView(
          padding:
              padding ??
              EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: isMobile ? 16 : 24,
              ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required Widget child,
    Color accent = Colors.indigo,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  /// Parses inline markdown (**bold**, _italic_, <u>underline</u>) in [text]
  /// and returns a list of styled TextSpans. Used by both the delta and
  /// plain-text rendering paths so that AI-generated markdown is always
  /// rendered as formatting rather than shown as literal symbols.
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
            // Explicit Quill formatting — use it directly.
            spans.add(TextSpan(
              text: insert,
              style: TextStyle(
                fontWeight: hasBold ? FontWeight.bold : FontWeight.normal,
                fontStyle: hasItalic ? FontStyle.italic : FontStyle.normal,
                decoration:
                    hasUnderline ? TextDecoration.underline : TextDecoration.none,
              ),
            ));
          } else {
            // No Quill attributes — text may contain AI-generated markdown
            // like **bold** or _italic_. Run it through the markdown parser.
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

    // ── Plain text / legacy markdown ─────────────────────────────────────────
    final spans = _markdownToSpans(normalized);
    return Text.rich(TextSpan(style: baseStyle, children: spans));
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

  Widget _buildPinEntry() {
    final tokenRecord = _tokenRecord!;
    final isMobile = ResponsiveHelper.isMobile(context);

    return _buildShell(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 20 : 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Board E-Vote Portal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Secure Voting Access',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 22 : 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This voting link is assigned to ${tokenRecord.memberName}. Enter the PIN from the invitation email to open the ballot.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: isMobile ? 14 : 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'Enter Voting PIN',
          subtitle:
              'Use the 6-digit PIN included in the invitation email to continue.',
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                TextField(
                  controller: _pinController,
                  enabled: !_isVerifyingPin,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  obscureText: true,
                  maxLength: 6,
                  onSubmitted: (_) => _isVerifyingPin ? null : _verifyPin(),
                  decoration: InputDecoration(
                    labelText: 'Voting PIN',
                    hintText: 'Enter 6-digit PIN',
                    errorText: _pinError,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isVerifyingPin ? null : _verifyPin,
                    icon: _isVerifyingPin
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      _isVerifyingPin ? 'Checking PIN...' : 'Continue to Vote',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final session = _session!;
    final meeting = session.meeting;
    final tokenRecord = session.tokenRecord;
    final existingVote = session.existingVote;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final votable = _votableItems;
    final isMobile = ResponsiveHelper.isMobile(context);

    return RefreshIndicator(
      onRefresh: _loadSession,
      child: _buildShell(
        children: [
          // ── Header banner ──────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Board E-Vote',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meeting.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 21 : 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Voting as ${tokenRecord.memberName}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: isMobile ? 14 : 15,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildBannerPill(
                      Icons.event,
                      dateFormat.format(meeting.dateTime),
                    ),
                    _buildBannerPill(
                      Icons.access_time,
                      timeFormat.format(meeting.dateTime),
                    ),
                    _buildBannerPill(
                      Icons.timer_outlined,
                      'Link expires ${DateFormat('MMM d, yyyy').format(tokenRecord.expiresAt)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Existing vote banner ───────────────────────────────────────
          if (existingVote != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      existingVote.itemVotes != null
                          ? 'You have voted on ${existingVote.itemVotes!.length} agenda item(s). You can update your votes before the organizer closes voting.'
                          : 'Your current vote is ${existingVote.voteChoice.displayName.toLowerCase()}. You can update it before the organizer closes voting.',
                      style: TextStyle(
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (existingVote != null) const SizedBox(height: 20),

          // ── E-Vote purpose ─────────────────────────────────────────────
          _buildSectionCard(
            title: meeting.meetingMode == MeetingMode.evote
                ? 'E-Vote Purpose'
                : 'Vote Summary',
            subtitle:
                'Review the agenda items and support documents below, then cast your vote on each item.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please review each agenda item and its supporting documents, then record your vote.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: isMobile ? 13 : 14,
                  ),
                ),
                if (meeting.notes != null &&
                    meeting.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildDescriptionWidget(
                    meeting.notes!.trim(),
                    TextStyle(
                      color: Colors.grey[800],
                      height: 1.5,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick Vote All (only shown when there are votable items) ───
          if (votable.isNotEmpty)
            _buildSectionCard(
              title: 'Quick Vote — Apply to All',
              subtitle:
                  'Apply the same choice to all votable agenda items at once. You can still override individual items below.',
              accent: Colors.deepPurple,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MeetingVoteChoice.values.map((choice) {
                  final Color color = switch (choice) {
                    MeetingVoteChoice.approve => Colors.green,
                    MeetingVoteChoice.reject => Colors.red,
                    MeetingVoteChoice.abstain => Colors.orange,
                  };
                  return SizedBox(
                    width: isMobile ? double.infinity : 220,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _applyVoteToAll(choice),
                      icon: Icon(
                        switch (choice) {
                          MeetingVoteChoice.approve => Icons.thumb_up_outlined,
                          MeetingVoteChoice.reject => Icons.thumb_down_outlined,
                          MeetingVoteChoice.abstain =>
                            Icons.remove_circle_outline,
                        },
                        size: 16,
                        color: color,
                      ),
                      label: Text(
                        choice.displayName,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: color.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (votable.isNotEmpty) const SizedBox(height: 20),

          // ── Agenda Items with per-item voting ─────────────────────────
          if (_agenda != null)
            _buildSectionCard(
              title: 'Agenda Items',
              subtitle: votable.isNotEmpty
                  ? 'Review each item and cast your vote. Items marked Recommended or Voted require your input.'
                  : 'These agenda items are attached to this e-vote meeting.',
              child: Column(
                children: _agenda!.agendaItems.isEmpty
                    ? [
                        Text(
                          'No agenda items were attached to this meeting yet.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ]
                    : _agenda!.agendaItems.map((item) {
                        final isVotable = _votableTypes.contains(
                          item.actionType,
                        );
                        final currentChoice = _itemVotes[item.id];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: isVotable
                                ? Colors.indigo.shade50.withValues(alpha: 0.4)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isVotable
                                  ? Colors.indigo.shade200
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Item header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.itemNumber.isNotEmpty
                                              ? item.itemNumber
                                              : '${item.order + 1}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildActionTypeBadge(item.actionType),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.title.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    if (item.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      _buildDescriptionWidget(
                                        item.description.trim(),
                                        TextStyle(
                                          color: Colors.grey[700],
                                          height: 1.45,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Attachments
                              if (item.attachments.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_file,
                                            size: 13,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Support Documents',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[500],
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: item.attachments
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              final idx = entry.key;
                                              final url = entry.value;
                                              final fileName = _attachmentLabel(
                                                url,
                                                idx,
                                              );
                                              return InkWell(
                                                onTap: () =>
                                                    _openAttachment(url),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color:
                                                          Colors.blue.shade200,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        _attachmentIcon(url),
                                                        size: 14,
                                                        color: Colors
                                                            .blue
                                                            .shade700,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        fileName,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .blue
                                                              .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.open_in_new,
                                                        size: 11,
                                                        color: Colors
                                                            .blue
                                                            .shade500,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Per-item vote selector
                              if (isVotable && currentChoice != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.indigo.shade100,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Your vote on this item:',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: _buildVoteChoiceSelector(
                                          selected: currentChoice,
                                          enabled: !_isSubmitting,
                                          onChanged: (choice) {
                                            setState(() {
                                              _itemVotes[item.id] = choice;
                                            });
                                          },
                                          isMobile: isMobile,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
              ),
            ),
          if (_agenda != null) const SizedBox(height: 20),

          // ── Comment & Submit ───────────────────────────────────────────
          _buildSectionCard(
            title: 'Comment & Submit',
            subtitle: votable.isNotEmpty
                ? 'Review your selections above, leave an optional note, then submit.'
                : 'Choose your vote, leave an optional note, then submit.',
            child: Column(
              children: [
                if (votable.isNotEmpty) ...[
                  // Vote summary chips
                  _buildVoteSummary(),
                  const SizedBox(height: 16),
                ] else ...[
                  // Fallback single overall vote when no agenda or no votable items
                  Text(
                    'Your vote:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _buildVoteChoiceSelector(
                      selected: _selectedChoice,
                      enabled: !_isSubmitting,
                      onChanged: (choice) {
                        setState(() => _selectedChoice = choice);
                      },
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Comment for the secretary (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submitVote,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.how_to_vote),
                    label: Text(
                      existingVote == null ? 'Submit Vote' : 'Update Vote',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildVoteSummary() {
    if (_itemVotes.isEmpty) return const SizedBox.shrink();

    final counts = <MeetingVoteChoice, int>{};
    for (final choice in _itemVotes.values) {
      counts[choice] = (counts[choice] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vote Summary (${_itemVotes.length} item${_itemVotes.length == 1 ? '' : 's'})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: MeetingVoteChoice.values
                .where((c) => counts.containsKey(c))
                .map((c) {
                  final Color color = switch (c) {
                    MeetingVoteChoice.approve => Colors.green,
                    MeetingVoteChoice.reject => Colors.red,
                    MeetingVoteChoice.abstain => Colors.orange,
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '${c.displayName}: ${counts[c]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoteChoiceSelector({
    required MeetingVoteChoice selected,
    required ValueChanged<MeetingVoteChoice> onChanged,
    required bool enabled,
    required bool isMobile,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: MeetingVoteChoice.values.map((choice) {
        final isSelected = choice == selected;
        final Color color = switch (choice) {
          MeetingVoteChoice.approve => Colors.green,
          MeetingVoteChoice.reject => Colors.red,
          MeetingVoteChoice.abstain => Colors.orange,
        };
        return SizedBox(
          width: isMobile ? double.infinity : 180,
          child: OutlinedButton.icon(
            onPressed: enabled ? () => onChanged(choice) : null,
            icon: Icon(
              switch (choice) {
                MeetingVoteChoice.approve => Icons.thumb_up_outlined,
                MeetingVoteChoice.reject => Icons.thumb_down_outlined,
                MeetingVoteChoice.abstain => Icons.remove_circle_outline,
              },
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            label: Text(
              choice.displayName,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: isSelected
                  ? color
                  : color.withValues(alpha: 0.06),
              side: BorderSide(color: color.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionTypeBadge(adcom.AgendaActionType actionType) {
    final Color color = switch (actionType) {
      adcom.AgendaActionType.recommended => Colors.indigo,
      adcom.AgendaActionType.voted => Colors.green,
      adcom.AgendaActionType.information => Colors.grey,
      adcom.AgendaActionType.forDiscussion => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        actionType.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _attachmentLabel(String url, int index) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final last = Uri.decodeComponent(pathSegments.last);
        if (last.isNotEmpty && last != '/') {
          // Trim long names
          if (last.length > 28) return '${last.substring(0, 25)}…';
          return last;
        }
      }
    } catch (_) {}
    return 'Document ${index + 1}';
  }

  IconData _attachmentIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (lower.contains('.doc') || lower.contains('.docx')) {
      return Icons.description_outlined;
    }
    if (lower.contains('.xls') || lower.contains('.xlsx')) {
      return Icons.table_chart_outlined;
    }
    if (lower.contains('.ppt') || lower.contains('.pptx')) {
      return Icons.slideshow_outlined;
    }
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildBannerPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: Colors.indigo.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
