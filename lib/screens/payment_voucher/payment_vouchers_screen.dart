import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/payment_voucher_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/payment_voucher.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/constants.dart';

class PaymentVouchersScreen extends StatefulWidget {
  const PaymentVouchersScreen({super.key});

  @override
  State<PaymentVouchersScreen> createState() => _PaymentVouchersScreenState();
}

class _PaymentVouchersScreenState extends State<PaymentVouchersScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVouchers();
    });
  }

  Future<void> _loadVouchers() async {
    final provider = context.read<PaymentVoucherProvider>();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      if (authProvider.canApprove()) {
        await provider.loadVouchers();
      } else {
        await provider.loadVouchersByUser(user.id);
      }
    }
  }

  List<PaymentVoucher> _getFilteredVouchers(List<PaymentVoucher> vouchers) {
    switch (_selectedFilter) {
      case 'draft':
        return vouchers.where((v) => v.status == 'draft').toList();
      case 'submitted':
        return vouchers.where((v) => v.status == 'submitted').toList();
      case 'approved':
        return vouchers.where((v) => v.status == 'approved').toList();
      case 'paid':
        return vouchers.where((v) => v.status == 'paid').toList();
      case 'rejected':
        return vouchers.where((v) => v.status == 'rejected').toList();
      default:
        return vouchers;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Consumer<PaymentVoucherProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final filteredVouchers =
                _getFilteredVouchers(provider.vouchers);

            return ResponsiveContainer(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildHeader(provider),
                  ),
                  _buildFilterChips(provider),
                  Expanded(
                    child: filteredVouchers.isEmpty
                        ? _buildEmptyState()
                        : _buildVoucherList(filteredVouchers),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(PaymentVoucherProvider provider) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Container(
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
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Finance Dashboard',
                onPressed: () => context.go('/finance-dashboard'),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.refresh,
                    tooltip: 'Refresh',
                    onPressed: _loadVouchers,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.add_circle_outline,
                    tooltip: 'New Voucher',
                    onPressed: () => context.push('/payment-vouchers/new'),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Vouchers',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${provider.vouchers.length} voucher${provider.vouchers.length == 1 ? '' : 's'} total',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid: ${AppConstants.currencySymbol}${NumberFormat('#,##0.00').format(provider.totalPaidAmount)}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long,
                  size: isMobile ? 36 : 48,
                  color: Colors.white,
                ),
              ),
            ],
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

  Widget _buildFilterChips(PaymentVoucherProvider provider) {
    final filters = [
      {'key': 'all', 'label': 'All', 'count': provider.vouchers.length},
      {'key': 'draft', 'label': 'Draft', 'count': provider.draftVouchers.length},
      {
        'key': 'submitted',
        'label': 'Submitted',
        'count': provider.submittedVouchers.length,
      },
      {
        'key': 'approved',
        'label': 'Approved',
        'count': provider.approvedVouchers.length,
      },
      {'key': 'paid', 'label': 'Paid', 'count': provider.paidVouchers.length},
      {
        'key': 'rejected',
        'label': 'Rejected',
        'count': provider.rejectedVouchers.length,
      },
    ];

    final horizontalPadding = ResponsiveHelper.getScreenPadding(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding.left,
        vertical: 8,
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text('${filter['label']} (${filter['count']})'),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
              },
              selectedColor: Colors.deepPurple.shade100,
              checkmarkColor: Colors.deepPurple.shade700,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.deepPurple.shade700
                    : Colors.grey[700],
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No payment vouchers found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first voucher',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/payment-vouchers/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Voucher'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(PaymentVoucher voucher, PaymentVoucherProvider provider) {
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
          'Permanently delete ${voucher.voucherNumber}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteVoucher(voucher.id);
              if (mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete voucher'),
                    backgroundColor: Colors.red,
                  ),
                );
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

  Widget _buildVoucherList(List<PaymentVoucher> vouchers) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final screenPadding = ResponsiveHelper.getScreenPadding(context);

    return Consumer<PaymentVoucherProvider>(
      builder: (context, provider, _) => ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: screenPadding.left,
          vertical: 8,
        ),
        itemCount: vouchers.length,
        itemBuilder: (context, index) {
          final voucher = vouchers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            elevation: 1,
            shadowColor: Colors.black12,
            child: InkWell(
              onTap: () => context.push('/payment-vouchers/${voucher.id}'),
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
                                voucher.voucherNumber,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                voucher.payTo,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildStatusChip(voucher.status),
                            if (voucher.status == 'draft') ...[
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: Colors.grey[600],
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    context.push(
                                        '/payment-vouchers/${voucher.id}/edit');
                                  } else if (value == 'delete') {
                                    _confirmDelete(voucher, provider);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outlined,
                                          size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: Colors.red)),
                                    ]),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    voucher.purpose,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(voucher.voucherDate),
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.business, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          voucher.department,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${AppConstants.currencySymbol}${currencyFormat.format(voucher.amount)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;
    String label;

    switch (status) {
      case 'draft':
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = 'Draft';
        break;
      case 'submitted':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        label = 'Submitted';
        break;
      case 'approved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        label = 'Approved';
        break;
      case 'paid':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade700;
        label = 'Paid';
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        label = 'Rejected';
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
