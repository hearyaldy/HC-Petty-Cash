import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/payment_voucher.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class PaymentVoucherPdfExportService {
  pw.Font? _ttf;
  pw.Font? _ttfBold;
  pw.ImageProvider? _logoImage;

  Future<void> _loadAssets() async {
    if (_ttf != null && _ttfBold != null) return;

    try {
      final fontData =
          await rootBundle.load('assets/fonts/NotoSansThai-Regular.ttf');
      _ttf = pw.Font.ttf(fontData);
      final fontBoldData =
          await rootBundle.load('assets/fonts/NotoSansThai-Bold.ttf');
      _ttfBold = pw.Font.ttf(fontBoldData);
    } catch (e) {
      AppLogger.warning('PaymentVoucherPdf: Failed to load custom fonts: $e');
    }

    try {
      final logoData =
          await rootBundle.load('assets/images/hope_channel_logo.png');
      _logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Logo loading failed; will use text fallback.
      AppLogger.warning('PaymentVoucherPdf: Failed to load logo: $e');
    }
  }

  Future<Uint8List> generatePdf(PaymentVoucher voucher) async {
    await _loadAssets();

    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: _ttf ?? pw.Font.helvetica(),
          bold: _ttfBold ?? pw.Font.helveticaBold(),
          fontFallback: [pw.Font.helvetica()],
        ),
        header: (context) => _buildHeader(voucher, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(voucher),
          pw.SizedBox(height: 16),
          _buildRecipientsTable(voucher),
          pw.SizedBox(height: 16),
          _buildPurposeSection(voucher),
          pw.SizedBox(height: 8),
          if (voucher.notes != null && voucher.notes!.isNotEmpty) ...[
            _buildNotesSection(voucher.notes!),
            pw.SizedBox(height: 16),
          ] else
            pw.SizedBox(height: 8),
          _buildAmountSection(voucher, currencyFormat),
          pw.SizedBox(height: 30),
          _buildSignatureSection(voucher),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> printVoucher(PaymentVoucher voucher) async {
    final pdfBytes = await generatePdf(voucher);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Payment_Voucher_${voucher.voucherNumber}',
    );
  }

  // ---------------------------------------------------------------------------
  // Header (repeating on every page)
  // ---------------------------------------------------------------------------

  pw.Widget _buildOrganizationHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
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
            child: pw.DecoratedBox(
              decoration: pw.BoxDecoration(
                color: PdfColors.grey300,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Center(
                child: pw.Text(
                  'H',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ),
          ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.organizationName,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                AppConstants.organizationAddress,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeader(PaymentVoucher voucher, DateFormat dateFormat) {
    return pw.Column(
      children: [
        _buildOrganizationHeader(),
        pw.SizedBox(height: 12),
        // Title box
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          padding:
              const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: pw.Center(
            child: pw.Text(
              'PAYMENT VOUCHER',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(height: 12),
        // Number & Date row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'No: ${voucher.voucherNumber}',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Date: ${dateFormat.format(voucher.voucherDate)}',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.Divider(thickness: 1),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Info section
  // ---------------------------------------------------------------------------

  pw.Widget _buildInfoSection(PaymentVoucher voucher) {
    String paymentMethodLabel;
    switch (voucher.paymentMethod) {
      case 'bank_transfer':
        paymentMethodLabel = 'Bank Transfer';
        break;
      case 'cheque':
        paymentMethodLabel = 'Cheque';
        break;
      default:
        paymentMethodLabel = 'Cash';
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Department:', voucher.department),
          pw.SizedBox(height: 6),
          _buildInfoRow('Payment Method:', paymentMethodLabel),
          if (voucher.paymentMethod == 'bank_transfer') ...[
            if (voucher.bankName != null && voucher.bankName!.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _buildInfoRow('Bank Name:', voucher.bankName!),
            ],
            if (voucher.accountNumber != null &&
                voucher.accountNumber!.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              _buildInfoRow('Account Number:', voucher.accountNumber!),
            ],
          ],
          if (voucher.paymentMethod == 'cheque' &&
              voucher.chequeNumber != null &&
              voucher.chequeNumber!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            _buildInfoRow('Cheque Number:', voucher.chequeNumber!),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Recipients table
  // ---------------------------------------------------------------------------

  pw.Widget _buildRecipientsTable(PaymentVoucher voucher) {
    final recipients = voucher.recipients;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Pay To:',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (recipients.isEmpty)
          pw.Text('N/A', style: const pw.TextStyle(fontSize: 10))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FixedColumnWidth(35),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('No.', isHeader: true),
                  _buildTableCell('Name', isHeader: true),
                ],
              ),
              // Data rows
              ...recipients.asMap().entries.map((entry) {
                final index = entry.key;
                final r = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}'),
                    _buildTableCell(
                      r.name.isEmpty ? '—' : r.name,
                      align: pw.TextAlign.left,
                    ),
                  ],
                );
              }),
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
          fontSize: isHeader ? 10 : 9,
          fontWeight:
              isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Purpose section
  // ---------------------------------------------------------------------------

  pw.Widget _buildPurposeSection(PaymentVoucher voucher) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Purpose / Description:',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(voucher.purpose, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Notes section
  // ---------------------------------------------------------------------------

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
            style:
                pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Amount section
  // ---------------------------------------------------------------------------

  pw.Widget _buildAmountSection(
      PaymentVoucher voucher, NumberFormat currencyFormat) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Left: amount in figures
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Amount in Figures:',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${AppConstants.currencySymbol} ${currencyFormat.format(voucher.amount)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 16),
        // Right: amount in words
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Amount in Words:',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${_amountToWords(voucher.amount)} Baht Only',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Signature section
  // ---------------------------------------------------------------------------

  pw.Widget _buildSignatureSection(PaymentVoucher voucher) {
    // Build the list of signature boxes:
    // 1. Each recipient
    // 2. Prepared By (createdByName)

    final allBoxes = <_SigBox>[
      ...voucher.recipients.map((r) => _SigBox(r.name, r.title)),
      _SigBox(voucher.createdByName, 'Prepared By'),
    ];

    // Split into rows of max 4 boxes.
    const maxPerRow = 4;
    final rows = <List<_SigBox>>[];
    for (var i = 0; i < allBoxes.length; i += maxPerRow) {
      rows.add(
        allBoxes.sublist(
          i,
          (i + maxPerRow).clamp(0, allBoxes.length),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Signatures',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: rows.asMap().entries.map((entry) {
              final isLast = entry.key == rows.length - 1;
              return pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: entry.value
                        .map((box) =>
                            _buildSignatureBox(box.name, box.title))
                        .toList(),
                  ),
                  if (!isLast) pw.Divider(color: PdfColors.grey300),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureBox(String name, String title) {
    return pw.Expanded(
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 50), // space for signature
            pw.Container(
              height: 1,
              color: PdfColors.grey700,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              name,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
            if (title.isNotEmpty)
              pw.Text(
                title,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer (repeating on every page)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Amount-to-words helpers
  // ---------------------------------------------------------------------------

  String _amountToWords(double amount) {
    final intPart = amount.truncate();
    final decPart = ((amount - intPart) * 100).round();
    final words = _intToWords(intPart);
    if (decPart > 0) {
      return '$words and ${_intToWords(decPart)} Satang';
    }
    return words;
  }

  String _intToWords(int n) {
    if (n == 0) return 'Zero';
    if (n < 0) return 'Minus ${_intToWords(-n)}';

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

    if (n < 20) return ones[n];
    if (n < 100) {
      final rem = n % 10;
      return tens[n ~/ 10] + (rem > 0 ? ' ${ones[rem]}' : '');
    }
    if (n < 1000) {
      final rem = n % 100;
      return '${ones[n ~/ 100]} Hundred'
          '${rem > 0 ? ' ${_intToWords(rem)}' : ''}';
    }
    if (n < 1000000) {
      final rem = n % 1000;
      return '${_intToWords(n ~/ 1000)} Thousand'
          '${rem > 0 ? ' ${_intToWords(rem)}' : ''}';
    }
    if (n < 1000000000) {
      final rem = n % 1000000;
      return '${_intToWords(n ~/ 1000000)} Million'
          '${rem > 0 ? ' ${_intToWords(rem)}' : ''}';
    }
    final rem = n % 1000000000;
    return '${_intToWords(n ~/ 1000000000)} Billion'
        '${rem > 0 ? ' ${_intToWords(rem)}' : ''}';
  }
}

// Helper value object used internally.
class _SigBox {
  final String name;
  final String title;
  const _SigBox(this.name, this.title);
}
