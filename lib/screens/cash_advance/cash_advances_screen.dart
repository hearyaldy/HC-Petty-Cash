import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import '../../models/cash_advance.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cash_advance_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;
  final Color lightColor;

  _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.lightColor,
  });
}

class CashAdvancesScreen extends StatefulWidget {
  const CashAdvancesScreen({super.key, this.initialViewMode});

  final CashAdvancesViewMode? initialViewMode;

  @override
  State<CashAdvancesScreen> createState() => _CashAdvancesScreenState();
}

class _CashAdvancesScreenState extends State<CashAdvancesScreen> {
  String _selectedStatus = 'all';
  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMM dd, yyyy');

  static const _viewModePrefsKey = 'cash_advances_view_mode';
  CashAdvancesViewMode _viewMode = CashAdvancesViewMode.cards;

  final List<String> _statusOptions = [
    'all',
    'draft',
    'submitted',
    'approved',
    'disbursed',
    'settled',
    'rejected',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAdvances();
    });
  }

  Future<void> _loadViewMode() async {
    if (widget.initialViewMode != null) {
      setState(() => _viewMode = widget.initialViewMode!);
      await _saveViewMode(widget.initialViewMode!);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_viewModePrefsKey);
    if (!mounted) return;
    setState(() {
      _viewMode =
          raw == 'table' ? CashAdvancesViewMode.table : CashAdvancesViewMode.cards;
    });
  }

  Future<void> _saveViewMode(CashAdvancesViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModePrefsKey, mode == CashAdvancesViewMode.table ? 'table' : 'cards');
  }

  Future<void> _loadAdvances() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cashAdvanceProvider =
        Provider.of<CashAdvanceProvider>(context, listen: false);
    final isAdmin = authProvider.canManageUsers();
    final user = authProvider.currentUser;

    if (isAdmin) {
      await cashAdvanceProvider.loadAdvances();
    } else if (user != null) {
      await cashAdvanceProvider.loadAdvancesByUser(user.id);
    }
  }

  Color _getStatusColor(String status) {
    final statusEnum = status.toCashAdvanceStatus();
    return statusEnum.color;
  }

  String _getStatusDisplayName(String status) {
    return status.cashAdvanceStatusDisplayName;
  }

  List<CashAdvance> _filterAdvances(List<CashAdvance> advances) {
    if (_selectedStatus == 'all') {
      return advances;
    }
    return advances.where((a) => a.status == _selectedStatus).toList();
  }

  Widget _buildViewModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'View Mode',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Row(
          children: [
            _buildViewModeButton(
              icon: Icons.view_module,
              tooltip: 'Card view',
              isSelected: _viewMode == CashAdvancesViewMode.cards,
              onTap: () => _setViewMode(CashAdvancesViewMode.cards),
            ),
            const SizedBox(width: 8),
            _buildViewModeButton(
              icon: Icons.table_rows_outlined,
              tooltip: 'Table view',
              isSelected: _viewMode == CashAdvancesViewMode.table,
              onTap: () => _setViewMode(CashAdvancesViewMode.table),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.indigo : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.indigo : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Future<void> _setViewMode(CashAdvancesViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await _saveViewMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<AuthProvider, CashAdvanceProvider>(
        builder: (context, authProvider, cashAdvanceProvider, child) {
          final isAdmin = authProvider.canManageUsers();
          final advances = _filterAdvances(cashAdvanceProvider.advances);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: contentPadding.left,
                        right: contentPadding.right,
                        top: MediaQuery.of(context).padding.top + 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderBanner(cashAdvanceProvider),
                          const SizedBox(height: 16),
                          _buildStatCards(context, cashAdvanceProvider),
                          const SizedBox(height: 24),
                          _buildViewModeToggle(),
                          const SizedBox(height: 12),
                          _buildFilterChips(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (cashAdvanceProvider.isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (advances.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.request_quote_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedStatus == 'all'
                                  ? 'No cash advances yet'
                                  : 'No ${_getStatusDisplayName(_selectedStatus).toLowerCase()} advances',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a new cash advance to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: contentPadding.left,
                      ),
                      sliver: _viewMode == CashAdvancesViewMode.table
                          ? SliverToBoxAdapter(
                              child: _buildAdvanceTable(context, advances),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final advance = advances[index];
                                  return _buildAdvanceCard(
                                    context,
                                    advance,
                                    isAdmin,
                                  );
                                },
                                childCount: advances.length,
                              ),
                            ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderBanner(CashAdvanceProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.indigo.shade400,
            Colors.indigo.shade600,
            Colors.indigo.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.shade200,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/finance-dashboard'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _printAdvances(provider.advances),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _loadAdvances,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push('/cash-advances/new'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: Colors.indigo.shade700, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'New Request',
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.request_quote, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cash Advances',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track, approve, and settle cash advance requests.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, CashAdvanceProvider provider) {
    final stats = [
      _StatData(
        title: 'Total Requests',
        value: provider.advances.length.toString(),
        icon: Icons.receipt_long,
        gradient: [Colors.blue.shade400, Colors.blue.shade600],
        lightColor: Colors.blue.shade50,
      ),
      _StatData(
        title: 'Pending Approval',
        value: provider.pendingApprovalCount.toString(),
        icon: Icons.pending_actions,
        gradient: [Colors.orange.shade400, Colors.orange.shade600],
        lightColor: Colors.orange.shade50,
      ),
      _StatData(
        title: 'Pending Settlement',
        value: provider.pendingSettlementCount.toString(),
        icon: Icons.account_balance_wallet,
        gradient: [Colors.purple.shade400, Colors.purple.shade600],
        lightColor: Colors.purple.shade50,
      ),
      _StatData(
        title: 'Outstanding',
        value: _currencyFormat.format(provider.totalOutstandingAmount),
        icon: Icons.attach_money,
        gradient: [Colors.green.shade400, Colors.green.shade600],
        lightColor: Colors.green.shade50,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: stat.gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: stat.gradient[0].withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(stat.icon, color: Colors.white, size: 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stat.value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      stat.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusOptions.map((status) {
          final isSelected = _selectedStatus == status;
          final displayName =
              status == 'all' ? 'All' : _getStatusDisplayName(status);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedStatus = status;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: status == 'all'
                  ? Colors.indigo.shade100
                  : _getStatusColor(status).withValues(alpha: 0.2),
              checkmarkColor: status == 'all'
                  ? Colors.indigo
                  : _getStatusColor(status),
              labelStyle: TextStyle(
                color: isSelected
                    ? (status == 'all'
                        ? Colors.indigo
                        : _getStatusColor(status))
                    : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? (status == 'all'
                        ? Colors.indigo
                        : _getStatusColor(status))
                    : Colors.grey.shade300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvanceCard(
    BuildContext context,
    CashAdvance advance,
    bool isAdmin,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/cash-advances/${advance.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          advance.requestNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          advance.purpose,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(advance.status),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.person_outline,
                      advance.requesterName,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.business,
                      advance.department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.calendar_today,
                      _dateFormat.format(advance.requestDate),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(advance.requestedAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (advance.status == CashAdvanceStatus.disbursed.name &&
                  advance.disbursedAmount != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Disbursed: ${_currencyFormat.format(advance.disbursedAmount)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (advance.requiresActionNo && advance.actionNo != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    'Action No: ${advance.actionNo}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final displayName = _getStatusDisplayName(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAdvanceTable(BuildContext context, List<CashAdvance> advances) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('Request No.')),
            DataColumn(label: Text('Requester')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Status')),
          ],
          rows: advances.map((advance) {
            return DataRow(
              onSelectChanged: (_) =>
                  context.push('/cash-advances/${advance.id}'),
              cells: [
                DataCell(Text(advance.requestNumber)),
                DataCell(Text(advance.requesterName)),
                DataCell(Text(advance.department)),
                DataCell(Text(_dateFormat.format(advance.requestDate))),
                DataCell(Text(_currencyFormat.format(advance.requestedAmount))),
                DataCell(_buildStatusCell(advance.status)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusCell(String status) {
    final color = _getStatusColor(status);
    final displayName = _getStatusDisplayName(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _printAdvances(List<CashAdvance> advances) async {
    if (advances.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cash advances to print')),
      );
      return;
    }

    final pdf = pw.Document();
    final currency = NumberFormat.currency(
      symbol: AppConstants.currencySymbol,
      decimalDigits: 2,
    );
    const brandColor = PdfColor.fromInt(0xFF3F51B5);
    const lightBrand = PdfColor.fromInt(0xFFE8EAF6);
    const mutedText = PdfColor.fromInt(0xFF6B7280);
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load(AppConstants.companyLogo);
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(logoImage),
              pw.SizedBox(height: 12),
              _buildPdfHero(
                title: 'Cash Advances List',
                subtitle: 'Summary of requests',
                count: advances.length,
                brandColor: brandColor,
                lightBrand: lightBrand,
              ),
              pw.SizedBox(height: 12),
              _buildPdfSectionCard(
                title: 'Requests',
                child: pw.TableHelper.fromTextArray(
                  headers: const [
                    'Request No.',
                    'Requester',
                    'Department',
                    'Date',
                    'Amount',
                    'Status',
                  ],
                  data: advances
                      .map(
                        (a) => [
                          a.requestNumber,
                          a.requesterName,
                          a.department,
                          _dateFormat.format(a.requestDate),
                          currency.format(a.requestedAmount),
                          a.status.toUpperCase(),
                        ],
                      )
                      .toList(),
                  headerStyle:
                      pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  cellPadding: const pw.EdgeInsets.all(4),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(1.5),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                ),
              ),
              pw.SizedBox(height: 18),
              _buildPdfSectionCard(
                title: 'Signatures',
                child: _buildPdfSignatureSection(),
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated on: ${_dateFormat.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 9, color: mutedText),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  pw.Widget _buildPdfHeader(pw.ImageProvider? logoImage) {
    return pw.Row(
      children: [
        if (logoImage != null)
          pw.Container(
            width: 36,
            height: 36,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        else
          pw.Container(
            width: 36,
            height: 36,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey300,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Center(
              child: pw.Text(
                'H',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
            ),
          ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.organizationName,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.Text(
                AppConstants.organizationAddress,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSignatureSection() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _buildPdfSignatureBlock('Prepared By'),
        _buildPdfSignatureBlock('Reviewed By'),
        _buildPdfSignatureBlock('Approved By'),
      ],
    );
  }

  pw.Widget _buildPdfSignatureBlock(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.SizedBox(height: 28),
        pw.Container(
          width: 160,
          height: 0.5,
          color: PdfColors.grey700,
        ),
        pw.SizedBox(height: 6),
        pw.Text('Name / Signature', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildPdfHero({
    required String title,
    required String subtitle,
    required int count,
    required PdfColor brandColor,
    required PdfColor lightBrand,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: lightBrand,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: brandColor),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: brandColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: brandColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              '$count requests',
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

enum CashAdvancesViewMode { cards, table }
