import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../../models/purchase_requisition.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/edit_purchase_requisition_dialog.dart';

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

class PurchaseRequisitionsScreen extends StatefulWidget {
  const PurchaseRequisitionsScreen({super.key});

  @override
  State<PurchaseRequisitionsScreen> createState() =>
      _PurchaseRequisitionsScreenState();
}

class _PurchaseRequisitionsScreenState
    extends State<PurchaseRequisitionsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedStatus;

  final List<String> _statusOptions = [
    'all',
    'draft',
    'submitted',
    'approved',
    'rejected',
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.grey;
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'closed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createNewRequisition() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not found')));
      }
      return;
    }

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditPurchaseRequisitionDialog(
        requesterId: user.id,
        requesterName: user.name,
      ),
    );

    if (result != null && mounted) {
      try {
        final requisitionNumber =
            _firestoreService.generatePurchaseRequisitionNumber();
        final newRequisition = PurchaseRequisition(
          id: const Uuid().v4(),
          requisitionNumber: requisitionNumber,
          requisitionDate: result['requisitionDate'] as DateTime,
          requestedBy: result['requestedBy'] as String,
          idNo: result['idNo'] as String,
          chargeToDepartment: result['chargeToDepartment'] as String,
          notes: result['notes'] as String?,
          createdAt: DateTime.now(),
        );

        await _firestoreService.savePurchaseRequisition(newRequisition);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase requisition created successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to detail screen
          context.push('/purchase-requisitions/${newRequisition.id}');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating requisition: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _approveRequisition(PurchaseRequisition requisition) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    String? actionNo;
    // Check if any item exceeds 20,000 Baht threshold
    if (requisition.totalAmount > 20000) {
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
                  'This requisition exceeds 20,000 Baht. Please enter the Action No.:',
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.of(context).pop(controller.text.trim());
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve'),
              ),
            ],
          );
        },
      );

      if (actionNo == null) return; // User cancelled
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Requisition'),
          content: Text(
            'Are you sure you want to approve "${requisition.requisitionNumber}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Approve'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    try {
      await _firestoreService.approvePurchaseRequisition(
        requisition.id,
        user.name,
        actionNo: actionNo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requisition approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving requisition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequisition(PurchaseRequisition requisition) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Requisition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject "${requisition.requisitionNumber}"?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await _firestoreService.rejectPurchaseRequisition(requisition.id, reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requisition rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting requisition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revertToDraft(PurchaseRequisition requisition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to Draft'),
        content: Text(
          'Are you sure you want to revert "${requisition.requisitionNumber}" to draft status?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestoreService.revertPurchaseRequisitionToDraft(requisition.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requisition reverted to draft'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reverting requisition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRequisition(PurchaseRequisition requisition) async {
    if (!['draft', 'submitted'].contains(requisition.status)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You can only delete draft or submitted requisitions',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Requisition'),
        content: Text(
          'Are you sure you want to delete "${requisition.requisitionNumber}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deletePurchaseRequisition(requisition.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Requisition "${requisition.requisitionNumber}" deleted successfully',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting requisition: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isAdmin = authProvider.canManageUsers();

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Requisitions Management'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade400, Colors.purple.shade600],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => context.go('/dashboard'),
            tooltip: 'Home',
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.go('/admin'),
              tooltip: 'Admin',
            ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: _buildDesktopLayout(context, isAdmin), // Using desktop layout for all screen sizes for simplicity
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRequisition,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Requisition'),
      ),
    );
  }

  // Removed the mobile and tablet layouts since we're using a single layout for all screen sizes

  Widget _buildDesktopLayout(BuildContext context, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(context),
          const SizedBox(height: 16),
          // Top section with stats and summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildStatCards(context),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: _buildSummaryBar(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildRequisitionList(context, isAdmin),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade600, Colors.purple.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Purchase Requisitions',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your purchase requests',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track, approve, and manage purchase requisitions',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context) {
    return StreamBuilder<List<PurchaseRequisition>>(
      stream: _firestoreService.purchaseRequisitionsStream(),
      builder: (context, snapshot) {
        final requisitions = snapshot.data ?? [];

        final draftCount = requisitions.where((r) => r.status == 'draft').length;
        final pendingCount = requisitions.where((r) => r.status == 'submitted').length;
        final approvedCount = requisitions.where((r) => r.status == 'approved').length;
        final totalAmount = requisitions.fold<double>(
          0.0,
          (sum, r) => sum + r.totalAmount,
        );

        final stats = [
          _StatData(
            title: 'Total Requisitions',
            value: requisitions.length.toString(),
            icon: Icons.shopping_cart,
            gradient: [Colors.purple.shade400, Colors.purple.shade600],
            lightColor: Colors.purple.shade50,
          ),
          _StatData(
            title: 'Draft Requisitions',
            value: draftCount.toString(),
            icon: Icons.edit_document,
            gradient: [Colors.orange.shade400, Colors.orange.shade600],
            lightColor: Colors.orange.shade50,
          ),
          _StatData(
            title: 'Pending Approval',
            value: pendingCount.toString(),
            icon: Icons.pending_actions,
            gradient: [Colors.blue.shade400, Colors.blue.shade600],
            lightColor: Colors.blue.shade50,
          ),
          _StatData(
            title: 'Approved',
            value: approvedCount.toString(),
            icon: Icons.check_circle,
            gradient: [Colors.green.shade400, Colors.green.shade600],
            lightColor: Colors.green.shade50,
          ),
        ];

        return Column(
          children: [
            for(int i = 0; i < stats.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildModernStatCard(context, stats[i]),
                    ),
                    if(i+1 < stats.length) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildModernStatCard(context, stats[i+1]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildModernStatCard(BuildContext context, _StatData stat) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: stat.gradient.map((c) => c.withOpacity(0.1)).toList(),
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: stat.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(stat.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stat.value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: stat.gradient[1],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stat.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            children: [
              Icon(Icons.filter_list, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Filter by Status',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    prefixIcon: Icon(
                      Icons.label,
                      color: Colors.purple.shade600,
                    ),
                  ),
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(
                        status == 'all' ? 'All Statuses' : status.toUpperCase(),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return StreamBuilder<List<PurchaseRequisition>>(
      stream: _firestoreService.purchaseRequisitionsStream(),
      builder: (context, snapshot) {
        final requisitions = snapshot.data ?? [];
        final currencyFormat = NumberFormat('#,##0.00', 'en_US');

        final draftCount =
            requisitions.where((r) => r.status == 'draft').length;
        final pendingCount =
            requisitions.where((r) => r.status == 'submitted').length;
        final approvedCount =
            requisitions.where((r) => r.status == 'approved').length;
        final totalAmount = requisitions.fold<double>(
          0.0,
          (sum, r) => sum + r.totalAmount,
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple.shade400, Colors.purple.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Financial Summary',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFinancialSummaryItem(
                          'Draft',
                          draftCount.toString(),
                          Icons.edit_document,
                          Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: _buildFinancialSummaryItem(
                          'Pending',
                          pendingCount.toString(),
                          Icons.pending,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFinancialSummaryItem(
                          'Approved',
                          approvedCount.toString(),
                          Icons.check_circle,
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildFinancialSummaryItem(
                          'Total Value',
                          '฿${currencyFormat.format(totalAmount)}',
                          Icons.account_balance,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialSummaryItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequisitionList(BuildContext context, bool isAdmin) {
    return StreamBuilder<List<PurchaseRequisition>>(
      stream: _firestoreService.purchaseRequisitionsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var requisitions = snapshot.data!;

        // Apply status filter
        if (_selectedStatus != null && _selectedStatus != 'all') {
          requisitions = requisitions
              .where((req) => req.status == _selectedStatus)
              .toList();
        }

        if (requisitions.isEmpty) {
          return _buildEmptyState();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 16, bottom: 16),
            itemCount: requisitions.length,
            itemBuilder: (context, index) {
              final requisition = requisitions[index];
              return _buildRequisitionCard(requisition, isAdmin);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(48),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No purchase requisitions yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first requisition to get started!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequisitionCard(PurchaseRequisition requisition, bool isAdmin) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');
    final statusColor = _getStatusColor(requisition.status);

    IconData statusIcon;
    switch (requisition.status) {
      case 'approved':
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusIcon = Icons.pending;
        break;
      default:
        statusIcon = Icons.edit_document;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: Colors.white),
        ),
        title: Text(
          requisition.requisitionNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${requisition.requestedBy} • ${dateFormat.format(requisition.requisitionDate)}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              requisition.chargeToDepartment,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '฿${currencyFormat.format(requisition.totalAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (String choice) {
                if (choice == 'view') {
                  context.push('/purchase-requisitions/${requisition.id}');
                } else if (choice == 'approve' && isAdmin) {
                  _approveRequisition(requisition);
                } else if (choice == 'reject' && isAdmin) {
                  _rejectRequisition(requisition);
                } else if (choice == 'revert' && isAdmin) {
                  _revertToDraft(requisition);
                } else if (choice == 'delete') {
                  _deleteRequisition(requisition);
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 20),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                if (isAdmin && requisition.status == 'submitted') ...[
                  const PopupMenuItem<String>(
                    value: 'approve',
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 20, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Approve',
                          style: TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'reject',
                    child: Row(
                      children: [
                        Icon(Icons.close, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Reject',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isAdmin && ['approved', 'rejected'].contains(requisition.status)) ...[
                  const PopupMenuItem<String>(
                    value: 'revert',
                    child: Row(
                      children: [
                        Icon(Icons.undo, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Revert to Draft',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
                if (['draft', 'submitted'].contains(requisition.status)) ...[
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () => context.push('/purchase-requisitions/${requisition.id}'),
      ),
    );
  }
}
