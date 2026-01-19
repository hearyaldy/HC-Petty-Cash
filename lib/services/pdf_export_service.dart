import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/petty_cash_report.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';
import 'firestore_service.dart';
import '../models/enums.dart';

class PdfExportService {
  Future<String> exportReport(PettyCashReport report) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$');

    // Get transactions
    final transactions = await FirestoreService().getTransactionsByReportId(
      report.id,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(report),
        footer: (context) => _buildFooter(context, report),
        build: (context) => [
          _buildInfoSection(report, dateFormat),
          pw.SizedBox(height: 20),

          // Opening Balance
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Opening Balance:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                currencyFormat.format(report.openingBalance),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // Transactions Table (auto-paginates)
          pw.Text(
            'Transactions',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildTransactionsTable(transactions, dateFormat, currencyFormat),
          pw.SizedBox(height: 20),

          // Summary
          _buildSummarySection(report, currencyFormat),

          // Notes
          if (report.notes != null && report.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Notes:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Text(report.notes!),
          ],

          // Signature Section
          pw.SizedBox(height: 30),
          _buildSignatureSection(),
        ],
      ),
    );

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${report.reportNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = '${directory.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    return filePath;
  }

  pw.Widget _buildInfoSection(PettyCashReport report, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Report Number:', report.reportNumber),
          _buildInfoRow(
            'Period:',
            '${dateFormat.format(report.periodStart)} - ${dateFormat.format(report.periodEnd)}',
          ),
          _buildInfoRow('Department:', report.department),
          _buildInfoRow('Custodian:', report.custodianName),
          _buildInfoRow('Status:', report.statusEnum.displayName),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  pw.Widget _buildTransactionsTable(
    List<Transaction> transactions,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    final rows = transactions
        .map(
          (transaction) => [
            dateFormat.format(transaction.date),
            transaction.receiptNo,
            transaction.description,
            transaction.category.expenseCategoryDisplayName,
            currencyFormat.format(transaction.amount),
          ],
        )
        .toList();

    return pw.ListView.builder(
      itemCount: rows.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildTransactionRow(const [
            'Date',
            'Receipt No',
            'Description',
            'Category',
            'Amount',
          ], isHeader: true);
        }

        return _buildTransactionRow(rows[index - 1]);
      },
    );
  }

  pw.Widget _buildTransactionRow(List<String> cells, {bool isHeader = false}) {
    final styles = pw.TextStyle(
      fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: isHeader ? 10 : 9,
    );

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.grey300 : null,
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 15, child: pw.Text(cells[0], style: styles)),
          pw.Expanded(flex: 15, child: pw.Text(cells[1], style: styles)),
          pw.Expanded(flex: 30, child: pw.Text(cells[2], style: styles)),
          pw.Expanded(flex: 20, child: pw.Text(cells[3], style: styles)),
          pw.Expanded(
            flex: 15,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(cells[4], style: styles),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.Alignment? alignment,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      alignment: alignment ?? pw.Alignment.centerLeft,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 10 : 9,
        ),
      ),
    );
  }

  pw.Widget _buildHeader(PettyCashReport report) {
    return pw.Column(
      children: [
        pw.Text(
          AppConstants.organizationName,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          AppConstants.organizationNameThai,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          AppConstants.organizationAddress,
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'PETTY CASH REPORT',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Report: ${report.reportNumber}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Divider(),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context, PettyCashReport report) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(
    PettyCashReport report,
    NumberFormat currencyFormat,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          _buildSummaryRow(
            'Opening Balance:',
            currencyFormat.format(report.openingBalance),
          ),
          _buildSummaryRow(
            'Total Disbursements:',
            currencyFormat.format(report.totalDisbursements),
          ),
          pw.Divider(),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Balance:',
                currencyFormat.format(
                  report.openingBalance - report.totalDisbursements,
                ),
                isBold: true,
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4, top: 2),
                child: pw.Text(
                  '(${_convertToWords(report.openingBalance - report.totalDisbursements)})',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _buildSummaryRow(
            'Cash on Hand:',
            currencyFormat.format(report.cashOnHand),
          ),
          _buildSummaryRow(
            'Closing Balance:',
            currencyFormat.format(report.closingBalance),
          ),
          _buildSummaryRow('Variance:', currencyFormat.format(report.variance)),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSignatureBox('Received By:', 'Name'),
          _buildSignatureBox('Paid By:', ''),
          _buildApprovedByBox(),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBox(String title, String subtitle) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 30),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black)),
            ),
            height: 1,
          ),
          pw.SizedBox(height: 4),
          if (subtitle.isNotEmpty)
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildApprovedByBox() {
    return pw.Container(
      width: 120,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Approved By:',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 30),
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

  String _convertToWords(double amount) {
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
