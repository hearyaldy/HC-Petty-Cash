import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/adcom_minutes.dart';
import '../../services/adcom_minutes_service.dart';
import '../../utils/constants.dart';

class AdcomMinutesViewScreen extends StatefulWidget {
  final String minutesId;
  final bool isPrintMode;
  final String? returnToMeetingId;

  const AdcomMinutesViewScreen({
    super.key,
    required this.minutesId,
    this.isPrintMode = false,
    this.returnToMeetingId,
  });

  @override
  State<AdcomMinutesViewScreen> createState() => _AdcomMinutesViewScreenState();
}

class _AdcomMinutesViewScreenState extends State<AdcomMinutesViewScreen> {
  final AdcomMinutesService _service = AdcomMinutesService();
  AdcomMinutes? _minutes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMinutes();
  }

  Future<void> _loadMinutes() async {
    setState(() => _isLoading = true);
    try {
      final minutes = await _service.getMinutesById(widget.minutesId);
      setState(() {
        _minutes = minutes;
        _isLoading = false;
      });

      // Auto-print if in print mode
      if (widget.isPrintMode && minutes != null) {
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
      color: Colors.teal[700],
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
            tooltip: 'Back to Edit',
          ),
          const SizedBox(width: 16),
          const Text(
            'Minutes Preview',
            style: TextStyle(
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
              foregroundColor: Colors.teal[700],
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
    context.go('/admin/adcom-minutes/${widget.minutesId}$meetingQuery');
  }

  Widget _buildDocumentView() {
    final presentMembers = _minutes!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _minutes!.attendanceMembers
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
                  const SizedBox(height: 8),
                  const Text(
                    'MINUTES',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      decoration: TextDecoration.underline,
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
            if (_minutes!.attendanceMembers.isNotEmpty) ...[
              const Text(
                'ATTENDANCE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 8),
              if ((_minutes!.startTime ?? '').isNotEmpty)
                Text(
                  'START TIME: ${_minutes!.startTime}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if ((_minutes!.openingPrayer ?? '').isNotEmpty)
                Text(
                  'OPENING PRAYER: ${_minutes!.openingPrayer}',
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

            // Minutes Items
            if (_minutes!.minutesItems.isNotEmpty) ...[
              const Text(
                'PROCEEDINGS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 16),
              ..._minutes!.minutesItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildMinutesItemDocument(item, index);
              }),
            ],

            // Closing
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            if ((_minutes!.closingPrayer ?? '').isNotEmpty)
              Text(
                'CLOSING PRAYER: ${_minutes!.closingPrayer}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if ((_minutes!.meetingAdjournedAt ?? '').isNotEmpty)
              Text(
                'MEETING ADJOURNED AT: ${_minutes!.meetingAdjournedAt}',
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

  Widget _buildMinutesItemDocument(MinutesItem item, int index) {
    Color statusColor;
    switch (item.status) {
      case MinutesItemStatus.voted:
        statusColor = Colors.green.shade800;
        break;
      case MinutesItemStatus.tabled:
        statusColor = Colors.orange.shade800;
        break;
      case MinutesItemStatus.discussed:
        statusColor = Colors.blue.shade800;
        break;
      case MinutesItemStatus.pending:
        statusColor = Colors.grey.shade600;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Item number and status
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.status.displayName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right column: Title, Description, Resolution
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title with underline
                Text(
                  item.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 4),
                // Description
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 11, height: 1.4),
                ),
                // Resolution (if voted)
                if (item.status == MinutesItemStatus.voted &&
                    item.resolution != null &&
                    item.resolution!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOTED:',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.resolution!,
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Tabled note
                if (item.status == MinutesItemStatus.tabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'This item has been tabled for future discussion.',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
                // Notes
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes: ${item.notes}',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildMeetingDescriptionText() {
    final dayFormat = DateFormat('EEEE, MMMM d');
    final dayName = dayFormat.format(_minutes!.meetingDate);
    final time = _minutes!.meetingTime.isNotEmpty
        ? _minutes!.meetingTime
        : '10:00AM';
    final location = _minutes!.location.isNotEmpty
        ? _minutes!.location
        : 'the ${AppConstants.organizationName} Conference Room';

    return 'Minutes of the HC ADCOM Meeting held on $dayName at $time (Thailand) at $location.';
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final presentMembers = _minutes!.attendanceMembers
        .where((m) => m.isPresent)
        .toList();
    final absentMembers = _minutes!.attendanceMembers
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
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'MINUTES',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                      decoration: pw.TextDecoration.underline,
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
            if (_minutes!.attendanceMembers.isNotEmpty) ...[
              pw.Text(
                'ATTENDANCE',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 6),
              if ((_minutes!.startTime ?? '').isNotEmpty)
                pw.Text(
                  'START TIME: ${_minutes!.startTime}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              if ((_minutes!.openingPrayer ?? '').isNotEmpty)
                pw.Text(
                  'OPENING PRAYER: ${_minutes!.openingPrayer}',
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

            // Proceedings
            if (_minutes!.minutesItems.isNotEmpty) ...[
              pw.Text(
                'PROCEEDINGS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),
              pw.SizedBox(height: 15),
              ..._minutes!.minutesItems.map(
                (item) => _buildPdfMinutesItem(item),
              ),
            ],

            // Closing
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 15),
            if ((_minutes!.closingPrayer ?? '').isNotEmpty)
              pw.Text(
                'CLOSING PRAYER: ${_minutes!.closingPrayer}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if ((_minutes!.meetingAdjournedAt ?? '').isNotEmpty)
              pw.Text(
                'MEETING ADJOURNED AT: ${_minutes!.meetingAdjournedAt}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'ADCOM_Minutes_${DateFormat('yyyy-MM-dd').format(_minutes!.meetingDate)}',
    );
  }

  pw.Widget _buildPdfMinutesItem(MinutesItem item) {
    PdfColor statusColor;
    switch (item.status) {
      case MinutesItemStatus.voted:
        statusColor = PdfColors.green800;
        break;
      case MinutesItemStatus.tabled:
        statusColor = PdfColors.orange800;
        break;
      case MinutesItemStatus.discussed:
        statusColor = PdfColors.blue800;
        break;
      case MinutesItemStatus.pending:
        statusColor = PdfColors.grey600;
        break;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left column
          pw.SizedBox(
            width: 80,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.itemNumber,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: statusColor, width: 0.5),
                  ),
                  child: pw.Text(
                    item.status.displayName,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Right column
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  item.description,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                if (item.status == MinutesItemStatus.voted &&
                    item.resolution != null &&
                    item.resolution!.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'VOTED:',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          item.resolution!,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontStyle: pw.FontStyle.italic,
                            color: PdfColors.green900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (item.status == MinutesItemStatus.tabled) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      border: pw.Border.all(color: PdfColors.orange200),
                    ),
                    child: pw.Text(
                      'This item has been tabled for future discussion.',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.orange900,
                      ),
                    ),
                  ),
                ],
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Notes: ${item.notes}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
