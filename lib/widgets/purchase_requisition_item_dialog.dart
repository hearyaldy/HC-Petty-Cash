import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/purchase_requisition.dart';

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
  late TextEditingController _remarkController;
  final currencyFormat = NumberFormat('#,##0.00', 'en_US');

  double get _totalPrice {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final unitPrice = double.tryParse(_unitPriceController.text) ?? 0.0;
    return quantity * unitPrice;
  }

  @override
  void initState() {
    super.initState();
    final item = widget.item;

    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _quantityController = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    _unitPriceController = TextEditingController(
      text: item?.unitPrice.toString() ?? '0',
    );
    _remarkController = TextEditingController(
      text: item?.remark ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final quantity = int.parse(_quantityController.text.trim());
      final unitPrice = double.parse(_unitPriceController.text.trim());

      if (quantity < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quantity must be at least 1'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (unitPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unit price must be greater than 0'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final result = {
        'itemNo': widget.item?.itemNo ?? widget.nextItemNo,
        'description': _descriptionController.text.trim(),
        'quantity': quantity,
        'unitPrice': unitPrice,
        'remark': _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
      };

      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.item == null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  initialValue: (widget.item?.itemNo ?? widget.nextItemNo)
                      .toString(),
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

                // Quantity and Unit Price in a row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final number = int.tryParse(value.trim());
                          if (number == null || number < 1) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _unitPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Unit Price (฿)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          final number = double.tryParse(value.trim());
                          if (number == null || number <= 0) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Total Price (Calculated, Read-only)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Price:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.purple.shade700,
                        ),
                      ),
                      Text(
                        '฿${currencyFormat.format(_totalPrice)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Warning for items > 20,000 Baht
                if (_totalPrice > 20000) ...[
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
                        Icon(
                          Icons.warning,
                          size: 20,
                          color: Colors.orange.shade700,
                        ),
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
                        backgroundColor: Colors.purple,
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
