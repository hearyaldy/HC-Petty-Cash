import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/petty_cash_report.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../utils/constants.dart';

class VoucherPreviewDialog extends StatelessWidget {
  final Transaction transaction;
  final PettyCashReport report;
  final User? requestor;
  final VoidCallback? onPrint;

  const VoucherPreviewDialog({
    super.key,
    required this.transaction,
    required this.report,
    this.requestor,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '${AppConstants.currencySymbol} ',
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Voucher Preview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Preview Content (Professional A5 Layout)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                ), // A5 proportion
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Organization Header
                    _buildHeader(),
                    const SizedBox(height: 16),

                    // Title
                    _buildTitle(),
                    const SizedBox(height: 16),

                    // Voucher Information Section
                    _buildVoucherInfoSection(
                      requestor,
                      dateFormat,
                      currencyFormat,
                    ),
                    const SizedBox(height: 16),

                    // Description Section
                    _buildDescriptionSection(),
                    const SizedBox(height: 16),

                    // Amount Section
                    _buildAmountSection(currencyFormat),
                    const SizedBox(height: 16),

                    // Signature Section
                    _buildSignatureSection(),

                    // Footer
                    const SizedBox(height: 16),
                    _buildFooter(dateFormat),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onPrint != null
                      ? () {
                          Navigator.of(context).pop(false);
                          onPrint!();
                        }
                      : null,
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.download),
                  label: const Text('Export PDF'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          AppConstants.organizationName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          AppConstants.organizationNameThai,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          AppConstants.organizationAddress,
          style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade500),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: const Center(
        child: Text(
          'PETTY CASH VOUCHER',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildVoucherInfoSection(
    User? requestor,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voucher number and date row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoRow('Voucher No:', transaction.receiptNo),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Date:',
                  dateFormat.format(transaction.date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Report number and department row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoRow('Report No:', report.reportNumber),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: _buildInfoRow('Department:', report.department),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Paid to and requestor row
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Paid to:',
                  transaction.paidTo ?? requestor?.name ?? 'Unknown',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: _buildInfoRow(
                  'Requestor:',
                  requestor?.name ?? 'Unknown',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(transaction.description, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  'Category:',
                  transaction.category.toExpenseCategory().displayName,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildInfoRow(
                  'Payment Method:',
                  transaction.paymentMethod.toPaymentMethod().displayName,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(NumberFormat currencyFormat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade500),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: const Text(
                  'AMOUNT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    currencyFormat.format(transaction.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '(${_convertToWords(transaction.amount)})',
              style: const TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Text(
            'SIGNATURES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSignatureBox('Received By'),
              _buildSignatureBox('Paid By'),
              _buildSignatureBox('Approved By'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox(String title) {
    return SizedBox(
      width: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 25),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black)),
            ),
            padding: const EdgeInsets.only(top: 2),
            child: const Text(
              'Signature',
              style: TextStyle(fontSize: 8, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Date', style: TextStyle(fontSize: 8, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFooter(DateFormat dateFormat) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Voucher ID: ${transaction.id.substring(0, 10)}...',
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
          ),
          Text(
            'Printed: ${dateFormat.format(DateTime.now())}',
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
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

    return number.toString();
  }
}
