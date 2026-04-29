import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/budget_year.dart';
import '../../providers/budget_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/app_drawer.dart';

class BudgetListScreen extends StatefulWidget {
  const BudgetListScreen({super.key});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().subscribeYears();
    });
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────

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
                            'Annual Budget',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Admin · HCSA Financial Plan',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 22),
                        tooltip: 'New Budget Year',
                        onPressed: _showCreateDialog,
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

  // ─── Welcome banner ────────────────────────────────────────────────────────

  Widget _buildWelcomeHeader(BudgetProvider provider) {
    final cs = Theme.of(context).colorScheme;
    final approvedCount = provider.years.where((y) => y.isApproved).length;
    final draftCount = provider.years.length - approvedCount;

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
          final isCompact = constraints.maxWidth < 760;
          final stats = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statPill('${provider.years.length}', 'Total'),
              const SizedBox(width: 8),
              _statPill('$approvedCount', 'Approved'),
              const SizedBox(width: 8),
              _statPill('$draftCount', 'Draft'),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Annual Budgets',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hope Channel Southeast Asia',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 12),
                ),
                const SizedBox(height: 12),
                stats,
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
                child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Annual Budgets',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hope Channel Southeast Asia',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              stats,
            ],
          );
        },
      ),
    );
  }

  Widget _statPill(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 9)),
        ],
      ),
    );
  }

  // ─── Create dialog ─────────────────────────────────────────────────────────

  Future<void> _showCreateDialog() async {
    final provider = context.read<BudgetProvider>();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final years = provider.years;
    final existingYears = years.map((y) => y.year).toSet();
    int selectedYear = DateTime.now().year + 1;
    String? copyFromId;
    final notesCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final cs = Theme.of(ctx).colorScheme;
          final alreadyExists = existingYears.contains(selectedYear);
          return AlertDialog(
            title: const Text('New Budget Year'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Year:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: selectedYear,
                      items: List.generate(
                              6, (i) => DateTime.now().year + i)
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text(y.toString()),
                              ))
                          .toList(),
                      onChanged: (v) => setS(() => selectedYear = v!),
                    ),
                    if (alreadyExists) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.warning_amber,
                          color: Colors.orange.shade600, size: 16),
                      const SizedBox(width: 4),
                      Text('Exists',
                          style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 11)),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                if (years.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    key: ValueKey('copy_$copyFromId'),
                    initialValue: copyFromId,
                    decoration: const InputDecoration(
                      labelText: 'Copy amounts from',
                      border: OutlineInputBorder(),
                      helperText:
                          'Leave blank to use 2026 HCSA baseline',
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('— Fresh start —')),
                      ...years.map((y) => DropdownMenuItem(
                            value: y.id,
                            child: Text('${y.year} (${y.status})'),
                          )),
                    ],
                    onChanged: (v) => setS(() => copyFromId = v),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: alreadyExists
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        try {
                          await provider.createYear(
                            year: selectedYear,
                            createdBy: user.id,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                            copyFromYearId: copyFromId,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Budget $selectedYear created'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
    notesCtrl.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildTopBar(context),
      drawer: const AppDrawer(),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, _) {
          return ResponsiveContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _buildWelcomeHeader(provider),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.years.isEmpty
                          ? _buildEmpty(context)
                          : _buildList(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(BudgetProvider provider) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: provider.years.length,
          itemBuilder: (context, i) =>
              _buildYearCard(provider.years[i]),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 72, color: cs.outlineVariant),
          const SizedBox(height: 16),
          Text('No budgets yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Tap + in the top bar to create the first budget year',
              style:
                  TextStyle(fontSize: 13, color: cs.outlineVariant)),
        ],
      ),
    );
  }

  Widget _buildYearCard(BudgetYear year) {
    final cs = Theme.of(context).colorScheme;
    final isApproved = year.isApproved;
    final statusColor = isApproved ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/admin/budget/${year.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    year.year.toString(),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget ${year.year}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (year.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(year.notes!,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      'Created ${DateFormat('MMM dd, yyyy').format(year.createdAt)}',
                      style: TextStyle(
                          fontSize: 11, color: cs.outlineVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isApproved ? 'Approved' : 'Draft',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 18, color: cs.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
