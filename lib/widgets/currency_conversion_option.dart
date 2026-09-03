import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Holds the user's currency conversion choice from the print dialog.
/// [rate] is THB per 1 unit of [currencyCode] (e.g. 1 MYR = 8.42 THB),
/// matching the convention used by CurrencyConversionPdfService.
class CurrencyConversionOption {
  bool enabled;
  String currencyCode;
  double? rate;

  CurrencyConversionOption({
    this.enabled = false,
    this.currencyCode = 'MYR',
    this.rate,
  });
}

/// Supported display currencies: code → name.
const Map<String, String> kConversionCurrencies = {
  'MYR': 'Ringgit Malaysia',
  'USD': 'US Dollar',
  'SGD': 'Singapore Dollar',
  'IDR': 'Indonesian Rupiah',
  'PHP': 'Philippine Peso',
  'VND': 'Vietnamese Dong',
  'LAK': 'Lao Kip',
  'KHR': 'Cambodian Riel',
  'MMK': 'Myanmar Kyat',
  'CNY': 'Chinese Yuan',
  'EUR': 'Euro',
};

/// A dialog section that lets the user enable a currency conversion,
/// pick the currency, and adjust the live-fetched exchange rate.
class CurrencyConversionOptionTile extends StatefulWidget {
  final CurrencyConversionOption option;

  const CurrencyConversionOptionTile({super.key, required this.option});

  @override
  State<CurrencyConversionOptionTile> createState() =>
      _CurrencyConversionOptionTileState();
}

class _CurrencyConversionOptionTileState
    extends State<CurrencyConversionOptionTile> {
  final _rateController = TextEditingController();
  bool _fetchingRate = false;
  bool _rateFetchFailed = false;

  CurrencyConversionOption get option => widget.option;

  @override
  void initState() {
    super.initState();
    if (option.rate != null) {
      _rateController.text = option.rate!.toStringAsFixed(4);
    } else {
      _fetchRate();
    }
    _rateController.addListener(() {
      option.rate = double.tryParse(_rateController.text.trim());
    });
  }

  @override
  void dispose() {
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _fetchRate() async {
    setState(() {
      _fetchingRate = true;
      _rateFetchFailed = false;
    });
    final rate = await CurrencyService().getRate(option.currencyCode, 'THB');
    if (!mounted) return;
    setState(() {
      _fetchingRate = false;
      _rateFetchFailed = rate == null;
      if (rate != null) {
        option.rate = rate;
        _rateController.text = rate.toStringAsFixed(4);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            value: option.enabled,
            onChanged: (v) => setState(() => option.enabled = v),
            title: const Text(
              'Show Converted Amounts',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Add total & available balance in another currency',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            secondary: Icon(
              Icons.currency_exchange,
              color: option.enabled
                  ? Colors.blue.shade600
                  : Colors.grey.shade400,
            ),
          ),
          if (option.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: option.currencyCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: kConversionCurrencies.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.key} — ${e.value}'),
                          ),
                        )
                        .toList(),
                    onChanged: (code) {
                      if (code == null) return;
                      setState(() => option.currencyCode = code);
                      _fetchRate();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Rate: 1 ${option.currencyCode} = ? THB',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      helperText: _fetchingRate
                          ? 'Fetching live rate…'
                          : _rateFetchFailed
                              ? 'Live rate unavailable — enter manually'
                              : 'Live rate — adjust if needed',
                      suffixIcon: _fetchingRate
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              tooltip: 'Refresh rate',
                              onPressed: _fetchRate,
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
