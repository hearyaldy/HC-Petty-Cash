import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/purchase_requisition.dart';
import '../../services/firestore_service.dart';
import '../../services/purchase_requisition_pdf_export_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/edit_purchase_requisition_dialog.dart';
import '../../widgets/purchase_requisition_item_dialog.dart';

class PurchaseRequisitionDetailScreen extends StatefulWidget {
  final String requisitionId;

  const PurchaseRequisitionDetailScreen({
    super.key,
    required this.requisitionId,
  });

  @override
  State<PurchaseRequisitionDetailScreen> createState() =>
      _PurchaseRequisitionDetailScreenState();
}

class _PurchaseRequisitionDetailScreenState
    extends State<PurchaseRequisitionDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PurchaseRequisitionPdfExportService _exportService =
      PurchaseRequisitionPdfExportService();

  Future<void> _editRequisition(PurchaseRequisition requisition) async {
    if (requisition.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only edit draft requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditPurchaseRequisitionDialog(
        requisition: requisition,
        requesterId: requisition.requestedBy,
        requesterName: requisition.requestedBy,
      ),
    );

    if (result != null && mounted) {
      try {
        final updatedRequisition = requisition.copyWith(
          requisitionDate: result['requisitionDate'] as DateTime,
          requestedBy: result['requestedBy'] as String,
          idNo: result['idNo'] as String,
          chargeToDepartment: result['chargeToDepartment'] as String,
          notes: result['notes'] as String?,
          updatedAt: DateTime.now(),
        );

        await _firestoreService.updatePurchaseRequisition(updatedRequisition);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Requisition updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating requisition: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addItem(PurchaseRequisition requisition) async {
    if (requisition.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only add items to draft requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final items = await _firestoreService.getPurchaseRequisitionItems(
      requisition.id,
    );
    final nextItemNo = items.isEmpty ? 1 : items.last.itemNo + 1;

    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PurchaseRequisitionItemDialog(
        nextItemNo: nextItemNo,
      ),
    );

    if (result != null && mounted) {
      try {
        final item = PurchaseRequisitionItem(
          id: const Uuid().v4(),
          requisitionId: requisition.id,
          itemNo: result['itemNo'] as int,
          description: result['description'] as String,
          quantity: result['quantity'] as int,
          unitPrice: result['unitPrice'] as double,
          remark: result['remark'] as String?,
          createdAt: DateTime.now(),
        );

        await _firestoreService.savePurchaseRequisitionItem(item);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editItem(
    PurchaseRequisition requisition,
    PurchaseRequisitionItem item,
  ) async {
    if (requisition.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only edit items in draft requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => PurchaseRequisitionItemDialog(item: item),
    );

    if (result != null && mounted) {
      try {
        final updatedItem = item.copyWith(
          description: result['description'] as String,
          quantity: result['quantity'] as int,
          unitPrice: result['unitPrice'] as double,
          remark: result['remark'] as String?,
        );

        await _firestoreService.updatePurchaseRequisitionItem(updatedItem);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteItem(
    PurchaseRequisition requisition,
    PurchaseRequisitionItem item,
  ) async {
    if (requisition.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only delete items from draft requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
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
        await _firestoreService.deletePurchaseRequisitionItem(item.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitRequisition(PurchaseRequisition requisition) async {
    if (requisition.status != 'draft') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Requisition already submitted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if there are items
    final items = await _firestoreService.getPurchaseRequisitionItems(
      requisition.id,
    );
    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please add at least one item before submitting',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Requisition'),
        content: const Text(
          'Are you sure you want to submit this requisition? You will not be able to edit it after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.submitPurchaseRequisition(
          requisition.id,
          user.id,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Requisition submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error submitting requisition: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _printRequisition(PurchaseRequisition requisition) async {
    try {
      final items = await _firestoreService.getPurchaseRequisitionItems(
        requisition.id,
      );
      await _exportService.printPurchaseRequisition(requisition, items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing requisition: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveRequisition(PurchaseRequisition requisition) async {
    if (requisition.status != 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only approve submitted requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) return;

    String? actionNo;
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

      if (actionNo == null) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Approve Requisition'),
          content: const Text(
            'Are you sure you want to approve this requisition?',
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
        setState(() {});
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
    if (requisition.status != 'submitted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Can only reject submitted requisitions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Requisition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
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
        setState(() {});
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
        content: const Text(
          'Are you sure you want to revert this requisition to draft status?',
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
        setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.canManageUsers();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Purchase Requisition'),
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              final requisition = await _firestoreService.getPurchaseRequisition(
                widget.requisitionId,
              );
              if (requisition == null) return;

              switch (value) {
                case 'edit':
                  _editRequisition(requisition);
                  break;
                case 'submit':
                  _submitRequisition(requisition);
                  break;
                case 'print':
                  _printRequisition(requisition);
                  break;
                case 'approve':
                  _approveRequisition(requisition);
                  break;
                case 'reject':
                  _rejectRequisition(requisition);
                  break;
                case 'revert':
                  _revertToDraft(requisition);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 12),
                    Text('Edit Requisition'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'submit',
                child: Row(
                  children: [
                    Icon(Icons.send, size: 20),
                    SizedBox(width: 12),
                    Text('Submit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    Icon(Icons.print, size: 20),
                    SizedBox(width: 12),
                    Text('Print'),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 20, color: Colors.green),
                      SizedBox(width: 12),
                      Text('Approve'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Reject'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'revert',
                  child: Row(
                    children: [
                      Icon(Icons.undo, size: 20, color: Colors.orange),
                      SizedBox(width: 12),
                      Text('Revert to Draft'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: FutureBuilder<PurchaseRequisition?>(
        future: _firestoreService.getPurchaseRequisition(widget.requisitionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requisition = snapshot.data;
          if (requisition == null) {
            return const Center(child: Text('Requisition not found'));
          }

          return _buildRequisitionContent(requisition);
        },
      ),
    );
  }

  Widget _buildRequisitionContent(PurchaseRequisition requisition) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildRequisitionHeader(requisition),
              _buildInfoSection(requisition),
              _buildItemsSection(requisition),
              _buildSummarySection(requisition),
              _buildNoteSection(),
              _buildSignatureSection(requisition),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequisitionHeader(PurchaseRequisition requisition) {
    final dateFormat = DateFormat('MMM dd, yyyy');
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

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 12,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PURCHASE REQUISITION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No: ${requisition.requisitionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Date: ${dateFormat.format(requisition.requisitionDate)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      requisition.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
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

  Widget _buildInfoSection(PurchaseRequisition requisition) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.purple.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Request Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  Icons.person,
                  'Requested By',
                  requisition.requestedBy,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDetailRow(
                  Icons.badge,
                  'ID No.',
                  requisition.idNo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            Icons.business,
            'Charge to Department',
            requisition.chargeToDepartment,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(PurchaseRequisition requisition) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    color: Colors.purple.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Purchase Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (requisition.status == 'draft')
                ElevatedButton.icon(
                  onPressed: () => _addItem(requisition),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          StreamBuilder<List<PurchaseRequisitionItem>>(
            stream: _firestoreService.purchaseRequisitionItemsStream(
              requisition.id,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final items = snapshot.data!;

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No items yet',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Click "Add Item" to create your first item',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _buildItemsTable(requisition, items);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(
    PurchaseRequisition requisition,
    List<PurchaseRequisitionItem> items,
  ) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Text(
                  'No.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const Expanded(
                flex: 3,
                child: Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(
                width: 60,
                child: Text(
                  'Qty',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(
                width: 100,
                child: Text(
                  'Unit Price',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(
                width: 100,
                child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
              ),
              const Expanded(
                flex: 2,
                child: Text(
                  'Remark',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              if (requisition.status == 'draft') const SizedBox(width: 80),
            ],
          ),
        ),
        // Table Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey.shade200,
            height: 1,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final exceedsThreshold = item.totalPrice > 20000;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              color: exceedsThreshold
                  ? Colors.orange.shade50
                  : (index.isEven ? Colors.white : Colors.grey.shade50),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${item.itemNo}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.description,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (exceedsThreshold)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Action No. Required',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${item.quantity}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      '฿${currencyFormat.format(item.unitPrice)}',
                      style: const TextStyle(fontSize: 13),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      '฿${currencyFormat.format(item.totalPrice)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      item.remark ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (requisition.status == 'draft')
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.blue.shade600,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => _editItem(requisition, item),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red.shade600,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => _deleteItem(requisition, item),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection(PurchaseRequisition requisition) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple.shade400, Colors.purple.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            '฿${currencyFormat.format(requisition.totalAmount)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'In case you plan to purchase items for more than one department, please identify on the "Remarks" column.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureSection(PurchaseRequisition requisition) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.draw, color: Colors.purple.shade600, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Signature Section',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSignatureBox(
                  'Requested By',
                  requisition.requestedBy,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSignatureBox(
                  'Approved By',
                  requisition.approvedBy,
                ),
              ),
              if (requisition.requiresActionNo) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSignatureBox(
                    'Action No.\n(for amount > 20,000฿)',
                    requisition.actionNo,
                    isActionNo: true,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox(String label, String? value, {bool isActionNo = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: isActionNo ? Colors.orange.shade50 : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActionNo ? Colors.orange.shade700 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            height: 1,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            value ?? '(________________)',
            style: TextStyle(
              fontSize: 13,
              color: value != null ? Colors.black : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

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
}
