import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CurrencyConversionPdfService {
  pw.Font? _regular;
  pw.Font? _bold;
  pw.Font? _notoFallback;
  pw.Font? _emojiFont;

  Future<void> _loadFonts() async {
    if (_regular != null) return;
    try {
      final r = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
      final b = await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
      _regular = pw.Font.ttf(r);
      _bold = pw.Font.ttf(b);
    } catch (_) {
      _regular = pw.Font.helvetica();
      _bold = pw.Font.helveticaBold();
    }
    try {
      _notoFallback = await PdfGoogleFonts.notoSansRegular();
    } catch (_) {}
    try {
      _emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();
    } catch (_) {}
  }

  /// Prints a currency conversion support document.
  ///
  /// [foreignCurrency] e.g. 'MYR', 'USD', 'THB'
  /// [foreignAmount]   the amount in the foreign currency
  /// [exchangeRate]    how many THB per 1 unit of foreignCurrency
  /// [exchangeRateDate] the date the rate was referenced
  /// [thbAmount]       the converted THB amount (foreignAmount * exchangeRate)
  /// [receiptNo]       transaction receipt number
  /// [description]     transaction description
  /// [transactionDate] date of the transaction
  Future<void> printConversionPage({
    required String foreignCurrency,
    required double foreignAmount,
    required double exchangeRate,
    required DateTime exchangeRateDate,
    required double thbAmount,
    required String receiptNo,
    required String description,
    required DateTime transactionDate,
  }) async {
    await _loadFonts();
    final bytes = await _buildPdf(
      foreignCurrency: foreignCurrency,
      foreignAmount: foreignAmount,
      exchangeRate: exchangeRate,
      exchangeRateDate: exchangeRateDate,
      thbAmount: thbAmount,
      receiptNo: receiptNo,
      description: description,
      transactionDate: transactionDate,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<Uint8List> _buildPdf({
    required String foreignCurrency,
    required double foreignAmount,
    required double exchangeRate,
    required DateTime exchangeRateDate,
    required double thbAmount,
    required String receiptNo,
    required String description,
    required DateTime transactionDate,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy');
    final numFormat = NumberFormat('#,##0.00');

    final theme = pw.ThemeData.withFont(
      base: _regular!,
      bold: _bold!,
      fontFallback: [?_notoFallback, ?_emojiFont],
    );

    final currencySymbol = _currencySymbol(foreignCurrency);
    final thbSymbol = '฿';

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo700,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CURRENCY CONVERSION',
                    style: pw.TextStyle(
                      font: _bold,
                      fontSize: 18,
                      color: PdfColors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Support Document',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.indigo100),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Transaction details
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  _row('Receipt No.', receiptNo, bold: true),
                  _row('Transaction Date', dateFormat.format(transactionDate)),
                  _row('Description', description),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Conversion details
            pw.Text(
              'CONVERSION DETAILS',
              style: pw.TextStyle(
                font: _bold,
                fontSize: 11,
                color: PdfColors.indigo700,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.indigo200),
              ),
              child: pw.Column(
                children: [
                  _row('Foreign Currency', foreignCurrency, bold: true),
                  _row('Original Amount', '$currencySymbol ${numFormat.format(foreignAmount)}', bold: true),
                  _row('Exchange Rate Date', dateFormat.format(exchangeRateDate)),
                  _row('Exchange Rate', '1 $foreignCurrency = $thbSymbol ${numFormat.format(exchangeRate)}'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Converted amount highlight
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.green400, width: 1.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'CONVERTED AMOUNT (THB)',
                    style: pw.TextStyle(
                      font: _bold,
                      fontSize: 11,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.Text(
                    '$thbSymbol ${numFormat.format(thbAmount)}',
                    style: pw.TextStyle(
                      font: _bold,
                      fontSize: 16,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),

            // Formula note
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'Formula: $currencySymbol ${numFormat.format(foreignAmount)} × ${numFormat.format(exchangeRate)} = $thbSymbol ${numFormat.format(thbAmount)}',
                // Explicitly set font so the PDF library does NOT fall back to
                // Helvetica-Oblique (which has no Unicode / Thai support).
                style: pw.TextStyle(
                  font: _regular,
                  fontSize: 9,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                  fontFallback: [?_notoFallback, ?_emojiFont],
                ),
              ),
            ),

            pw.Spacer(),

            // Footer
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text(
              'Generated on ${dateFormat.format(DateTime.now())} — Exchange rate sourced at time of entry',
              // Same fix: pin the font so italic does not revert to Helvetica-Oblique.
              style: pw.TextStyle(
                font: _regular,
                fontSize: 8,
                color: PdfColors.grey500,
                fontStyle: pw.FontStyle.italic,
                fontFallback: [?_notoFallback, ?_emojiFont],
              ),
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _row(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 130,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'MYR': return 'RM';
      case 'USD': return '\$';
      case 'THB': return '฿';
      default: return code;
    }
  }
}
