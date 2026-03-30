import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/adcom_minutes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cash_advance_provider.dart';
import '../../services/adcom_minutes_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/responsive_helper.dart';

class NewCashAdvanceScreen extends StatefulWidget {
  final String? advanceId;
  final String? purchaseRequisitionId;
  final String? initialPurpose;
  final double? initialAmount;
  final String? initialDepartment;

  const NewCashAdvanceScreen({
    super.key,
    this.advanceId,
    this.purchaseRequisitionId,
    this.initialPurpose,
    this.initialAmount,
    this.initialDepartment,
  });

  @override
  State<NewCashAdvanceScreen> createState() => _NewCashAdvanceScreenState();
}

class _NewCashAdvanceScreenState extends State<NewCashAdvanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _departmentController = TextEditingController();
  final _idNoController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _requestDate = DateTime.now();
  DateTime? _requiredByDate;
  bool _isLoading = false;
  bool _isEditing = false;

  // Meeting minutes reference
  String? _linkedMinutesId;
  String? _linkedMinutesLabel;
  String? _linkedActionItemNumber;
  String? _linkedActionItemTitle;
  String? _linkedActionItemDescription;
  String? _linkedActionItemAction;

  final _minutesService = AdcomMinutesService();
  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user != null) {
      _departmentController.text = user.department;
    }
    if (widget.initialPurpose != null) {
      _purposeController.text = widget.initialPurpose!;
    }
    if (widget.initialDepartment != null) {
      _departmentController.text = widget.initialDepartment!;
    }
    if (widget.advanceId != null) {
      _isEditing = true;
      _loadExistingAdvance();
    }
  }

  Future<void> _loadExistingAdvance() async {
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<CashAdvanceProvider>(context, listen: false);
      final advance = await provider.loadAdvance(widget.advanceId!);
      if (advance != null && mounted) {
        setState(() {
          _purposeController.text = advance.purpose;
          _idNoController.text = advance.idNo ?? '';
          _notesController.text = advance.notes ?? '';
          _departmentController.text = advance.department;
          _requestDate = advance.requestDate;
          _requiredByDate = advance.requiredByDate;
          _linkedMinutesId = advance.linkedMinutesId;
          _linkedMinutesLabel = advance.linkedMinutesLabel;
          _linkedActionItemNumber = advance.linkedActionItemNumber;
          _linkedActionItemTitle = advance.linkedActionItemTitle;
          _linkedActionItemDescription = advance.linkedActionItemDescription;
          _linkedActionItemAction = advance.linkedActionItemAction;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(bool isRequestDate) async {
    final initial = isRequestDate
        ? _requestDate
        : (_requiredByDate ?? DateTime.now().add(const Duration(days: 7)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isRequestDate) {
          _requestDate = picked;
        } else {
          _requiredByDate = picked;
        }
      });
    }
  }

  Future<void> _pickMinutesReference() async {
    // Step 1 – pick a minutes document
    setState(() => _isLoading = true);
    List<AdcomMinutes> minutesList = [];
    try {
      minutesList = await _minutesService.getMinutes().first;
    } catch (_) {}
    setState(() => _isLoading = false);

    if (!mounted) return;

    final AdcomMinutes? selectedMinutes = await showDialog<AdcomMinutes>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Meeting Minutes'),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: minutesList.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No meeting minutes found.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: minutesList.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = minutesList[index];
                    final dateStr =
                        DateFormat('MMM dd, yyyy').format(m.meetingDate);
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.article_outlined,
                            size: 20, color: Colors.indigo.shade600),
                      ),
                      title: Text('ADCOM – $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(m.location,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: m.status == 'finalized'
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: m.status == 'finalized'
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          m.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: m.status == 'finalized'
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                      onTap: () => Navigator.pop(context, m),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMinutes == null || !mounted) return;

    // Step 2 – pick an action item from that minutes
    final MinutesItem? selectedItem = await showDialog<MinutesItem>(
      context: context,
      builder: (context) {
        final items = selectedMinutes.minutesItems;
        final dateStr =
            DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
        return AlertDialog(
          title: Text('ADCOM – $dateStr'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No action items in this minutes.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border:
                                Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Text(
                            item.itemNumber,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ),
                        title: Text(item.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: item.resolution != null
                            ? Text(item.resolution!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]))
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
          ],
        );
      },
    );

    if (selectedItem == null || !mounted) return;

    final dateStr =
        DateFormat('MMM dd, yyyy').format(selectedMinutes.meetingDate);
    setState(() {
      _linkedMinutesId = selectedMinutes.id;
      _linkedMinutesLabel = 'ADCOM – $dateStr';
      _linkedActionItemNumber = selectedItem.itemNumber;
      _linkedActionItemTitle = selectedItem.title;
      _linkedActionItemDescription = selectedItem.description;
      _linkedActionItemAction = selectedItem.status.displayName;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CashAdvanceProvider>(context, listen: false);

      if (_isEditing && widget.advanceId != null) {
        final existing = provider.selectedAdvance;
        if (existing != null) {
          final updated = existing.copyWith(
            purpose: _purposeController.text.trim(),
            requestDate: _requestDate,
            requiredByDate: _requiredByDate,
            department: _departmentController.text.trim(),
            idNo: _idNoController.text.trim().isEmpty
                ? null
                : _idNoController.text.trim(),
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            linkedMinutesId: _linkedMinutesId,
            linkedMinutesLabel: _linkedMinutesLabel,
            linkedActionItemNumber: _linkedActionItemNumber,
            linkedActionItemTitle: _linkedActionItemTitle,
            linkedActionItemDescription: _linkedActionItemDescription,
            linkedActionItemAction: _linkedActionItemAction,
            updatedAt: DateTime.now(),
          );
          final success = await provider.updateAdvance(updated);
          if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cash advance updated'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/cash-advances/${widget.advanceId}');
          }
        }
      } else {
        final advance = await provider.createAdvance(
          purpose: _purposeController.text.trim(),
          requestedAmount: widget.initialAmount ?? 0.0,
          department: _departmentController.text.trim(),
          requester: user,
          requestDate: _requestDate,
          requiredByDate: _requiredByDate,
          idNo: _idNoController.text.trim().isEmpty
              ? null
              : _idNoController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          purchaseRequisitionId: widget.purchaseRequisitionId,
          linkedMinutesId: _linkedMinutesId,
          linkedMinutesLabel: _linkedMinutesLabel,
          linkedActionItemNumber: _linkedActionItemNumber,
          linkedActionItemTitle: _linkedActionItemTitle,
          linkedActionItemDescription: _linkedActionItemDescription,
          linkedActionItemAction: _linkedActionItemAction,
        );

        if (advance != null && widget.purchaseRequisitionId != null) {
          try {
            await FirestoreService().updatePurchaseRequisitionCashAdvanceId(
              widget.purchaseRequisitionId!,
              advance.id,
            );
          } catch (_) {}
        }

        if (advance != null && mounted) {
          context.go('/cash-advances/${advance.id}');
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to create cash advance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _departmentController.dispose();
    _idNoController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = ResponsiveHelper.getScreenPadding(context);
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeaderBanner(),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Basic Information',
                                icon: Icons.info_outline,
                                children: [
                                  _buildField(
                                    controller: _purposeController,
                                    label: 'Purpose *',
                                    hint: 'What is this advance for?',
                                    icon: Icons.description_outlined,
                                    maxLines: 3,
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Please enter the purpose'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    controller: _departmentController,
                                    label: 'Department *',
                                    hint: 'Enter department name',
                                    icon: Icons.business_outlined,
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Please enter the department'
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Dates',
                                icon: Icons.calendar_month_outlined,
                                children: [
                                  _buildDateTile(
                                    label: 'Request Date',
                                    value: _dateFormat.format(_requestDate),
                                    onTap: () => _selectDate(true),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildDateTile(
                                    label: 'Required By (optional)',
                                    value: _requiredByDate != null
                                        ? _dateFormat.format(_requiredByDate!)
                                        : 'Not set',
                                    isPlaceholder: _requiredByDate == null,
                                    onTap: () => _selectDate(false),
                                    trailing: _requiredByDate != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () =>
                                                setState(() => _requiredByDate = null),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Additional Information',
                                icon: Icons.notes_outlined,
                                children: [
                                  _buildField(
                                    controller: _idNoController,
                                    label: 'ID Number (optional)',
                                    hint: 'Employee / Staff ID',
                                    icon: Icons.badge_outlined,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildField(
                                    controller: _notesController,
                                    label: 'Notes (optional)',
                                    hint: 'Any additional remarks',
                                    icon: Icons.notes_outlined,
                                    maxLines: 3,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Meeting Reference (optional)',
                                icon: Icons.meeting_room_outlined,
                                children: [
                                  _buildMinutesReferenceTile(),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: _save,
                                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                                  label: Text(
                                    _isEditing ? 'Save Changes' : 'Create Cash Advance',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
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
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (_isEditing && widget.advanceId != null) {
                    context.go('/cash-advances/${widget.advanceId}');
                  } else {
                    context.go('/cash-advances');
                  }
                },
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
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.request_quote, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Cash Advance' : 'New Cash Advance',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isEditing
                          ? 'Update the request details below.'
                          : 'Create the request, then add items to tally the total.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }

  Widget _buildMinutesReferenceTile() {
    final hasReference = _linkedMinutesId != null;
    return InkWell(
      onTap: _pickMinutesReference,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasReference ? Colors.indigo.shade300 : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(12),
          color: hasReference ? Colors.indigo.shade50 : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.article_outlined,
              color: hasReference ? Colors.indigo : Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: hasReference
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _linkedMinutesLabel!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.indigo[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _linkedActionItemNumber!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo[700],
                                ),
                              ),
                            ),
                            if (_linkedActionItemAction != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: Colors.teal.shade200),
                                ),
                                child: Text(
                                  _linkedActionItemAction!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_linkedActionItemTitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _linkedActionItemTitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_linkedActionItemDescription != null &&
                            _linkedActionItemDescription!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _linkedActionItemDescription!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link to Meeting Minutes',
                          style: TextStyle(
                              fontSize: 15, color: Colors.grey[500]),
                        ),
                        Text(
                          'Tap to select minutes & action item',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ),
            ),
            if (hasReference)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                color: Colors.grey[500],
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () => setState(() {
                  _linkedMinutesId = null;
                  _linkedMinutesLabel = null;
                  _linkedActionItemNumber = null;
                  _linkedActionItemTitle = null;
                  _linkedActionItemDescription = null;
                  _linkedActionItemAction = null;
                }),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool isPlaceholder = false,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.indigo, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isPlaceholder ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.edit_outlined, color: Colors.grey[500], size: 18),
          ],
        ),
      ),
    );
  }
}
