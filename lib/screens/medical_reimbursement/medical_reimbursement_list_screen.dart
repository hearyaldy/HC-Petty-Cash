import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_bill_reimbursement_provider.dart';
import '../../models/medical_bill_reimbursement.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import 'add_medical_reimbursement_dialog.dart';

class _StatData {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> gradient;

  _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}

enum _ViewMode { cards, table }

class MedicalReimbursementListScreen extends StatefulWidget {
  const MedicalReimbursementListScreen({super.key});

  @override
  State<MedicalReimbursementListScreen> createState() =>
      _MedicalReimbursementListScreenState();
}

class _MedicalReimbursementListScreenState
    extends State<MedicalReimbursementListScreen> {
  String _selectedStatus = 'all';
  String _searchQuery = '';
  _ViewMode _viewMode = _ViewMode.cards;

  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMM dd, yyyy');

  static const _viewModePrefsKey = 'medical_reimbursement_view_mode';

  final List<String> _statusOptions = [
    'all',
    'draft',
    'submitted',
    'approved',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReimbursements();
    });
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_viewModePrefsKey);
    if (!mounted) return;
    setState(() {
      _viewMode = raw == 'table' ? _ViewMode.table : _ViewMode.cards;
    });
  }

  Future<void> _saveViewMode(_ViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _viewModePrefsKey, mode == _ViewMode.table ? 'table' : 'cards');
  }

  Future<void> _loadReimbursements() async {
    final provider =
        Provider.of<MedicalBillReimbursementProvider>(context, listen: false);
    await provider.loadReimbursements();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey.shade600;
      case 'submitted':
        return Colors.orange.shade600;
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      case 'closed':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'draft':
        return 'Draft';
      case 'submitted':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  List<MedicalBillReimbursement> _filterReimbursements(
      List<MedicalBillReimbursement> reimbursements) {
    var filtered = reimbursements;

    // Filter by status
    if (_selectedStatus != 'all') {
      filtered = filtered.where((r) => r.status == _selectedStatus).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((r) {
        return r.requesterName.toLowerCase().contains(_searchQuery) ||
            r.subject.toLowerCase().contains(_searchQuery) ||
            r.reportNumber.toLowerCase().contains(_searchQuery) ||
            r.department.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer2<AuthProvider, MedicalBillReimbursementProvider>(
        builder: (context, authProvider, provider, child) {
          final reimbursements = _filterReimbursements(provider.reimbursements);

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
                          _buildHeaderBanner(authProvider),
                          const SizedBox(height: 16),
                          _buildStatCards(context, provider),
                          const SizedBox(height: 24),
                          _buildSearchBar(),
                          const SizedBox(height: 16),
                          _buildViewModeToggle(),
                          const SizedBox(height: 12),
                          _buildFilterChips(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  if (provider.isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (reimbursements.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedStatus == 'all'
                                  ? 'No medical reimbursements yet'
                                  : 'No ${_getStatusDisplayName(_selectedStatus).toLowerCase()} reimbursements',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a new claim to get started',
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
                      sliver: _viewMode == _ViewMode.table
                          ? SliverToBoxAdapter(
                              child: _buildReimbursementTable(context, reimbursements),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final reimbursement = reimbursements[index];
                                  return _buildReimbursementCard(reimbursement);
                                },
                                childCount: reimbursements.length,
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

  Widget _buildHeaderBanner(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal.shade400,
            Colors.teal.shade600,
            Colors.teal.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.shade200,
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
                onTap: _loadReimbursements,
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
                onTap: () => _showAddReimbursementDialog(authProvider),
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
                      Icon(Icons.add, color: Colors.teal.shade700, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'New Claim',
                        style: TextStyle(
                          color: Colors.teal.shade700,
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
                child: const Icon(Icons.local_hospital, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Bill Reimbursements',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Submit and track medical expense claims.',
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

  Widget _buildStatCards(
      BuildContext context, MedicalBillReimbursementProvider provider) {
    final stats = [
      _StatData(
        title: 'Total Claims',
        value: provider.reimbursements.length.toString(),
        icon: Icons.receipt_long,
        gradient: [Colors.blue.shade400, Colors.blue.shade600],
      ),
      _StatData(
        title: 'Pending Approval',
        value: provider.pendingApprovalCount.toString(),
        icon: Icons.pending_actions,
        gradient: [Colors.orange.shade400, Colors.orange.shade600],
      ),
      _StatData(
        title: 'Total Reimbursement',
        value: _currencyFormat.format(provider.totalReimbursementAmount),
        icon: Icons.attach_money,
        gradient: [Colors.green.shade400, Colors.green.shade600],
      ),
      _StatData(
        title: 'Approved Amount',
        value: _currencyFormat.format(provider.approvedReimbursementAmount),
        icon: Icons.check_circle,
        gradient: [Colors.purple.shade400, Colors.purple.shade600],
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      stat.title,
                      style: TextStyle(
                        fontSize: 11,
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

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search by name, subject, or report number...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
        });
      },
    );
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
              isSelected: _viewMode == _ViewMode.cards,
              onTap: () => _setViewMode(_ViewMode.cards),
            ),
            const SizedBox(width: 8),
            _buildViewModeButton(
              icon: Icons.table_rows_outlined,
              tooltip: 'Table view',
              isSelected: _viewMode == _ViewMode.table,
              onTap: () => _setViewMode(_ViewMode.table),
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
            color: isSelected ? Colors.teal.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.teal : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.teal : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Future<void> _setViewMode(_ViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    await _saveViewMode(mode);
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
                  ? Colors.teal.shade100
                  : _getStatusColor(status).withValues(alpha: 0.2),
              checkmarkColor:
                  status == 'all' ? Colors.teal : _getStatusColor(status),
              labelStyle: TextStyle(
                color: isSelected
                    ? (status == 'all' ? Colors.teal : _getStatusColor(status))
                    : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? (status == 'all' ? Colors.teal : _getStatusColor(status))
                    : Colors.grey.shade300,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReimbursementCard(MedicalBillReimbursement reimbursement) {
    final isDraft = reimbursement.status == 'draft';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/medical-reimbursement/${reimbursement.id}'),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.teal,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reimbursement.reportNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reimbursement.subject,
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
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusChip(reimbursement.status),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                        onSelected: (value) => _handleCardMenuAction(value, reimbursement),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, color: Colors.teal, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          if (isDraft) ...[
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      Icons.person_outline,
                      reimbursement.requesterName,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      Icons.business,
                      reimbursement.department,
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
                      _dateFormat.format(reimbursement.reportDate),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reimbursement',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        Text(
                          _currencyFormat.format(reimbursement.totalReimbursement),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (reimbursement.claimItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${reimbursement.claimItems.length} claim item${reimbursement.claimItems.length > 1 ? 's' : ''} • Total Bill: ${_currencyFormat.format(reimbursement.totalBill)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
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

  Widget _buildReimbursementTable(
      BuildContext context, List<MedicalBillReimbursement> reimbursements) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('Report No.')),
            DataColumn(label: Text('Requester')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Total Bill')),
            DataColumn(label: Text('Reimbursement')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: reimbursements.map((reimbursement) {
            final isDraft = reimbursement.status == 'draft';
            return DataRow(
              onSelectChanged: (_) =>
                  context.push('/medical-reimbursement/${reimbursement.id}'),
              cells: [
                DataCell(Text(reimbursement.reportNumber)),
                DataCell(Text(reimbursement.requesterName)),
                DataCell(Text(reimbursement.department)),
                DataCell(Text(_dateFormat.format(reimbursement.reportDate))),
                DataCell(Text(_currencyFormat.format(reimbursement.totalBill))),
                DataCell(Text(
                  _currencyFormat.format(reimbursement.totalReimbursement),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                )),
                DataCell(_buildStatusCell(reimbursement.status)),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.teal, size: 20),
                        tooltip: 'View',
                        onPressed: () => context.push('/medical-reimbursement/${reimbursement.id}'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      if (isDraft) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _editReimbursement(reimbursement),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          tooltip: 'Delete',
                          onPressed: () => _deleteReimbursement(reimbursement),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),
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

  Future<void> _showAddReimbursementDialog(AuthProvider authProvider) async {
    final result = await showDialog<MedicalBillReimbursement>(
      context: context,
      builder: (context) => AddMedicalReimbursementDialog(
        user: authProvider.currentUser!,
      ),
    );

    if (result != null && mounted) {
      context.push('/medical-reimbursement/${result.id}');
    }
  }

  void _handleCardMenuAction(String action, MedicalBillReimbursement reimbursement) {
    switch (action) {
      case 'view':
        context.push('/medical-reimbursement/${reimbursement.id}');
        break;
      case 'edit':
        _editReimbursement(reimbursement);
        break;
      case 'delete':
        _deleteReimbursement(reimbursement);
        break;
    }
  }

  Future<void> _editReimbursement(MedicalBillReimbursement reimbursement) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await showDialog<MedicalBillReimbursement>(
      context: context,
      builder: (context) => AddMedicalReimbursementDialog(
        user: authProvider.currentUser!,
        existingReimbursement: reimbursement,
      ),
    );

    if (result != null && mounted) {
      _loadReimbursements();
    }
  }

  Future<void> _deleteReimbursement(MedicalBillReimbursement reimbursement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reimbursement'),
        content: Text(
          'Are you sure you want to delete "${reimbursement.reportNumber}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<MedicalBillReimbursementProvider>(context, listen: false);
      await provider.deleteReimbursement(reimbursement.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${reimbursement.reportNumber} deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
