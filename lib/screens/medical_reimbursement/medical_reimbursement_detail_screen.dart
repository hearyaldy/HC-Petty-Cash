import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medical_bill_reimbursement_provider.dart';
import '../../models/medical_bill_reimbursement.dart';
import '../../models/enums.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';
import '../../services/medical_bill_reimbursement_export_service.dart';
import 'add_medical_reimbursement_dialog.dart';

class MedicalReimbursementDetailScreen extends StatefulWidget {
  final String reimbursementId;

  const MedicalReimbursementDetailScreen({
    super.key,
    required this.reimbursementId,
  });

  @override
  State<MedicalReimbursementDetailScreen> createState() =>
      _MedicalReimbursementDetailScreenState();
}

class _MedicalReimbursementDetailScreenState
    extends State<MedicalReimbursementDetailScreen> {
  final _exportService = MedicalBillReimbursementExportService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MedicalBillReimbursementProvider>();
      if (provider.reimbursements.isEmpty) {
        provider.loadReimbursements();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicalBillReimbursementProvider>();
    final authProvider = context.watch<AuthProvider>();

    final reimbursement = provider.reimbursements.cast<MedicalBillReimbursement?>().firstWhere(
      (r) => r?.id == widget.reimbursementId,
      orElse: () => null,
    );

    if (reimbursement == null && provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (reimbursement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Reimbursement not found',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/medical-reimbursement'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: ResponsiveContainer(
          padding: ResponsiveHelper.getScreenPadding(context).copyWith(
            top: MediaQuery.of(context).padding.top + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(reimbursement, authProvider, provider),
              const SizedBox(height: 16),
              _buildInfoCard(reimbursement),
              const SizedBox(height: 16),
              _buildClaimItemsCard(reimbursement),
              const SizedBox(height: 16),
              _buildSummaryCard(reimbursement),
              if (reimbursement.notes != null && reimbursement.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(reimbursement),
              ],
              const SizedBox(height: 24),
              _buildActionButtons(reimbursement, authProvider, provider),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade600, Colors.teal.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Navigation row
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
              if (reimbursement.status == 'draft')
                InkWell(
                  onTap: () => _editReimbursement(reimbursement, authProvider),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              const SizedBox(width: 8),
              _buildMenuButton(reimbursement, authProvider, provider),
            ],
          ),
          const SizedBox(height: 16),
          // Content row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_hospital, size: 40, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reimbursement.reportNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reimbursement.requesterName,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(reimbursement.statusEnum),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(value, reimbursement, authProvider, provider),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'print',
          child: Row(
            children: [
              Icon(Icons.print, size: 20),
              SizedBox(width: 12),
              Text('Print Form'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.download, size: 20),
              SizedBox(width: 12),
              Text('Export PDF'),
            ],
          ),
        ),
        if (reimbursement.status == 'draft') ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'submit',
            child: Row(
              children: [
                Icon(Icons.send, color: Colors.blue, size: 20),
                SizedBox(width: 12),
                Text('Submit for Approval'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        if (reimbursement.status == 'submitted' &&
            (authProvider.currentUser?.role == 'admin' ||
                authProvider.currentUser?.role == 'finance' ||
                authProvider.currentUser?.role == 'manager')) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'approve',
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text('Approve'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'reject',
            child: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text('Reject'),
              ],
            ),
          ),
        ],
        if (reimbursement.status == 'approved') ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'close',
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.purple, size: 20),
                SizedBox(width: 12),
                Text('Close'),
              ],
            ),
          ),
        ],
        // Admin option to revert any non-draft status back to draft
        if (reimbursement.status != 'draft' &&
            authProvider.currentUser?.role == 'admin') ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'revert_to_draft',
            child: Row(
              children: [
                Icon(Icons.refresh, color: Colors.orange, size: 20),
                SizedBox(width: 12),
                Text('Revert to Draft'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoCard(MedicalBillReimbursement reimbursement) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildInfoRow('Date', dateFormat.format(reimbursement.reportDate)),
            _buildInfoRow('Department', reimbursement.department),
            _buildInfoRow('Subject', reimbursement.subject),
            if (reimbursement.paidTo != null && reimbursement.paidTo!.isNotEmpty)
              _buildInfoRow('Paid To', reimbursement.paidTo!),
            if (reimbursement.submittedAt != null)
              _buildInfoRow('Submitted', dateFormat.format(reimbursement.submittedAt!)),
            if (reimbursement.approvedAt != null)
              _buildInfoRow('Approved', dateFormat.format(reimbursement.approvedAt!)),
            if (reimbursement.approverName != null)
              _buildInfoRow('Approved By', reimbursement.approverName!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimItemsCard(MedicalBillReimbursement reimbursement) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isMobile = ResponsiveHelper.isMobile(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Claim Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${reimbursement.claimItems.length} items',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(height: 24),
            if (!isMobile) ...[
              // Table header for desktop/tablet
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 40, child: Text('No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 50, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('Total Bill', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    SizedBox(width: 50, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                    Expanded(child: Text('Reimburse', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...reimbursement.claimItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text('${index + 1}.'),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(item.description),
                      ),
                      SizedBox(
                        width: 50,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.claimTypeEnum == MedicalClaimType.outPatient
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.claimTypeEnum.shortName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: item.claimTypeEnum == MedicalClaimType.outPatient
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${AppConstants.currencySymbol} ${currencyFormat.format(item.totalBill)}',
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${(item.claimTypeEnum.reimbursementRate * 100).toInt()}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${AppConstants.currencySymbol} ${currencyFormat.format(item.amountReimburse)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              // Card-style layout for mobile
              ...reimbursement.claimItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}. ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Expanded(
                            child: Text(
                              item.description,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.claimTypeEnum == MedicalClaimType.outPatient
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.claimTypeEnum.shortName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: item.claimTypeEnum == MedicalClaimType.outPatient
                                    ? Colors.blue
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Bill',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '${AppConstants.currencySymbol} ${currencyFormat.format(item.totalBill)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Rate',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '${(item.claimTypeEnum.reimbursementRate * 100).toInt()}%',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Reimburse',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                              Text(
                                '${AppConstants.currencySymbol} ${currencyFormat.format(item.amountReimburse)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(MedicalBillReimbursement reimbursement) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final isMobile = ResponsiveHelper.isMobile(context);
    final opTotal = reimbursement.getTotalBillByType(MedicalClaimType.outPatient);
    final opReimburse = reimbursement.getTotalReimbursementByType(MedicalClaimType.outPatient);
    final ipTotal = reimbursement.getTotalBillByType(MedicalClaimType.inPatient);
    final ipReimburse = reimbursement.getTotalReimbursementByType(MedicalClaimType.inPatient);

    final opBox = _buildSummaryBox(
      'Out Patient (75%)',
      'Bill: ${AppConstants.currencySymbol} ${currencyFormat.format(opTotal)}',
      'Reimburse: ${AppConstants.currencySymbol} ${currencyFormat.format(opReimburse)}',
      Colors.blue,
    );
    final ipBox = _buildSummaryBox(
      'In Patient (90%)',
      'Bill: ${AppConstants.currencySymbol} ${currencyFormat.format(ipTotal)}',
      'Reimburse: ${AppConstants.currencySymbol} ${currencyFormat.format(ipReimburse)}',
      Colors.orange,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            if (isMobile) ...[
              opBox,
              const SizedBox(height: 12),
              ipBox,
            ] else
              Row(
                children: [
                  Expanded(child: opBox),
                  const SizedBox(width: 12),
                  Expanded(child: ipBox),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Bill', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '${AppConstants.currencySymbol} ${currencyFormat.format(reimbursement.totalBill)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Reimbursement', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '${AppConstants.currencySymbol} ${currencyFormat.format(reimbursement.totalReimbursement)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Bill', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '${AppConstants.currencySymbol} ${currencyFormat.format(reimbursement.totalBill)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Reimbursement', style: TextStyle(color: Colors.grey[600])),
                            Text(
                              '${AppConstants.currencySymbol} ${currencyFormat.format(reimbursement.totalReimbursement)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String title, String line1, String line2, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 8),
          Text(line1, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(line2, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNotesCard(MedicalBillReimbursement reimbursement) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Text(reimbursement.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ReportStatus status) {
    Color backgroundColor;
    switch (status) {
      case ReportStatus.draft:
        backgroundColor = Colors.grey.shade600;
        break;
      case ReportStatus.submitted:
        backgroundColor = Colors.orange.shade600;
        break;
      case ReportStatus.underReview:
        backgroundColor = Colors.blue.shade600;
        break;
      case ReportStatus.approved:
        backgroundColor = Colors.green.shade600;
        break;
      case ReportStatus.closed:
        backgroundColor = Colors.purple.shade600;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildActionButtons(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) {
    final status = reimbursement.statusEnum;
    final List<Widget> buttons = [];
    final canApprove = authProvider.currentUser?.role == 'admin' ||
        authProvider.currentUser?.role == 'finance' ||
        authProvider.currentUser?.role == 'manager';

    if (status == ReportStatus.draft) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _editReimbursement(reimbursement, authProvider),
          icon: const Icon(Icons.edit),
          label: const Text('Edit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      );
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _submitReimbursement(reimbursement, authProvider, provider),
          icon: const Icon(Icons.send),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (status == ReportStatus.submitted && canApprove) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _approveReimbursement(reimbursement, authProvider, provider),
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _rejectReimbursement(reimbursement, provider),
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (status == ReportStatus.approved && canApprove) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () async {
            await provider.closeReimbursement(reimbursement.id);
          },
          icon: const Icon(Icons.lock),
          label: const Text('Close'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: buttons,
    );
  }

  Future<void> _editReimbursement(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
  ) async {
    final result = await showDialog<MedicalBillReimbursement>(
      context: context,
      builder: (context) => AddMedicalReimbursementDialog(
        user: authProvider.currentUser!,
        existingReimbursement: reimbursement,
      ),
    );

    if (result != null && mounted) {
      context.read<MedicalBillReimbursementProvider>().loadReimbursements();
    }
  }

  void _handleMenuAction(
    String action,
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) async {
    switch (action) {
      case 'print':
        await _exportService.printMedicalBillReimbursement(reimbursement);
        break;
      case 'export':
        final path = await _exportService.exportMedicalBillReimbursement(reimbursement);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported to: $path')),
          );
        }
        break;
      case 'submit':
        await _submitReimbursement(reimbursement, authProvider, provider);
        break;
      case 'approve':
        await _approveReimbursement(reimbursement, authProvider, provider);
        break;
      case 'reject':
        await _rejectReimbursement(reimbursement, provider);
        break;
      case 'close':
        await provider.closeReimbursement(reimbursement.id);
        break;
      case 'revert_to_draft':
        await _revertToDraft(reimbursement, provider);
        break;
      case 'delete':
        await _deleteReimbursement(reimbursement, provider);
        break;
    }
  }

  Future<void> _submitReimbursement(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit for Approval'),
        content: const Text('Are you sure you want to submit this reimbursement for approval?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.submitReimbursement(reimbursement.id, authProvider.currentUser!.id);
    }
  }

  Future<void> _approveReimbursement(
    MedicalBillReimbursement reimbursement,
    AuthProvider authProvider,
    MedicalBillReimbursementProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Reimbursement'),
        content: const Text('Are you sure you want to approve this reimbursement?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.approveReimbursement(
        reimbursement.id,
        authProvider.currentUser!.id,
        authProvider.currentUser!.name,
      );
    }
  }

  Future<void> _revertToDraft(
    MedicalBillReimbursement reimbursement,
    MedicalBillReimbursementProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to Draft'),
        content: Text(
          'Are you sure you want to revert "${reimbursement.reportNumber}" back to draft status?\n\n'
          'This will allow the requester to edit and resubmit the reimbursement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Revert to Draft'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = await provider.revertToDraft(reimbursement.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reimbursement reverted to draft'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _rejectReimbursement(
    MedicalBillReimbursement reimbursement,
    MedicalBillReimbursementProvider provider,
  ) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Reimbursement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm == true && reasonController.text.isNotEmpty) {
      await provider.rejectReimbursement(reimbursement.id, reasonController.text);
    }
  }

  Future<void> _deleteReimbursement(
    MedicalBillReimbursement reimbursement,
    MedicalBillReimbursementProvider provider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reimbursement'),
        content: const Text('Are you sure you want to delete this reimbursement? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await provider.deleteReimbursement(reimbursement.id);
      if (mounted) {
        context.go('/medical-reimbursement');
      }
    }
  }
}
