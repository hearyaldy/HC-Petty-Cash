import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/cash_advance.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cash_advance_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/cash_advance_pdf_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class CashAdvanceDetailScreen extends StatefulWidget {
  final String advanceId;

  const CashAdvanceDetailScreen({super.key, required this.advanceId});

  @override
  State<CashAdvanceDetailScreen> createState() =>
      _CashAdvanceDetailScreenState();
}

class _CashAdvanceDetailScreenState extends State<CashAdvanceDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final _dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');

  CashAdvance? _advance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdvance();
  }

  Future<void> _loadAdvance() async {
    setState(() => _isLoading = true);
    try {
      final advance = await _firestoreService.getCashAdvance(widget.advanceId);
      setState(() {
        _advance = advance;
        _isLoading = false;
      });
      if (advance != null && mounted) {
        context.read<CashAdvanceProvider>().setSelectedAdvance(advance);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading advance: $e')),
        );
      }
    }
  }

  Future<void> _submitAdvance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || _advance == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit for Approval'),
        content: const Text(
          'Are you sure you want to submit this cash advance request? '
          'You will not be able to edit it after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.submitCashAdvance(_advance!.id, user.id);
      await _loadAdvance();
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash advance submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: $e')),
        );
      }
    }
  }

  Future<void> _approveAdvance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || _advance == null) return;

    String? actionNo;

    if (_advance!.requiresActionNo) {
      actionNo = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Action No. Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This request exceeds 20,000 Baht. Please enter the Action No.:',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Action No.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, controller.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
            ],
          );
        },
      );

      if (actionNo == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Request'),
          content: Text(
            'Are you sure you want to approve this cash advance request for '
            '${_currencyFormat.format(_advance!.requestedAmount)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    try {
      await _firestoreService.approveCashAdvance(
        _advance!.id,
        user.name,
        actionNo: actionNo,
      );
      await _loadAdvance();
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash advance approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e')),
        );
      }
    }
  }

  Future<void> _rejectAdvance() async {
    if (_advance == null) return;

    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    try {
      await _firestoreService.rejectCashAdvance(_advance!.id, reason);
      await _loadAdvance();
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash advance rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e')),
        );
      }
    }
  }

  Future<void> _disburseAdvance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null || _advance == null) return;

    final amountController =
        TextEditingController(text: _advance!.requestedAmount.toString());
    final referenceController = TextEditingController();
    String paymentMethod = 'cash';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Disburse Funds'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Disbursement Amount',
                    border: const OutlineInputBorder(),
                    prefixText: '${AppConstants.currencySymbol} ',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Payment Method'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(
                        value: 'bankTransfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    setState(() => paymentMethod = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference Number (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  Navigator.pop(context, {
                    'amount': amount,
                    'paymentMethod': paymentMethod,
                    'referenceNumber': referenceController.text.trim(),
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Disburse'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    try {
      await _firestoreService.disburseCashAdvance(
        advanceId: _advance!.id,
        disbursedBy: user.name,
        amount: result['amount'] as double,
        paymentMethod: result['paymentMethod'] as String,
        referenceNumber: result['referenceNumber'] as String?,
      );
      await _loadAdvance();
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funds disbursed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disbursing: $e')),
        );
      }
    }
  }

  Future<void> _deleteAdvance() async {
    if (_advance == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text(
          'Are you sure you want to delete this cash advance request? '
          'This action cannot be undone.',
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

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteCashAdvance(_advance!.id);
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash advance deleted'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/cash-advances');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.canManageUsers();
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _advance == null
              ? const Center(child: Text('Advance not found'))
              : Center(
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
                                _buildHeaderBanner(isAdmin),
                                const SizedBox(height: 16),
                                _buildStatusCard(),
                                const SizedBox(height: 16),
                                _buildDetailsCard(),
                                if (_advance!.items.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildItemsCard(),
                                ],
                                const SizedBox(height: 16),
                                _buildRequesterCard(),
                                if (_advance!.status != CashAdvanceStatus.draft.name) ...[
                                  const SizedBox(height: 16),
                                  _buildTimelineCard(),
                                ],
                                if (_advance!.disbursedAmount != null) ...[
                                  const SizedBox(height: 16),
                                  _buildDisbursementCard(),
                                ],
                                if (_advance!.purchaseRequisitionId != null) ...[
                                  const SizedBox(height: 16),
                                  _buildLinkedPRCard(),
                                ],
                                if (_advance!.settlementId != null) ...[
                                  const SizedBox(height: 16),
                                  _buildSettlementCard(),
                                ],
                                if (_advance!.notes != null &&
                                    _advance!.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _buildNotesCard(),
                                ],
                                const SizedBox(height: 24),
                                _buildActionButtons(isAdmin),
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderBanner(bool isAdmin) {
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
          // Navigation row
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/cash-advances'),
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
                onTap: _advance == null ? null : _printRequest,
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
                onTap: _loadAdvance,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                ),
              ),
              if (_advance != null && _advance!.status == CashAdvanceStatus.draft.name) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _deleteAdvance,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Title row
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _advance?.requestNumber ?? 'Cash Advance Request',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Review request details and approval status.',
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

  Future<void> _printRequest() async {
    final advance = _advance;
    if (advance == null) return;
    final bytes = await CashAdvancePdfService().buildPdf(advance);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }


  Widget _buildStatusCard() {
    final status = _advance!.statusEnum;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(status),
                size: 32,
                color: status.color,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.displayName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: status.color,
                    ),
                  ),
                  Text(
                    _getStatusDescription(status),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(_advance!.requestedAmount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                if (_advance!.requiresActionNo)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Action No. Required',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(CashAdvanceStatus status) {
    switch (status) {
      case CashAdvanceStatus.draft:
        return Icons.edit_note;
      case CashAdvanceStatus.submitted:
        return Icons.pending_actions;
      case CashAdvanceStatus.approved:
        return Icons.thumb_up;
      case CashAdvanceStatus.disbursed:
        return Icons.payments;
      case CashAdvanceStatus.settled:
        return Icons.check_circle;
      case CashAdvanceStatus.rejected:
        return Icons.cancel;
      case CashAdvanceStatus.cancelled:
        return Icons.block;
    }
  }

  String _getStatusDescription(CashAdvanceStatus status) {
    switch (status) {
      case CashAdvanceStatus.draft:
        return 'This request is in draft and can be edited';
      case CashAdvanceStatus.submitted:
        return 'Waiting for manager approval';
      case CashAdvanceStatus.approved:
        return 'Approved and ready for disbursement';
      case CashAdvanceStatus.disbursed:
        return 'Funds have been disbursed';
      case CashAdvanceStatus.settled:
        return 'Settlement has been completed';
      case CashAdvanceStatus.rejected:
        return 'Request was rejected';
      case CashAdvanceStatus.cancelled:
        return 'Request was cancelled';
    }
  }

  Widget _buildDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Request Number', _advance!.requestNumber),
            _buildDetailRow('Purpose', _advance!.purpose),
            _buildDetailRow(
              'Request Date',
              _dateFormat.format(_advance!.requestDate),
            ),
            if (_advance!.requiredByDate != null)
              _buildDetailRow(
                'Required By',
                _dateFormat.format(_advance!.requiredByDate!),
              ),
            _buildDetailRow(
              'Requested Amount',
              _currencyFormat.format(_advance!.requestedAmount),
            ),
            if (_advance!.actionNo != null)
              _buildDetailRow('Action No.', _advance!.actionNo!),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard() {
    final items = _advance!.items;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.quantity} x ${_currencyFormat.format(item.unitPrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _currencyFormat.format(item.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Total: ${_currencyFormat.format(items.fold<double>(0, (sum, item) => sum + item.total))}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequesterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Requester Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Name', _advance!.requesterName),
            _buildDetailRow('Department', _advance!.department),
            if (_advance!.idNo != null && _advance!.idNo!.isNotEmpty)
              _buildDetailRow('ID No.', _advance!.idNo!),
            if (_advance!.companyName != null &&
                _advance!.companyName!.isNotEmpty)
              _buildDetailRow('Company', _advance!.companyName!),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Timeline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Created',
              _dateTimeFormat.format(_advance!.createdAt),
              Icons.add_circle,
              Colors.grey,
              true,
            ),
            if (_advance!.submittedAt != null)
              _buildTimelineItem(
                'Submitted',
                _dateTimeFormat.format(_advance!.submittedAt!),
                Icons.send,
                Colors.orange,
                _advance!.approvedAt != null || _advance!.status == 'rejected',
              ),
            if (_advance!.approvedAt != null)
              _buildTimelineItem(
                'Approved by ${_advance!.approvedBy ?? ""}',
                _dateTimeFormat.format(_advance!.approvedAt!),
                Icons.check_circle,
                Colors.green,
                _advance!.disbursedAt != null,
              ),
            if (_advance!.status == 'rejected' &&
                _advance!.rejectionReason != null)
              _buildTimelineItem(
                'Rejected: ${_advance!.rejectionReason}',
                '',
                Icons.cancel,
                Colors.red,
                false,
              ),
            if (_advance!.disbursedAt != null)
              _buildTimelineItem(
                'Disbursed by ${_advance!.disbursedBy ?? ""}',
                _dateTimeFormat.format(_advance!.disbursedAt!),
                Icons.payments,
                Colors.blue,
                _advance!.settledAt != null,
              ),
            if (_advance!.settledAt != null)
              _buildTimelineItem(
                'Settled',
                _dateTimeFormat.format(_advance!.settledAt!),
                Icons.done_all,
                Colors.purple,
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool showLine,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                SizedBox(height: showLine ? 24 : 0),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisbursementCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Disbursement Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Amount Disbursed',
              _currencyFormat.format(_advance!.disbursedAmount),
            ),
            _buildDetailRow(
              'Payment Method',
              _advance!.paymentMethod?.paymentMethodDisplayName ?? 'N/A',
            ),
            if (_advance!.referenceNumber != null &&
                _advance!.referenceNumber!.isNotEmpty)
              _buildDetailRow('Reference No.', _advance!.referenceNumber!),
            if (_advance!.disbursedBy != null)
              _buildDetailRow('Disbursed By', _advance!.disbursedBy!),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedPRCard() {
    return Card(
      color: Colors.teal.shade50,
      child: InkWell(
        onTap: () => context.push(
          '/purchase-requisitions/${_advance!.purchaseRequisitionId}',
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.teal[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked Purchase Requisition',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _advance!.purchaseRequisitionId!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.teal[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettlementCard() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Settlement Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_advance!.settledAmount != null)
              _buildDetailRow(
                'Settled Amount',
                _currencyFormat.format(_advance!.settledAmount),
              ),
            if (_advance!.returnedAmount != null &&
                _advance!.returnedAmount! > 0)
              _buildDetailRow(
                'Returned Amount',
                _currencyFormat.format(_advance!.returnedAmount),
              ),
            _buildDetailRow('Settlement ID', _advance!.settlementId!),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              _advance!.notes!,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  Widget _buildActionButtons(bool isAdmin) {
    final status = _advance!.statusEnum;
    final List<Widget> buttons = [];

    if (status == CashAdvanceStatus.draft) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => context.push('/cash-advances/${_advance!.id}/edit'),
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
          onPressed: _submitAdvance,
          icon: const Icon(Icons.send),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (status == CashAdvanceStatus.submitted && isAdmin) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _approveAdvance,
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
          onPressed: _rejectAdvance,
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (status == CashAdvanceStatus.approved && isAdmin) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: _disburseAdvance,
          icon: const Icon(Icons.payments),
          label: const Text('Disburse'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    if (status == CashAdvanceStatus.disbursed) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () {
            final advanceId = _advance?.id;
            if (advanceId == null) return;
            final prId = _advance?.purchaseRequisitionId;
            final uri = prId != null
                ? '/reports/new/advance-settlement?cashAdvanceId=$advanceId&purchaseRequisitionId=$prId'
                : '/reports/new/advance-settlement?cashAdvanceId=$advanceId';
            context.push(uri);
          },
          icon: const Icon(Icons.receipt_long),
          label: const Text('Create Settlement'),
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

  Future<void> _refreshProviderCache() async {
    if (!mounted) return;
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
}
