import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/staff.dart';
import '../../models/salary_benefits.dart';
import '../../services/salary_benefits_service.dart';
import '../../services/staff_service.dart';
import '../../utils/responsive_helper.dart';

class AddEditSalaryBenefitsScreen extends StatefulWidget {
  final String? salaryBenefitsId;

  const AddEditSalaryBenefitsScreen({super.key, this.salaryBenefitsId});

  @override
  State<AddEditSalaryBenefitsScreen> createState() =>
      _AddEditSalaryBenefitsScreenState();
}

class _AddEditSalaryBenefitsScreenState
    extends State<AddEditSalaryBenefitsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salaryBenefitsService = SalaryBenefitsService();
  final _staffService = StaffService();

  // Controllers for form fields
  final _baseSalaryController = TextEditingController();
  final _overtimeRateController = TextEditingController();
  final _bonusController = TextEditingController();
  final _commissionController = TextEditingController();
  final _allowancesController = TextEditingController();
  final _deductionsController = TextEditingController();
  final _providentFundPercentageController = TextEditingController();
  final _healthInsurancePercentageController = TextEditingController();
  final _socialSecurityPercentageController = TextEditingController();
  final _salaryGradeController = TextEditingController();
  final _payGradeController = TextEditingController();
  final _notesController = TextEditingController();
  final _effectiveDateController = TextEditingController();

  // New controllers for updated salary structure
  final _wageFactorController = TextEditingController();
  final _salaryPercentageController = TextEditingController();
  final _phoneAllowanceController = TextEditingController();
  final _continueEducationAllowanceController = TextEditingController();
  final _equipmentAllowanceController = TextEditingController();
  final _tithePercentageController = TextEditingController();

  // Health Benefits controllers
  final _outPatientPercentageController = TextEditingController();
  final _inPatientPercentageController = TextEditingController();
  final _annualLeaveDaysController = TextEditingController();
  final _housingAllowanceController = TextEditingController();

  // House Rental controller
  final _houseRentalPercentageController = TextEditingController();

  // Form fields
  Staff? _staff;
  String _currency = 'THB';
  bool _isActive = true;
  DateTime? _effectiveDate;
  DateTime? _endDate;
  String? _editingSalaryBenefitsId;
  DateTime? _existingCreatedAt;

  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Schedule the loading to happen after the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() async {
    try {
      final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
      debugPrint('Debug: _loadInitialData called');
      debugPrint('Debug: args = $args');

      if (args != null) {
        _staff = args['staff'] as Staff?;
        debugPrint('Debug: _staff = ${_staff?.fullName}');

        final existingSalaryBenefits =
            args['salaryBenefits'] as SalaryBenefits?;
        final isNewYearRecord = args['isNewYearRecord'] as bool? ?? false;
        debugPrint('Debug: existingSalaryBenefits = $existingSalaryBenefits');
        debugPrint(
          'Debug: existingSalaryBenefits id = ${existingSalaryBenefits?.id}',
        );
        debugPrint(
          'Debug: existingSalaryBenefits baseSalary = ${existingSalaryBenefits?.baseSalary}',
        );
        debugPrint('Debug: isNewYearRecord = $isNewYearRecord');

        if (existingSalaryBenefits != null) {
          debugPrint('Debug: Populating form with existing salary benefits');
          if (isNewYearRecord) {
            // Pre-fill form from previous record but create a new record
            _editingSalaryBenefitsId = null;
            _existingCreatedAt = null;
          } else {
            _editingSalaryBenefitsId = existingSalaryBenefits.id;
            _existingCreatedAt = existingSalaryBenefits.createdAt;
          }
          _populateForm(existingSalaryBenefits);
          if (isNewYearRecord) {
            // Set effective date to Jan 1 of next year
            final nextYear = DateTime(existingSalaryBenefits.effectiveDate.year + 1, 1, 1);
            _effectiveDate = nextYear;
            _effectiveDateController.text = DateFormat('dd/MM/yyyy').format(nextYear);
          }
          _staff ??= await _staffService.getStaffById(
            existingSalaryBenefits.staffId,
          );
        } else {
          debugPrint('Debug: No existing salary benefits to populate');
        }
      } else {
        debugPrint('Debug: args is null');
      }

      // If staff is still null after loading args, try to get it from widget if we have salaryBenefitsId
      if (_staff == null && widget.salaryBenefitsId != null) {
        // Try to load the salary benefits record to get the staff ID, then load the staff
        // This is a fallback for cases where staff wasn't passed in the arguments
        debugPrint(
          'Debug: Staff not provided, attempting to load from salary benefits ID',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Debug: Error in _loadInitialData: $e');
      debugPrint('Debug: Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        // Add mounted check
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  void _populateForm(SalaryBenefits salaryBenefits) {
    debugPrint('Debug: _populateForm called');
    debugPrint('Debug: baseSalary = ${salaryBenefits.baseSalary}');
    debugPrint('Debug: wageFactor = ${salaryBenefits.wageFactor}');
    debugPrint('Debug: salaryPercentage = ${salaryBenefits.salaryPercentage}');

    _baseSalaryController.text = salaryBenefits.baseSalary.toString();
    _overtimeRateController.text =
        salaryBenefits.overtimeRate?.toString() ?? '';
    _bonusController.text = salaryBenefits.bonus?.toString() ?? '';
    _commissionController.text = salaryBenefits.commission?.toString() ?? '';
    _allowancesController.text = salaryBenefits.allowances?.toString() ?? '';
    _deductionsController.text = salaryBenefits.deductions?.toString() ?? '';
    _providentFundPercentageController.text =
        salaryBenefits.providentFundPercentage?.toString() ?? '';
    _healthInsurancePercentageController.text =
        salaryBenefits.healthInsurancePercentage?.toString() ?? '';
    _socialSecurityPercentageController.text =
        salaryBenefits.socialSecurityPercentage?.toString() ?? '';
    _salaryGradeController.text = salaryBenefits.salaryGrade ?? '';
    _payGradeController.text = salaryBenefits.payGrade ?? '';
    _notesController.text = salaryBenefits.notes ?? '';
    _currency = salaryBenefits.currency ?? 'THB';
    _isActive = salaryBenefits.isActive;

    _effectiveDate = salaryBenefits.effectiveDate;
    _effectiveDateController.text = DateFormat(
      'dd/MM/yyyy',
    ).format(salaryBenefits.effectiveDate);

    _endDate = salaryBenefits.endDate;

    // Populate new fields
    _wageFactorController.text = salaryBenefits.wageFactor?.toString() ?? '';
    _salaryPercentageController.text =
        salaryBenefits.salaryPercentage?.toString() ?? '';
    _phoneAllowanceController.text =
        salaryBenefits.phoneAllowance?.toString() ?? '';
    _continueEducationAllowanceController.text =
        salaryBenefits.continueEducationAllowance?.toString() ?? '';
    _equipmentAllowanceController.text =
        salaryBenefits.equipmentAllowance?.toString() ?? '';
    _tithePercentageController.text =
        salaryBenefits.tithePercentage?.toString() ?? '10';

    // Populate health benefits fields
    _outPatientPercentageController.text =
        salaryBenefits.outPatientPercentage?.toString() ?? '75';
    _inPatientPercentageController.text =
        salaryBenefits.inPatientPercentage?.toString() ?? '90';
    _annualLeaveDaysController.text =
        salaryBenefits.annualLeaveDays?.toString() ?? '';
    _housingAllowanceController.text =
        salaryBenefits.housingAllowance?.toString() ?? '';

    // Populate house rental field
    _houseRentalPercentageController.text =
        salaryBenefits.houseRentalPercentage?.toString() ?? '10';

    debugPrint(
      'Debug: Form populated - wageFactor field = ${_wageFactorController.text}',
    );
    debugPrint(
      'Debug: Form populated - salaryPercentage field = ${_salaryPercentageController.text}',
    );

    // Force setState to update UI
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _baseSalaryController.dispose();
    _overtimeRateController.dispose();
    _bonusController.dispose();
    _commissionController.dispose();
    _allowancesController.dispose();
    _deductionsController.dispose();
    _providentFundPercentageController.dispose();
    _healthInsurancePercentageController.dispose();
    _socialSecurityPercentageController.dispose();
    _salaryGradeController.dispose();
    _payGradeController.dispose();
    _notesController.dispose();
    _effectiveDateController.dispose();
    // Dispose new controllers
    _wageFactorController.dispose();
    _salaryPercentageController.dispose();
    _phoneAllowanceController.dispose();
    _continueEducationAllowanceController.dispose();
    _equipmentAllowanceController.dispose();
    _tithePercentageController.dispose();
    // Dispose health benefits controllers
    _outPatientPercentageController.dispose();
    _inPatientPercentageController.dispose();
    _annualLeaveDaysController.dispose();
    _housingAllowanceController.dispose();
    // Dispose house rental controller
    _houseRentalPercentageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isEffectiveDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isEffectiveDate
          ? _effectiveDate ?? DateTime.now()
          : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      if (isEffectiveDate) {
        _effectiveDate = picked;
        _effectiveDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      } else {
        _endDate = picked;
      }
    }
  }

  // Calculate Gross Salary from Wage Factor and Salary Percentage
  double _calculateGrossSalary() {
    final wageFactor = double.tryParse(_wageFactorController.text) ?? 0;
    final salaryPercentage =
        double.tryParse(_salaryPercentageController.text) ?? 0;
    return wageFactor * (salaryPercentage / 100);
  }

  // Calculate Tithe from Gross Salary
  double _calculateTithe() {
    final grossSalary = _calculateGrossSalary();
    final tithePercentage =
        double.tryParse(_tithePercentageController.text) ?? 0;
    return grossSalary * (tithePercentage / 100);
  }

  // Calculate Provident Fund from Gross Salary
  double _calculateProvidentFund() {
    final grossSalary = _calculateGrossSalary();
    final providentFundPercentage =
        double.tryParse(_providentFundPercentageController.text) ?? 0;
    return grossSalary * (providentFundPercentage / 100);
  }

  // Calculate Social Security (fixed amount)
  double _calculateSocialSecurity() {
    return double.tryParse(_socialSecurityPercentageController.text) ?? 0;
  }

  // Calculate House Rental (from Gross Salary, excluded from net salary)
  double _calculateHouseRental() {
    final grossSalary = _calculateGrossSalary();
    final houseRentalPercentage =
        double.tryParse(_houseRentalPercentageController.text) ?? 0;
    return grossSalary * (houseRentalPercentage / 100);
  }

  // Calculate Total Deductions (including house rental)
  double _calculateTotalDeductions() {
    return _calculateTithe() +
        _calculateProvidentFund() +
        _calculateSocialSecurity() +
        _calculateHouseRental();
  }

  // Calculate Net Salary (Gross Salary - All Deductions, excluding Housing Allowance)
  double _calculateNetSalary() {
    final grossSalary = _calculateGrossSalary();
    final totalDeductions = _calculateTotalDeductions();
    return grossSalary - totalDeductions;
  }

  Future<void> _saveSalaryBenefits() async {
    debugPrint('Debug: Starting _saveSalaryBenefits method'); // Debug message
    if (!_formKey.currentState!.validate()) {
      debugPrint('Debug: Form validation failed'); // Debug message
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if staff is loaded
      if (_staff == null) {
        debugPrint(
          'Debug: Staff is null, cannot save salary benefits',
        ); // Debug message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Staff information not loaded'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      debugPrint('Debug: Preparing SalaryBenefits object'); // Debug message
      final salaryBenefits = SalaryBenefits(
        id:
            _editingSalaryBenefitsId ??
            widget.salaryBenefitsId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        staffId: _staff!.id,
        baseSalary:
            _calculateGrossSalary(), // Use calculated gross salary as base
        overtimeRate: _overtimeRateController.text.isNotEmpty
            ? double.parse(_overtimeRateController.text)
            : null,
        bonus: _bonusController.text.isNotEmpty
            ? double.parse(_bonusController.text)
            : null,
        commission: _commissionController.text.isNotEmpty
            ? double.parse(_commissionController.text)
            : null,
        allowances: _allowancesController.text.isNotEmpty
            ? double.parse(_allowancesController.text)
            : null,
        deductions:
            _calculateTotalDeductions(), // Use calculated total deductions
        providentFundPercentage:
            _providentFundPercentageController.text.isNotEmpty
            ? double.parse(_providentFundPercentageController.text)
            : null,
        healthInsurancePercentage:
            _healthInsurancePercentageController.text.isNotEmpty
            ? double.parse(_healthInsurancePercentageController.text)
            : null,
        socialSecurityPercentage:
            _socialSecurityPercentageController.text.isNotEmpty
            ? double.parse(_socialSecurityPercentageController.text)
            : null,
        salaryGrade: _salaryGradeController.text.isNotEmpty
            ? _salaryGradeController.text
            : null,
        payGrade: _payGradeController.text.isNotEmpty
            ? _payGradeController.text
            : null,
        currency: _currency,
        isActive: _isActive,
        effectiveDate: _effectiveDate ?? DateTime.now(),
        endDate: _endDate,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        createdAt: _existingCreatedAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        // Salary structure fields
        wageFactor: _wageFactorController.text.isNotEmpty
            ? double.parse(_wageFactorController.text)
            : null,
        salaryPercentage: _salaryPercentageController.text.isNotEmpty
            ? double.parse(_salaryPercentageController.text)
            : null,
        phoneAllowance: _phoneAllowanceController.text.isNotEmpty
            ? double.parse(_phoneAllowanceController.text)
            : null,
        continueEducationAllowance:
            _continueEducationAllowanceController.text.isNotEmpty
            ? double.parse(_continueEducationAllowanceController.text)
            : null,
        equipmentAllowance: _equipmentAllowanceController.text.isNotEmpty
            ? double.parse(_equipmentAllowanceController.text)
            : null,
        tithePercentage: _tithePercentageController.text.isNotEmpty
            ? double.parse(_tithePercentageController.text)
            : null,
        // Health Benefits fields
        outPatientPercentage: _outPatientPercentageController.text.isNotEmpty
            ? double.parse(_outPatientPercentageController.text)
            : null,
        inPatientPercentage: _inPatientPercentageController.text.isNotEmpty
            ? double.parse(_inPatientPercentageController.text)
            : null,
        annualLeaveDays: _annualLeaveDaysController.text.isNotEmpty
            ? int.parse(_annualLeaveDaysController.text)
            : null,
        housingAllowance: _housingAllowanceController.text.isNotEmpty
            ? double.parse(_housingAllowanceController.text)
            : null,
        // House Rental
        houseRentalPercentage: _houseRentalPercentageController.text.isNotEmpty
            ? double.parse(_houseRentalPercentageController.text)
            : null,
      );

      debugPrint(
        'Debug: Created SalaryBenefits object for staff: ${salaryBenefits.staffId}',
      ); // Debug message
      debugPrint(
        'Debug: Base salary: ${salaryBenefits.baseSalary}',
      ); // Debug message

      if (_editingSalaryBenefitsId != null || widget.salaryBenefitsId != null) {
        debugPrint(
          'Debug: Updating existing salary benefits record',
        ); // Debug message
        // Update existing
        await _salaryBenefitsService.updateSalaryBenefits(salaryBenefits);
      } else {
        debugPrint('Debug: Creating new salary benefits record'); // Debug message
        // Create new
        await _salaryBenefitsService.createSalaryBenefits(salaryBenefits);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.salaryBenefitsId != null
                  ? 'Salary & Benefits updated successfully'
                  : 'Salary & Benefits added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to the management screen
        context.pop();
      }
    } catch (e) {
      debugPrint('Debug: Error in _saveSalaryBenefits: $e'); // Debug message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving salary & benefits: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    IconData? icon,
    String? helperText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade600) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Color> iconGradient,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconGradient[0].withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
              border: Border(
                left: BorderSide(color: iconGradient[0], width: 4),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: iconGradient[0].withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconGradient[0],
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatedValueCard({
    required String label,
    required double value,
    required MaterialColor color,
    bool isLarge = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 20 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            'THB ${NumberFormat('#,##0').format(value)}',
            style: TextStyle(
              fontSize: isLarge ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.salaryBenefitsId != null;

    final isMobile = ResponsiveHelper.isMobile(context);
    final staff = _staff;

    final header = Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.purple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 8,
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
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                )
              else
                _buildHeaderActionButton(
                  icon: Icons.save,
                  tooltip: 'Save',
                  onPressed: _saveSalaryBenefits,
                ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          if (staff != null)
            Row(
              children: [
                Container(
                  width: isMobile ? 50 : 60,
                  height: isMobile ? 50 : 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 2),
                    image: staff.photoUrl != null
                        ? DecorationImage(
                            image: NetworkImage(staff.photoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: staff.photoUrl == null
                      ? Center(
                          child: Text(
                            staff.fullName.isNotEmpty
                                ? staff.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.fullName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isEditing
                            ? 'Edit Salary & Benefits'
                            : 'Add Salary & Benefits',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          staff.employeeId,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isEditing ? 'Edit Salary & Benefits' : 'Add Salary & Benefits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    final wrappedHeader = Padding(
      padding: ResponsiveHelper.getScreenPadding(context),
      child: ResponsiveContainer(child: header),
    );

    if (!_isInitialized || _staff == null) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Column(
          children: [
            wrappedHeader,
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    final content = SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxContentWidth(context),
          ),
          padding: ResponsiveHelper.getScreenPadding(context),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Staff Information Card
                _buildSectionCard(
                  title: 'Staff Information',
                  icon: Icons.person,
                  iconGradient: [Colors.blue.shade400, Colors.blue.shade600],
                  children: [
                    _buildStaffInfoRow('Name', _staff?.fullName ?? ''),
                    _buildStaffInfoRow('Employee ID', _staff?.employeeId ?? ''),
                    _buildStaffInfoRow('Position', _staff?.position ?? ''),
                    _buildStaffInfoRow('Department', _staff?.department ?? ''),
                  ],
                ),
                const SizedBox(height: 24),

                // Basic Salary Information Section
                _buildSectionCard(
                  title: 'Basic Salary Information',
                  icon: Icons.attach_money,
                  iconGradient: [Colors.green.shade400, Colors.green.shade600],
                  children: [
                    TextFormField(
                      controller: _wageFactorController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration(
                        label: 'Wage Factor (THB) *',
                        icon: Icons.attach_money,
                        helperText: 'Base wage factor amount',
                      ),
                      onChanged: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter wage factor';
                        if (double.tryParse(value) == null) return 'Please enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _salaryPercentageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration(
                        label: 'Salary Scale (%) *',
                        icon: Icons.percent,
                        helperText: 'Percentage of wage factor',
                      ),
                      onChanged: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please enter salary scale percentage';
                        if (double.tryParse(value) == null) return 'Please enter a valid number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildCalculatedValueCard(
                      label: 'Gross Salary (Calculated):',
                      value: _calculateGrossSalary(),
                      color: Colors.green,
                      isLarge: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _effectiveDateController,
                      readOnly: true,
                      decoration: _buildInputDecoration(
                        label: 'Effective Date *',
                        icon: Icons.calendar_today,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Please select effective date';
                        return null;
                      },
                      onTap: () => _selectDate(isEffectiveDate: true),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Health Benefits Section
                _buildSectionCard(
                  title: 'Health Benefits',
                  icon: Icons.health_and_safety,
                  iconGradient: [Colors.pink.shade400, Colors.pink.shade600],
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _outPatientPercentageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Out-Patient (%)',
                              icon: Icons.local_hospital,
                              hintText: '75',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _inPatientPercentageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'In-Patient (%)',
                              icon: Icons.bed,
                              hintText: '90',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _annualLeaveDaysController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration(
                              label: 'Annual Leave (Days)',
                              icon: Icons.beach_access,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _housingAllowanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Housing Allowance (THB)',
                              icon: Icons.home,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Monthly Allowances Section
                _buildSectionCard(
                  title: 'Monthly Allowances',
                  icon: Icons.account_balance_wallet,
                  iconGradient: [Colors.orange.shade400, Colors.orange.shade600],
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These allowances are paid every month.',
                              style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneAllowanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Phone Allowance (THB/Month)',
                              icon: Icons.phone_android,
                              helperText: 'Monthly amount',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Annual Allowances Section
                _buildSectionCard(
                  title: 'Annual Allowances',
                  icon: Icons.card_giftcard,
                  iconGradient: [Colors.teal.shade400, Colors.teal.shade600],
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.teal.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'These allowances are paid once a year, not monthly.',
                              style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _equipmentAllowanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Equipment Allowance (THB/Year)',
                              icon: Icons.computer,
                              helperText: 'Annual amount',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _continueEducationAllowanceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Continuing Education (THB/Year)',
                              icon: Icons.school,
                              helperText: 'Annual amount',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Deductions Section
                _buildSectionCard(
                  title: 'Deductions',
                  icon: Icons.remove_circle_outline,
                  iconGradient: [Colors.red.shade400, Colors.red.shade600],
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _tithePercentageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Tithe (%)',
                              icon: Icons.volunteer_activism,
                              hintText: '10',
                            ),
                            onChanged: (_) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildCalculatedValueCard(
                            label: 'Tithe Amount:',
                            value: _calculateTithe(),
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _socialSecurityPercentageController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _buildInputDecoration(
                        label: 'Social Security (THB)',
                        icon: Icons.security,
                      ),
                      onChanged: (_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _providentFundPercentageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'Provident Fund (%)',
                              icon: Icons.savings,
                              hintText: '10',
                            ),
                            onChanged: (_) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildCalculatedValueCard(
                            label: 'Provident Fund:',
                            value: _calculateProvidentFund(),
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _houseRentalPercentageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: _buildInputDecoration(
                              label: 'House Rental (%)',
                              icon: Icons.house,
                              hintText: '10',
                            ),
                            onChanged: (_) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() {});
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 3,
                          child: _buildCalculatedValueCard(
                            label: 'House Rental:',
                            value: _calculateHouseRental(),
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCalculatedValueCard(
                      label: 'Total Deductions:',
                      value: _calculateTotalDeductions(),
                      color: Colors.red,
                      isLarge: true,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Additional Information Section
                _buildSectionCard(
                  title: 'Additional Information',
                  icon: Icons.info_outline,
                  iconGradient: [Colors.indigo.shade400, Colors.indigo.shade600],
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: _buildInputDecoration(
                        label: 'Currency',
                        icon: Icons.currency_exchange,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'THB', child: Text('THB (Thai Baht)')),
                        DropdownMenuItem(value: 'USD', child: Text('USD (US Dollar)')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR (Euro)')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP (British Pound)')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() { _currency = value; });
                      },
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Is this salary record currently active?'),
                        value: _isActive,
                        onChanged: (value) => setState(() { _isActive = value; }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _buildInputDecoration(
                        label: 'Notes',
                        icon: Icons.note,
                        hintText: 'Any additional notes...',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Net Salary Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.green.shade500, Colors.green.shade700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Net Salary',
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'THB ${NumberFormat('#,##0').format(_calculateNetSalary())}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          wrappedHeader,
          Expanded(child: content),
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

  Widget _buildStaffInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
