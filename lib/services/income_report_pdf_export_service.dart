import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/income_report.dart';
import '../models/organization.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class IncomeReportPdfExportService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.ImageProvider? _logoImage;

  Future<void> _loadFonts() async {
    if (_ttf != null && _ttfBold != null) return;

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Regular.ttf',
      );
      _ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Bold.ttf',
      );
      _ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    // Load default logo
    try {
      final logoData =
          await rootBundle.load('assets/images/hope_channel_logo.png');
      _logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }
  }

  Future<void> _loadOrganizationLogo(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return;

    // For now, we use the default logo
    // In the future, could fetch from network using http package
  }

  Future<Uint8List> generateIncomeReportPdf(
    IncomeReport report,
    List<IncomeEntry> entries, {
    Organization? organization,
  }) async {
    await _loadFonts();
    if (organization?.logoUrl != null) {
      await _loadOrganizationLogo(organization!.logoUrl);
    }

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    // Sort entries by date
    final sortedEntries = List<IncomeEntry>.from(entries)
      ..sort((a, b) => a.dateReceived.compareTo(b.dateReceived));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? pw.Font.helvetica(),
          bold: _ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [pw.Font.helvetica()],
        ),
        header: (context) =>
            _buildHeader(report, dateFormat, organization: organization),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(report, dateFormat),
          pw.SizedBox(height: 20),
          _buildEntriesTable(sortedEntries, currencyFormat, dateFormat),
          pw.SizedBox(height: 16),
          _buildTotalSection(report, currencyFormat),
          pw.SizedBox(height: 20),
          _buildCategorySummary(sortedEntries, currencyFormat),
          if (report.description != null &&
              report.description!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildNotesSection(report.description!),
          ],
          pw.SizedBox(height: 30),
          _buildSignatureSection(report),
        ],
      ),
    );

    return await pdf.save();
  }

  Future<void> printIncomeReport(
    IncomeReport report,
    List<IncomeEntry> entries, {
    Organization? organization,
  }) async {
    final pdfBytes = await generateIncomeReportPdf(
      report,
      entries,
      organization: organization,
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Income_Report_${report.reportNumber}',
    );
  }

  pw.Widget _buildOrganizationHeader({Organization? organization}) {
    final orgName = organization?.name ?? AppConstants.organizationName;
    final orgAddress = organization?.address ?? AppConstants.organizationAddress;

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (_logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(_logoImage!, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        "H",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 10),
            // Organization name and address
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    orgName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    orgAddress,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildHeader(
    IncomeReport report,
    DateFormat dateFormat, {
    Organization? organization,
  }) {
    return pw.Column(
      children: [
        // Organization header
        _buildOrganizationHeader(organization: organization),
        pw.SizedBox(height: 16),

        // Title
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.green600),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.green50,
          ),
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text(
              'INCOME REPORT',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 16),

        // Document number and date
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'No: ${report.reportNumber}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Generated: ${dateFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
        pw.Divider(thickness: 1, color: PdfColors.green400),
        pw.SizedBox(height: 8),
      ],
    );
  }

  pw.Widget _buildInfoSection(IncomeReport report, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Report Name:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      report.reportName,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Department:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      report.department,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Created By:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      report.createdByName,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Status:',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      _formatStatus(report.status),
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Period:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Submitted';
      case 'approved':
        return 'Approved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  pw.Widget _buildEntriesTable(
    List<IncomeEntry> entries,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Income Entries:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FixedColumnWidth(30),
            1: const pw.FixedColumnWidth(65),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.5),
            4: const pw.FixedColumnWidth(70),
            5: const pw.FixedColumnWidth(80),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.green100),
              children: [
                _buildTableCell('No.', isHeader: true),
                _buildTableCell('Date', isHeader: true),
                _buildTableCell('Source / Description', isHeader: true),
                _buildTableCell('Category', isHeader: true),
                _buildTableCell('Payment', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
              ],
            ),
            // Data Rows
            ...entries.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return pw.TableRow(
                children: [
                  _buildTableCell('$index'),
                  _buildTableCell(
                    DateFormat('MM/dd/yy').format(item.dateReceived),
                  ),
                  _buildTableCell(
                    '${item.sourceName}\n${item.description}',
                    align: pw.TextAlign.left,
                  ),
                  _buildTableCell(
                    item.categoryEnum.displayName,
                    align: pw.TextAlign.left,
                  ),
                  _buildTableCell(
                    item.paymentMethodEnum.displayName,
                    align: pw.TextAlign.left,
                  ),
                  _buildTableCell(
                    currencyFormat.format(item.amount),
                    align: pw.TextAlign.right,
                  ),
                ],
              );
            }),
            // Empty rows if less than 5 entries
            ...List.generate(
              (3 - entries.length).clamp(0, 3),
              (index) => pw.TableRow(
                children: [
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                  _buildTableCell(''),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildTotalSection(
    IncomeReport report,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.green600, width: 1.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          color: PdfColors.green50,
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'TOTAL INCOME:',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.Text(
              '${AppConstants.currencySymbol}${currencyFormat.format(report.totalIncome)}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildCategorySummary(
    List<IncomeEntry> entries,
    NumberFormat currencyFormat,
  ) {
    // Group by category
    final categoryTotals = <String, double>{};
    for (final entry in entries) {
      final category = entry.categoryEnum.displayName;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + entry.amount;
    }

    if (categoryTotals.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary by Category:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...sortedCategories.map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    entry.key,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Text(
                    '${AppConstants.currencySymbol}${currencyFormat.format(entry.value)}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNotesSection(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Notes:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            notes,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection(IncomeReport report) {
    return pw.Column(
      children: [
        pw.Text(
          'SIGNATURE SECTION',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSignatureBox('Prepared By', report.createdByName),
              _buildSignatureBox('Reviewed By', null),
              _buildSignatureBox('Approved By', report.approvedBy),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBox(String label, String? value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 120,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.black),
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value ?? '(________________)',
            style: pw.TextStyle(
              fontSize: 9,
              color: value != null ? PdfColors.black : PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }
}
