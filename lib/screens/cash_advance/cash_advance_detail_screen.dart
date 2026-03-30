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

  // ── Item management ──────────────────────────────────────────────────────

  Future<void> _updateItems(List<CashAdvanceItem> newItems) async {
    final total = newItems.fold<double>(0, (sum, i) => sum + i.total);
    final updated = _advance!.copyWith(
      items: newItems,
      requestedAmount: total,
      updatedAt: DateTime.now(),
    );
    final success =
        await context.read<CashAdvanceProvider>().updateAdvance(updated);
    if (success && mounted) {
      setState(() => _advance = updated);
    }
  }

  Future<void> _showAddItemDialog({
    CashAdvanceItem? existing,
    int? index,
  }) async {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final qtyController =
        TextEditingController(text: existing?.quantity.toString() ?? '1');
    final priceController = TextEditingController(
        text: existing != null
            ? existing.unitPrice.toStringAsFixed(2)
            : '');
    final notesController =
        TextEditingController(text: existing?.notes ?? '');

    final result = await showDialog<CashAdvanceItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Item' : 'Edit Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Unit Price *',
                  border: const OutlineInputBorder(),
                  prefixText: '${AppConstants.currencySymbol} ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () {
              final name = nameController.text.trim();
              final qty = int.tryParse(qtyController.text.trim()) ?? 0;
              final price =
                  double.tryParse(priceController.text.trim()) ?? 0;
              if (name.isEmpty || qty <= 0 || price <= 0) return;
              Navigator.pop(
                context,
                CashAdvanceItem(
                  name: name,
                  quantity: qty,
                  unitPrice: price,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                ),
              );
            },
            child: Text(
              existing == null ? 'Add' : 'Save',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    final newItems = List<CashAdvanceItem>.from(_advance!.items);
    if (index != null && index >= 0 && index < newItems.length) {
      newItems[index] = result;
    } else {
      newItems.add(result);
    }
    await _updateItems(newItems);
  }

  Future<void> _removeItem(int index) async {
    final newItems = List<CashAdvanceItem>.from(_advance!.items);
    newItems.removeAt(index);
    await _updateItems(newItems);
  }

  // ── Workflow actions ──────────────────────────────────────────────────────

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
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
                        value: 'bankTransfer',
                        child: Text('Bank Transfer')),
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
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

  Future<void> _revertToDraft() async {
    if (_advance == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to Draft'),
        content: const Text(
          'This will revert the request back to draft so you can edit it. '
          'It will need to be submitted again for approval.',
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

    if (confirmed != true) return;

    try {
      await _firestoreService.revertCashAdvanceToDraft(_advance!.id);
      await _loadAdvance();
      await _refreshProviderCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reverted to draft'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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

  Future<void> _printRequest() async {
    final advance = _advance;
    if (advance == null) return;
    final bytes = await CashAdvancePdfService().buildPdf(advance);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<void> _refreshProviderCache() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cashAdvanceProvider =
        Provider.of<CashAdvanceProvider>(context, listen: false);
    final isAdmin = authProvider.canApprove();
    final user = authProvider.currentUser;

    if (isAdmin) {
      await cashAdvanceProvider.loadAdvances();
    } else if (user != null) {
      await cashAdvanceProvider.loadAdvancesByUser(user.id);
    }
  }

  void _handleMenuAction(String action, bool isAdmin) {
    switch (action) {
      case 'print':
        _printRequest();
        break;
      case 'edit':
        context.push('/cash-advances/${_advance!.id}/edit');
        break;
      case 'submit':
        _submitAdvance();
        break;
      case 'delete':
        _deleteAdvance();
        break;
      case 'approve':
        _approveAdvance();
        break;
      case 'reject':
        _rejectAdvance();
        break;
      case 'revert_draft':
        _revertToDraft();
        break;
      case 'disburse':
        _disburseAdvance();
        break;
      case 'settle':
        final advanceId = _advance?.id;
        if (advanceId == null) break;
        final prId = _advance?.purchaseRequisitionId;
        final uri = prId != null
            ? '/reports/new/advance-settlement?cashAdvanceId=$advanceId&purchaseRequisitionId=$prId'
            : '/reports/new/advance-settlement?cashAdvanceId=$advanceId';
        context.push(uri);
        break;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.canApprove();
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
                                _buildItemsCard(
                                  isDraft: _advance!.status ==
                                      CashAdvanceStatus.draft.name,
                                ),
                                const SizedBox(height: 16),
                                _buildDetailsCard(),
                                const SizedBox(height: 16),
                                _buildRequesterCard(),
                                if (_advance!.status !=
                                    CashAdvanceStatus.draft.name) ...[
                                  const SizedBox(height: 16),
                                  _buildTimelineCard(),
                                ],
                                if (_advance!.disbursedAmount != null) ...[
                                  const SizedBox(height: 16),
                                  _buildDisbursementCard(),
                                ],
                                if (_advance!.purchaseRequisitionId !=
                                    null) ...[
                                  const SizedBox(height: 16),
                                  _buildLinkedPRCard(),
                                ],
                                if (_advance!.linkedMinutesId != null) ...[
                                  const SizedBox(height: 16),
                                  _buildLinkedMinutesCard(),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeaderBanner(bool isAdmin) {
    final status = _advance!.statusEnum;
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
          // Nav row
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/cash-advances'),
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
                onTap: _loadAdvance,
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
              const SizedBox(width: 8),
              _buildPopupMenu(isAdmin),
            ],
          ),
          const SizedBox(height: 16),
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.request_quote,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _advance!.requestNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _advance!.requesterName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(CashAdvanceStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPopupMenu(bool isAdmin) {
    final status = _advance!.statusEnum;
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(value, isAdmin),
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
          child: Row(children: [
            Icon(Icons.print, size: 20),
            SizedBox(width: 12),
            Text('Print'),
          ]),
        ),
        if (status == CashAdvanceStatus.draft) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Edit Details'),
            ]),
          ),
          const PopupMenuItem(
            value: 'submit',
            child: Row(children: [
              Icon(Icons.send, size: 20, color: Colors.indigo),
              SizedBox(width: 12),
              Text('Submit for Approval'),
            ]),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ]),
          ),
        ],
        if (status == CashAdvanceStatus.submitted ||
            status == CashAdvanceStatus.approved) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'revert_draft',
            child: Row(children: [
              Icon(Icons.undo, size: 20, color: Colors.orange),
              SizedBox(width: 12),
              Text('Revert to Draft',
                  style: TextStyle(color: Colors.orange)),
            ]),
          ),
        ],
        if (status == CashAdvanceStatus.submitted && isAdmin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'approve',
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              SizedBox(width: 12),
              Text('Approve'),
            ]),
          ),
          const PopupMenuItem(
            value: 'reject',
            child: Row(children: [
              Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Reject', style: TextStyle(color: Colors.red)),
            ]),
          ),
        ],
        if (status == CashAdvanceStatus.approved && isAdmin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'disburse',
            child: Row(children: [
              Icon(Icons.payments_outlined, size: 20, color: Colors.green),
              SizedBox(width: 12),
              Text('Disburse Funds'),
            ]),
          ),
        ],
        if (status == CashAdvanceStatus.disbursed) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'settle',
            child: Row(children: [
              Icon(Icons.receipt_long_outlined, size: 20, color: Colors.purple),
              SizedBox(width: 12),
              Text('Create Settlement'),
            ]),
          ),
        ],
      ],
    );
  }

  // ── Status card ───────────────────────────────────────────────────────────

  Widget _buildStatusCard() {
    final status = _advance!.statusEnum;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: status.color,
                    ),
                  ),
                  Text(
                    _getStatusDescription(status),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[700],
                  ),
                ),
                if (_advance!.actionNo != null)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag, size: 12, color: Colors.indigo[700]),
                        const SizedBox(width: 4),
                        Text(
                          _advance!.actionNo!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_advance!.requiresActionNo)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
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
        return 'Add items below to tally the total amount';
      case CashAdvanceStatus.submitted:
        return 'Waiting for approval';
      case CashAdvanceStatus.approved:
        return 'Approved and ready for disbursement';
      case CashAdvanceStatus.disbursed:
        return 'Funds have been disbursed';
      case CashAdvanceStatus.settled:
        return 'Settlement completed';
      case CashAdvanceStatus.rejected:
        return 'Request was rejected';
      case CashAdvanceStatus.cancelled:
        return 'Request was cancelled';
    }
  }

  // ── Items card ────────────────────────────────────────────────────────────

  Widget _buildItemsCard({required bool isDraft}) {
    final items = _advance!.items;
    final total = items.fold<double>(0, (sum, i) => sum + i.total);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const Icon(Icons.list_alt_outlined,
                    size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Items',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isDraft)
                  TextButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.indigo,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Empty state
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.grey[400], size: 20),
                    const SizedBox(width: 12),
                    Text(
                      isDraft
                          ? 'Tap "Add Item" to build your advance list.'
                          : 'No items recorded.',
                      style:
                          TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  // Item rows
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // Item number badge
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantity} × ${_currencyFormat.format(item.unitPrice)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600]),
                                ),
                                if (item.notes != null &&
                                    item.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item.notes!,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500]),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _currencyFormat.format(item.total),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          if (isDraft) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: Colors.blue,
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _showAddItemDialog(
                                  existing: item, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18),
                              color: Colors.red,
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _removeItem(index),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),

                  // Total tally
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calculate_outlined,
                                size: 18, color: Colors.indigo.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Total Requested',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _currencyFormat.format(total),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ── Detail cards ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.receipt_outlined, 'Request Details'),
            const SizedBox(height: 16),
            _buildDetailRow('Request No.', _advance!.requestNumber),
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

  Widget _buildRequesterCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.person_outline, 'Requester'),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.timeline_outlined, 'Timeline'),
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
                _advance!.approvedAt != null ||
                    _advance!.status == 'rejected',
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      elevation: 1,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
                Icons.payments_outlined, 'Disbursement Details',
                color: Colors.green[700]!),
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
              _buildDetailRow(
                  'Reference No.', _advance!.referenceNumber!),
            if (_advance!.disbursedBy != null)
              _buildDetailRow('Disbursed By', _advance!.disbursedBy!),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkedPRCard() {
    return Card(
      elevation: 1,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildLinkedMinutesCard() {
    return Card(
      elevation: 1,
      color: Colors.indigo.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
              Icons.meeting_room_outlined,
              'Meeting Reference',
              color: Colors.indigo[700]!,
            ),
            const SizedBox(height: 16),
            if (_advance!.linkedMinutesLabel != null)
              _buildDetailRow('Minutes', _advance!.linkedMinutesLabel),
            if (_advance!.linkedActionItemNumber != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        'Action Item',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Text(
                            _advance!.linkedActionItemNumber!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ),
                        if (_advance!.linkedActionItemAction != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border:
                                  Border.all(color: Colors.teal.shade200),
                            ),
                            child: Text(
                              _advance!.linkedActionItemAction!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.teal[700]),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_advance!.linkedActionItemTitle != null)
              _buildDetailRow('Title', _advance!.linkedActionItemTitle),
            if (_advance!.linkedActionItemDescription != null &&
                _advance!.linkedActionItemDescription!.isNotEmpty)
              _buildDetailRow(
                  'Description', _advance!.linkedActionItemDescription),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard() {
    return Card(
      elevation: 1,
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(
                Icons.receipt_long_outlined, 'Settlement Details',
                color: Colors.purple[700]!),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(Icons.notes_outlined, 'Notes'),
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

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildCardHeader(IconData icon, String title,
      {Color color = Colors.indigo}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color == Colors.indigo ? Colors.black87 : color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String? value) {
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
              value ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
