import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/staff.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../services/medical_bill_reimbursement_service.dart';
import '../../services/salary_benefits_service.dart';
import '../../services/staff_service.dart';
import '../../utils/constants.dart';
import '../../utils/responsive_helper.dart';

class _StaffClaimSummary {
  final Staff staff;
  final double approvedAmount;
  final double? claimLimit;
  final String limitNote;
  final Map<MedicalClaimCategory, double> byCategory;

  _StaffClaimSummary({
    required this.staff,
    required this.approvedAmount,
    required this.claimLimit,
    required this.limitNote,
    required this.byCategory,
  });

  double get remaining => claimLimit != null ? claimLimit! - approvedAmount : 0;
  bool get isOver => claimLimit != null && approvedAmount > claimLimit!;
  double get usedPercent =>
      claimLimit != null && claimLimit! > 0 ? (approvedAmount / claimLimit!) * 100 : 0;
}

class MedicalClaimsSummaryScreen extends StatefulWidget {
  const MedicalClaimsSummaryScreen({super.key});

  @override
  State<MedicalClaimsSummaryScreen> createState() =>
      _MedicalClaimsSummaryScreenState();
}

class _MedicalClaimsSummaryScreenState
    extends State<MedicalClaimsSummaryScreen> {
  final _staffService = StaffService();
  final _salaryService = SalaryBenefitsService();
  final _medicalService = MedicalBillReimbursementService();

  final _currency = NumberFormat.currency(
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  bool _isLoading = true;
  String? _error;
  List<_StaffClaimSummary> _summaries = [];
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Load active staff and approved claims in parallel
      final staffFuture = _staffService.getActiveStaff().first;
      final claimsFuture = _medicalService.getApprovedForYear(_year);
      final activeStaff = await staffFuture;
      final claims = await claimsFuture;

      // Index claims by requesterId (Auth UID) AND by requesterName (fallback)
      // claim.requesterId = Firebase Auth UID (user.id from authProvider.currentUser)
      // staff.userId = same Auth UID — primary match key
      // staff.fullName == claim.requesterName — tertiary fallback for unlinked staff
      final Map<String, double> claimsByKey = {};
      final Map<String, Map<MedicalClaimCategory, double>> categoryByKey = {};

      void addClaimAmount(String key, double amount, MedicalClaimCategory? cat) {
        claimsByKey[key] = (claimsByKey[key] ?? 0.0) + amount;
        if (cat != null) {
          categoryByKey[key] ??= {};
          categoryByKey[key]![cat] = (categoryByKey[key]![cat] ?? 0.0) + amount;
        }
      }

      for (final claim in claims) {
        final idKey = claim.requesterId;
        final nameKey = claim.requesterName.trim().toLowerCase();

        if (claim.claimItems.isNotEmpty) {
          for (final item in claim.claimItems) {
            addClaimAmount(idKey, item.amountReimburse, item.claimCategoryEnum);
            addClaimAmount(nameKey, item.amountReimburse, item.claimCategoryEnum);
          }
        } else {
          addClaimAmount(idKey, claim.totalReimbursement, null);
          addClaimAmount(nameKey, claim.totalReimbursement, null);
        }
      }

      // Resolve: for each staff, pick amounts using best available match key
      // Priority: 1) staff.userId  2) staff.id  3) staff.fullName (case-insensitive)
      Map<String, double> claimsByStaff = {};
      Map<String, Map<MedicalClaimCategory, double>> categoryByStaff = {};
      for (final staff in activeStaff) {
        final nameKey = staff.fullName.trim().toLowerCase();
        final resolvedKey = claimsByKey.containsKey(staff.userId)
            ? staff.userId!
            : claimsByKey.containsKey(staff.id)
                ? staff.id
                : nameKey;
        claimsByStaff[staff.id] = claimsByKey[resolvedKey] ?? 0.0;
        categoryByStaff[staff.id] = categoryByKey[resolvedKey] ?? {};
      }

      final salaryFutures = activeStaff.map((s) async {
        if (s.currentSalaryBenefitsId != null) {
          final result = await _salaryService.getSalaryBenefitsById(s.currentSalaryBenefitsId!);
          if (result != null && result.wageFactor != null && result.wageFactor! > 0) return result;
        }
        // Fallback: search by staffId for cases where currentSalaryBenefitsId is not set
        return _salaryService.getCurrentSalaryBenefitsOnce(s.id);
      }).toList();

      final salaryResults = await Future.wait(salaryFutures);

      final summaries = <_StaffClaimSummary>[];
      for (int i = 0; i < activeStaff.length; i++) {
        final staff = activeStaff[i];
        final salary = salaryResults[i];
        final approved = claimsByStaff[staff.userId ?? staff.id] ??
            claimsByStaff[staff.id] ??
            0.0;

        double? limit;
        String note = '';

        final wf = salary?.wageFactor;
        if (wf == null || wf == 0) {
          note = 'No wage factor set';
        } else {
          final multiplier = staff.familyStatus == 'family'
              ? 1 + staff.familyMemberCount
              : 1;
          limit = wf * 0.75 * multiplier;
        }

        summaries.add(_StaffClaimSummary(
          staff: staff,
          approvedAmount: approved,
          claimLimit: limit,
          limitNote: note,
          byCategory: categoryByStaff[staff.userId ?? staff.id] ??
              categoryByStaff[staff.id] ??
              {},
        ));
      }

      // Sort: over-limit first, then by used% descending
      summaries.sort((a, b) {
        if (a.isOver && !b.isOver) return -1;
        if (!a.isOver && b.isOver) return 1;
        return b.usedPercent.compareTo(a.usedPercent);
      });

      if (mounted) {
        setState(() {
          _summaries = summaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxWidth = ResponsiveHelper.getMaxContentWidth(context);
    final hPad = ResponsiveHelper.getScreenPadding(context).horizontal / 2;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: cs.primary,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Medical Claims Summary',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Policy limit tracker · $_year',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Year selector
                        _buildYearChip(cs),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                          tooltip: 'Refresh',
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: $_error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: hPad,
                        vertical: 16,
                      ),
                      children: [
                        _buildSummaryStats(cs),
                        const SizedBox(height: 20),
                        _buildTable(context, cs),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildYearChip(ColorScheme cs) {
    return GestureDetector(
      onTap: _pickYear,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 13),
            const SizedBox(width: 5),
            Text(
              '$_year',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Year'),
        children: List.generate(5, (i) => now.year - i).map((y) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, y),
            child: Text(
              '$y',
              style: TextStyle(
                fontWeight: y == _year ? FontWeight.bold : FontWeight.normal,
                color: y == _year ? Theme.of(ctx).colorScheme.primary : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
    if (picked != null && picked != _year) {
      setState(() => _year = picked);
      _loadData();
    }
  }

  Widget _buildSummaryStats(ColorScheme cs) {
    final overLimit = _summaries.where((s) => s.isOver).length;
    final noData = _summaries.where((s) => s.claimLimit == null).length;
    final totalApproved =
        _summaries.fold(0.0, (sum, s) => sum + s.approvedAmount);

    final stats = [
      (
        'Staff',
        '${_summaries.length}',
        Icons.people_outline,
        Colors.indigo.shade400,
      ),
      (
        'Over Limit',
        '$overLimit',
        Icons.warning_amber_rounded,
        Colors.red.shade400,
      ),
      (
        'Missing Data',
        '$noData',
        Icons.info_outline,
        Colors.orange.shade400,
      ),
      (
        'Total Approved',
        _currency.format(totalApproved),
        Icons.attach_money,
        Colors.teal.shade500,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveHelper.isMobile(context) ? 2 : 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: stats.map((s) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: s.$4.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.$4.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(s.$3, color: s.$4, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.$2,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: s.$4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    s.$1,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTable(BuildContext context, ColorScheme cs) {
    final isAdmin = context.read<AuthProvider>().hasRole(UserRole.admin);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded, size: 18, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Staff Medical Claim Limits',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (isAdmin)
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Policy'),
                    onPressed: _summaries.isEmpty
                        ? null
                        : () => _showEditPolicyDialog(_summaries.first.staff),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.primary,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey.shade50),
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Staff')),
                DataColumn(label: Text('Dept')),
                DataColumn(label: Text('Policy')),
                DataColumn(label: Text('Limit'), numeric: true),
                DataColumn(label: Text('Approved (YTD)'), numeric: true),
                DataColumn(label: Text('Remaining'), numeric: true),
                DataColumn(label: Text('Usage')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Breakdown')),
              ],
              rows: _summaries.map((s) => _buildRow(s, isAdmin)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildRow(_StaffClaimSummary s, bool isAdmin) {
    final pct = s.usedPercent;
    final color = s.isOver
        ? Colors.red
        : pct >= 80
            ? Colors.orange
            : Colors.teal;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                child: Text(
                  s.staff.fullName.isNotEmpty
                      ? s.staff.fullName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.staff.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(s.staff.employeeId,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _showEditPolicyDialog(s.staff),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.settings_outlined,
                        size: 14, color: Colors.grey[400]),
                  ),
                ),
              ],
            ],
          ),
        ),
        DataCell(Text(s.staff.department,
            style: const TextStyle(fontSize: 12))),
        DataCell(_buildPolicyBadge(s.staff)),
        DataCell(
          s.claimLimit != null
              ? Text(_currency.format(s.claimLimit!),
                  style: const TextStyle(fontSize: 12))
              : Text(s.limitNote,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic)),
        ),
        DataCell(
          Text(
            _currency.format(s.approvedAmount),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: s.approvedAmount > 0 ? Colors.teal[700] : Colors.grey,
            ),
          ),
        ),
        DataCell(
          s.claimLimit != null
              ? Text(
                  _currency.format(s.remaining),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.isOver ? Colors.red : Colors.green[700],
                  ),
                )
              : const Text('—', style: TextStyle(color: Colors.grey)),
        ),
        DataCell(
          s.claimLimit != null
              ? SizedBox(
                  width: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const Text('—', style: TextStyle(color: Colors.grey)),
        ),
        DataCell(_buildStatusBadge(s)),
        DataCell(
          s.byCategory.isEmpty
              ? const Text('—', style: TextStyle(color: Colors.grey))
              : TextButton(
                  onPressed: () => _showCategoryBreakdown(s),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: const Text('Details', style: TextStyle(fontSize: 12)),
                ),
        ),
      ],
    );
  }

  void _showCategoryBreakdown(_StaffClaimSummary s) {
    final currency = _currency;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Category Breakdown — ${s.staff.fullName}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...(s.byCategory.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value)))
                    .map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key.displayName,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${(e.key.reimbursementRate * 100).toInt()}% · ${e.key.limitDescription}',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          currency.format(e.value),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Approved',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      currency.format(s.approvedAmount),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: s.isOver ? Colors.red : Colors.teal[700]),
                    ),
                  ],
                ),
                if (s.claimLimit != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Policy Limit',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                      Text(
                        currency.format(s.claimLimit!),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyBadge(Staff staff) {
    final isFamily = staff.familyStatus == 'family';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFamily
            ? Colors.purple.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFamily
              ? Colors.purple.withValues(alpha: 0.3)
              : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFamily ? Icons.family_restroom : Icons.person,
            size: 12,
            color: isFamily ? Colors.purple : Colors.blue,
          ),
          const SizedBox(width: 4),
          Text(
            isFamily ? 'Family' : 'Single',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFamily ? Colors.purple : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(_StaffClaimSummary s) {
    if (s.claimLimit == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('No Data',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
      );
    }
    final isOver = s.isOver;
    final pct = s.usedPercent;
    final label = isOver
        ? 'Over Limit'
        : pct >= 80
            ? 'Near Limit'
            : 'Within Limit';
    final color = isOver
        ? Colors.red
        : pct >= 80
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<void> _showEditPolicyDialog(Staff initial) async {
    // Find the latest version from summaries so we're editing current state
    final current = _summaries.firstWhere(
      (s) => s.staff.id == initial.id,
      orElse: () => _StaffClaimSummary(
          staff: initial, approvedAmount: 0, claimLimit: null, limitNote: '', byCategory: {}),
    );

    await showDialog(
      context: context,
      builder: (ctx) => _EditPolicyDialog(
        staff: current.staff,
        staffService: _staffService,
        onSaved: _loadData,
      ),
    );
  }
}

// ─── Edit Policy Dialog ───────────────────────────────────────────────────────

class _EditPolicyDialog extends StatefulWidget {
  final Staff staff;
  final StaffService staffService;
  final VoidCallback onSaved;

  const _EditPolicyDialog({
    required this.staff,
    required this.staffService,
    required this.onSaved,
  });

  @override
  State<_EditPolicyDialog> createState() => _EditPolicyDialogState();
}

class _EditPolicyDialogState extends State<_EditPolicyDialog> {
  late String _familyStatus;
  late int _familyMemberCount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _familyStatus = widget.staff.familyStatus;
    _familyMemberCount = widget.staff.familyMemberCount;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.staffService.updateFamilyMedicalSettings(
        widget.staff.id,
        familyStatus: _familyStatus,
        familyMemberCount: _familyStatus == 'family' ? _familyMemberCount : 0,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: cs.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Medical Policy — ${widget.staff.fullName}',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Policy Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'single',
                  label: Text('Single'),
                  icon: Icon(Icons.person, size: 16),
                ),
                ButtonSegment(
                  value: 'family',
                  label: Text('Married / Family'),
                  icon: Icon(Icons.family_restroom, size: 16),
                ),
              ],
              selected: {_familyStatus},
              onSelectionChanged: (s) =>
                  setState(() => _familyStatus = s.first),
            ),
            const SizedBox(height: 16),
            if (_familyStatus == 'family') ...[
              const Text('Number of covered family members',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Spouse, children, and other dependents covered under the plan',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _familyMemberCount > 1
                        ? () => setState(() => _familyMemberCount--)
                        : null,
                  ),
                  Container(
                    width: 48,
                    alignment: Alignment.center,
                    child: Text(
                      '$_familyMemberCount',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _familyMemberCount++),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _familyMemberCount == 1 ? 'member' : 'members',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Limit multiplier',
                        style: TextStyle(fontSize: 12)),
                    Text(
                      '${1 + _familyMemberCount}× staff wage factor × 75%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Limit = staff\'s own wage factor × 75%',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

