import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/traveling_report.dart';
import '../models/traveling_per_diem_entry.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'firestore_service.dart';
import 'firebase_storage_service.dart';
import 'package:printing/printing.dart';

class TravelingReportExportService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Export traveling report as PDF
  Future<String> exportTravelingReport(TravelingReport report) async {
    final pdf = await _generateTravelingReportPdf(report);

    // Save file
    final fileName =
        'TravelingReport_${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      // Web platform - trigger download
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    } else {
      // Mobile/Desktop platform - save to file system
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    }
  }

  /// Print traveling report
  Future<void> printTravelingReport(TravelingReport report) async {
    final pdf = await _generateTravelingReportPdf(report);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'TravelingReport_${report.reportNumber}',
    );
  }

  /// Export traveling report as voucher PDF
  Future<String> exportTravelingReportVoucher(TravelingReport report) async {
    // Get per diem entries for the report
    final firestoreService = FirestoreService();
    final entries = await firestoreService.getPerDiemEntriesByReport(report.id);

    final pdf = await _generateTravelingReportVoucherPdf(report, entries);

    // Save file
    final fileName =
        'TravelingVoucher_${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      // Web platform - trigger download
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    } else {
      // Mobile/Desktop platform - save to file system
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    }
  }

  /// Print traveling report voucher
  Future<void> printTravelingReportVoucher(TravelingReport report) async {
    // Get per diem entries for the report
    final firestoreService = FirestoreService();
    final entries = await firestoreService.getPerDiemEntriesByReport(report.id);

    final pdf = await _generateTravelingReportVoucherPdf(report, entries);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'TravelingVoucher_${report.reportNumber}',
    );
  }

  /// Print support document for a traveling report
  Future<void> printSupportDocument(
    String documentUrl,
    String reportNumber,
  ) async {
    try {
      AppLogger.info('Fetching support document: $documentUrl');

      final storageService = FirebaseStorageService();
      final imageBytes = await storageService.downloadImageData(documentUrl);

      if (imageBytes == null) {
        throw Exception('Failed to load support document');
      }

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => imageBytes,
        name: 'Support_Document_$reportNumber',
      );
    } catch (e) {
      AppLogger.severe('Error printing support document: $e');
      throw Exception('Failed to print support document: $e');
    }
  }

  /// Print multiple support documents for a traveling report in one PDF
  Future<void> printMultipleSupportDocuments(
    List<String> documentUrls,
    String reportNumber,
  ) async {
    try {
      AppLogger.info(
        'Printing ${documentUrls.length} support documents for traveling report $reportNumber',
      );

      if (documentUrls.isEmpty) {
        throw Exception('No support documents to print');
      }

      final pdf = pw.Document();

      // Add a page for each support document
      final storageService = FirebaseStorageService();
      for (int i = 0; i < documentUrls.length; i++) {
        final documentUrl = documentUrls[i];

        try {
          final imageBytes = await storageService.downloadImageData(
            documentUrl,
          );
          if (imageBytes != null) {
            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (context) => pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Support Document ${i + 1} of ${documentUrls.length} - Traveling Report $reportNumber',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } catch (e) {
          AppLogger.warning('Failed to load support document ${i + 1}: $e');
          // Continue with other documents
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw Exception('Failed to load any support documents');
      }

      final bytes = await pdf.save();

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Support_Documents_$reportNumber',
      );

      AppLogger.info(
        'Successfully printed ${pdf.document.pdfPageList.pages.length} support documents',
      );
    } catch (e) {
      AppLogger.severe('Error printing multiple support documents: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

  /// Generate PDF document for traveling report
  Future<pw.Document> _generateTravelingReportPdf(
    TravelingReport report,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Load Thai font
    pw.Font? ttf;
    pw.Font? ttfBold;

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Regular.ttf',
      );
      ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Bold.ttf',
      );
      ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/hope_channel_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }

    // Get per diem entries
    final entries = await _firestoreService.getPerDiemEntriesByReport(
      report.id,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        theme: pw.ThemeData.withFont(
          base: ttf ?? pw.Font.helvetica(),
          bold: ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [pw.Font.helvetica()],
        ),
        header: (context) => pw.Column(
          children: [
            pw.Center(child: _buildHeader(ttf, ttfBold, logoImage)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => _buildFooter(report, ttf),
        build: (context) => [
          // Title
          _buildTitle(ttf, ttfBold),
          pw.SizedBox(height: 8),

          // Report Info Section
          _buildReportInfo(report, dateFormat, ttf, ttfBold),
          pw.SizedBox(height: 8),

          // Traveling Details Section
          _buildTravelingDetails(report, dateTimeFormat, ttf, ttfBold),
          pw.SizedBox(height: 8),

          // Mileage Section
          _buildMileageSection(report, ttf, ttfBold),
          pw.SizedBox(height: 8),

          // Per Diem Section
          _buildPerDiemSection(report, entries, dateFormat, ttf, ttfBold),
          pw.SizedBox(height: 8),

          // Summary Section
          _buildSummarySection(report, ttf, ttfBold),
          pw.SizedBox(height: 8),

          // If the per diem list is long, start signatures
          // on a fresh page so they never get clipped.
          if (entries.length > 8) pw.NewPage(),

          // Signature Section
          _buildSignatureSection(report, ttf, ttfBold),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildVoucherHeader(pw.Font? font, pw.Font? fontBold, pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (logoImage != null)
              pw.Container(
                width: 30,
                height: 30,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 30,
                height: 30,
                child: pw.Padding(
                  padding: pw.EdgeInsets.all(3),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        "H",
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 8),
            // Organization name and address
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold ?? pw.Font.helvetica(),
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: pw.TextStyle(fontSize: 5, font: font ?? pw.Font.helvetica()),
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

  pw.Widget _buildVoucherTitle(pw.Font? font, pw.Font? fontBold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 2),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'TRAVELING EXPENSE VOUCHER',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            font: fontBold ?? pw.Font.helvetica(),
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  pw.Widget _buildTitle(pw.Font? ttf, pw.Font? ttfBold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
        child: pw.Text(
          'TRAVELING EXPENSE REPORT',
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildReportInfo(
    TravelingReport report,
    DateFormat dateFormat,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Report No:',
                      report.reportNumber,
                      ttf,
                      ttfBold,
                    ),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Reporter Name:',
                      report.reporterName,
                      ttf,
                      ttfBold,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // Right column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Date:',
                      dateFormat.format(report.reportDate),
                      ttf,
                      ttfBold,
                    ),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Department:',
                      report.department,
                      ttf,
                      ttfBold,
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

  pw.Widget _buildTravelingDetails(
    TravelingReport report,
    DateFormat dateTimeFormat,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TRAVELING DETAILS',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Left column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Purpose:', report.purpose, ttf, ttfBold),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Place Name:',
                      report.placeName,
                      ttf,
                      ttfBold,
                    ),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Departure:',
                      dateTimeFormat.format(report.departureTime),
                      ttf,
                      ttfBold,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // Right column
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Destination:',
                      dateTimeFormat.format(report.destinationTime),
                      ttf,
                      ttfBold,
                    ),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Total Members:',
                      '${report.totalMembers}',
                      ttf,
                      ttfBold,
                    ),
                    pw.SizedBox(height: 4),
                    _buildInfoRow(
                      'Travel Type:',
                      report.travelLocationEnum.displayName,
                      ttf,
                      ttfBold,
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

  pw.Widget _buildMileageSection(
    TravelingReport report,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MILEAGE SECTION',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('Mileage Start', ttfBold, isHeader: true),
                  _buildTableCell('Mileage End', ttfBold, isHeader: true),
                  _buildTableCell('Total KM', ttfBold, isHeader: true),
                  _buildTableCell('Amount (5 THB/KM)', ttfBold, isHeader: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell(
                    '${currencyFormat.format(report.mileageStart)} KM',
                    ttf,
                  ),
                  _buildTableCell(
                    '${currencyFormat.format(report.mileageEnd)} KM',
                    ttf,
                  ),
                  _buildTableCell(
                    '${currencyFormat.format(report.totalKM)} KM',
                    ttf,
                  ),
                  _buildTableCell(
                    '฿ ${currencyFormat.format(report.mileageAmount)}',
                    ttf,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPerDiemSection(
    TravelingReport report,
    List<TravelingPerDiemEntry> entries,
    DateFormat dateFormat,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final mealRate = report.travelLocationEnum.perDiemRate;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PER DIEM SECTION',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Travel Type: ${report.travelLocationEnum.displayName} (฿${currencyFormat.format(mealRate)}/meal)',
            style: pw.TextStyle(font: ttf, fontSize: 10),
          ),
          pw.Text(
            'Total Members: ${report.totalMembers}',
            style: pw.TextStyle(font: ttf, fontSize: 10),
          ),
          pw.Divider(),
          pw.SizedBox(height: 4),
          if (entries.isEmpty)
            pw.Text(
              'No per diem entries',
              style: pw.TextStyle(
                font: ttf,
                fontSize: 10,
                color: PdfColors.grey,
              ),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
                5: const pw.FlexColumnWidth(3),
                6: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildTableCell('Date', ttfBold, isHeader: true),
                    _buildTableCell('B', ttfBold, isHeader: true),
                    _buildTableCell('L', ttfBold, isHeader: true),
                    _buildTableCell('S', ttfBold, isHeader: true),
                    _buildTableCell('I', ttfBold, isHeader: true),
                    _buildTableCell('Notes', ttfBold, isHeader: true),
                    _buildTableCell('Amount', ttfBold, isHeader: true),
                  ],
                ),
                ...entries.map(
                  (entry) => pw.TableRow(
                    children: [
                      _buildTableCell(dateFormat.format(entry.date), ttf),
                      _buildTableCell(entry.hasBreakfast ? '✓' : '', ttf),
                      _buildTableCell(entry.hasLunch ? '✓' : '', ttf),
                      _buildTableCell(entry.hasSupper ? '✓' : '', ttf),
                      _buildTableCell(entry.hasIncidentMeal ? '✓' : '', ttf),
                      _buildTableCell(entry.notes, ttf),
                      _buildTableCell(
                        '฿ ${currencyFormat.format(entry.dailyTotalAllMembers)}\n(${entry.mealsCount} meals × ${report.totalMembers} members)',
                        ttf,
                        fontSize: 8,
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

  pw.Widget _buildSummarySection(
    TravelingReport report,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final amountInWords = _convertToWords(report.grandTotal);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 2)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Mileage Total:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '฿ ${currencyFormat.format(report.mileageAmount)}',
                style: pw.TextStyle(font: ttf),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Per Diem Total:', style: pw.TextStyle(font: ttf)),
              pw.Text(
                '฿ ${currencyFormat.format(report.perDiemTotal)}',
                style: pw.TextStyle(font: ttf),
              ),
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'TOTAL CLAIM:',
                style: pw.TextStyle(font: ttfBold, fontSize: 14),
              ),
              pw.Text(
                '฿ ${currencyFormat.format(report.grandTotal)}',
                style: pw.TextStyle(font: ttfBold, fontSize: 14),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '($amountInWords)',
            style: pw.TextStyle(
              font: ttf,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection(
    TravelingReport report,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(border: pw.Border.all()),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'APPROVAL & SIGNATURE',
            style: pw.TextStyle(
              font: ttfBold,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Reported by:',
                      style: pw.TextStyle(font: ttfBold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(
                      width: double.infinity,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide()),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      report.reporterName,
                      style: pw.TextStyle(font: ttf, fontSize: 9),
                    ),
                    pw.Text(
                      'Employee',
                      style: pw.TextStyle(font: ttf, fontSize: 9),
                    ),
                    if (report.submittedAt != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${dateTimeFormat.format(report.submittedAt!)}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Approved by Treasurer',
                      style: pw.TextStyle(font: ttfBold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(
                      width: double.infinity,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide()),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    if (report.approvedBy != null &&
                        report.approvedBy!.isNotEmpty)
                      pw.Text(
                        report.approvedBy!,
                        style: pw.TextStyle(font: ttf, fontSize: 9),
                      ),
                    pw.Text(
                      '',
                      style: pw.TextStyle(font: ttf, fontSize: 9),
                    ),
                    if (report.approvedAt != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${dateTimeFormat.format(report.approvedAt!)}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 8,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Date:',
                      style: pw.TextStyle(font: ttfBold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 25),
                    pw.Container(
                      width: double.infinity,
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide()),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text('', style: pw.TextStyle(font: ttf, fontSize: 9)),
                    pw.Text(
                      '',
                      style: pw.TextStyle(font: ttf, fontSize: 9),
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

  pw.Widget _buildFooter(TravelingReport report, pw.Font? ttf) {
    final now = DateTime.now();
    final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(now);

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Report ID: ${report.id}',
          style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Printed: $timestamp',
          style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font? ttf,
    pw.Font? ttfBold,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            label,
            style: pw.TextStyle(font: ttfBold, fontSize: 10),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: pw.TextStyle(font: ttf, fontSize: 10)),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font? font, {
    bool isHeader = false,
    double fontSize = 9,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: fontSize,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  /// Convert amount to words (English)
  String _convertToWords(double amount) {
    if (amount == 0) return 'ZERO BAHT';

    final int baht = amount.floor();
    final int satang = ((amount - baht) * 100).round();

    String result = _numberToWords(baht).toUpperCase();
    result += ' BAHT';

    if (satang > 0) {
      result += ' AND ${_numberToWords(satang).toUpperCase()} SATANG';
    }

    return result;
  }

  String _numberToWords(int number) {
    if (number == 0) return 'zero';

    const ones = [
      '',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
    ];
    const teens = [
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    const tens = [
      '',
      '',
      'twenty',
      'thirty',
      'forty',
      'fifty',
      'sixty',
      'seventy',
      'eighty',
      'ninety',
    ];

    String convertHundreds(int n) {
      if (n == 0) return '';
      if (n < 10) return ones[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        return '${tens[n ~/ 10]} ${ones[n % 10]}'.trim();
      }
      return '${ones[n ~/ 100]} hundred ${convertHundreds(n % 100)}'.trim();
    }

    if (number < 1000) {
      return convertHundreds(number);
    } else if (number < 1000000) {
      return '${convertHundreds(number ~/ 1000)} thousand ${convertHundreds(number % 1000)}'
          .trim();
    } else {
      return '${convertHundreds(number ~/ 1000000)} million ${convertHundreds((number % 1000000) ~/ 1000)} thousand ${convertHundreds(number % 1000)}'
          .trim();
    }
  }

  Future<pw.Document> _generateTravelingReportVoucherPdf(
    TravelingReport report,
    List<TravelingPerDiemEntry> entries,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Load Thai font for proper rendering, with fallback to default fonts
    pw.Font? ttf;
    pw.Font? ttfBold;

    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Regular.ttf',
      );
      ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load(
        'assets/fonts/NotoSansThai-Bold.ttf',
      );
      ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      // If custom fonts fail to load, use default fonts
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/hope_channel_logo.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed, will use fallback
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(
          base: ttf ?? pw.Font.helvetica(),
          bold: ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [pw.Font.helvetica()],
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header with organization details
            _buildVoucherHeader(ttf, ttfBold, logoImage),
            pw.SizedBox(height: 10),

            // Voucher Title
            _buildVoucherTitle(ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Voucher Information Section
            _buildTravelingVoucherInfoSection(report, dateFormat, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Description Section
            _buildTravelingDescriptionSection(report, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Amount Section
            _buildTravelingAmountSection(report, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Spacer to push signature section to bottom
            pw.Expanded(child: pw.Container()),

            // Signature Section
            _buildTravelingSignatureSection(report, ttf, ttfBold),

            // Footer with voucher ID and timestamp
            pw.SizedBox(height: 12),
            _buildTravelingVoucherFooter(report, dateFormat, ttf),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(pw.Font? font, pw.Font? fontBold, pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Add logo
            if (logoImage != null)
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 40,
                height: 40,
                child: pw.Padding(
                  padding: pw.EdgeInsets.all(5),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        "H",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
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
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold ?? pw.Font.helvetica(),
                    ),
                    textAlign: pw.TextAlign.left,
                  ),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      font: font ?? pw.Font.helvetica(),
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

  pw.Widget _buildTravelingVoucherInfoSection(
    TravelingReport report,
    DateFormat dateFormat,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Voucher number and date row
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Voucher No:',
                  report.reportNumber,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Date:',
                  dateFormat.format(report.reportDate),
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Reporter and department row
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Reporter:',
                  report.reporterName,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Department:',
                  report.department,
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Travel location and members row
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Travel Location:',
                  report.travelLocationEnum.displayName,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildVoucherInfoRow(
                  'Total Members:',
                  report.totalMembers.toString(),
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingDescriptionSection(
    TravelingReport report,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DESCRIPTION',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            report.purpose,
            style: pw.TextStyle(
              fontSize: 10,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildVoucherInfoRow(
                  'Place:',
                  report.placeName,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildVoucherInfoRow(
                  'Total KM:',
                  '${report.totalKM.toStringAsFixed(1)} km',
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildVoucherInfoRow(
                  'Departure:',
                  DateFormat('dd/MM/yyyy HH:mm').format(report.departureTime),
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildVoucherInfoRow(
                  'Destination:',
                  DateFormat('dd/MM/yyyy HH:mm').format(report.destinationTime),
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingAmountSection(
    TravelingReport report,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    final mileageAmountText =
        '฿ ${NumberFormat('#,##0.00').format(report.mileageAmount)}';
    final perDiemAmountText =
        '฿ ${NumberFormat('#,##0.00').format(report.perDiemTotal)}';
    final totalAmountText =
        '฿ ${NumberFormat('#,##0.00').format(report.grandTotal)}';

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey500),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'AMOUNT BREAKDOWN',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'Mileage (${report.totalKM.toStringAsFixed(1)} km × ฿5.00):',
                  style: pw.TextStyle(fontSize: 9, font: font),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    mileageAmountText,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'Per Diem (${report.perDiemDays} days):',
                  style: pw.TextStyle(fontSize: 9, font: font),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    perDiemAmountText,
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'TOTAL AMOUNT:',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                    font: fontBold,
                  ),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    totalAmountText,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red,
                      font: fontBold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              '(${_convertToWords(report.grandTotal)})',
              style: pw.TextStyle(
                fontSize: 9,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey800,
                font: font ?? pw.Font.helvetica(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingSignatureSection(
    TravelingReport report,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildTravelingSignatureBox(
            'Reported By:',
            report.reporterName,
            font,
            fontBold,
          ),
          _buildTravelingSignatureBox(
            'Approved by Treasurer',
            report.approvedBy ?? '',
            font,
            fontBold,
          ),
          _buildTravelingDateBox(font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingSignatureBox(
    String title,
    String name,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      width: 100,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
            ),
            height: 1,
          ),
          pw.SizedBox(height: 2),
          if (name.isNotEmpty)
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
                font: font ?? pw.Font.helvetica(),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingDateBox(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      width: 80,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Date:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            height: 20,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Center(
              child: pw.Text('', style: pw.TextStyle(fontSize: 8, font: font)),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTravelingVoucherFooter(
    TravelingReport report,
    DateFormat dateFormat,
    pw.Font? font,
  ) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Report ID: ${report.id.substring(0, 10)}...',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
          pw.Text(
            'Printed: ${dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVoucherInfoRow(
    String label,
    String value,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
            font: fontBold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, font: font)),
      ],
    );
  }

}
