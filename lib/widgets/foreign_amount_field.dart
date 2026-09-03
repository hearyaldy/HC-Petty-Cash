import 'package:flutter/material.dart';

/// A companion input for a THB amount field: lets the user type the amount
/// in the report's foreign currency (e.g. the RM figure on a Malaysian
/// receipt) and fills the THB field via the report's exchange rate — or the
/// reverse. [rate] is THB per 1 unit of [currencyCode].
class ForeignAmountField extends StatefulWidget {
  final TextEditingController thbController;
  final String currencyCode;
  final double rate;

  const ForeignAmountField({
    super.key,
    required this.thbController,
    required this.currencyCode,
    required this.rate,
  });

  @override
  State<ForeignAmountField> createState() => _ForeignAmountFieldState();
}

class _ForeignAmountFieldState extends State<ForeignAmountField> {
  final _foreignController = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _syncFromThb();
    widget.thbController.addListener(_syncFromThb);
  }

  @override
  void dispose() {
    widget.thbController.removeListener(_syncFromThb);
    _foreignController.dispose();
    super.dispose();
  }

  void _syncFromThb() {
    if (_syncing) return;
    final thb = double.tryParse(widget.thbController.text.trim());
    _syncing = true;
    _foreignController.text =
        thb == null ? '' : (thb / widget.rate).toStringAsFixed(2);
    _syncing = false;
  }

  void _onForeignChanged(String value) {
    if (_syncing) return;
    final foreign = double.tryParse(value.trim());
    _syncing = true;
    widget.thbController.text =
        foreign == null ? '' : (foreign * widget.rate).toStringAsFixed(2);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _foreignController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: _onForeignChanged,
      decoration: InputDecoration(
        labelText: 'Amount in ${widget.currencyCode}',
        border: const OutlineInputBorder(),
        prefixText: '${widget.currencyCode} ',
        prefixIcon: const Icon(Icons.currency_exchange),
        helperText: 'Fills the Baht amount @ 1 ${widget.currencyCode} = '
            '${widget.rate.toStringAsFixed(4)} THB — edit either field',
      ),
    );
  }
}
