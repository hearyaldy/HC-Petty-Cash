import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/internal_debit_note_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/internal_debit_note.dart';
import '../../services/internal_debit_note_pdf_export_service.dart';
import '../../utils/responsive_helper.dart';
import '../../utils/print_options_dialog.dart';
import '../../utils/quill_text_utils.dart';

class InternalDebitNoteDetailScreen extends StatefulWidget {
  final String noteId;

  const InternalDebitNoteDetailScreen({super.key, required this.noteId});

  @override
  State<InternalDebitNoteDetailScreen> createState() =>
      _InternalDebitNoteDetailScreenState();
}

class _InternalDebitNoteDetailScreenState
    extends State<InternalDebitNoteDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNote();
    });
  }

  Future<void> _loadNote() async {
    final provider = context.read<InternalDebitNoteProvider>();
    if (provider.getNoteById(widget.noteId) == null) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.canApprove()) {
        await provider.loadNotes();
      } else {
        final user = authProvider.currentUser;
        if (user != null) await provider.loadNotesByUser(user.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InternalDebitNoteProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: const SafeArea(child: Center(child: CircularProgressIndicator())),
          );
        }

        final note = provider.getNoteById(widget.noteId);

        if (note == null) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows_outlined, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Debit note not found',
                      style: TextStyle(
                          fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/internal-debit-notes'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      child: const Text('Back to Debit Notes'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final authProvider = context.read<AuthProvider>();
        final isAdmin = authProvider.canManageUsers();
        final isOwner = authProvider.currentUser?.id == note.createdById;

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: SafeArea(
            child: ResponsiveContainer(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(note, isAdmin, isOwner, provider),
                    const SizedBox(height: 8),
                    _buildInfoCard(note),
                    const SizedBox(height: 12),
                    _buildDetailsCard(note),
                    const SizedBox(height: 12),
                    _buildReasonCard(note),
                    const SizedBox(height: 12),
                    _buildSignatureCard(note),
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

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(
    InternalDebitNote note,
    bool isAdmin,
    bool isOwner,
    InternalDebitNoteProvider provider,
  ) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final canManage = isAdmin || isOwner;

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderActionButton(
                icon: Icons.arrow_back,
                tooltip: 'Back to Debit Notes',
                onPressed: () => context.go('/internal-debit-notes'),
              ),
              Row(
                children: [
                  _buildHeaderActionButton(
                    icon: Icons.print_outlined,
                    tooltip: 'Print',
                    onPressed: () async {
                      await showPrintOptionsDialog(
                        context: context,
                        title: 'Print Internal Debit Note',
                        onPrint: () async {
                          final service = InternalDebitNotePdfExportService();
                          try {
                            await service.printNote(note);
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
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderActionButton(
                    icon: Icons.home_outlined,
                    tooltip: 'Finance Dashboard',
                    onPressed: () => context.go('/finance-dashboard'),
                  ),
                  if (canManage) ...[
                    const SizedBox(width: 8),
                    _buildPopupMenu(note, isAdmin, isOwner, provider),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.debitNoteNumber,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.issuedToCompany,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.apartment,
                            size: 13, color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(
                          note.department,
                          style: TextStyle(
                              fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.calendar_today,
                            size: 13, color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(note.noteDate),
                          style: TextStyle(
                              fontSize: 13, color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(note.status),
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

  Widget _buildPopupMenu(
    InternalDebitNote note,
    bool isAdmin,
    bool isOwner,
    InternalDebitNoteProvider provider,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            context.push('/internal-debit-notes/${note.id}/edit');
            break;
          case 'issue':
            await provider.issueNote(note.id);
            break;
          case 'revert':
            await provider.revertToDraft(note.id);
            break;
          case 'delete':
            _confirmDelete(note, provider);
            break;
        }
      },
      itemBuilder: (_) => [
        if (note.status == 'draft')
          const PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('Edit'),
            ]),
          ),
        if (note.status == 'draft')
          const PopupMenuItem(
            value: 'issue',
            child: Row(children: [
              Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('Mark as Issued'),
            ]),
          ),
        if (note.status == 'issued' && isAdmin)
          const PopupMenuItem(
            value: 'revert',
            child: Row(children: [
              Icon(Icons.undo, size: 18),
              SizedBox(width: 8),
              Text('Revert to Draft'),
            ]),
          ),
        if (note.status == 'draft')
          const PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outlined, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ]),
          ),
      ],
    );
  }

  void _confirmDelete(InternalDebitNote note, InternalDebitNoteProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Debit Note'),
          ],
        ),
        content: Text('Permanently delete ${note.debitNoteNumber}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteNote(note.id);
              if (mounted) {
                if (success) {
                  context.go('/internal-debit-notes');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete debit note'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isIssued = status == 'issued';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Text(
        isIssued ? 'Issued' : 'Draft',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  // ─── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard(InternalDebitNote note) {
    return _buildCard(
      title: 'Note Information',
      icon: Icons.info_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Company', note.companyName),
          const SizedBox(height: 10),
          _buildInfoRow('Issued To', note.issuedToCompany),
          const SizedBox(height: 10),
          _buildInfoRow('Department', note.department),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }

  // ─── Details card ──────────────────────────────────────────────────────────

  Widget _buildDetailsCard(InternalDebitNote note) {
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    return _buildCard(
      title: 'Details',
      icon: Icons.list_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...note.lineItems.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildQuillRichText(item.description, const TextStyle(fontSize: 14)),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${note.currency} ${currencyFormat.format(item.amount)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Debit Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              Text(
                '${note.currency} ${currencyFormat.format(note.totalAmount)}',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Reason / terms card ───────────────────────────────────────────────────

  Widget _buildReasonCard(InternalDebitNote note) {
    return _buildCard(
      title: 'Reason & Terms',
      icon: Icons.description_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reason for Debit',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(note.reasonForDebit, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          Text('Payment / Settlement Terms',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(note.paymentTerms, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // ─── Signature card ────────────────────────────────────────────────────────

  Widget _buildSignatureCard(InternalDebitNote note) {
    return _buildCard(
      title: 'Signatures',
      icon: Icons.draw_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Prepared by', note.preparedByName),
          const SizedBox(height: 10),
          _buildInfoRow('Checked by', note.checkedByName?.isNotEmpty == true ? note.checkedByName! : '—'),
          const SizedBox(height: 10),
          _buildInfoRow('Approved by', note.approvedByName?.isNotEmpty == true ? note.approvedByName! : '—'),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  Icon(icon, color: Colors.deepPurple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ],
              ),
              const Divider(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
