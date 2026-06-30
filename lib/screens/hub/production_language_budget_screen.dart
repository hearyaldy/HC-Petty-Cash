import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

class _ProductionEntry {
  String name;
  String language;
  double amount;

  _ProductionEntry({required this.name, required this.language, required this.amount});

  Map<String, dynamic> toMap() => {'name': name, 'language': language, 'amount': amount};

  static _ProductionEntry fromMap(Map<String, dynamic> m) => _ProductionEntry(
        name: m['name'] as String? ?? '',
        language: m['language'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
      );
}

class _NameAmountRow {
  TextEditingController nameController;
  TextEditingController amountController;

  _NameAmountRow({required this.nameController, required this.amountController});

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ProductionLanguageBudgetScreen extends StatefulWidget {
  const ProductionLanguageBudgetScreen({super.key});

  @override
  State<ProductionLanguageBudgetScreen> createState() =>
      _ProductionLanguageBudgetScreenState();
}

class _ProductionLanguageBudgetScreenState
    extends State<ProductionLanguageBudgetScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  static final List<String> _languageOptions =
      MediaLanguage.values.map((e) => e.displayName).toList();

  int _year = DateTime.now().year;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _editMode = false;

  double _totalBudget = 0;
  List<_ProductionEntry> _productions = [];

  // Edit-mode state (language-grouped)
  final _budgetController = TextEditingController();
  final Map<String, List<_NameAmountRow>> _editGroups = {};
  List<String> _editLanguages = [];
  final Map<String, TextEditingController> _groupAddName = {};
  final Map<String, TextEditingController> _groupAddAmount = {};
  String _newLangValue = '';
  final _newLangController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _newLangValue = _languageOptions.first;
    _load();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _newLangController.dispose();
    _disposeEditGroups();
    super.dispose();
  }

  void _disposeEditGroups() {
    for (final rows in _editGroups.values) {
      for (final r in rows) {
        r.dispose();
      }
    }
    for (final c in _groupAddName.values) {
      c.dispose();
    }
    for (final c in _groupAddAmount.values) {
      c.dispose();
    }
    _editGroups.clear();
    _groupAddName.clear();
    _groupAddAmount.clear();
    _editLanguages.clear();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await _firestore
          .collection('production_language_budgets')
          .doc('$_year')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _totalBudget = (data['totalBudget'] as num?)?.toDouble() ?? 0;
        final rawList = data['productions'] as List<dynamic>? ?? [];
        _productions = rawList
            .map((e) => _ProductionEntry.fromMap(e as Map<String, dynamic>))
            .toList();
      } else {
        _totalBudget = 0;
        _productions = [];
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterEditMode() {
    _budgetController.text = _totalBudget > 0 ? _totalBudget.toStringAsFixed(0) : '';
    _disposeEditGroups();

    // Build language groups from existing productions
    for (final p in _productions) {
      _editGroups.putIfAbsent(p.language, () => []).add(_NameAmountRow(
        nameController: TextEditingController(text: p.name),
        amountController: TextEditingController(
            text: p.amount > 0 ? p.amount.toStringAsFixed(0) : ''),
      ));
    }
    _editLanguages = _editGroups.keys.toList();

    // Add per-language inline-add controllers
    for (final lang in _editLanguages) {
      _groupAddName[lang] = TextEditingController();
      _groupAddAmount[lang] = TextEditingController();
    }

    _newLangValue = _languageOptions.first;
    _newLangController.clear();
    setState(() => _editMode = true);
  }

  void _cancelEdit() {
    _disposeEditGroups();
    setState(() => _editMode = false);
  }

  void _addLanguageSection() {
    final custom = _newLangController.text.trim();
    final name = custom.isNotEmpty
        ? (custom[0].toUpperCase() + custom.substring(1))
        : _newLangValue;
    if (_editLanguages.contains(name)) {
      _showSnack('Language "$name" already added.', Colors.orange);
      return;
    }
    setState(() {
      _editLanguages.add(name);
      _editGroups[name] = [];
      _groupAddName[name] = TextEditingController();
      _groupAddAmount[name] = TextEditingController();
      _newLangController.clear();
    });
  }

  void _removeLanguageSection(String lang) {
    for (final r in _editGroups[lang] ?? []) {
      r.dispose();
    }
    _groupAddName[lang]?.dispose();
    _groupAddAmount[lang]?.dispose();
    setState(() {
      _editGroups.remove(lang);
      _groupAddName.remove(lang);
      _groupAddAmount.remove(lang);
      _editLanguages.remove(lang);
    });
  }

  void _addToGroup(String lang) {
    final name = _groupAddName[lang]?.text.trim() ?? '';
    final amount =
        double.tryParse(_groupAddAmount[lang]?.text.replaceAll(',', '') ?? '') ?? 0;
    if (name.isEmpty) { _showSnack('Enter a production name.', Colors.orange); return; }
    if (amount <= 0) { _showSnack('Enter a valid budget amount.', Colors.orange); return; }
    setState(() {
      _editGroups.putIfAbsent(lang, () => []).add(_NameAmountRow(
        nameController: TextEditingController(text: name),
        amountController: TextEditingController(text: amount.toStringAsFixed(0)),
      ));
      _groupAddName[lang]?.clear();
      _groupAddAmount[lang]?.clear();
    });
  }

  void _removeFromGroup(String lang, int index) {
    _editGroups[lang]![index].dispose();
    setState(() => _editGroups[lang]!.removeAt(index));
  }

  double get _editAllocTotal => _editGroups.values.fold(
        0,
        (acc, rows) => acc +
            rows.fold(
              0,
              (a, r) =>
                  a + (double.tryParse(r.amountController.text.replaceAll(',', '')) ?? 0),
            ),
      );

  Future<void> _save() async {
    final total =
        double.tryParse(_budgetController.text.replaceAll(',', ''));
    if (total == null || total <= 0) {
      _showSnack('Enter a valid total budget amount.', Colors.red);
      return;
    }
    final productions = <_ProductionEntry>[];
    for (final lang in _editLanguages) {
      for (final r in _editGroups[lang] ?? []) {
        final name = r.nameController.text.trim();
        final amount =
            double.tryParse(r.amountController.text.replaceAll(',', '')) ?? 0;
        if (name.isNotEmpty && amount > 0) {
          productions.add(_ProductionEntry(name: name, language: lang, amount: amount));
        }
      }
    }

    setState(() => _saving = true);
    try {
      final auth = context.read<AuthProvider>();
      await _firestore.collection('production_language_budgets').doc('$_year').set({
        'year': _year,
        'totalBudget': total,
        'productions': productions.map((p) => p.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': auth.currentUser?.name ?? '',
      });
      _totalBudget = total;
      _productions = productions;
      _disposeEditGroups();
      setState(() { _editMode = false; _saving = false; });
      _showSnack('Budget saved successfully.', Colors.green);
    } catch (e) {
      setState(() => _saving = false);
      _showSnack('Failed to save: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ─── PDF print ────────────────────────────────────────────────────────────

  Future<void> _printBudget() async {
    final allocated = _productions.fold<double>(0, (a, p) => a + p.amount);
    final remaining = _totalBudget - allocated;
    final utilPct = _totalBudget > 0 ? allocated / _totalBudget : 0.0;

    final byLang = <String, double>{};
    for (final p in _productions) {
      byLang[p.language] = (byLang[p.language] ?? 0) + p.amount;
    }
    final sortedLangs = byLang.keys.toList()..sort();

    const teal = PdfColor.fromInt(0xFF00695C);
    const headerBg = PdfColor.fromInt(0xFF00796B);
    const white = PdfColors.white;
    const grey = PdfColor.fromInt(0xFF757575);
    const darkText = PdfColor.fromInt(0xFF212121);
    const rowAlt = PdfColor.fromInt(0xFFE0F2F1);
    const divider = PdfColor.fromInt(0xFFE0E0E0);

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const pw.BoxDecoration(color: teal),
            child: pw.Row(children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HOPE CHANNEL SOUTHEAST ASIA',
                        style: pw.TextStyle(
                            color: white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Production Budget Plan - $_year',
                        style: pw.TextStyle(
                            color: white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.Text('Printed: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(color: white, fontSize: 7)),
            ]),
          ),
          pw.SizedBox(height: 8),
        ],
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Production Budget - Confidential',
              style: const pw.TextStyle(fontSize: 7, color: grey)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 7, color: grey)),
        ],
      ),
      build: (_) => [
        // Summary banner
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(color: rowAlt),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _pdfStat('Total Budget', 'THB ${_currencyFormat.format(_totalBudget)}', teal),
              _pdfStat('Total Allocated', 'THB ${_currencyFormat.format(allocated)}', teal),
              _pdfStat('Remaining', 'THB ${_currencyFormat.format(remaining)}', teal),
              _pdfStat('Utilization', '${(utilPct * 100).toStringAsFixed(1)}%', teal),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Productions by language
        ...sortedLangs.map((lang) {
          final langProds = _productions.where((p) => p.language == lang).toList();
          final langTotal = byLang[lang] ?? 0;
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const pw.BoxDecoration(color: teal),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(lang,
                        style: pw.TextStyle(
                            color: white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('THB ${_currencyFormat.format(langTotal)}',
                        style: pw.TextStyle(
                            color: white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Production / Project Name', 'Budget (THB)'],
                data: langProds.asMap().entries.map((e) => [
                      '${e.key + 1}',
                      e.value.name,
                      _currencyFormat.format(e.value.amount),
                    ]).toList(),
                headerStyle: pw.TextStyle(
                    color: darkText, fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: rowAlt),
                cellStyle: const pw.TextStyle(fontSize: 9, color: darkText),
                cellAlignments: {0: pw.Alignment.center, 2: pw.Alignment.centerRight},
                rowDecoration: const pw.BoxDecoration(color: white),
                oddRowDecoration: const pw.BoxDecoration(color: rowAlt),
                border: pw.TableBorder.all(color: divider, width: 0.5),
              ),
              pw.SizedBox(height: 12),
            ],
          );
        }),

        // Language summary table
        pw.Text('Summary by Language',
            style: pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkText)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Language', 'Productions', 'Allocated (THB)', '% of Budget'],
          data: sortedLangs.map((lang) {
            final langTotal = byLang[lang] ?? 0;
            final count = _productions.where((p) => p.language == lang).length;
            final pct = _totalBudget > 0 ? langTotal / _totalBudget * 100 : 0.0;
            return [lang, '$count', _currencyFormat.format(langTotal), '${pct.toStringAsFixed(1)}%'];
          }).toList(),
          headerStyle: pw.TextStyle(
              color: white, fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: headerBg),
          cellStyle: const pw.TextStyle(fontSize: 9, color: darkText),
          cellAlignments: {
            1: pw.Alignment.center,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.center,
          },
          rowDecoration: const pw.BoxDecoration(color: white),
          oddRowDecoration: const pw.BoxDecoration(color: rowAlt),
          border: pw.TableBorder.all(color: divider, width: 0.5),
        ),
      ],
    ));

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) =>
      pw.Column(children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF757575))),
      ]);

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allocated = _productions.fold<double>(0, (a, p) => a + p.amount);
    final remaining = _totalBudget - allocated;

    return Scaffold(
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildWelcomeHeader(allocated, remaining),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _buildErrorState()
                else if (_editMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildEditCard(),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSummaryCards(allocated, remaining),
                  ),
                  if (_productions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionLabel('By Language'),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildLanguageSummary(),
                    ),
                  ] else if (_totalBudget > 0)
                    _buildNoProductionsState()
                  else
                    _buildNoBudgetState(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ──────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildTopBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: cs.primary,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text('HC',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Production Budget',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text('Annual production budget planning',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 10)),
                        ],
                      ),
                      const Spacer(),
                      if (!_editMode) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          tooltip: 'Edit Budget',
                          onPressed: _loading ? null : _enterEditMode,
                        ),
                        if (_totalBudget > 0 && _productions.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.print_outlined,
                                color: Colors.white, size: 20),
                            tooltip: 'Print Budget',
                            onPressed: _loading ? null : _printBudget,
                          ),
                      ],
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _load,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Welcome header ───────────────────────────────────────────────────────

  Widget _buildWelcomeHeader(double allocated, double remaining) {
    final cs = Theme.of(context).colorScheme;

    final yearRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () { setState(() => _year--); _load(); },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('$_year',
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        InkWell(
          onTap: () { setState(() => _year++); _load(); },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.85), cs.primary],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final statsRow = Row(children: [
          _bannerStat(
            _totalBudget > 0
                ? 'THB ${_currencyFormat.format(_totalBudget)}'
                : 'Not set',
            'Budget',
          ),
          const SizedBox(width: 24),
          _bannerStat('THB ${_currencyFormat.format(allocated)}', 'Allocated'),
          const SizedBox(width: 24),
          _bannerStat(
            _totalBudget == 0
                ? '-'
                : 'THB ${_currencyFormat.format(remaining.abs())}',
            remaining < 0 && _totalBudget > 0 ? 'Over Budget' : 'Remaining',
            valueColor:
                remaining < 0 && _totalBudget > 0 ? Colors.red.shade200 : null,
          ),
        ]);

        if (isCompact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Production Budget',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Annual budget planning',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              yearRow,
            ]),
            const SizedBox(height: 14),
            statsRow,
          ]);
        }

        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.video_library_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Production Budget',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Annual production budget planning',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          yearRow,
          const SizedBox(width: 24),
          statsRow,
        ]);
      }),
    );
  }

  Widget _bannerStat(String value, String label, {Color? valueColor}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        Text(label,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
      ]);

  Widget _buildSectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration:
            BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 8),
      Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: cs.onSurfaceVariant)),
    ]);
  }

  // ─── Summary cards ────────────────────────────────────────────────────────

  Widget _buildSummaryCards(double allocated, double remaining) {
    final cs = Theme.of(context).colorScheme;
    final pct = _totalBudget > 0 ? allocated / _totalBudget : 0.0;
    final progressColor = pct > 1.0
        ? Colors.red.shade600
        : pct > 0.8
            ? Colors.orange.shade600
            : Colors.green.shade500;

    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final cards = [
          _summaryCard(
              icon: Icons.account_balance,
              label: 'Total Budget $_year',
              value: 'THB ${_currencyFormat.format(_totalBudget)}',
              color: cs.primary),
          _summaryCard(
              icon: Icons.video_library_outlined,
              label: 'Total Allocated',
              value: 'THB ${_currencyFormat.format(allocated)}',
              color: Colors.indigo.shade700,
              sub: '${_productions.length} production${_productions.length != 1 ? 's' : ''}'),
          _summaryCard(
              icon: Icons.savings_outlined,
              label: remaining >= 0 ? 'Remaining' : 'Over Budget',
              value: 'THB ${_currencyFormat.format(remaining.abs())}',
              color: remaining >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              sub: '${(pct * 100).toStringAsFixed(1)}% allocated'),
        ];
        if (isNarrow) {
          return Column(
              children: cards
                  .map((c) =>
                      Padding(padding: const EdgeInsets.only(bottom: 10), child: c))
                  .toList());
        }
        return IntrinsicHeight(
          child: Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 10),
            Expanded(child: cards[1]),
            const SizedBox(width: 10),
            Expanded(child: cards[2]),
          ]),
        );
      }),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Budget Utilization',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[700])),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: progressColor)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            if (sub != null)
              Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ]),
        ),
      ]),
    );
  }

  // ─── Language summary (read mode) ─────────────────────────────────────────

  Widget _buildLanguageSummary() {
    final byLang = <String, List<_ProductionEntry>>{};
    for (final p in _productions) {
      byLang.putIfAbsent(p.language, () => []).add(p);
    }
    final sortedLangs = byLang.keys.toList()..sort();

    return Column(
      children: sortedLangs.map((lang) {
        final langProds = byLang[lang]!;
        final langTotal = langProds.fold<double>(0, (a, p) => a + p.amount);
        final pct = _totalBudget > 0 ? langTotal / _totalBudget : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
              ],
            ),
            child: Column(children: [
              // Language header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(children: [
                  _langBadge(lang),
                  const SizedBox(width: 8),
                  Text(
                    '${langProds.length} production${langProds.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('THB ${_currencyFormat.format(langTotal)}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700)),
                    Text('${(pct * 100).toStringAsFixed(1)}% of budget',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ]),
                ]),
              ),
              // Progress bar
              ClipRRect(
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  minHeight: 4,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      pct > 0.5 ? Colors.orange.shade600 : Colors.teal.shade500),
                ),
              ),
              // Productions list
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: langProds.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(p.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          Text('THB ${_currencyFormat.format(p.amount)}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700])),
                        ]),
                      )).toList(),
                ),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _langBadge(String lang) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Text(lang,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 11, color: cs.primary)),
    );
  }

  // ─── Edit card ────────────────────────────────────────────────────────────

  Widget _buildEditCard() {
    final cs = Theme.of(context).colorScheme;
    final allocated = _editAllocTotal;
    final budgetInput =
        double.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0;
    final remaining = budgetInput - allocated;
    final isOver = budgetInput > 0 && allocated > budgetInput;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(color: cs.primary.withValues(alpha: 0.06), blurRadius: 12)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Set Budget for $_year',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cs.primary)),
        ]),
        const SizedBox(height: 20),

        // Total budget field
        TextField(
          controller: _budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          ],
          decoration: InputDecoration(
            labelText: 'Total Annual Budget (THB)',
            prefixIcon: Icon(Icons.account_balance, color: cs.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary, width: 1.5)),
            filled: true,
            fillColor: cs.primary.withValues(alpha: 0.04),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Running tally
        if (budgetInput > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isOver ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isOver ? Colors.red.shade300 : Colors.green.shade300),
            ),
            child: Row(children: [
              Icon(
                isOver ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 16,
                color: isOver ? Colors.red.shade600 : Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOver
                      ? 'Over budget by THB ${_currencyFormat.format((allocated - budgetInput).abs())}  —  Allocated: THB ${_currencyFormat.format(allocated)}'
                      : 'Remaining: THB ${_currencyFormat.format(remaining)}  —  Allocated: THB ${_currencyFormat.format(allocated)}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isOver ? Colors.red.shade700 : Colors.green.shade700),
                ),
              ),
            ]),
          ),
        const SizedBox(height: 24),

        // Language sections
        if (_editLanguages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No language sections yet. Add a language below to start.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          )
        else
          ..._editLanguages
              .map((lang) => _buildLanguageEditSection(lang, cs)),

        const SizedBox(height: 4),

        // Add language section
        _buildAddLanguageRow(cs),
        const SizedBox(height: 24),

        // Save / Cancel
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving...' : 'Save Budget'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildLanguageEditSection(String lang, ColorScheme cs) {
    final rows = _editGroups[lang] ?? [];
    final langTotal = rows.fold<double>(
        0,
        (a, r) =>
            a + (double.tryParse(r.amountController.text.replaceAll(',', '')) ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Language header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.07),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(children: [
              Icon(Icons.language, size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Text(lang,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cs.primary)),
              const SizedBox(width: 8),
              if (langTotal > 0)
                Text('THB ${_currencyFormat.format(langTotal)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.primary.withValues(alpha: 0.7))),
              const Spacer(),
              InkWell(
                onTap: () => _removeLanguageSection(lang),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.red.shade400),
                ),
              ),
            ]),
          ),

          // Existing productions in this language
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: rows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: r.nameController,
                          decoration: InputDecoration(
                            labelText: 'Production / Project Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: r.amountController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Budget (THB)',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.5)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: Colors.red.shade400, size: 20),
                        tooltip: 'Remove',
                        onPressed: () => _removeFromGroup(lang, i),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),

          // Inline add row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _groupAddName[lang],
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'New production / project name',
                    hintStyle:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.add, size: 16, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.primary, width: 1.5)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onSubmitted: (_) => _addToGroup(lang),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _groupAddAmount[lang],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  decoration: InputDecoration(
                    hintText: 'Amount (THB)',
                    hintStyle:
                        TextStyle(fontSize: 12, color: Colors.grey[400]),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: cs.primary, width: 1.5)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onSubmitted: (_) => _addToGroup(lang),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _addToGroup(lang),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('Add', style: TextStyle(fontSize: 13)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAddLanguageRow(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Add Language Section',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey[700])),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _newLangValue,
              decoration: InputDecoration(
                labelText: 'Language',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _languageOptions
                  .map((l) => DropdownMenuItem(
                      value: l,
                      child: Text(l, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) => setState(() => _newLangValue = v ?? _newLangValue),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('or', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: TextField(
              controller: _newLangController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Custom language',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary, width: 1.5)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _addLanguageSection(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _addLanguageSection,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ]),
      ]),
    );
  }

  // ─── Empty / error states ─────────────────────────────────────────────────

  Widget _buildNoBudgetState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(children: [
          Icon(Icons.video_library_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No production budget set for $_year',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            'Tap the edit button to set an annual budget,\nthen add language sections and productions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _enterEditMode,
            icon: const Icon(Icons.add),
            label: Text('Set $_year Budget'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoProductionsState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(children: [
          Icon(Icons.playlist_add, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No productions added yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            'Budget: THB ${_currencyFormat.format(_totalBudget)}.\nTap edit to add language sections and productions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _enterEditMode,
            icon: const Icon(Icons.add),
            label: const Text('Add Productions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(_error!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ),
    );
  }
}
