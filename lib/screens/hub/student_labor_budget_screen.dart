import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class StudentLaborBudgetScreen extends StatefulWidget {
  const StudentLaborBudgetScreen({super.key});

  @override
  State<StudentLaborBudgetScreen> createState() =>
      _StudentLaborBudgetScreenState();
}

class _StudentLaborBudgetScreenState extends State<StudentLaborBudgetScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

  int _year = DateTime.now().year;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  double _totalBudget = 0;
  final Map<String, double> _allocations = {};
  final Map<String, double> _paid = {};
  List<String> _languages = [];

  final _budgetController = TextEditingController();
  final _newLangController = TextEditingController();
  final Map<String, TextEditingController> _allocControllers = {};
  bool _editMode = false;
  bool _amountMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _newLangController.dispose();
    for (final c in _allocControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait([_loadLanguages(), _loadBudget(), _loadActualSpend()]);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadLanguages() async {
    final snap = await _firestore
        .collection('student_profiles')
        .get(const GetOptions(source: Source.server));
    final langs = <String>{};
    for (final doc in snap.docs) {
      final lang = (doc.data()['language'] as String?)?.trim() ?? '';
      if (lang.isNotEmpty) langs.add(lang);
    }
    if (langs.isEmpty) langs.add('Other');
    _languages = langs.toList()..sort();
  }

  Future<void> _loadBudget() async {
    final doc = await _firestore
        .collection('student_labor_budgets')
        .doc('$_year')
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _totalBudget = (data['totalBudget'] as num?)?.toDouble() ?? 0;
      final rawAlloc = data['allocations'] as Map<String, dynamic>? ?? {};
      _allocations.clear();
      for (final e in rawAlloc.entries) {
        _allocations[e.key] = (e.value as num).toDouble();
      }
    } else {
      _totalBudget = 0;
      _allocations.clear();
    }
  }

  Future<void> _loadActualSpend() async {
    final profileSnap = await _firestore.collection('student_profiles').get();
    final studentLang = <String, String>{};
    for (final doc in profileSnap.docs) {
      final lang = (doc.data()['language'] as String?)?.trim() ?? '';
      studentLang[doc.id] = lang.isEmpty ? 'Other' : lang;
    }

    final reportsSnap = await _firestore
        .collection('student_monthly_reports')
        .get(const GetOptions(source: Source.server));

    _paid.clear();
    for (final doc in reportsSnap.docs) {
      final data = doc.data();
      final month = data['month'] as String? ?? '';
      if (!month.startsWith('$_year-')) continue;

      final status = data['status'] as String? ?? '';
      final paymentStatus = data['paymentStatus'] as String? ?? '';
      final isPaid = status == 'paid' ||
          status == 'processed' ||
          paymentStatus == 'paid';
      if (!isPaid) continue;

      final sid = data['studentId'] as String? ?? '';
      final lang = studentLang[sid] ?? 'Other';
      final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
      _paid[lang] = (_paid[lang] ?? 0) + amount;
    }
  }

  void _enterEditMode() {
    _amountMode = false;
    _budgetController.text =
        _totalBudget > 0 ? _totalBudget.toStringAsFixed(0) : '';
    // Merge saved allocation languages into the list so they're editable
    for (final lang in _allocations.keys) {
      if (!_languages.contains(lang)) {
        _languages = [..._languages, lang]..sort();
      }
    }
    for (final lang in _languages) {
      _allocControllers.putIfAbsent(lang, () => TextEditingController());
      _allocControllers[lang]!.text =
          (_allocations[lang] ?? 0).toStringAsFixed(1);
    }
    setState(() => _editMode = true);
  }

  // Switch between % and THB amount input, converting controller values.
  void _toggleMode(bool toAmountMode) {
    final budgetInput = double.tryParse(_budgetController.text) ?? _totalBudget;
    for (final lang in _languages) {
      if (toAmountMode) {
        final pct = double.tryParse(_allocControllers[lang]?.text ?? '') ?? 0;
        _allocControllers[lang]?.text = budgetInput > 0
            ? (budgetInput * (pct / 100)).toStringAsFixed(0)
            : '0';
      } else {
        final amt = double.tryParse(_allocControllers[lang]?.text ?? '') ?? 0;
        _allocControllers[lang]?.text = budgetInput > 0
            ? (amt / budgetInput * 100).toStringAsFixed(1)
            : '0.0';
      }
    }
    setState(() => _amountMode = toAmountMode);
  }

  // Sum of all allocation controller values (% or THB depending on mode).
  double get _allocTotal => _languages.fold(
        0,
        (acc, lang) =>
            acc + (double.tryParse(_allocControllers[lang]?.text ?? '') ?? 0),
      );

  void _addLanguage() {
    final name = _newLangController.text.trim();
    if (name.isEmpty) return;
    final normalized = name[0].toUpperCase() + name.substring(1);
    if (_languages.contains(normalized)) {
      _showSnack('Language "$normalized" already exists.', Colors.orange);
      return;
    }
    _allocControllers[normalized] =
        TextEditingController(text: _amountMode ? '0' : '0.0');
    setState(() {
      _languages = [..._languages, normalized]..sort();
      _newLangController.clear();
    });
  }

  void _deleteLanguage(String lang) {
    _allocControllers[lang]?.dispose();
    _allocControllers.remove(lang);
    setState(() {
      _languages = List<String>.from(_languages)..remove(lang);
    });
  }

  Future<void> _save() async {
    final total = double.tryParse(_budgetController.text.replaceAll(',', ''));
    if (total == null || total <= 0) {
      _showSnack('Enter a valid total budget amount.', Colors.red);
      return;
    }

    final newAlloc = <String, double>{};

    if (_amountMode) {
      final sumAmounts = _allocTotal;
      if ((sumAmounts - total).abs() > total * 0.005) {
        _showSnack(
          'Amounts must total the full budget.\nCurrent: THB ${_currencyFormat.format(sumAmounts)} / THB ${_currencyFormat.format(total)}',
          Colors.red,
        );
        return;
      }
      for (final lang in _languages) {
        final amt = double.tryParse(_allocControllers[lang]?.text ?? '') ?? 0;
        if (amt > 0) newAlloc[lang] = (amt / total) * 100;
      }
    } else {
      if ((_allocTotal - 100).abs() > 0.1) {
        _showSnack(
          'Allocations must total 100% (currently ${_allocTotal.toStringAsFixed(1)}%)',
          Colors.red,
        );
        return;
      }
      for (final lang in _languages) {
        final pct = double.tryParse(_allocControllers[lang]?.text ?? '') ?? 0;
        if (pct > 0) newAlloc[lang] = pct;
      }
    }

    setState(() => _saving = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await _firestore.collection('student_labor_budgets').doc('$_year').set({
        'year': _year,
        'totalBudget': total,
        'allocations': newAlloc,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': authProvider.currentUser?.name ?? '',
      }, SetOptions(merge: true));

      _totalBudget = total;
      _allocations
        ..clear()
        ..addAll(newAlloc);
      setState(() {
        _editMode = false;
        _saving = false;
      });
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

  void _distributeEvenly() {
    if (_languages.isEmpty) return;
    final budgetInput = double.tryParse(_budgetController.text) ?? _totalBudget;
    for (final lang in _languages) {
      _allocControllers.putIfAbsent(lang, () => TextEditingController());
      if (_amountMode) {
        final share = budgetInput > 0 ? budgetInput / _languages.length : 0.0;
        _allocControllers[lang]!.text = share.toStringAsFixed(0);
      } else {
        _allocControllers[lang]!.text =
            (100 / _languages.length).toStringAsFixed(1);
      }
    }
    setState(() {});
  }

  Future<void> _printBudget() async {
    final totalPaid = _paid.values.fold<double>(0, (acc, v) => acc + v);
    final remaining = _totalBudget - totalPaid;
    final pct = _totalBudget > 0 ? totalPaid / _totalBudget : 0.0;

    const orange = PdfColor.fromInt(0xFFE65100);
    const headerBg = PdfColor.fromInt(0xFFF57C00);
    const white = PdfColors.white;
    const grey = PdfColor.fromInt(0xFF757575);
    const darkText = PdfColor.fromInt(0xFF212121);
    const rowAlt = PdfColor.fromInt(0xFFFFF8F0);
    const divider = PdfColor.fromInt(0xFFE0E0E0);

    final allLangs = {..._allocations.keys, ..._paid.keys}.toList()..sort();

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const pw.BoxDecoration(color: orange),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('HOPE CHANNEL SOUTHEAST ASIA',
                            style: pw.TextStyle(
                                color: white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Student Labor Budget Plan - $_year',
                            style: pw.TextStyle(
                                color: white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.Text(
                    'Printed: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(color: white, fontSize: 7),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Student Labor Budget - Confidential',
                style: const pw.TextStyle(fontSize: 7, color: grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: grey)),
          ],
        ),
        build: (_) => [
          // Summary banner
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFBE9E7)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _pdfStat('Total Budget', 'THB ${_currencyFormat.format(_totalBudget)}', orange),
                _pdfStat('Total Paid', 'THB ${_currencyFormat.format(totalPaid)}', orange),
                _pdfStat('Remaining', 'THB ${_currencyFormat.format(remaining)}', orange),
                _pdfStat('Utilization', '${(pct * 100).toStringAsFixed(1)}%', orange),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          // Language breakdown table
          pw.TableHelper.fromTextArray(
            headers: ['Language', 'Alloc %', 'Budget (THB)', 'Paid (THB)', 'Remaining', 'Utilization'],
            data: allLangs.map((lang) {
              final langPct = _allocations[lang] ?? 0;
              final langBudget = _totalBudget * (langPct / 100);
              final paid = _paid[lang] ?? 0;
              final rem = langBudget - paid;
              final util = langBudget > 0 ? paid / langBudget * 100 : 0.0;
              return [
                lang,
                '${langPct.toStringAsFixed(1)}%',
                _currencyFormat.format(langBudget),
                _currencyFormat.format(paid),
                rem < 0 ? '-${_currencyFormat.format(rem.abs())}' : _currencyFormat.format(rem),
                '${util.toStringAsFixed(1)}%',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(color: white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: headerBg),
            cellStyle: const pw.TextStyle(fontSize: 9, color: darkText),
            cellAlignments: {
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
            },
            rowDecoration: const pw.BoxDecoration(color: white),
            oddRowDecoration: const pw.BoxDecoration(color: rowAlt),
            border: pw.TableBorder.all(color: divider, width: 0.5),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF757575))),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalPaid = _paid.values.fold<double>(0, (acc, v) => acc + v);
    final remaining = _totalBudget - totalPaid;

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
                  child: _buildWelcomeHeader(totalPaid, remaining),
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
                    child: _buildSummaryCards(totalPaid, remaining),
                  ),
                  const SizedBox(height: 20),
                  if (_totalBudget > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildSectionLabel('By Language'),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildLanguageBreakdown(),
                    ),
                  ] else
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
              offset: const Offset(0, 4),
            ),
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
                          tooltip: 'Menu',
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
                          child: Text(
                            'HC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Budget Planning',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Student labor · Yearly budget by language',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!_editMode) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          tooltip: 'Set / Edit Budget',
                          onPressed: _loading ? null : _enterEditMode,
                        ),
                        if (_totalBudget > 0)
                          IconButton(
                            icon: const Icon(Icons.print_outlined,
                                color: Colors.white, size: 20),
                            tooltip: 'Print Budget Report',
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

  Widget _buildWelcomeHeader(double totalPaid, double remaining) {
    final cs = Theme.of(context).colorScheme;

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 600;

          final yearRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () {
                  setState(() => _year--);
                  _load();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 18),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '$_year',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() => _year++);
                  _load();
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          );

          final statsRow = Row(
            children: [
              _bannerStat(
                _totalBudget > 0
                    ? 'THB ${_currencyFormat.format(_totalBudget)}'
                    : 'Not set',
                'Budget',
              ),
              const SizedBox(width: 24),
              _bannerStat(
                _loading
                    ? '...'
                    : 'THB ${_currencyFormat.format(totalPaid)}',
                'Paid',
              ),
              const SizedBox(width: 24),
              _bannerStat(
                _loading || _totalBudget == 0
                    ? '-'
                    : 'THB ${_currencyFormat.format(remaining)}',
                remaining < 0 ? 'Over Budget' : 'Remaining',
                valueColor: remaining < 0 && _totalBudget > 0
                    ? Colors.red.shade200
                    : null,
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Labor Budget',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Yearly budget planning by language',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    yearRow,
                  ],
                ),
                const SizedBox(height: 14),
                statsRow,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Labor Budget',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Yearly budget planning by language',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              yearRow,
              const SizedBox(width: 24),
              statsRow,
            ],
          );
        },
      ),
    );
  }

  Widget _bannerStat(String value, String label, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ─── Section label ────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ─── Summary cards ────────────────────────────────────────────────────────

  Widget _buildSummaryCards(double totalPaid, double remaining) {
    final cs = Theme.of(context).colorScheme;
    final pct = _totalBudget > 0 ? totalPaid / _totalBudget : 0.0;
    final progressColor = pct > 0.95
        ? Colors.red.shade600
        : pct > 0.8
            ? Colors.orange.shade600
            : Colors.green.shade500;

    return Column(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final cards = [
            _summaryCard(
              icon: Icons.account_balance,
              label: 'Total Budget $_year',
              value: 'THB ${_currencyFormat.format(_totalBudget)}',
              color: cs.primary,
            ),
            _summaryCard(
              icon: Icons.payments_outlined,
              label: 'Total Paid',
              value: 'THB ${_currencyFormat.format(totalPaid)}',
              color: Colors.red.shade700,
              sub: '${(pct * 100).toStringAsFixed(1)}% of budget',
            ),
            _summaryCard(
              icon: Icons.savings_outlined,
              label: remaining >= 0 ? 'Remaining' : 'Over Budget',
              value: 'THB ${_currencyFormat.format(remaining.abs())}',
              color: remaining >= 0
                  ? Colors.green.shade700
                  : Colors.red.shade700,
              sub: remaining < 0
                  ? 'Exceeded by THB ${_currencyFormat.format(remaining.abs())}'
                  : null,
            ),
          ];

          if (isNarrow) {
            return Column(
              children: cards
                  .map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: c,
                      ))
                  .toList(),
            );
          }
          return IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 10),
                Expanded(child: cards[1]),
                const SizedBox(width: 10),
                Expanded(child: cards[2]),
              ],
            ),
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
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overall Utilization',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.grey[700]),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: progressColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (sub != null)
                  Text(sub,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Language breakdown (read mode) ──────────────────────────────────────

  Widget _buildLanguageBreakdown() {
    final allLangs = {
      ..._allocations.keys,
      ..._paid.keys,
    }.toList()..sort();

    return Column(
      children: allLangs
          .map((lang) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLanguageCard(lang),
              ))
          .toList(),
    );
  }

  Widget _buildLanguageCard(String lang) {
    final pct = _allocations[lang] ?? 0;
    final langBudget = _totalBudget * (pct / 100);
    final paid = _paid[lang] ?? 0;
    final remaining = langBudget - paid;
    final utilization =
        langBudget > 0 ? (paid / langBudget).clamp(0.0, 1.5) : 0.0;
    final progressColor = utilization > 0.95
        ? Colors.red.shade600
        : utilization > 0.8
            ? Colors.orange.shade600
            : Colors.green.shade500;
    final isOver = remaining < 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOver ? Colors.red.shade300 : Colors.grey.shade200,
          width: isOver ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _langBadge(lang),
              const SizedBox(width: 8),
              Text(
                '${pct.toStringAsFixed(1)}% of budget',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const Spacer(),
              if (isOver)
                _chip('OVER BUDGET', Colors.red)
              else
                _chip(
                  '${(utilization * 100).toStringAsFixed(0)}% used',
                  utilization > 0.8 ? Colors.orange : Colors.green,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: utilization.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _langStat('Budget',
                  'THB ${_currencyFormat.format(langBudget)}',
                  Colors.grey.shade700),
              const SizedBox(width: 20),
              _langStat(
                  'Paid', 'THB ${_currencyFormat.format(paid)}',
                  Colors.red.shade700),
              const SizedBox(width: 20),
              _langStat(
                isOver ? 'Over by' : 'Remaining',
                'THB ${_currencyFormat.format(remaining.abs())}',
                isOver ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _langBadge(String lang) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        lang,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _chip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.shade700),
      ),
    );
  }

  Widget _langStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ─── Edit card ────────────────────────────────────────────────────────────

  Widget _buildEditCard() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.edit_outlined, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Set Budget for $_year',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Total budget
          TextField(
            controller: _budgetController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: InputDecoration(
              labelText: 'Total Yearly Budget (THB)',
              prefixIcon: Icon(Icons.account_balance, color: cs.primary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              filled: true,
              fillColor: cs.primary.withValues(alpha: 0.04),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          // Allocation header row: label + total chip + mode toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  'Language Allocations',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              _allocTotalChip(),
              const SizedBox(width: 8),
              _modeToggle(cs),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _amountMode
                ? 'Enter THB amount per language — must total the full budget'
                : 'Percentages must total exactly 100%',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          // Language rows
          ..._languages.map((lang) => _buildAllocRow(lang, cs)),
          // Add language row
          _buildAddLanguageRow(cs),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _distributeEvenly,
            icon: Icon(Icons.auto_fix_high, size: 16, color: cs.primary),
            label: Text(
              'Distribute evenly (${_languages.length} languages)',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          // Budget preview
          if ((double.tryParse(_budgetController.text) ?? 0) > 0 ||
              _totalBudget > 0) ...[
            const SizedBox(height: 8),
            _buildBudgetPreview(cs),
          ],
          const SizedBox(height: 20),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _saving ? null : () => setState(() => _editMode = false),
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
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save Budget'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modeToggle(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeButton(label: '%', selected: !_amountMode, cs: cs,
              onTap: () { if (_amountMode) _toggleMode(false); }),
          _modeButton(label: 'THB', selected: _amountMode, cs: cs,
              onTap: () { if (!_amountMode) _toggleMode(true); }),
        ],
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool selected,
    required ColorScheme cs,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildAllocRow(String lang, ColorScheme cs) {
    _allocControllers.putIfAbsent(lang, () {
      final c = TextEditingController();
      c.text = _amountMode
          ? (_totalBudget * ((_allocations[lang] ?? 0) / 100))
              .toStringAsFixed(0)
          : (_allocations[lang] ?? 0).toStringAsFixed(1);
      return c;
    });

    final rawVal =
        double.tryParse(_allocControllers[lang]!.text) ?? 0;
    final budgetInput =
        double.tryParse(_budgetController.text) ?? _totalBudget;

    // Preview label: in % mode show THB; in amount mode show %
    String previewLabel;
    if (_amountMode) {
      final pct = budgetInput > 0 ? (rawVal / budgetInput * 100) : 0.0;
      previewLabel = '${pct.toStringAsFixed(1)}%';
    } else {
      final cap = budgetInput * (rawVal / 100);
      previewLabel =
          cap > 0 ? 'THB ${_currencyFormat.format(cap)}' : '-';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(lang,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _allocControllers[lang],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              decoration: InputDecoration(
                suffixText: _amountMode ? null : '%',
                prefixText: _amountMode ? null : null,
                hintText: _amountMode ? 'Amount' : '0.0',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              previewLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary),
            ),
          ),
          // Delete button
          IconButton(
            icon: Icon(Icons.remove_circle_outline,
                size: 18, color: Colors.red.shade300),
            tooltip: 'Remove $lang',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _deleteLanguage(lang),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLanguageRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newLangController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Add language...',
                hintStyle:
                    TextStyle(fontSize: 13, color: Colors.grey[400]),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon:
                    Icon(Icons.add, size: 18, color: Colors.grey[400]),
              ),
              onSubmitted: (_) => _addLanguage(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _addLanguage,
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
        ],
      ),
    );
  }

  Widget _allocTotalChip() {
    final total = _allocTotal;
    final budgetInput =
        double.tryParse(_budgetController.text) ?? _totalBudget;
    final bool isOk;
    final String label;

    if (_amountMode) {
      isOk = budgetInput > 0 && (total - budgetInput).abs() <= budgetInput * 0.005;
      label = 'THB ${_currencyFormat.format(total)}';
    } else {
      isOk = (total - 100).abs() <= 0.1;
      label = 'Total: ${total.toStringAsFixed(1)}%';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOk ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isOk ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isOk ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _buildBudgetPreview(ColorScheme cs) {
    final budgetInput =
        double.tryParse(_budgetController.text) ?? _totalBudget;
    if (budgetInput <= 0) return const SizedBox.shrink();

    final activeLangs = _languages.where((l) {
      final val = double.tryParse(_allocControllers[l]?.text ?? '') ?? 0;
      return val > 0;
    }).toList();

    if (activeLangs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Preview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...activeLangs.map((lang) {
            final val =
                double.tryParse(_allocControllers[lang]!.text) ?? 0;
            final double pct;
            final double cap;
            if (_amountMode) {
              cap = val;
              pct = budgetInput > 0 ? (val / budgetInput * 100) : 0;
            } else {
              pct = val;
              cap = budgetInput * (val / 100);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(lang,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%  ->  THB ${_currencyFormat.format(cap)}',
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Empty / error states ─────────────────────────────────────────────────

  Widget _buildNoBudgetState() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No budget set for $_year',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the edit button in the top bar to set a yearly budget and allocate by language.',
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
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
