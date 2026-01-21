import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
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
import 'firebase_storage_service.dart';
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
            _buildHeader(ttf, ttfBold, logoImage),
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

  pw.Widget _buildHeader(pw.Font? font, pw.Font? fontBold, pw.ImageProvider? logoImage) {
    return pw.Column(
      children: [
        // Logo
        if (logoImage != null)
          pw.Center(
            child: pw.Container(
              width: 40,
              height: 40,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          ),
        if (logoImage != null) pw.SizedBox(height: 4),
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
    final isBankTransfer =
        transaction.paymentMethod == PaymentMethod.bankTransfer.name;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureBox(
            'Received By:',
            'Name',
            isBankTransfer,
            font,
            fontBold,
          ),
          _buildSignatureBox('Paid By:', '', false, font, fontBold),
          _buildActionNumberBox(font, fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(
    String title,
    String subtitle,
    bool showTR,
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
            'Approved By:',
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
  Future<void> printSupportDocument(
    String documentUrl,
    String transactionReceiptNo,
  ) async {
    try {
      AppLogger.info('Fetching support document: $documentUrl');

      // Fetch the image using FirebaseStorageService for proper authentication
      final storageService = FirebaseStorageService();
      final imageBytes = await storageService.downloadImageData(documentUrl);

      if (imageBytes == null) {
        throw Exception('Failed to load support document');
      }

      // Detect basic image format; skip unsupported (e.g., PDF)
      String imageFormat = 'unknown';
      if (imageBytes.length > 4) {
        if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
          imageFormat = 'JPEG';
        } else if (imageBytes[0] == 0x89 &&
            imageBytes[1] == 0x50 &&
            imageBytes[2] == 0x4E &&
            imageBytes[3] == 0x47) {
          imageFormat = 'PNG';
        } else if (imageBytes[0] == 0x47 &&
            imageBytes[1] == 0x49 &&
            imageBytes[2] == 0x46) {
          imageFormat = 'GIF';
        } else if (imageBytes[0] == 0x25 &&
            imageBytes[1] == 0x50 &&
            imageBytes[2] == 0x44 &&
            imageBytes[3] == 0x46) {
          imageFormat = 'PDF';
        }
      }

      AppLogger.info(
        'Support document format detected: $imageFormat, size: ${imageBytes.length} bytes',
      );

      if (imageFormat == 'PDF') {
        AppLogger.info(
          'Detected PDF support document, sending raw PDF to printer',
        );
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => imageBytes,
          name: 'Support_Document_$transactionReceiptNo',
        );
        return;
      }

      if (imageFormat == 'unknown') {
        throw Exception('Unsupported support document format: $imageFormat');
      }

      // Load fonts using built-in Google fonts to avoid Helvetica fallback
      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        ttf = await PdfGoogleFonts.notoSansThaiRegular();
        ttfBold = await PdfGoogleFonts.notoSansThaiBold();
      } catch (e) {
        AppLogger.warning(
          'Failed to load Google fonts for support doc print: $e',
        );
      }

      final image = pw.MemoryImage(imageBytes);

      // Create PDF with the image
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: ttf ?? pw.Font.helvetica(),
            bold: ttfBold ?? pw.Font.helveticaBold(),
            fontFallback: [pw.Font.helvetica(), pw.Font.courier()],
          ),
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'Support Document - Voucher $transactionReceiptNo',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  height: PdfPageFormat.a4.height * 0.7,
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
      AppLogger.info(
        'Printing ${documentUrls.length} support documents for voucher $transactionReceiptNo',
      );

      if (documentUrls.isEmpty) {
        throw Exception('No support documents to print');
      }

      final pdf = pw.Document();

      // Load font for better rendering (Google Fonts avoids Helvetica fallback)
      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        ttf = await PdfGoogleFonts.notoSansThaiRegular();
        ttfBold = await PdfGoogleFonts.notoSansThaiBold();
      } catch (e) {
        AppLogger.warning('Failed to load Google font: $e');
      }

      // Add a page for each support document
      final storageService = FirebaseStorageService();
      for (int i = 0; i < documentUrls.length; i++) {
        try {
          AppLogger.info('Fetching document ${i + 1}/${documentUrls.length}');

          final imageBytes = await storageService.downloadImageData(
            documentUrls[i],
          );
          if (imageBytes != null) {
            // Detect format to skip non-images
            String imageFormat = 'unknown';
            if (imageBytes.length > 4) {
              if (imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) {
                imageFormat = 'JPEG';
              } else if (imageBytes[0] == 0x89 &&
                  imageBytes[1] == 0x50 &&
                  imageBytes[2] == 0x4E &&
                  imageBytes[3] == 0x47) {
                imageFormat = 'PNG';
              } else if (imageBytes[0] == 0x47 &&
                  imageBytes[1] == 0x49 &&
                  imageBytes[2] == 0x46) {
                imageFormat = 'GIF';
              } else if (imageBytes[0] == 0x25 &&
                  imageBytes[1] == 0x50 &&
                  imageBytes[2] == 0x44 &&
                  imageBytes[3] == 0x46) {
                imageFormat = 'PDF';
              }
            }

            AppLogger.info('Document ${i + 1} format: $imageFormat');

            if (imageFormat == 'JPEG' ||
                imageFormat == 'PNG' ||
                imageFormat == 'GIF') {
              final image = pw.MemoryImage(imageBytes);

              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  theme: pw.ThemeData.withFont(
                    base: ttf,
                    bold: ttfBold,
                    fontFallback: [
                      pw.Font.helvetica(),
                      pw.Font.helveticaBold(),
                    ],
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
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
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
              AppLogger.warning(
                'Skipping document ${i + 1} due to unsupported format: $imageFormat',
              );
            }
          } else {
            AppLogger.warning('Failed to load document ${i + 1}');
          }
        } catch (e) {
          AppLogger.warning('Error loading document ${i + 1}: $e');
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

      AppLogger.info(
        'Successfully printed ${pdf.document.pdfPageList.pages.length} support documents',
      );
    } catch (e) {
      AppLogger.severe('Error printing multiple support documents: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

  /// Generate PDF for multiple support documents with grid layout (up to 4 per page) - for preview
  /// Uses the same pattern as traveling report export service which is known to work
  Future<pw.Document> generateMultipleSupportDocumentsGrid(
    List<String> documentUrls,
    String transactionReceiptNo,
    String description,
    double amount,
  ) async {
    try {
      AppLogger.info(
        'Generating PDF for ${documentUrls.length} support documents',
      );

      if (documentUrls.isEmpty) {
        throw Exception('No support documents to generate');
      }

      final pdf = pw.Document();
      final storageService = FirebaseStorageService();

      // Load Thai font for proper rendering including Baht symbol
      pw.Font? ttf;
      pw.Font? ttfBold;
      try {
        ttf = await PdfGoogleFonts.notoSansThaiRegular();
        ttfBold = await PdfGoogleFonts.notoSansThaiBold();
      } catch (e) {
        AppLogger.warning('Failed to load Google font: $e');
      }

      final totalDocs = documentUrls.length;

      // Follow the exact same pattern as traveling report export service:
      // Fetch each image and immediately add page in the same loop iteration
      for (int i = 0; i < documentUrls.length; i++) {
        final documentUrl = documentUrls[i];

        try {
          AppLogger.info('Fetching document ${i + 1}/${documentUrls.length}');
          final imageBytes = await storageService.downloadImageData(documentUrl);

          if (imageBytes != null) {
            AppLogger.info('Successfully fetched document ${i + 1}, size: ${imageBytes.length} bytes');

            // Validate image format
            bool isValidImage = false;
            if (imageBytes.length > 4) {
              // Check for JPEG, PNG, or GIF magic bytes
              if ((imageBytes[0] == 0xFF && imageBytes[1] == 0xD8) || // JPEG
                  (imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && imageBytes[2] == 0x4E && imageBytes[3] == 0x47) || // PNG
                  (imageBytes[0] == 0x47 && imageBytes[1] == 0x49 && imageBytes[2] == 0x46)) { // GIF
                isValidImage = true;
              }
            }

            if (isValidImage) {
              final docNumber = i + 1;
              // Add page immediately with imageBytes in scope - exactly like traveling report service
              pdf.addPage(
                pw.Page(
                  pageFormat: PdfPageFormat.a4,
                  margin: const pw.EdgeInsets.all(24),
                  theme: pw.ThemeData.withFont(
                    base: ttf ?? pw.Font.helvetica(),
                    bold: ttfBold ?? pw.Font.helveticaBold(),
                    fontFallback: [pw.Font.helvetica()],
                  ),
                  build: (context) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
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
                                    'Support Document $docNumber of $totalDocs',
                                    style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 6),
                                  pw.Text(
                                    'Voucher No: $transactionReceiptNo',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                  pw.Text(
                                    'Description: $description',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                  pw.Text(
                                    'Amount: ${NumberFormat.currency(symbol: "THB ", decimalDigits: 2).format(amount)}',
                                    style: const pw.TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey200,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                'Page $docNumber/$totalDocs',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 12),

                      // Image section - 70% smaller (30% of original size in container)
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Container(
                            constraints: const pw.BoxConstraints(
                              maxWidth: 350,  // 70% smaller
                              maxHeight: 450, // 70% smaller
                            ),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                            ),
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Image(
                              pw.MemoryImage(imageBytes),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 12),

                      // Signature section
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                          children: [
                            pw.Container(
                              width: 180,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Verified By:',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.SizedBox(height: 30),
                                  pw.Container(
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(
                                        bottom: pw.BorderSide(color: PdfColors.black),
                                      ),
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
                            pw.Container(
                              width: 140,
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
                                  pw.SizedBox(height: 30),
                                  pw.Container(
                                    decoration: const pw.BoxDecoration(
                                      border: pw.Border(
                                        bottom: pw.BorderSide(color: PdfColors.black),
                                      ),
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
                      ),
                    ],
                  ),
                ),
              );
              AppLogger.info('Added page for document ${i + 1}');
            } else {
              AppLogger.warning('Skipping document ${i + 1} - not a valid image format');
            }
          } else {
            AppLogger.warning('Failed to download document ${i + 1}');
          }
        } catch (e) {
          AppLogger.warning('Error loading document ${i + 1}: $e');
          // Continue with other documents
        }
      }

      if (pdf.document.pdfPageList.pages.isEmpty) {
        throw Exception('Failed to load any support documents');
      }

      AppLogger.info(
        'PDF generated successfully with ${pdf.document.pdfPageList.pages.length} pages',
      );

      return pdf;
    } catch (e) {
      AppLogger.severe('Error generating support documents: $e');
      throw Exception('Failed to generate support documents: $e');
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
      print('=== PRINTING MULTIPLE SUPPORT DOCUMENTS GRID ===');
      final pdf = await generateMultipleSupportDocumentsGrid(
        documentUrls,
        transactionReceiptNo,
        description,
        amount,
      );

      print('Saving PDF to bytes...');
      final bytes = await pdf.save();
      print('PDF saved successfully, size: ${bytes.length} bytes, pages: ${pdf.document.pdfPageList.pages.length}');
      AppLogger.info(
        'PDF generated successfully, size: ${bytes.length} bytes, pages: ${pdf.document.pdfPageList.pages.length}',
      );

      print('Sending PDF to printer...');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          print('Printing layoutPdf called, returning ${bytes.length} bytes');
          AppLogger.info(
            'Printing layoutPdf called, returning ${bytes.length} bytes',
          );
          return bytes;
        },
        name: 'Support_Documents_Grid_$transactionReceiptNo',
      );
      print('PDF sent to printer successfully');

      AppLogger.info(
        'Successfully printed ${documentUrls.length} documents in grid layout',
      );
    } catch (e) {
      AppLogger.severe('Error printing support documents in grid: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

  /// Build signature section for support documents
  pw.Widget _buildSupportDocumentSignatureSection(
    pw.Font? font,
    pw.Font? fontBold,
  ) {
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
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black),
                    ),
                  ),
                  height: 1,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Signature',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
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
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black),
                    ),
                  ),
                  height: 1,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'DD/MM/YYYY',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build image grid layout from raw bytes (creates MemoryImage inline for proper PDF embedding)
  pw.Widget _buildImageGridFromBytes(List<Uint8List> imageDataList, int startIndex) {
    final count = imageDataList.length;

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
                constraints: const pw.BoxConstraints(maxHeight: 650, maxWidth: 500),
                child: pw.Image(
                  pw.MemoryImage(imageDataList[0]),
                  fit: pw.BoxFit.contain,
                ),
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
                      child: pw.Image(
                        pw.MemoryImage(imageDataList[i]),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + i + 1}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
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
                      margin: pw.EdgeInsets.only(
                        right: i == 0 ? 6 : 0,
                        bottom: 6,
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Image(
                              pw.MemoryImage(imageDataList[i]),
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Document ${startIndex + i + 1}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
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
                      child: pw.Image(
                        pw.MemoryImage(imageDataList[2]),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + 3}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
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
                    if (row * 2 + col < imageDataList.length)
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
                                child: pw.Image(
                                  pw.MemoryImage(imageDataList[row * 2 + col]),
                                  fit: pw.BoxFit.contain,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Document ${startIndex + row * 2 + col + 1}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
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

  /// Build image grid layout based on number of images (1-4 per page) - legacy method
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
                constraints: const pw.BoxConstraints(maxHeight: 650, maxWidth: 500),
                child: pw.Image(
                  images[0],
                  fit: pw.BoxFit.scaleDown, // Changed from BoxFit.contain to BoxFit.scaleDown
                ),
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
                      child: pw.Image(
                        images[i],
                        fit: pw.BoxFit.scaleDown, // Changed from BoxFit.contain to BoxFit.scaleDown
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + i + 1}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
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
                      margin: pw.EdgeInsets.only(
                        right: i == 0 ? 6 : 0,
                        bottom: 6,
                      ),
                      padding: const pw.EdgeInsets.all(4),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Expanded(
                            child: pw.Image(
                              images[i],
                              fit: pw.BoxFit.scaleDown, // Changed from BoxFit.contain to BoxFit.scaleDown
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Document ${startIndex + i + 1}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
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
                      child: pw.Image(
                        images[2],
                        fit: pw.BoxFit.scaleDown, // Changed from BoxFit.contain to BoxFit.scaleDown
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Document ${startIndex + 3}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
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
                                child: pw.Image(
                                  images[row * 2 + col],
                                  fit: pw.BoxFit.scaleDown, // Changed from BoxFit.contain to BoxFit.scaleDown
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Document ${startIndex + row * 2 + col + 1}',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700,
                                ),
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
      print(
        'Printing all support documents for ${transactions.length} transactions',
      );

      // Filter transactions with support documents
      final transactionsWithDocs = transactions
          .where(
            (t) =>
                t.supportDocumentUrl != null &&
                t.supportDocumentUrl!.isNotEmpty,
          )
          .toList();

      if (transactionsWithDocs.isEmpty) {
        throw Exception('No support documents found');
      }

      final pdf = pw.Document();

      // Load font for better rendering
      pw.Font? ttf;
      try {
        final fontData = await rootBundle.load(
          'assets/fonts/NotoSansThai-Regular.ttf',
        );
        ttf = pw.Font.ttf(fontData);
      } catch (e) {
        AppLogger.warning('Failed to load custom font: $e');
      }

      // Add a page for each support document
      for (var transaction in transactionsWithDocs) {
        try {
          print('Fetching document for voucher ${transaction.receiptNo}');

          final response = await http.get(
            Uri.parse(transaction.supportDocumentUrl!),
          );
          if (response.statusCode == 200) {
            final imageBytes = response.bodyBytes;
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                theme: pw.ThemeData.withFont(base: ttf ?? pw.Font.helvetica()),
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
                          pw.Text(
                            'Amount: ฿${NumberFormat('#,##0.00').format(transaction.amount)}',
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
            print(
              'Failed to load document for voucher ${transaction.receiptNo}',
            );
          }
        } catch (e) {
          print(
            'Error loading document for voucher ${transaction.receiptNo}: $e',
          );
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

      print(
        'Successfully printed ${pdf.document.pdfPageList.pages.length} support documents',
      );
    } catch (e) {
      AppLogger.severe('Error printing all support documents: $e');
      throw Exception('Failed to print support documents: $e');
    }
  }

}
