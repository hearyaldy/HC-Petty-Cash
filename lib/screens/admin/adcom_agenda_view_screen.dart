import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/adcom_agenda.dart';
import '../../models/meeting_template.dart';
import '../../services/adcom_agenda_service.dart';
import '../../services/meeting_service.dart';
import '../../services/meeting_template_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../models/meeting.dart' hide AgendaItem;

class AdcomAgendaViewScreen extends StatefulWidget {
  final String agendaId;
  final bool isPrintMode;
  final String? returnToMeetingId;

  const AdcomAgendaViewScreen({
    super.key,
    required this.agendaId,
    this.isPrintMode = false,
    this.returnToMeetingId,
  });

  @override
  State<AdcomAgendaViewScreen> createState() => _AdcomAgendaViewScreenState();
}

class _AdcomAgendaViewScreenState extends State<AdcomAgendaViewScreen> {
  final AdcomAgendaService _service = AdcomAgendaService();
  final MeetingService _meetingService = MeetingService();
  final MeetingTemplateService _templateService = MeetingTemplateService();
  AdcomAgenda? _agenda;
  Meeting? _meeting;
  MeetingTemplate? _agendaIntroTemplate;
  MeetingTemplate? _openingPrayerTemplate;
  MeetingTemplate? _closingPrayerTemplate;
  bool _isLoading = true;
  String _resolveHeadingText() {
    final customHeading = (_meeting?.customHeading ?? '').trim();
    if (customHeading.isNotEmpty) {
      return customHeading;
    }
    return _agenda!.organization.toUpperCase().contains('ADCOM')
        ? 'HC ADCOM AGENDA'
        : 'HOPE CHANNEL SEA BOARD MEETING AGENDA';
  }

  @override
  void initState() {
    super.initState();
    _loadAgenda();
  }

  Future<void> _loadAgenda() async {
    setState(() => _isLoading = true);
    try {
      final agenda = await _service.getAgendaById(widget.agendaId);
      final meeting = widget.returnToMeetingId != null
          ? await _meetingService.getMeeting(widget.returnToMeetingId!)
          : null;
      if (agenda != null) {
        final templates = await Future.wait([
          _templateService.getTemplate(
            agenda.organization,
            MeetingTemplateType.agendaIntroduction,
          ),
          _templateService.getTemplate(
            agenda.organization,
            MeetingTemplateType.openingPrayer,
          ),
          _templateService.getTemplate(
            agenda.organization,
            MeetingTemplateType.closingPrayer,
          ),
        ]);
        setState(() {
          _agenda = agenda;
          _meeting = meeting;
          _agendaIntroTemplate = templates[0];
          _openingPrayerTemplate = templates[1];
          _closingPrayerTemplate = templates[2];
          _isLoading = false;
        });
      } else {
        setState(() {
          _agenda = agenda;
          _meeting = meeting;
          _isLoading = false;
        });
      }

      // Auto-print if in print mode
      if (widget.isPrintMode && agenda != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _generatePdf();
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
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
    final isMobile = ResponsiveHelper.isMobile(context);
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Center(child: _buildDocumentView()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    final isMobile = ResponsiveHelper.isMobile(context);
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.grey[800],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBack,
                  tooltip: 'Back to Edit',
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Document Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.home_outlined, color: Colors.white),
                  onPressed: () => context.go('/admin-hub'),
                  tooltip: 'Home',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (widget.returnToMeetingId != null)
                  ElevatedButton.icon(
                    onPressed: () => context.go(
                      '/meetings/${widget.returnToMeetingId}?tab=agenda',
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Agenda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.grey[800],
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _generatePdf,
                  icon: const Icon(Icons.print),
                  label: const Text('Print / Save PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[800],
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
            tooltip: 'Back to Edit',
          ),
          const SizedBox(width: 16),
          Text(
            'Document Preview',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.returnToMeetingId != null) ...[
            ElevatedButton.icon(
              onPressed: () => context.go(
                '/meetings/${widget.returnToMeetingId}?tab=agenda',
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Agenda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.grey[800],
              ),
            ),
            const SizedBox(width: 12),
          ],
          ElevatedButton.icon(
            onPressed: _generatePdf,
            icon: const Icon(Icons.print),
            label: const Text('Print / Save PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            onPressed: () => context.go('/admin-hub'),
            tooltip: 'Home',
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (widget.returnToMeetingId != null) {
      context.go('/meetings/${widget.returnToMeetingId}?tab=agenda');
      return;
    }
    context.go('/admin/adcom-agenda/${widget.agendaId}');
  }

  Widget _buildDocumentView() {
    // Always use the structured view for consistent formatting
    return _buildStructuredDocumentView();
  }

  Widget _buildStructuredDocumentView() {
    final presentMembers = _agenda!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _agenda!.attendanceMembers
        .where((m) => m.isAbsentWithApology)
        .toList();

    return Container(
      width: 816, // A4 width in pixels at 96 DPI
      constraints: const BoxConstraints(minHeight: 1056), // A4 height
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Organization Header with Logo
            Center(
              child: Column(
                children: [
                  // Logo and Organization Name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        AppConstants.companyLogo,
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(width: 48, height: 48),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.organizationName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (AppConstants.organizationAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              AppConstants.organizationAddress,
                              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  Text(
                    '${_agenda!.organization.toUpperCase()} MEETING',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resolveHeadingText(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _buildAgendaIntroductionText(),
                    style: const TextStyle(fontSize: 11, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Section
            if (_agenda!.attendanceMembers.isNotEmpty) ...[
              const Text(
                'ATTENDANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              if ((_agenda!.startTime ?? '').isNotEmpty)
                Text(
                  'START TIME: ${_agenda!.startTime}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (_resolveOpeningPrayerText() != null)
                Text(
                  'OPENING PRAYER: ${_resolveOpeningPrayerText()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 12),
              if (presentMembers.isNotEmpty) ...[
                const Text(
                  'Members Present:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  children: presentMembers.map((m) {
                    final index = presentMembers.indexOf(m);
                    final isLast = index == presentMembers.length - 1;
                    return Text(
                      '${m.name} (${m.affiliation})${isLast ? '' : ', '}',
                      style: const TextStyle(fontSize: 11),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (absentMembers.isNotEmpty) ...[
                const Text(
                  'Members Absent with Apology:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  children: absentMembers.map((m) {
                    final index = absentMembers.indexOf(m);
                    final isLast = index == absentMembers.length - 1;
                    return Text(
                      '${m.name} (${m.affiliation})${isLast ? '' : ', '}',
                      style: const TextStyle(fontSize: 11),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
            ],

            // Agenda Items (structured view - only shown when no rich text content)
            if (_agenda!.agendaItems.isNotEmpty) ...[
              const Text(
                'AGENDA ITEMS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 16),
              ..._agenda!.agendaItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildAgendaItemDocument(item, index);
              }),
            ],

            // Closing
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            if (_resolveClosingPrayerText() != null)
              Text(
                'CLOSING PRAYER: ${_resolveClosingPrayerText()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if ((_agenda!.meetingAdjournedAt ?? '').isNotEmpty)
              Text(
                'MEETING ADJOURNED AT: ${_agenda!.meetingAdjournedAt}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaItemDocument(AgendaItem item, int index) {
    const double leftColumnWidth = 80.0;
    const double columnGap = 16.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Item number and title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftColumnWidth,
                child: Text(
                  item.itemNumber,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: columnGap),
              Expanded(
                child: Text(
                  item.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Action type with description aligned to title column
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftColumnWidth,
                child: Text(
                  item.actionType.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: columnGap),
              Expanded(
                child: item.description.isNotEmpty
                    ? _buildFormattedText(
                        item.description,
                        const TextStyle(fontSize: 11, height: 1.5),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Parses inline formatting markers into segments.
  /// Supported: **bold**, _italic_, <u>underline</u>
  List<({String text, bool bold, bool italic, bool underline})>
  _parseFormatting(String text) {
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

  /// Flutter UI: renders formatted text (Delta JSON or legacy markdown).
  Widget _buildFormattedText(String text, TextStyle baseStyle) {
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
    final segments = _parseFormatting(text);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: segments.map((seg) => TextSpan(
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

  String _buildMeetingDescriptionText() {
    final dayFormat = DateFormat('EEEE, MMMM d');
    final dayName = dayFormat.format(_agenda!.meetingDate);
    final time = _agenda!.meetingTime.isNotEmpty
        ? _agenda!.meetingTime
        : '10:00AM';
    final location = _agenda!.location.isNotEmpty
        ? _agenda!.location
        : 'the ${AppConstants.organizationName} Conference Room';

    final organizationLabel = _agenda!.organization == 'HC Board'
        ? 'Hope Channel SEA Board'
        : _agenda!.organization;

    return 'Agenda for $organizationLabel Meeting held on $dayName at $time (Thailand) at $location.';
  }

  String _buildAgendaIntroductionText() {
    final template = _agendaIntroTemplate;
    if (template != null) {
      final text = template.processContent(
        meetingDate: _agenda!.meetingDate,
        customOrganization: _agenda!.organization,
      );
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return _buildMeetingDescriptionText();
  }

  String? _resolveOpeningPrayerText() {
    final direct = _agenda!.openingPrayer?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final template = _openingPrayerTemplate;
    if (template != null) {
      final text = template.processContent(
        meetingDate: _agenda!.meetingDate,
        customOrganization: _agenda!.organization,
      );
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _resolveClosingPrayerText() {
    final direct = _agenda!.closingPrayer?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final template = _closingPrayerTemplate;
    if (template != null) {
      final text = template.processContent(
        meetingDate: _agenda!.meetingDate,
        customOrganization: _agenda!.organization,
      );
      final trimmed = text.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _generatePdf() async {
    // Load Unicode-supporting fonts (required for bullet • and non-ASCII chars)
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();
    final fontBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
        italic: fontItalic,
        boldItalic: fontBoldItalic,
      ),
    );

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(AppConstants.companyLogo);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    // Always use structured approach for consistent formatting
    final presentMembers = _agenda!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _agenda!.attendanceMembers
        .where((m) => m.isAbsentWithApology)
        .toList();

    final pdfHeadingText = _resolveHeadingText();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return [
            // Organization Header with logo
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 36,
                          height: 36,
                          margin: const pw.EdgeInsets.only(right: 8),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            AppConstants.organizationName.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (AppConstants.organizationAddress.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                              AppConstants.organizationAddress,
                              style: pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    '${_agenda!.organization.toUpperCase()} MEETING',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    pdfHeadingText,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    _buildAgendaIntroductionText(),
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Attendance
            if (_agenda!.attendanceMembers.isNotEmpty) ...[
              pw.Text(
                'ATTENDANCE',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 6),
              if ((_agenda!.startTime ?? '').isNotEmpty)
                pw.Text(
                  'START TIME: ${_agenda!.startTime}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if (_resolveOpeningPrayerText() != null)
                pw.Text(
                  'OPENING PRAYER: ${_resolveOpeningPrayerText()}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.SizedBox(height: 10),
              if (presentMembers.isNotEmpty) ...[
                pw.Text(
                  'Members Present:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  presentMembers
                      .map((m) => '${m.name} (${m.affiliation})')
                      .join(', '),
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 10),
              ],
              if (absentMembers.isNotEmpty) ...[
                pw.Text(
                  'Members Absent with Apology:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  absentMembers
                      .map((m) => '${m.name} (${m.affiliation})')
                      .join(', '),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
            ],

            // Agenda Items
            if (_agenda!.agendaItems.isNotEmpty) ...[
              pw.Text(
                'AGENDA ITEMS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 15),
              ..._agenda!.agendaItems.map((item) => _buildPdfAgendaItem(item)),
            ],

            // Closing
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 15),
            if (_resolveClosingPrayerText() != null)
              pw.Text(
                'CLOSING PRAYER: ${_resolveClosingPrayerText()}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if ((_agenda!.meetingAdjournedAt ?? '').isNotEmpty)
              pw.Text(
                'MEETING ADJOURNED AT: ${_agenda!.meetingAdjournedAt}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildPdfAgendaItem(AgendaItem item) {
    const double leftColumnWidth = 80.0;
    const double columnGap = 16.0;
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Row 1: Item number and title
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: leftColumnWidth,
                child: pw.Text(
                  item.itemNumber,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: columnGap),
              pw.Expanded(
                child: pw.Text(
                  item.title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          // Row 2: Action type with description aligned to title column
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: leftColumnWidth,
                child: pw.Text(
                  item.actionType.displayName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(width: columnGap),
              pw.Expanded(
                child: item.description.isNotEmpty
                    ? _buildPdfFormattedText(
                        item.description,
                        pw.TextStyle(fontSize: 10, lineSpacing: 1.5),
                      )
                    : pw.SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// PDF: renders formatted text as pw.RichText.
  pw.Widget _buildPdfFormattedText(String text, pw.TextStyle baseStyle) {
    if (text.startsWith('[')) {
      try {
        final List<dynamic> ops = jsonDecode(text) as List;
        final spans = <pw.TextSpan>[];
        for (final op in ops) {
          if (op is! Map) continue;
          final insert = op['insert'];
          if (insert is! String) continue;
          final attrs = (op['attributes'] as Map?) ?? {};
          spans.add(pw.TextSpan(
            text: insert,
            style: baseStyle.copyWith(
              fontWeight: attrs['bold'] == true ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: attrs['italic'] == true ? pw.FontStyle.italic : pw.FontStyle.normal,
              decoration: attrs['underline'] == true ? pw.TextDecoration.underline : pw.TextDecoration.none,
            ),
          ));
        }
        if (spans.isNotEmpty) {
          return pw.RichText(text: pw.TextSpan(children: spans));
        }
      } catch (_) {}
    }
    final segments = _parseFormatting(text);
    return pw.RichText(
      text: pw.TextSpan(
        children: segments.map((seg) => pw.TextSpan(
          text: seg.text,
          style: baseStyle.copyWith(
            fontWeight: seg.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: seg.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            decoration: seg.underline ? pw.TextDecoration.underline : pw.TextDecoration.none,
          ),
        )).toList(),
      ),
    );
  }
}
