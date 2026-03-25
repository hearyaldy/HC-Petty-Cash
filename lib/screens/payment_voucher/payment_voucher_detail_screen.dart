import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_voucher_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/payment_voucher.dart';
import '../../services/payment_voucher_pdf_export_service.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class PaymentVoucherDetailScreen extends StatefulWidget {
  final String voucherId;

  const PaymentVoucherDetailScreen({super.key, required this.voucherId});

  @override
  State<PaymentVoucherDetailScreen> createState() =>
      _PaymentVoucherDetailScreenState();
}

class _PaymentVoucherDetailScreenState
    extends State<PaymentVoucherDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVoucher();
    });
  }

  Future<void> _loadVoucher() async {
    final provider = context.read<PaymentVoucherProvider>();
    // If voucher is already in list, no need to reload all
    if (provider.getVoucherById(widget.voucherId) == null) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.canApprove()) {
        await provider.loadVouchers();
      } else {
        final user = authProvider.currentUser;
        if (user != null) await provider.loadVouchersByUser(user.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PaymentVoucherProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final voucher = provider.getVoucherById(widget.voucherId);

        if (voucher == null) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Voucher not found',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/payment-vouchers'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Back to Vouchers'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final authProvider = context.read<AuthProvider>();
        final canApprove = authProvider.canApprove();
        final isAdmin = authProvider.canManageUsers();

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: ResponsiveContainer(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(voucher, canApprove, isAdmin, provider),
                    const SizedBox(height: 8),
                    _buildPaymentDetailsCard(voucher),
                    const SizedBox(height: 12),
                    if (voucher.approvedByName != null ||
                        voucher.paidAt != null)
                      _buildApprovalCard(voucher),
                    if (voucher.rejectionReason != null)
                      _buildRejectionCard(voucher),
                    const SizedBox(height: 12),
                    _buildStatusTimeline(voucher),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    PaymentVoucher voucher,
    bool canApprove,
    bool isAdmin,
    PaymentVoucherProvider provider,
  ) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Vouchers',
                onPressed: () => context.go('/payment-vouchers'),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.print_outlined,
                    tooltip: 'Print',
                    onPressed: () async {
                      final service = PaymentVoucherPdfExportService();
                      try {
                        await service.printVoucher(voucher);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Print failed: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Admin Hub',
                    onPressed: () => context.go('/admin-hub'),
                  ),
                  const SizedBox(width: 8),
                  _buildPopupMenu(voucher, canApprove, isAdmin, provider),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Voucher number & status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.voucherNumber,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      voucher.recipients.isEmpty
                          ? '—'
                          : voucher.recipients.length == 1
                              ? voucher.recipients.first.name
                              : '${voucher.recipients.first.name} (+${voucher.recipients.length - 1} more)',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(
                          voucher.department,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.calendar_today,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(voucher.voucherDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(voucher.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenu(
    PaymentVoucher voucher,
    bool canApprove,
    bool isAdmin,
    PaymentVoucherProvider provider,
  ) {
    final items = <PopupMenuEntry<String>>[];

    if (voucher.status == 'draft') {
      items.addAll([
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        const PopupMenuItem(
          value: 'submit',
          child: Row(children: [
            Icon(Icons.send_outlined, size: 18, color: Colors.orange),
            SizedBox(width: 8),
            Text('Submit for Approval',
                style: TextStyle(color: Colors.orange)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outlined, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ]);
    }

    if (voucher.status == 'submitted' && canApprove) {
      items.addAll([
        const PopupMenuItem(
          value: 'approve',
          child: Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve', style: TextStyle(color: Colors.green)),
          ]),
        ),
        const PopupMenuItem(
          value: 'reject',
          child: Row(children: [
            Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ]);
    }

    if (voucher.status == 'approved' && canApprove) {
      items.add(
        const PopupMenuItem(
          value: 'mark_paid',
          child: Row(children: [
            Icon(Icons.paid_outlined, size: 18, color: Colors.blue),
            SizedBox(width: 8),
            Text('Mark as Paid', style: TextStyle(color: Colors.blue)),
          ]),
        ),
      );
    }

    if (isAdmin && voucher.status != 'draft') {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem(
          value: 'revert_draft',
          child: Row(children: [
            Icon(Icons.undo_outlined, size: 18, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Revert to Draft',
                style: TextStyle(color: Colors.deepOrange)),
          ]),
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildHeaderActionButton(
      icon: Icons.more_vert,
      tooltip: 'Actions',
      onPressed: () => _showActionsMenu(voucher, canApprove, isAdmin, provider),
    );
  }

  void _showActionsMenu(
    PaymentVoucher voucher,
    bool canApprove,
    bool isAdmin,
    PaymentVoucherProvider provider,
  ) {
    final items = <PopupMenuEntry<String>>[];

    if (voucher.status == 'draft') {
      items.addAll([
        const PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('Edit'),
          ]),
        ),
        const PopupMenuItem(
          value: 'submit',
          child: Row(children: [
            Icon(Icons.send_outlined, size: 18, color: Colors.orange),
            SizedBox(width: 8),
            Text('Submit for Approval',
                style: TextStyle(color: Colors.orange)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.delete_outlined, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ]);
    }

    if (voucher.status == 'submitted' && canApprove) {
      items.addAll([
        const PopupMenuItem(
          value: 'approve',
          child: Row(children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
            SizedBox(width: 8),
            Text('Approve', style: TextStyle(color: Colors.green)),
          ]),
        ),
        const PopupMenuItem(
          value: 'reject',
          child: Row(children: [
            Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Reject', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ]);
    }

    if (voucher.status == 'approved' && canApprove) {
      items.add(
        const PopupMenuItem(
          value: 'mark_paid',
          child: Row(children: [
            Icon(Icons.paid_outlined, size: 18, color: Colors.blue),
            SizedBox(width: 8),
            Text('Mark as Paid', style: TextStyle(color: Colors.blue)),
          ]),
        ),
      );
    }

    if (isAdmin && voucher.status != 'draft') {
      if (items.isNotEmpty) items.add(const PopupMenuDivider());
      items.add(
        const PopupMenuItem(
          value: 'revert_draft',
          child: Row(children: [
            Icon(Icons.undo_outlined, size: 18, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Revert to Draft',
                style: TextStyle(color: Colors.deepOrange)),
          ]),
        ),
      );
    }

    if (items.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + renderBox.size.width - 200,
        position.dy + 80,
        position.dx + renderBox.size.width,
        0,
      ),
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ).then((value) {
      if (value == null || !mounted) return;
      _handleAction(value, voucher, provider);
    });
  }

  void _handleAction(
    String action,
    PaymentVoucher voucher,
    PaymentVoucherProvider provider,
  ) {
    switch (action) {
      case 'edit':
        context.push('/payment-vouchers/${voucher.id}/edit');
        break;
      case 'submit':
        _confirmSubmit(voucher, provider);
        break;
      case 'approve':
        _confirmApprove(voucher, provider);
        break;
      case 'reject':
        _showRejectDialog(voucher, provider);
        break;
      case 'mark_paid':
        _confirmMarkAsPaid(voucher, provider);
        break;
      case 'delete':
        _confirmDelete(voucher, provider);
        break;
      case 'revert_draft':
        _confirmRevertToDraft(voucher, provider);
        break;
    }
  }

  void _confirmRevertToDraft(
      PaymentVoucher voucher, PaymentVoucherProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.undo_outlined, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Revert to Draft'),
          ],
        ),
        content: Text(
            'Revert ${voucher.voucherNumber} back to draft? This will clear any approval data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await provider.revertToDraft(voucher.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Voucher reverted to draft'
                        : 'Failed to revert voucher'),
                    backgroundColor:
                        success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revert to Draft'),
          ),
        ],
      ),
    );
  }

  void _confirmSubmit(PaymentVoucher voucher, PaymentVoucherProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Voucher'),
        content: const Text(
            'Submit this payment voucher for approval? You will not be able to edit it after submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success =
                  await provider.submitVoucher(voucher.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Voucher submitted for approval'
                        : 'Failed to submit voucher'),
                    backgroundColor:
                        success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _confirmApprove(
      PaymentVoucher voucher, PaymentVoucherProvider provider) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Approve Voucher'),
        content: Text(
            'Approve payment voucher ${voucher.voucherNumber} for ${AppConstants.currencySymbol}${NumberFormat('#,##0.00').format(voucher.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.approveVoucher(
                voucher.id,
                user?.id ?? '',
                user?.name ?? '',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Voucher approved successfully'
                        : 'Failed to approve voucher'),
                    backgroundColor:
                        success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
      PaymentVoucher voucher, PaymentVoucherProvider provider) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Voucher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final success = await provider.rejectVoucher(
                voucher.id,
                reasonController.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Voucher rejected'
                        : 'Failed to reject voucher'),
                    backgroundColor:
                        success ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsPaid(
      PaymentVoucher voucher, PaymentVoucherProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark as Paid'),
        content: Text(
            'Confirm payment of ${AppConstants.currencySymbol}${NumberFormat('#,##0.00').format(voucher.amount)} to ${voucher.payTo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.markAsPaid(voucher.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? 'Voucher marked as paid'
                        : 'Failed to update status'),
                    backgroundColor:
                        success ? Colors.blue : Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      PaymentVoucher voucher, PaymentVoucherProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Voucher'),
          ],
        ),
        content: Text(
            'Permanently delete voucher ${voucher.voucherNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteVoucher(voucher.id);
              if (mounted) {
                if (success) {
                  context.go('/payment-vouchers');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete voucher'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'draft':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = 'Draft';
        icon = Icons.edit_note;
        break;
      case 'submitted':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
        label = 'Submitted';
        icon = Icons.schedule;
        break;
      case 'approved':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        label = 'Approved';
        icon = Icons.check_circle_outline;
        break;
      case 'paid':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade800;
        label = 'Paid';
        icon = Icons.paid_outlined;
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        label = 'Rejected';
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = status;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard(PaymentVoucher voucher) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    String paymentMethodLabel;
    switch (voucher.paymentMethod) {
      case 'bank_transfer':
        paymentMethodLabel = 'Bank Transfer';
        break;
      case 'cheque':
        paymentMethodLabel = 'Cheque';
        break;
      default:
        paymentMethodLabel = 'Cash';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.payment_outlined,
                      color: Colors.deepPurple.shade400, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Payment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Amount - prominent display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.deepPurple.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.deepPurple.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppConstants.currencySymbol} ${currencyFormat.format(voucher.amount)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Recipients section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.people_outline, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipients',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (voucher.recipients.isEmpty)
                          const Text('—', style: TextStyle(fontSize: 14))
                        else
                          ...voucher.recipients.map((r) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.person_outline,
                                        size: 16,
                                        color: Colors.grey[500]),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (r.title.isNotEmpty)
                                            Text(
                                              r.title,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                  Icons.credit_card_outlined, 'Payment Method', paymentMethodLabel),

              if (voucher.paymentMethod == 'bank_transfer') ...[
                if (voucher.bankName != null && voucher.bankName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildDetailRow(Icons.account_balance_outlined,
                        'Bank Name', voucher.bankName!),
                  ),
                if (voucher.accountNumber != null &&
                    voucher.accountNumber!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _buildDetailRow(Icons.numbers_outlined,
                        'Account Number', voucher.accountNumber!),
                  ),
              ],

              if (voucher.paymentMethod == 'cheque' &&
                  voucher.chequeNumber != null &&
                  voucher.chequeNumber!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildDetailRow(Icons.receipt_outlined,
                      'Cheque Number', voucher.chequeNumber!),
                ),

              const SizedBox(height: 12),
              _buildDetailRow(Icons.description_outlined, 'Purpose',
                  voucher.purpose),

              if (voucher.notes != null && voucher.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                    Icons.notes_outlined, 'Notes', voucher.notes!),
              ],

              const SizedBox(height: 12),
              _buildDetailRow(
                  Icons.person_add_outlined, 'Created By', voucher.createdByName),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalCard(PaymentVoucher voucher) {
    final screenPadding = ResponsiveHelper.getScreenPadding(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined,
                      color: Colors.green.shade400, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Approval Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (voucher.approvedByName != null)
                _buildDetailRow(Icons.how_to_reg_outlined, 'Approved By',
                    voucher.approvedByName!),
              if (voucher.paidAt != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(Icons.paid_outlined, 'Paid On',
                    dateFormat.format(voucher.paidAt!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectionCard(PaymentVoucher voucher) {
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    return Padding(
      padding: EdgeInsets.only(
        left: screenPadding.left,
        right: screenPadding.right,
        top: 12,
      ),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.red.shade50,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rejection Reason',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voucher.rejectionReason!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(PaymentVoucher voucher) {
    final screenPadding = ResponsiveHelper.getScreenPadding(context);
    final allStatuses = ['draft', 'submitted', 'approved', 'paid'];

    // Determine active index
    int activeIndex = allStatuses.indexOf(voucher.status);
    if (voucher.status == 'rejected') activeIndex = 1; // stops at submitted

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenPadding.left),
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.timeline,
                      color: Colors.deepPurple.shade400, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Status Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: List.generate(allStatuses.length * 2 - 1, (i) {
                  if (i.isOdd) {
                    // Connector line
                    final stepIndex = i ~/ 2;
                    final isCompleted = stepIndex < activeIndex;
                    return Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted
                            ? Colors.deepPurple
                            : Colors.grey.shade200,
                      ),
                    );
                  }

                  final stepIndex = i ~/ 2;
                  final isCompleted = stepIndex <= activeIndex &&
                      voucher.status != 'rejected';
                  final isCurrent = stepIndex == activeIndex;
                  final isRejected =
                      voucher.status == 'rejected' && stepIndex == 1;

                  final statusLabels = ['Draft', 'Submitted', 'Approved', 'Paid'];

                  Color dotColor;
                  IconData dotIcon;
                  if (isRejected) {
                    dotColor = Colors.red;
                    dotIcon = Icons.cancel;
                  } else if (isCompleted) {
                    dotColor = Colors.deepPurple;
                    dotIcon = Icons.check_circle;
                  } else {
                    dotColor = Colors.grey.shade300;
                    dotIcon = Icons.radio_button_unchecked;
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(dotIcon, color: dotColor, size: isCurrent ? 28 : 22),
                      const SizedBox(height: 4),
                      Text(
                        statusLabels[stepIndex],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCompleted || isCurrent
                              ? Colors.deepPurple
                              : Colors.grey,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
