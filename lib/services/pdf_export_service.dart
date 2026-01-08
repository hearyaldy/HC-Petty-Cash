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
        build: (context) => [
          // Header
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Column(
              children: [
                pw.Text(
                  AppConstants.organizationName,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  AppConstants.organizationNameThai,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  AppConstants.organizationAddress,
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 8),
                pw.Text(
                  'PETTY CASH REPORT',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Report Information
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

          // Transactions Table
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

          // Footer
          pw.SizedBox(height: 30),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated on: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
              pw.Text(
                'Report: ${report.reportNumber}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ],
          ),
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
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildTableCell('Date', isHeader: true),
            _buildTableCell('Receipt No', isHeader: true),
            _buildTableCell('Description', isHeader: true),
            _buildTableCell('Category', isHeader: true),
            _buildTableCell('Amount', isHeader: true),
          ],
        ),
        // Data rows
        ...transactions.map((transaction) {
          return pw.TableRow(
            children: [
              _buildTableCell(dateFormat.format(transaction.date)),
              _buildTableCell(transaction.receiptNo),
              _buildTableCell(transaction.description),
              _buildTableCell(transaction.category.expenseCategoryDisplayName),
              _buildTableCell(
                currencyFormat.format(transaction.amount),
                alignment: pw.Alignment.centerRight,
              ),
            ],
          );
        }),
      ],
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
            'Total Disbursements:',
            currencyFormat.format(report.totalDisbursements),
          ),
          _buildSummaryRow(
            'Cash on Hand:',
            currencyFormat.format(report.cashOnHand),
          ),
          _buildSummaryRow(
            'Closing Balance:',
            currencyFormat.format(report.closingBalance),
          ),
          pw.Divider(),
          _buildSummaryRow(
            'Variance:',
            currencyFormat.format(report.variance),
            isBold: true,
          ),
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
}
