import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/purchase_requisition.dart';
import '../services/currency_service.dart';

class PurchaseRequisitionItemDialog extends StatefulWidget {
  final PurchaseRequisitionItem? item; // null for new item
  final int nextItemNo;

  const PurchaseRequisitionItemDialog({
    super.key,
    this.item,
    this.nextItemNo = 1,
  });

  @override
  State<PurchaseRequisitionItemDialog> createState() =>
      _PurchaseRequisitionItemDialogState();
}

class _PurchaseRequisitionItemDialogState
    extends State<PurchaseRequisitionItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _quantityController;
  late TextEditingController _unitPriceController;
  late TextEditingController _usdUnitPriceController;
  late TextEditingController _exchangeRateController;
  late TextEditingController _remarkController;

  String _currency = 'THB'; // 'THB' or 'USD'
  bool _fetchingRate = false;

  final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  // Unit price in THB (final stored value)
  double get _unitPriceTHB {
    if (_currency == 'THB') {
      return double.tryParse(_unitPriceController.text) ?? 0.0;
    } else {
      final usd = double.tryParse(_usdUnitPriceController.text) ?? 0.0;
      final rate = double.tryParse(_exchangeRateController.text) ?? 0.0;
      return usd * rate;
    }
  }

  double get _usdUnitPrice =>
      double.tryParse(_usdUnitPriceController.text) ?? 0.0;
  double get _exchangeRate =>
      double.tryParse(_exchangeRateController.text) ?? 0.0;
  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  double get _totalTHB => _quantity * _unitPriceTHB;
  double get _totalUSD => _quantity * _usdUnitPrice;

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _quantityController =
        TextEditingController(text: item?.quantity.toString() ?? '1');
    _unitPriceController =
        TextEditingController(text: item?.unitPrice.toString() ?? '0');
    // Restore USD values when editing an existing item
    _usdUnitPriceController = TextEditingController(
      text: item?.usdUnitPrice != null
          ? item!.usdUnitPrice!.toStringAsFixed(2)
          : '',
    );
    _exchangeRateController = TextEditingController(
      text: item?.exchangeRate?.toStringAsFixed(4) ?? '35.0',
    );
    _remarkController = TextEditingController(text: item?.remark ?? '');

    if (item?.usdUnitPrice != null) {
      _currency = 'USD';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _usdUnitPriceController.dispose();
    _exchangeRateController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveRate() async {
    setState(() => _fetchingRate = true);
    final rate = await CurrencyService().getUsdToThbRate(forceRefresh: true);
    if (mounted) {
      setState(() {
        _fetchingRate = false;
        if (rate != null) {
          _exchangeRateController.text = rate.toStringAsFixed(4);
        }
      });
      if (rate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not fetch live rate. Please enter manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());
    if (quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quantity must be at least 1'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final unitPrice = _unitPriceTHB;
    if (unitPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unit price must be greater than 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'itemNo': widget.item?.itemNo ?? widget.nextItemNo,
      'description': _descriptionController.text.trim(),
      'quantity': quantity,
      'unitPrice': unitPrice, // always THB
      'usdUnitPrice': _currency == 'USD' ? _usdUnitPrice : null,
      'exchangeRate': _currency == 'USD' ? _exchangeRate : null,
      'remark': _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isNew ? 'Add Item' : 'Edit Item',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Item No
                TextFormField(
                  initialValue:
                      (widget.item?.itemNo ?? widget.nextItemNo).toString(),
                  decoration: const InputDecoration(
                    labelText: 'No.',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Quantity
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Required';
                    final n = int.tryParse(value.trim());
                    if (n == null || n < 1) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency toggle
                const Text(
                  'Currency',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'THB',
                      label: Text('THB (฿)'),
                      icon: Icon(Icons.currency_exchange, size: 16),
                    ),
                    ButtonSegment(
                      value: 'USD',
                      label: Text('USD (\$)'),
                      icon: Icon(Icons.attach_money, size: 16),
                    ),
                  ],
                  selected: {_currency},
                  onSelectionChanged: (set) {
                    setState(() {
                      _currency = set.first;
                    });
                  },
                  style: ButtonStyle(
                    iconSize: WidgetStateProperty.all(16),
                  ),
                ),
                const SizedBox(height: 16),

                // Price fields
                if (_currency == 'THB') ...[
                  TextFormField(
                    controller: _unitPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Unit Price (฿)',
                      prefixText: '฿ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final n = double.tryParse(value.trim());
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ] else ...[
                  // USD price + exchange rate side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _usdUnitPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Unit Price (USD)',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (_currency != 'USD') return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            final n = double.tryParse(value.trim());
                            if (n == null || n <= 0) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _exchangeRateController,
                              decoration: const InputDecoration(
                                labelText: 'Rate (฿/\$)',
                                border: OutlineInputBorder(),
                                helperText: 'THB per 1 USD',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,4}')),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if (_currency != 'USD') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Required';
                                }
                                final n = double.tryParse(value.trim());
                                if (n == null || n <= 0) return 'Invalid rate';
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 28,
                              child: _fetchingRate
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : TextButton.icon(
                                      onPressed: _fetchLiveRate,
                                      icon: const Icon(Icons.sync, size: 14),
                                      label: const Text('Live rate',
                                          style: TextStyle(fontSize: 11)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.blue.shade700,
                                        padding: EdgeInsets.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // THB conversion preview for USD mode
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.currency_exchange,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unit price in THB: ฿${currencyFormat.format(_unitPriceTHB)}'
                            '  (${currencyFormat.format(_usdUnitPrice)} × ${currencyFormat.format(_exchangeRate)})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Total Price
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      if (_currency == 'USD') ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total (USD):',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              '\$${currencyFormat.format(_totalUSD)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _currency == 'USD'
                                ? 'Total (THB):'
                                : 'Total Price:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          Text(
                            '฿${currencyFormat.format(_totalTHB)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Warning for items > 20,000 Baht
                if (_totalTHB > 20000) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            size: 20, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This item exceeds 20,000 Baht and will require Action No. for approval.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Remark
                TextFormField(
                  controller: _remarkController,
                  decoration: const InputDecoration(
                    labelText: 'Remark (Optional)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Use for department specification if purchasing for multiple departments',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isNew ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
