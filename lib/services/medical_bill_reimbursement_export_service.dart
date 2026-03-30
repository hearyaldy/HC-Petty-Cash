import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../models/medical_bill_reimbursement.dart';
import '../models/enums.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class MedicalBillReimbursementExportService {
  /// Export medical bill reimbursement as PDF
  Future<String> exportMedicalBillReimbursement(
    MedicalBillReimbursement report,
  ) async {
    final pdf = await _generateMedicalBillReimbursementPdf(report);

    final fileName =
        'MedicalBillReimbursement_${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return fileName;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    }
  }

  /// Print medical bill reimbursement
  Future<void> printMedicalBillReimbursement(
    MedicalBillReimbursement report,
  ) async {
    final pdf = await _generateMedicalBillReimbursementPdf(report);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'MedicalBillReimbursement_${report.reportNumber}',
    );
  }

  /// Generate PDF document for medical bill reimbursement
  Future<pw.Document> _generateMedicalBillReimbursementPdf(
    MedicalBillReimbursement report,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

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

    pw.Font? notoFallback;
    pw.Font? emojiFont;
    try {
      notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}

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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        theme: pw.ThemeData.withFont(
          base: ttf ?? pw.Font.helvetica(),
          bold: ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [?notoFallback, ?emojiFont],
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(ttf, ttfBold, logoImage),
            pw.SizedBox(height: 12),

            // Title
            _buildTitle(ttf, ttfBold),
            pw.SizedBox(height: 16),

            // Report Info Section
            _buildReportInfoSection(report, dateFormat, ttf, ttfBold),
            pw.SizedBox(height: 16),

            // Medical Claims Table
            _buildMedicalClaimsTable(report, currencyFormat, ttf, ttfBold),
            pw.SizedBox(height: 16),

            // Summary Section
            _buildSummarySection(report, currencyFormat, ttf, ttfBold),

            // Spacer
            pw.Expanded(child: pw.Container()),

            // Signature Section
            _buildSignatureSection(report, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Footer
            _buildFooter(report, dateFormat, ttf),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(
    pw.Font? font,
    pw.Font? fontBold,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Logo
            if (logoImage != null)
              pw.Container(
                width: 50,
                height: 50,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 50,
                height: 50,
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.DecoratedBox(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'H',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            pw.SizedBox(width: 16),
            // Organization info
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    AppConstants.organizationName,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      font: fontBold ?? pw.Font.helvetica(),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    AppConstants.organizationAddress,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                      font: font ?? pw.Font.helvetica(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTitle(pw.Font? font, pw.Font? fontBold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 2),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(
          'MEDICAL BILL REIMBURSEMENT FORM',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            font: fontBold ?? pw.Font.helvetica(),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildReportInfoSection(
    MedicalBillReimbursement report,
    DateFormat dateFormat,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow('Name:', report.requesterName, font, fontBold),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildInfoRow(
                  'Date:',
                  dateFormat.format(report.reportDate),
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow('Department:', report.department, font, fontBold),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: _buildInfoRow('Report No:', report.reportNumber, font, fontBold),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildInfoRow('Subject:', report.subject, font, fontBold),
          if (report.paidTo != null && report.paidTo!.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            _buildInfoRow('Paid To:', report.paidTo!, font, fontBold),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              font: fontBold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, font: font),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMedicalClaimsTable(
    MedicalBillReimbursement report,
    NumberFormat currencyFormat,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    const tableBorder = pw.TableBorder(
      left: pw.BorderSide(color: PdfColors.black, width: 0.5),
      right: pw.BorderSide(color: PdfColors.black, width: 0.5),
      top: pw.BorderSide(color: PdfColors.black, width: 0.5),
      bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
      horizontalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
      verticalInside: pw.BorderSide(color: PdfColors.grey400, width: 0.4),
    );

    final bodyRows = <pw.TableRow>[];

    // Add claim items
    for (var i = 0; i < report.claimItems.length; i++) {
      final item = report.claimItems[i];
      bodyRows.add(
        pw.TableRow(
          children: [
            _buildTableCell('${i + 1}', font, align: pw.TextAlign.center),
            _buildTableCell(item.description, font),
            _buildTableCell(
              item.claimTypeEnum.shortName,
              font,
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              '${AppConstants.currencySymbol} ${currencyFormat.format(item.totalBill)}',
              font,
              align: pw.TextAlign.right,
            ),
            _buildTableCell(
              '${(item.claimTypeEnum.reimbursementRate * 100).toInt()}%',
              font,
              align: pw.TextAlign.center,
            ),
            _buildTableCell(
              '${AppConstants.currencySymbol} ${currencyFormat.format(item.amountReimburse)}',
              font,
              align: pw.TextAlign.right,
            ),
          ],
        ),
      );
    }

    // Add empty rows to fill space (minimum 10 rows)
    final emptyRowsNeeded = 10 - report.claimItems.length;
    if (emptyRowsNeeded > 0) {
      for (var i = 0; i < emptyRowsNeeded; i++) {
        bodyRows.add(
          pw.TableRow(
            children: [
              _buildTableCell('', font),
              _buildTableCell('', font),
              _buildTableCell('', font),
              _buildTableCell('', font),
              _buildTableCell('', font),
              _buildTableCell('', font),
            ],
          ),
        );
      }
    }

    // Add total row
    bodyRows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          _buildTableCell('', fontBold),
          _buildTableCell('TOTAL', fontBold, align: pw.TextAlign.right),
          _buildTableCell('', fontBold),
          _buildTableCell(
            '${AppConstants.currencySymbol} ${currencyFormat.format(report.totalBill)}',
            fontBold,
            align: pw.TextAlign.right,
          ),
          _buildTableCell('', fontBold),
          _buildTableCell(
            '${AppConstants.currencySymbol} ${currencyFormat.format(report.totalReimbursement)}',
            fontBold,
            align: pw.TextAlign.right,
          ),
        ],
      ),
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Details of Medical Claim:',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            font: fontBold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: tableBorder,
          columnWidths: const {
            0: pw.FlexColumnWidth(0.8), // No
            1: pw.FlexColumnWidth(4.0), // Description
            2: pw.FlexColumnWidth(1.2), // Type (OP/IP)
            3: pw.FlexColumnWidth(2.0), // Total Bill
            4: pw.FlexColumnWidth(1.5), // Rate %
            5: pw.FlexColumnWidth(2.0), // Amount Reimburse
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _buildTableCell('No.', fontBold, align: pw.TextAlign.center, isHeader: true),
                _buildTableCell('Description', fontBold, align: pw.TextAlign.center, isHeader: true),
                _buildTableCell('Type\n(OP/IP)', fontBold, align: pw.TextAlign.center, isHeader: true),
                _buildTableCell('Total Bill', fontBold, align: pw.TextAlign.center, isHeader: true),
                _buildTableCell('Rate', fontBold, align: pw.TextAlign.center, isHeader: true),
                _buildTableCell('Amount\nReimburse', fontBold, align: pw.TextAlign.center, isHeader: true),
              ],
            ),
            ...bodyRows,
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Note: OP (Out Patient) = 75% reimbursement | IP (In Patient) = 90% reimbursement',
          style: pw.TextStyle(
            fontSize: 8,
            font: font,
            color: PdfColors.grey600,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font? font, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 9,
          font: font,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  pw.Widget _buildSummarySection(
    MedicalBillReimbursement report,
    NumberFormat currencyFormat,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    final opTotal = report.getTotalBillByType(MedicalClaimType.outPatient);
    final opReimburse = report.getTotalReimbursementByType(MedicalClaimType.outPatient);
    final ipTotal = report.getTotalBillByType(MedicalClaimType.inPatient);
    final ipReimburse = report.getTotalReimbursementByType(MedicalClaimType.inPatient);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SUMMARY',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              font: fontBold,
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
                      'Out Patient (OP) - 75%',
                      style: pw.TextStyle(fontSize: 9, font: fontBold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Total Bill: ${AppConstants.currencySymbol} ${currencyFormat.format(opTotal)}',
                      style: pw.TextStyle(fontSize: 9, font: font),
                    ),
                    pw.Text(
                      'Reimburse: ${AppConstants.currencySymbol} ${currencyFormat.format(opReimburse)}',
                      style: pw.TextStyle(fontSize: 9, font: font),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'In Patient (IP) - 90%',
                      style: pw.TextStyle(fontSize: 9, font: fontBold),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Total Bill: ${AppConstants.currencySymbol} ${currencyFormat.format(ipTotal)}',
                      style: pw.TextStyle(fontSize: 9, font: font),
                    ),
                    pw.Text(
                      'Reimburse: ${AppConstants.currencySymbol} ${currencyFormat.format(ipReimburse)}',
                      style: pw.TextStyle(fontSize: 9, font: font),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TOTAL REIMBURSEMENT',
                      style: pw.TextStyle(fontSize: 10, font: fontBold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '${AppConstants.currencySymbol} ${currencyFormat.format(report.totalReimbursement)}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        font: fontBold,
                        color: PdfColors.red800,
                      ),
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

  pw.Widget _buildSignatureSection(
    MedicalBillReimbursement report,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          // Requested By
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Requested By:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 150,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide()),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  report.requesterName,
                  style: pw.TextStyle(fontSize: 9, font: font),
                ),
                pw.Text(
                  '(Requester Name)',
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: font,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 40),
          // Approved By
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Approved By:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 150,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide()),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  report.approverName ?? '',
                  style: pw.TextStyle(fontSize: 9, font: font),
                ),
                pw.Text(
                  '(Approver Name)',
                  style: pw.TextStyle(
                    fontSize: 8,
                    font: font,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
    MedicalBillReimbursement report,
    DateFormat dateFormat,
    pw.Font? font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Report ID: ${report.id.length > 12 ? '${report.id.substring(0, 12)}...' : report.id}',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              font: font,
            ),
          ),
          pw.Text(
            'Printed: ${dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
              font: font,
            ),
          ),
        ],
      ),
    );
  }
}
