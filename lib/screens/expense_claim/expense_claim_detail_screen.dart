import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/enums.dart';
import '../../models/expense_claim.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_claim_provider.dart';
import '../../services/expense_claim_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/print_options_dialog.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/support_document_upload_dialog.dart';

class ExpenseClaimDetailScreen extends StatefulWidget {
  final String claimId;

  const ExpenseClaimDetailScreen({super.key, required this.claimId});

  @override
  State<ExpenseClaimDetailScreen> createState() =>
      _ExpenseClaimDetailScreenState();
}

class _ExpenseClaimDetailScreenState extends State<ExpenseClaimDetailScreen> {
  final _exportService = ExpenseClaimPdfService();

  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _dateTimeFormat = DateFormat('MMM dd, yyyy  HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<ExpenseClaimProvider>().loadClaim(widget.claimId);
  }

  Future<void> _print(ExpenseClaim claim) async {
    await showPrintOptionsDialog(
      context: context,
      title: 'Print Expense Claim',
      onPrint: () => _exportService.printClaim(claim),
    );
  }

  Future<void> _approve(ExpenseClaim claim) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Claim'),
        content: Text(
          'Approve expense claim ${claim.claimNumber} for '
          '${_currencyFormat.format(claim.totalAmount)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ok = await context.read<ExpenseClaimProvider>().approveClaim(
          claim.id,
          user.id,
          user.name,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Claim approved.' : 'Failed to approve claim.'),
        backgroundColor:
            ok ? Colors.green : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _reject(ExpenseClaim claim) async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Claim: ${claim.claimNumber}'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection *',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(context, reasonCtrl.text.trim());
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || !mounted) return;

    final ok = await context
        .read<ExpenseClaimProvider>()
        .rejectClaim(claim.id, reason);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Claim rejected.' : 'Failed to reject claim.'),
        backgroundColor:
            ok ? Colors.orange : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _delete(ExpenseClaim claim) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Claim'),
        content: const Text(
          'Are you sure you want to delete this expense claim? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final ok =
        await context.read<ExpenseClaimProvider>().deleteClaim(claim.id);
    if (!mounted) return;

    if (ok) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete claim.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.canViewAllReports();
    final currentUserId = auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Consumer<ExpenseClaimProvider>(
          builder: (context, provider, _) {
            if (provider.selectedClaim == null && provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final claim = provider.selectedClaim;
            if (claim == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Claim not found.',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final isOwner = claim.requesterId == currentUserId;
            final canDelete = claim.canDelete && (isAdmin || isOwner);
            final canApprove = claim.canApprove && isAdmin;

            return SingleChildScrollView(
              child: ResponsiveContainer(
                padding: ResponsiveHelper.getScreenPadding(context)
                    .copyWith(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGradientHeader(claim, theme),
                    const SizedBox(height: 16),
                    _buildInfoCard(claim, theme),
                    const SizedBox(height: 16),
                    _buildLineItemsSection(context, claim, theme),
                    if (claim.notes != null && claim.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildNotesCard(claim, theme),
                    ],
                    if (claim.status == 'approved' ||
                        claim.status == 'rejected') ...[
                      const SizedBox(height: 16),
                      _approvalBanner(claim, theme,
                          approved: claim.status == 'approved'),
                    ],
                    if (canApprove || canDelete) ...[
                      const SizedBox(height: 24),
                      _buildActions(claim, canApprove, canDelete, theme),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGradientHeader(ExpenseClaim claim, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepOrange.shade700, Colors.orange.shade500],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 20),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _print(claim),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.print_outlined,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _load,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long,
                    size: 32, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      claim.claimNumber,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        claim.status.toExpenseClaimStatus().displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _currencyFormat.format(claim.totalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${claim.items.length} item${claim.items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ExpenseClaim claim, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claim Details',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.deepOrange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow(theme, Icons.person_outline, claim.requesterName),
            const SizedBox(height: 6),
            _infoRow(theme, Icons.business_outlined, claim.department),
            const SizedBox(height: 6),
            _infoRow(
              theme,
              Icons.calendar_today_outlined,
              'Submitted ${_dateTimeFormat.format(claim.createdAt)}',
            ),
            if (claim.purpose.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Purpose',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(claim.purpose, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection(
      BuildContext context, ExpenseClaim claim, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Items',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.deepOrange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...claim.items.asMap().entries.map(
                  (entry) => _buildLineItemCard(
                      context, entry.key, entry.value, theme),
                ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  _currencyFormat.format(claim.totalAmount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(ExpenseClaim claim, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.deepOrange.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(claim.notes!, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    ExpenseClaim claim,
    bool canApprove,
    bool canDelete,
    ThemeData theme,
  ) {
    return Column(
      children: [
        if (canApprove)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(claim),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _approve(claim),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        if (canDelete) ...[
          if (canApprove) const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _delete(claim),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Claim'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLineItemCard(
    BuildContext context,
    int index,
    ExpenseLineItem item,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.deepOrange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.description,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                _currencyFormat.format(item.amount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _chip(theme, item.categoryDisplayName),
                    const SizedBox(width: 8),
                    Text(
                      _dateFormat.format(item.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                if (item.receiptRef != null &&
                    item.receiptRef!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Receipt: ${item.receiptRef}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ],
                if (item.supportDocumentUrls.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SupportDocumentUploadDialog(
                        transactionId: item.description,
                        existingDocumentUrls: item.supportDocumentUrls,
                        onDocumentsUploaded: (_) {},
                      ),
                    ),
                    icon: const Icon(Icons.attach_file, size: 14),
                    label: Text(
                      '${item.supportDocumentUrls.length} document${item.supportDocumentUrls.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.deepOrange.shade700,
        ),
      ),
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _approvalBanner(
    ExpenseClaim claim,
    ThemeData theme, {
    required bool approved,
  }) {
    final color = approved ? Colors.green.shade700 : Colors.red.shade700;
    final bg = approved ? Colors.green.shade50 : Colors.red.shade50;
    final icon =
        approved ? Icons.check_circle_outline : Icons.cancel_outlined;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                approved ? 'Approved' : 'Rejected',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (approved && claim.approvedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'By ${claim.approverName ?? claim.approvedBy ?? ''} on ${_dateTimeFormat.format(claim.approvedAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
          if (!approved && claim.rejectionReason != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reason: ${claim.rejectionReason}',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }
}
