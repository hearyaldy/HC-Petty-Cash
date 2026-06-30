import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../models/expense_claim.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_claim_provider.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class ExpenseClaimsListScreen extends StatefulWidget {
  const ExpenseClaimsListScreen({super.key});

  @override
  State<ExpenseClaimsListScreen> createState() =>
      _ExpenseClaimsListScreenState();
}

class _ExpenseClaimsListScreenState extends State<ExpenseClaimsListScreen> {
  String _selectedStatus = 'all';
  String _searchQuery = '';

  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final List<String> _statusOptions = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadClaims());
  }

  Future<void> _loadClaims() async {
    final provider = context.read<ExpenseClaimProvider>();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    if (auth.canViewAllReports()) {
      await provider.loadAllClaims();
    } else {
      await provider.loadClaimsByUser(user.id);
    }
  }

  List<ExpenseClaim> _filtered(List<ExpenseClaim> claims) {
    return claims.where((c) {
      final matchStatus = _selectedStatus == 'all' || c.status == _selectedStatus;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.requesterName.toLowerCase().contains(q) ||
          c.claimNumber.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.canViewAllReports();
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildTopBar(context, maxWidth, hPad),
      drawer: const AppDrawer(),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Consumer<ExpenseClaimProvider>(
            builder: (context, provider, _) {
              final filtered = _filtered(provider.claims);
              return RefreshIndicator(
                onRefresh: _loadClaims,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeaderBanner(provider),
                            const SizedBox(height: 16),
                            _buildSearchBar(),
                            const SizedBox(height: 10),
                            _buildFilterChips(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                    if (provider.isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (provider.errorMessage != null)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                provider.errorMessage!,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadClaims,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                provider.claims.isEmpty
                                    ? 'No expense claims yet'
                                    : 'No claims match the filter',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 15),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () => context
                                    .push('/expense-claims/new')
                                    .then((_) => _loadClaims()),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New Claim'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildCard(
                                  context, filtered[index], isAdmin),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(
      BuildContext context, double maxWidth, double hPad) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.deepOrange.shade700,
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
                            'Expense Claims',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Staff expense reimbursement',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: Colors.white, size: 20),
                        tooltip: 'Refresh',
                        onPressed: _loadClaims,
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Colors.white, size: 20),
                        tooltip: 'New Claim',
                        onPressed: () => context
                            .push('/expense-claims/new')
                            .then((_) => _loadClaims()),
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

  Widget _buildHeaderBanner(ExpenseClaimProvider provider) {
    final pending = provider.pendingClaims.length;
    final approved = provider.approvedClaims.length;
    final total = provider.claims.length;
    final approvedAmount = provider.totalApprovedAmount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepOrange.shade700, Colors.orange.shade600],
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
          final stats = [
            ('Total', '$total'),
            ('Pending', '$pending'),
            ('Approved', '$approved'),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Expense Claims',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Submit and track staff expense reimbursements',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children:
                      stats.map((s) => _bannerStat(s.$1, s.$2)).toList(),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expense Claims',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit and track staff expense reimbursements',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 20,
                      children:
                          stats.map((s) => _bannerStat(s.$1, s.$2)).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Approved',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(approvedAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bannerStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search by title, name, or claim number...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.deepOrange.shade400),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusOptions.map((s) {
          final selected = _selectedStatus == s;
          final Color chipColor;
          if (s == 'pending') {
            chipColor = Colors.orange.shade700;
          } else if (s == 'approved') {
            chipColor = Colors.green.shade700;
          } else if (s == 'rejected') {
            chipColor = Colors.red.shade700;
          } else {
            chipColor = Colors.deepOrange.shade700;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                s == 'all' ? 'All' : s.toExpenseClaimStatus().displayName,
              ),
              selected: selected,
              selectedColor: chipColor.withValues(alpha: 0.12),
              checkmarkColor: chipColor,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? chipColor : Colors.grey[700],
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                  color: selected ? chipColor : Colors.grey.shade300),
              onSelected: (_) => setState(() => _selectedStatus = s),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, ExpenseClaim claim, bool isAdmin) {
    final statusColor = claim.status.toExpenseClaimStatus().color;

    final IconData statusIcon;
    switch (claim.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        break;
      default:
        statusIcon = Icons.pending;
    }

    final subtitle = [
      if (isAdmin) claim.requesterName,
      _dateFormat.format(claim.createdAt),
      '${claim.items.length} item${claim.items.length == 1 ? '' : 's'}',
    ].join(' • ');

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: Colors.white, size: 20),
        ),
        title: Text(
          claim.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 13)),
            Text(
              claim.claimNumber,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: Text(
          _currencyFormat.format(claim.totalAmount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.deepOrange.shade700,
          ),
        ),
        onTap: () => context
            .push('/expense-claims/${claim.id}')
            .then((_) => _loadClaims()),
      ),
    );
  }
}
