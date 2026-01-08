import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../models/petty_cash_report.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import 'package:printing/printing.dart';

class VoucherExportService {
  /// Export a single transaction as a Petty Cash Voucher (A5 Simple Format)
  Future<String> exportVoucher(
    Transaction transaction,
    PettyCashReport report,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Load Thai font for proper rendering
    final fontData = await rootBundle.load('fonts/NotoSansThai-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load('fonts/NotoSansThai-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    // Get user information
    final requestor = await FirestoreService().getUser(transaction.requestorId);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Organization Name (simple, no border)
            _buildSimpleHeader(ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Voucher Fields
            _buildSimpleVoucherContent(
              transaction,
              requestor,
              dateFormat,
              ttf,
              ttfBold,
            ),

            pw.Spacer(),

            // Simple signature line
            _buildSimpleSignature(ttf, ttfBold),
          ],
        ),
      ),
    );

    // Save file
    final fileName =
        'Voucher_${transaction.receiptNo}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final bytes = await pdf.save();

    if (kIsWeb) {
      // Web platform - trigger download using printing package
      await Printing.sharePdf(
        bytes: bytes,
        filename: fileName,
      );
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

  pw.Widget _buildSimpleHeader(pw.Font font, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(
          AppConstants.organizationName,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            font: fontBold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          AppConstants.organizationNameThai,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            font: fontBold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          AppConstants.organizationAddress,
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey700,
            font: font,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'PETTY CASH VOUCHER',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            font: fontBold,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _buildSimpleVoucherContent(
    Transaction transaction,
    dynamic requestor,
    DateFormat dateFormat,
    pw.Font font,
    pw.Font fontBold,
  ) {
    // Use direct Baht symbol for better rendering
    final amountText =
        '฿ ${NumberFormat('#,##0.00').format(transaction.amount)}';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Number with decorative line
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: _buildSimpleField(
            'No.:',
            transaction.receiptNo,
            font,
            fontBold,
          ),
        ),
        pw.SizedBox(height: 8),

        // Date
        _buildSimpleField(
          'Date:',
          dateFormat.format(transaction.date),
          font,
          fontBold,
        ),
        pw.SizedBox(height: 8),

        // Paid to
        _buildSimpleField(
          'Paid to:',
          transaction.paidTo ?? requestor?.name ?? 'Unknown',
          font,
          fontBold,
        ),
        pw.SizedBox(height: 8),

        // Amount (highlighted)
        pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: _buildSimpleField('Amount:', amountText, font, fontBold),
        ),
        pw.SizedBox(height: 4),

        // Amount in words
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
          child: pw.Text(
            '(${_convertToWords(transaction.amount)})',
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey800,
              font: font,
            ),
          ),
        ),
        pw.SizedBox(height: 8),

        // For (Description) with box
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding: const pw.EdgeInsets.all(6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'For:',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                transaction.description,
                style: pw.TextStyle(fontSize: 10, font: font),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSimpleField(
    String label,
    String value,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 65,
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
          child: pw.Text(value, style: pw.TextStyle(fontSize: 10, font: font)),
        ),
      ],
    );
  }

  pw.Widget _buildSimpleSignature(pw.Font font, pw.Font fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureBox('Received By', fontBold),
          _buildSignatureBox('Paid By', fontBold),
          _buildSignatureBox('Approved By', fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(String title, pw.Font fontBold) {
    return pw.Container(
      width: 100,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              font: fontBold,
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.black)),
            ),
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              'Signature',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey,
                font: fontBold,
              ),
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
