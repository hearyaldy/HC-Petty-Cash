import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/adcom_agenda.dart';
import '../../services/adcom_agenda_service.dart';
import '../../utils/constants.dart';

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
  AdcomAgenda? _agenda;
  bool _isLoading = true;

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
      });

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
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(child: _buildDocumentView()),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
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
    final meetingQuery = widget.returnToMeetingId != null
        ? '?meetingId=${widget.returnToMeetingId}'
        : '';
    context.go('/admin/adcom-agenda/${widget.agendaId}$meetingQuery');
  }

  Widget _buildDocumentView() {
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
            color: Colors.black.withOpacity(0.2),
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
            // Organization Header
            Center(
              child: Column(
                children: [
                  // Organization Name from constants
                  Text(
                    AppConstants.organizationName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (AppConstants.organizationAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      AppConstants.organizationAddress,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'ADMINISTRATIVE COMMITTEE MEETING',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _buildMeetingDescriptionText(),
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

            // Agenda Items
            if (_agenda!.agendaItems.isNotEmpty) ...[
              const Text(
                'AGENDA',
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
            if ((_agenda!.startTime ?? '').isNotEmpty ||
                (_agenda!.openingPrayer ?? '').isNotEmpty ||
                (_agenda!.closingPrayer ?? '').isNotEmpty ||
                (_agenda!.meetingAdjournedAt ?? '').isNotEmpty) ...[
              const Text(
                'MEETING NOTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              if ((_agenda!.startTime ?? '').isNotEmpty)
                Text(
                  'Start Time: ${_agenda!.startTime}',
                  style: const TextStyle(fontSize: 11),
                ),
              if ((_agenda!.openingPrayer ?? '').isNotEmpty)
                Text(
                  'Opening Prayer: ${_agenda!.openingPrayer}',
                  style: const TextStyle(fontSize: 11),
                ),
              if ((_agenda!.closingPrayer ?? '').isNotEmpty)
                Text(
                  'Closing Prayer: ${_agenda!.closingPrayer}',
                  style: const TextStyle(fontSize: 11),
                ),
              if ((_agenda!.meetingAdjournedAt ?? '').isNotEmpty)
                Text(
                  'Meeting Adjourned At: ${_agenda!.meetingAdjournedAt}',
                  style: const TextStyle(fontSize: 11),
                ),
              const SizedBox(height: 16),
            ],
            const Text(
              'MEETING ADJOURNED',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
                    ? Text(
                        item.description,
                        style: const TextStyle(fontSize: 11, height: 1.5),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
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

    return 'Agenda for HC ADCOM Meeting held on $dayName at $time (Thailand) at $location.';
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final presentMembers = _agenda!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _agenda!.attendanceMembers
        .where((m) => m.isAbsentWithApology)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (pw.Context context) {
          return [
            // Organization Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    AppConstants.organizationName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (AppConstants.organizationAddress.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      AppConstants.organizationAddress,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'ADMINISTRATIVE COMMITTEE MEETING',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  pw.SizedBox(height: 16),
                  pw.Text(
                    _buildMeetingDescriptionText(),
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
                'AGENDA',
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
            if ((_agenda!.startTime ?? '').isNotEmpty ||
                (_agenda!.openingPrayer ?? '').isNotEmpty ||
                (_agenda!.closingPrayer ?? '').isNotEmpty ||
                (_agenda!.meetingAdjournedAt ?? '').isNotEmpty) ...[
              pw.Text(
                'MEETING NOTES',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 8),
              if ((_agenda!.startTime ?? '').isNotEmpty)
                pw.Text(
                  'Start Time: ${_agenda!.startTime}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if ((_agenda!.openingPrayer ?? '').isNotEmpty)
                pw.Text(
                  'Opening Prayer: ${_agenda!.openingPrayer}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if ((_agenda!.closingPrayer ?? '').isNotEmpty)
                pw.Text(
                  'Closing Prayer: ${_agenda!.closingPrayer}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              if ((_agenda!.meetingAdjournedAt ?? '').isNotEmpty)
                pw.Text(
                  'Meeting Adjourned At: ${_agenda!.meetingAdjournedAt}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              pw.SizedBox(height: 12),
            ],
            pw.Text(
              'MEETING ADJOURNED',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
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
                    ? pw.Text(
                        item.description,
                        style: pw.TextStyle(fontSize: 10, lineSpacing: 1.5),
                      )
                    : pw.SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
