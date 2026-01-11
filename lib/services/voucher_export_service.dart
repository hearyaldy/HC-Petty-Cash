import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
            _buildHeader(ttf, ttfBold),
            pw.SizedBox(height: 10),

            // Voucher Title
            _buildTitle(ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Voucher Information Section
            _buildVoucherInfoSection(
              transaction,
              report,
              requestor,
              dateFormat,
              ttf,
              ttfBold,
            ),
            pw.SizedBox(height: 12),

            // Description Section
            _buildDescriptionSection(transaction, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Amount Section
            _buildAmountSection(transaction, ttf, ttfBold),
            pw.SizedBox(height: 12),

            // Spacer to push signature section to bottom
            pw.Expanded(child: pw.Container()),

            // Signature Section
            _buildSignatureSection(transaction, ttf, ttfBold),

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
                  'Report Name:',
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

  pw.Widget _buildSignatureSection(
    Transaction transaction,
    pw.Font? font,
    pw.Font? fontBold,
  ) {
    // Check if it's a bank transfer
    final isBankTransfer = transaction.paymentMethod == PaymentMethod.bankTransfer.name;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureBox('Requested By:', 'Name', isBankTransfer, font, fontBold),
          _buildSignatureBox('Approved By:', '', false, font, fontBold),
          _buildActionNumberBox(font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(
      String title, String subtitle, bool showTR, pw.Font? font, pw.Font? fontBold) {
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
          if (showTR) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'T/R',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                font: fontBold ?? pw.Font.helvetica(),
              ),
            ),
            pw.SizedBox(height: 10),
          ] else
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

  /// Print support document for a transaction
  Future<void> printSupportDocument(String documentUrl, String transactionReceiptNo) async {
    try {
      print('Fetching support document: $documentUrl');

      // Fetch the image
      final response = await http.get(Uri.parse(documentUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load support document');
      }

      final imageBytes = response.bodyBytes;
      final image = pw.MemoryImage(imageBytes);

      // Create PDF with the image
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Support Document - Voucher $transactionReceiptNo',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 20),
                pw.Expanded(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ],
            ),
          ),
        ),
      );

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Support_Document_$transactionReceiptNo',
      );
    } catch (e) {
      AppLogger.severe('Error printing support document: $e');
      throw Exception('Failed to print support document: $e');
    }
  }

  /// Print multiple support documents for a single transaction in one PDF
  Future<void> printMultipleSupportDocuments(
    List<String> documentUrls,
    String transactionReceiptNo,
    String description,
    double amount,
  ) async {
    try {
      print('Printing ${documentUrls.length} support documents for voucher $transactionReceiptNo');

      if (documentUrls.isEmpty) {
        throw Exception('No support documents to print');
      }

      final pdf = pw.Document();

      // Load font for better rendering
      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
        final fontBoldData = await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
        ttfBold = pw.Font.ttf(fontBoldData);
      } catch (e) {
        AppLogger.warning('Failed to load custom font: $e');
      }

      // Add a page for each support document
      for (int i = 0; i < documentUrls.length; i++) {
        try {
          print('Fetching document ${i + 1}/${documentUrls.length}');

          final response = await http.get(Uri.parse(documentUrls[i]));
          if (response.statusCode == 200) {
            final imageBytes = response.bodyBytes;
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                theme: pw.ThemeData.withFont(
                  base: ttf,
                  bold: ttfBold,
                  fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
                ),
                build: (context) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header with voucher info
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                'Support Document ${i + 1} of ${documentUrls.length}',
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.Text(
                                'Page ${i + 1}',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey600,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Divider(),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Voucher No: $transactionReceiptNo',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'Description: $description',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                          pw.Text(
                            'Amount: ฿${NumberFormat('#,##0.00').format(amount)}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    // Image
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            print('Failed to load document ${i + 1}');
          }
        } catch (e) {
          print('Error loading document ${i + 1}: $e');
          // Continue with other documents even if one fails
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw Exception('Failed to load any support documents');
      }

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Support_Documents_$transactionReceiptNo',
      );

      print('Successfully printed ${pdf.document.pdfPageList.pages.length} support documents');
    } catch (e) {
      AppLogger.severe('Error printing multiple support documents: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

  /// Print multiple support documents with grid layout (up to 4 per page)
  Future<void> printMultipleSupportDocumentsGrid(
    List<String> documentUrls,
    String transactionReceiptNo,
    String description,
    double amount,
  ) async {
    try {
      print('Printing ${documentUrls.length} support documents in grid layout');

      if (documentUrls.isEmpty) {
        throw Exception('No support documents to print');
      }

      final pdf = pw.Document();

      // Load font for better rendering
      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
        final fontBoldData = await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
        ttfBold = pw.Font.ttf(fontBoldData);
      } catch (e) {
        AppLogger.warning('Failed to load custom font: $e');
      }

      // Fetch all images first
      final images = <pw.MemoryImage>[];
      for (int i = 0; i < documentUrls.length; i++) {
        try {
          print('Fetching document ${i + 1}/${documentUrls.length}');
          final response = await http.get(Uri.parse(documentUrls[i]));
          if (response.statusCode == 200) {
            images.add(pw.MemoryImage(response.bodyBytes));
          } else {
            print('Failed to load document ${i + 1}');
          }
        } catch (e) {
          print('Error loading document ${i + 1}: $e');
        }
      }

      if (images.isEmpty) {
        throw Exception('Failed to load any support documents');
      }

      // Create pages with up to 4 images per page
      final pagesCount = (images.length / 4).ceil();
      for (int pageIndex = 0; pageIndex < pagesCount; pageIndex++) {
        final startIndex = pageIndex * 4;
        final endIndex = (startIndex + 4).clamp(0, images.length);
        final pageImages = images.sublist(startIndex, endIndex);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            theme: pw.ThemeData.withFont(
              base: ttf,
              bold: ttfBold,
              fontFallback: [pw.Font.helvetica(), pw.Font.helveticaBold()],
            ),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Support Documents - Voucher $transactionReceiptNo',
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text('Description: $description', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text(
                              'Amount: ฿${NumberFormat('#,##0.00').format(amount)}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'Page ${pageIndex + 1}/$pagesCount',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                // Images in grid
                pw.Expanded(
                  child: _buildImageGrid(pageImages, startIndex),
                ),
                // Signature section at bottom
                pw.SizedBox(height: 12),
                _buildSupportDocumentSignatureSection(ttf, ttfBold),
              ],
            ),
          ),
        );
      }

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'Support_Documents_Grid_$transactionReceiptNo',
      );

      print('Successfully printed ${images.length} documents in grid layout on $pagesCount page(s)');
    } catch (e) {
      AppLogger.severe('Error printing support documents in grid: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

  /// Build signature section for support documents
  pw.Widget _buildSupportDocumentSignatureSection(pw.Font? font, pw.Font? fontBold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Approved By:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 25),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                  ),
                  height: 1,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Signature',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 40),
          pw.Container(
            width: 150,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Date:',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 25),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
                  ),
                  height: 1,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'DD/MM/YYYY',
                  style: pw.TextStyle(
                    fontSize: 8,
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

  /// Build image grid layout based on number of images (1-4 per page)
  pw.Widget _buildImageGrid(List<pw.MemoryImage> images, int startIndex) {
    final count = images.length;

    if (count == 1) {
      // Single image - centered
      return pw.Center(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Container(
                constraints: const pw.BoxConstraints(maxHeight: 650),
                child: pw.Image(images[0], fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Document ${startIndex + 1}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      );
    } else if (count == 2) {
      // Two images - side by side
      return pw.Row(
        children: [
          for (int i = 0; i < 2; i++)
            pw.Expanded(
              child: pw.Container(
                margin: pw.EdgeInsets.only(right: i == 0 ? 6 : 0),
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Expanded(
                      child: pw.Image(images[i], fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + i + 1}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } else if (count == 3) {
      // Three images - 2 on top, 1 centered at bottom
      return pw.Column(
        children: [
          // Top row - 2 images
          pw.Expanded(
            child: pw.Row(
              children: [
                for (int i = 0; i < 2; i++)
                  pw.Expanded(
                    child: pw.Container(
                      margin: pw.EdgeInsets.only(right: i == 0 ? 6 : 0, bottom: 6),
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Image(images[i], fit: pw.BoxFit.contain),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Document ${startIndex + i + 1}',
                            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Bottom row - 1 image centered
          pw.Expanded(
            child: pw.Center(
              child: pw.Container(
                width: 380,
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Expanded(
                      child: pw.Image(images[2], fit: pw.BoxFit.contain),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + 3}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Four images - 2x2 grid
      return pw.Column(
        children: [
          for (int row = 0; row < 2; row++)
            pw.Expanded(
              child: pw.Row(
                children: [
                  for (int col = 0; col < 2; col++)
                    if (row * 2 + col < images.length)
                      pw.Expanded(
                        child: pw.Container(
                          margin: pw.EdgeInsets.only(
                            right: col == 0 ? 6 : 0,
                            bottom: row == 0 ? 6 : 0,
                          ),
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                          ),
                          child: pw.Column(
                            children: [
                              pw.Expanded(
                                child: pw.Image(images[row * 2 + col], fit: pw.BoxFit.contain),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Document ${startIndex + row * 2 + col + 1}',
                                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
        ],
      );
    }
  }

  /// Print all support documents from a list of transactions in one PDF
  Future<void> printAllSupportDocuments(
    List<Transaction> transactions,
    PettyCashReport report,
  ) async {
    try {
      print('Printing all support documents for ${transactions.length} transactions');

      // Filter transactions with support documents
      final transactionsWithDocs = transactions
          .where((t) => t.supportDocumentUrl != null && t.supportDocumentUrl!.isNotEmpty)
          .toList();

      if (transactionsWithDocs.isEmpty) {
        throw Exception('No support documents found');
      }

      final pdf = pw.Document();

      // Load font for better rendering
      pw.Font? ttf;
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
        ttf = pw.Font.ttf(fontData);
      } catch (e) {
        AppLogger.warning('Failed to load custom font: $e');
      }

      // Add a page for each support document
      for (var transaction in transactionsWithDocs) {
        try {
          print('Fetching document for voucher ${transaction.receiptNo}');

          final response = await http.get(Uri.parse(transaction.supportDocumentUrl!));
          if (response.statusCode == 200) {
            final imageBytes = response.bodyBytes;
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                theme: pw.ThemeData.withFont(
                  base: ttf ?? pw.Font.helvetica(),
                ),
                build: (context) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header with voucher info
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Support Document',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Voucher No: ${transaction.receiptNo}'),
                          pw.Text('Description: ${transaction.description}'),
                          pw.Text('Amount: ฿${NumberFormat('#,##0.00').format(transaction.amount)}'),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    // Image
                    pw.Expanded(
                      child: pw.Center(
                        child: pw.Image(image, fit: pw.BoxFit.contain),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            print('Failed to load document for voucher ${transaction.receiptNo}');
          }
        } catch (e) {
          print('Error loading document for voucher ${transaction.receiptNo}: $e');
          // Continue with other documents even if one fails
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw Exception('Failed to load any support documents');
      }

      final bytes = await pdf.save();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'All_Support_Documents_${report.reportNumber}',
      );

      print('Successfully printed ${pdf.document.pdfPageList.pages.length} support documents');
    } catch (e) {
      AppLogger.severe('Error printing all support documents: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }
}
