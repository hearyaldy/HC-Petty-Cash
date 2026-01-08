import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/petty_cash_report.dart';
import '../models/enums.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'firestore_service.dart';
import 'package:printing/printing.dart';

class VoucherExportService {
  /// Export a single transaction as a Professional Petty Cash Voucher
  Future<String> exportVoucher(
    Transaction transaction,
    PettyCashReport report,
  ) async {
    final pdf = await _generateVoucherPdf(transaction, report);

    // Save file
    final fileName =
        'Voucher_${transaction.receiptNo}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      // Web platform - trigger download using printing package
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

  /// Print a single transaction as a Professional Petty Cash Voucher
  Future<void> printVoucher(
    Transaction transaction,
    PettyCashReport report,
  ) async {
    final pdf = await _generateVoucherPdf(transaction, report);
    final bytes = await pdf.save();

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Voucher_${transaction.receiptNo}',
    );
  }

  /// Generate PDF document for voucher (shared logic for export and print)
  Future<pw.Document> _generateVoucherPdf(
    Transaction transaction,
    PettyCashReport report,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Load Thai font for proper rendering, with fallback to default fonts
    pw.Font? ttf;
    pw.Font? ttfBold;

    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
      ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
      ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      // If custom fonts fail to load, use default fonts
      AppLogger.warning('Failed to load custom fonts: $e');
    }

    // Get user information
    final requestor = await FirestoreService().getUser(transaction.requestorId);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5.landscape,
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
            _buildHeader(ttf, ttfBold),
            pw.SizedBox(height: 10),

            // Voucher Title and Requested By Info in a row
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 2,
                  child: _buildTitle(ttf, ttfBold),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 1,
                  child: _buildRequestedByInfo(ttf, ttfBold),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Voucher Information and Description in columns
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _buildVoucherInfoSection(
                    transaction,
                    report,
                    requestor,
                    dateFormat,
                    ttf,
                    ttfBold,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _buildDescriptionSection(transaction, ttf, ttfBold),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Amount Section
            _buildAmountSection(transaction, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Spacer to push signature section to bottom
            pw.Expanded(child: pw.Container()),

            // Signature Section
            _buildSignatureSection(ttf, ttfBold),

            // Footer with voucher ID and timestamp
            pw.SizedBox(height: 12),
            _buildFooter(transaction, dateFormat, ttf),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(pw.Font? font, pw.Font? fontBold) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            AppConstants.organizationName,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            AppConstants.organizationNameThai,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            AppConstants.organizationAddress,
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey700,
              font: font ?? pw.Font.helvetica(),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTitle(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Center(
        child: pw.Text(
          'PETTY CASH VOUCHER',
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

  pw.Widget _buildVoucherInfoSection(
    Transaction transaction,
    PettyCashReport report,
    dynamic requestor,
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
                child: _buildInfoRow(
                  'Voucher No:',
                  transaction.receiptNo,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Date:',
                  dateFormat.format(transaction.date),
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // Report number and department row
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Report No:',
                  report.reportNumber,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Department:',
                  report.department,
                  font,
                  fontBold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // Paid to and requestor row
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Paid to:',
                  transaction.paidTo ?? requestor?.name ?? 'Unknown',
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Requestor:',
                  requestor?.name ?? 'Unknown',
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

  pw.Widget _buildInfoRow(
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

  pw.Widget _buildDescriptionSection(
    Transaction transaction,
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
            transaction.description,
            style: pw.TextStyle(
              fontSize: 10,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoRow(
                  'Category:',
                  transaction.category.toExpenseCategory().displayName,
                  font,
                  fontBold,
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildInfoRow(
                  'Payment Method:',
                  transaction.paymentMethod.toPaymentMethod().displayName,
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

  pw.Widget _buildAmountSection(
    Transaction transaction,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    final amountText =
        '฿ ${NumberFormat('#,##0.00').format(transaction.amount)}';

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
          pw.Row(
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'AMOUNT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                    font: fontBold ?? pw.Font.helvetica(),
                  ),
                ),
              ),
              pw.Expanded(
                flex: 3,
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    amountText,
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red,
                      font: fontBold ?? pw.Font.helvetica(),
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
              '(${_convertToWords(transaction.amount)})',
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

  pw.Widget _buildRequestedByInfo(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Requested by:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Heary Healdy Sairin',
            style: pw.TextStyle(
              fontSize: 8,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Department:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              font: fontBold ?? pw.Font.helvetica(),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Hope Channel Southeast Asia',
            style: pw.TextStyle(
              fontSize: 8,
              font: font ?? pw.Font.helvetica(),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureBox('Requested By:', 'Name', font, fontBold),
          _buildSignatureBox('Approved By:', '', font, fontBold),
          _buildActionNumberBox(font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(
      String title, String subtitle, pw.Font? font, pw.Font? fontBold) {
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
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
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

  pw.Widget _buildActionNumberBox(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      width: 80,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Action No:',
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
        ],
      ),
    );
  }

  pw.Widget _buildFooter(
    Transaction transaction,
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
            'Voucher ID: ${transaction.id.substring(0, 10)}...',
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

  String _convertToWords(double amount) {
    // Simple implementation - convert amount to words
    final baht = amount.floor();
    final satang = ((amount - baht) * 100).round();

    final bahtInWords = _numberToWords(baht);
    final satangInWords = satang > 0
        ? 'and ${_numberToWords(satang)} Satang'
        : '';

    return '${bahtInWords.toUpperCase()} BAHT $satangInWords'.trim();
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';

    final ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
    ];
    final teens = [
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];
    final tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 10) return ones[number];
    if (number < 20) return teens[number - 10];
    if (number < 100) {
      return '${tens[number ~/ 10]} ${ones[number % 10]}'.trim();
    }
    if (number < 1000) {
      return '${ones[number ~/ 100]} Hundred ${_numberToWords(number % 100)}'
          .trim();
    }
    if (number < 1000000) {
      return '${_numberToWords(number ~/ 1000)} Thousand ${_numberToWords(number % 1000)}'
          .trim();
    }

    return number.toString(); // Fallback for very large numbers
  }
}
