import 'package:flutter/material.dart';
import '../services/currency_service.dart';
import 'currency_conversion_option.dart';

/// Holds the foreign-currency choice for an opening balance / advance amount.
/// 'THB' means no conversion. [rate] is THB per 1 unit of [currencyCode].
class OpeningBalanceCurrencyState {
  String currencyCode;
  double? rate;
  double? foreignAmount;

  OpeningBalanceCurrencyState({
    this.currencyCode = 'THB',
    this.rate,
    this.foreignAmount,
  });

  bool get isForeign => currencyCode != 'THB';
  bool get isValid => !isForeign || (rate != null && rate! > 0);
}

/// Companion fields for a THB opening-balance text field: currency picker,
/// exchange rate, and a synced foreign-currency amount field. Editing either
/// amount updates the other through the rate, so both currencies always tally.
class OpeningBalanceCurrencyFields extends StatefulWidget {
  final TextEditingController thbController;
  final OpeningBalanceCurrencyState state;
  final VoidCallback? onChanged;

  const OpeningBalanceCurrencyFields({
    super.key,
    required this.thbController,
    required this.state,
    this.onChanged,
  });

  @override
  State<OpeningBalanceCurrencyFields> createState() =>
      _OpeningBalanceCurrencyFieldsState();
}

class _OpeningBalanceCurrencyFieldsState
    extends State<OpeningBalanceCurrencyFields> {
  final _foreignController = TextEditingController();
  final _rateController = TextEditingController();
  bool _syncing = false;
  bool _fetchingRate = false;
  bool _rateFetchFailed = false;

  OpeningBalanceCurrencyState get st => widget.state;

  @override
  void initState() {
    super.initState();
    if (st.rate != null) {
      _rateController.text = st.rate!.toStringAsFixed(4);
    }
    if (st.foreignAmount != null) {
      _foreignController.text = st.foreignAmount!.toStringAsFixed(2);
    } else {
      _syncForeignFromThb();
    }
    widget.thbController.addListener(_onThbChanged);
  }

  @override
  void dispose() {
    widget.thbController.removeListener(_onThbChanged);
    _foreignController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged?.call();

  void _onThbChanged() {
    if (_syncing) return;
    _syncForeignFromThb();
  }

  void _syncForeignFromThb() {
    final thb = double.tryParse(widget.thbController.text.trim());
    final rate = st.rate;
    if (thb == null || rate == null || rate <= 0) return;
    _syncing = true;
    st.foreignAmount = thb / rate;
    _foreignController.text = st.foreignAmount!.toStringAsFixed(2);
    _syncing = false;
    _notify();
  }

  void _onForeignChanged(String value) {
    if (_syncing) return;
    final foreign = double.tryParse(value.trim());
    st.foreignAmount = foreign;
    final rate = st.rate;
    if (foreign == null || rate == null || rate <= 0) return;
    _syncing = true;
    widget.thbController.text = (foreign * rate).toStringAsFixed(2);
    _syncing = false;
    _notify();
  }

  void _onRateChanged(String value) {
    st.rate = double.tryParse(value.trim());
    _syncForeignFromThb();
  }

  Future<void> _fetchRate() async {
    if (!st.isForeign) return;
    setState(() {
      _fetchingRate = true;
      _rateFetchFailed = false;
    });
    final rate = await CurrencyService().getRate(st.currencyCode, 'THB');
    if (!mounted) return;
    setState(() {
      _fetchingRate = false;
      _rateFetchFailed = rate == null;
      if (rate != null) {
        st.rate = rate;
        _rateController.text = rate.toStringAsFixed(4);
      }
    });
    _syncForeignFromThb();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: st.currencyCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Advance Currency',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.currency_exchange),
            helperText:
                'Pick the currency the money is used in to tally both amounts',
          ),
          items: [
            const DropdownMenuItem(
              value: 'THB',
              child: Text('THB — Thai Baht only'),
            ),
            ...kConversionCurrencies.entries.map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text('${e.key} — ${e.value}'),
              ),
            ),
          ],
          onChanged: (code) {
            if (code == null) return;
            setState(() => st.currencyCode = code);
            _notify();
            if (code != 'THB') _fetchRate();
          },
        ),
        if (st.isForeign) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _rateController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onRateChanged,
            decoration: InputDecoration(
              labelText: 'Rate: 1 ${st.currencyCode} = ? THB',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.swap_horiz),
              helperText: _fetchingRate
                  ? 'Fetching live rate…'
                  : _rateFetchFailed
                      ? 'Live rate unavailable — enter your transfer rate'
                      : 'Use the actual rate of your bank transfer',
              suffixIcon: _fetchingRate
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh live rate',
                      onPressed: _fetchRate,
                    ),
            ),
            validator: (value) {
              final rate = double.tryParse(value?.trim() ?? '');
              if (rate == null || rate <= 0) {
                return 'Please enter a valid exchange rate';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _foreignController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: _onForeignChanged,
            decoration: InputDecoration(
              labelText: 'Amount in ${st.currencyCode}',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.account_balance),
              prefixText: '${st.currencyCode} ',
              helperText:
                  'Synced with the Baht amount above — edit either one',
            ),
          ),
        ],
      ],
    );
  }
}
