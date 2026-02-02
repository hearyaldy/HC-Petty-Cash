import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class SalaryBenefits {
  final String id;
  final String staffId;
  final double baseSalary;
  final double? overtimeRate; // Per hour
  final double? bonus;
  final double? commission;
  final double? allowances; // Housing, transportation, etc.
  final double? deductions; // Tax, insurance, etc.
  final double? providentFundPercentage;
  final double? healthInsurancePercentage;
  final double? socialSecurityPercentage;
  final String? salaryGrade;
  final String? payGrade;
  final String? currency;
  final bool isActive;
  final DateTime effectiveDate;
  final DateTime? endDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // New fields for the updated salary structure
  final double? wageFactor; // Wage factor (e.g., THB 41,500.00)
  final double? salaryPercentage; // Current salary percentage from wage factor
  final double? phoneAllowance;
  final double? continueEducationAllowance;
  final double? equipmentAllowance;
  final double? tithePercentage; // Tithe percentage (e.g., 10%)

  // Health Benefits
  final double? outPatientPercentage; // Out Patient coverage (e.g., 75%)
  final double? inPatientPercentage; // In-Patient coverage (e.g., 90%)
  final int? annualLeaveDays; // Annual leave days
  final double? housingAllowance; // Housing allowance amount

  // House Rental Deduction
  final double? houseRentalPercentage; // House rental percentage (e.g., 10%)

  SalaryBenefits({
    required this.id,
    required this.staffId,
    required this.baseSalary,
    this.overtimeRate,
    this.bonus,
    this.commission,
    this.allowances,
    this.deductions,
    this.providentFundPercentage,
    this.healthInsurancePercentage,
    this.socialSecurityPercentage,
    this.salaryGrade,
    this.payGrade,
    this.currency,
    this.isActive = true,
    required this.effectiveDate,
    this.endDate,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.wageFactor,
    this.salaryPercentage,
    this.phoneAllowance,
    this.continueEducationAllowance,
    this.equipmentAllowance,
    this.tithePercentage,
    this.outPatientPercentage,
    this.inPatientPercentage,
    this.annualLeaveDays,
    this.housingAllowance,
    this.houseRentalPercentage,
  });

  // Calculate gross salary from wage factor and salary percentage
  double get grossSalary {
    if (wageFactor != null && salaryPercentage != null) {
      return wageFactor! * (salaryPercentage! / 100);
    }
    // Fallback to base salary if wage factor not set
    return baseSalary;
  }

  // Calculate total compensation (gross + monthly allowances)
  // Note: Equipment and Education allowances are annual, not included in monthly total
  double get totalCompensation {
    double total = grossSalary;
    total += allowances ?? 0;
    total += phoneAllowance ?? 0;
    // Equipment and Education allowances are annual (once a year), not monthly
    // total += continueEducationAllowance ?? 0;
    // total += equipmentAllowance ?? 0;
    total += housingAllowance ?? 0;
    return total;
  }

  // Calculate annual total compensation including yearly allowances
  double get annualTotalCompensation {
    double total = totalCompensation * 12; // Monthly total x 12
    total += continueEducationAllowance ?? 0; // Add annual education allowance
    total += equipmentAllowance ?? 0; // Add annual equipment allowance
    return total;
  }

  // Calculate net salary (Gross Salary - All Deductions, excluding Housing Allowance)
  double get netSalary {
    double total =
        grossSalary; // Start with gross salary only, not total compensation
    total -= titheAmount;
    total -= providentFundAmount;
    total -= socialSecurityAmount;
    total -= houseRentalAmount;
    return total;
  }

  // Calculate tithe amount (from gross salary)
  double get titheAmount {
    if (tithePercentage != null) {
      return grossSalary * (tithePercentage! / 100);
    }
    return 0;
  }

  // Calculate provident fund amount (from gross salary)
  double get providentFundAmount {
    if (providentFundPercentage != null) {
      return grossSalary * (providentFundPercentage! / 100);
    }
    return 0;
  }

  // Social security is a fixed amount (not percentage)
  double get socialSecurityAmount {
    return socialSecurityPercentage ?? 0;
  }

  // Calculate house rental amount (from gross salary, excluded from net salary)
  double get houseRentalAmount {
    if (houseRentalPercentage != null) {
      return grossSalary * (houseRentalPercentage! / 100);
    }
    return 0;
  }

  // Calculate current salary based on wage factor and percentage
  double get currentSalary {
    if (wageFactor != null && salaryPercentage != null) {
      return wageFactor! * (salaryPercentage! / 100);
    }
    return baseSalary;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'baseSalary': baseSalary,
      'overtimeRate': overtimeRate,
      'bonus': bonus,
      'commission': commission,
      'allowances': allowances,
      'deductions': deductions,
      'providentFundPercentage': providentFundPercentage,
      'healthInsurancePercentage': healthInsurancePercentage,
      'socialSecurityPercentage': socialSecurityPercentage,
      'salaryGrade': salaryGrade,
      'payGrade': payGrade,
      'currency': currency ?? 'THB', // Default to Thai Baht
      'isActive': isActive,
      'effectiveDate': firestore.Timestamp.fromDate(effectiveDate),
      'endDate': endDate != null
          ? firestore.Timestamp.fromDate(endDate!)
          : null,
      'notes': notes,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : null,
      // New fields for updated salary structure
      'wageFactor': wageFactor,
      'salaryPercentage': salaryPercentage,
      'phoneAllowance': phoneAllowance,
      'continueEducationAllowance': continueEducationAllowance,
      'equipmentAllowance': equipmentAllowance,
      'tithePercentage': tithePercentage,
      // Health Benefits
      'outPatientPercentage': outPatientPercentage,
      'inPatientPercentage': inPatientPercentage,
      'annualLeaveDays': annualLeaveDays,
      'housingAllowance': housingAllowance,
      // House Rental
      'houseRentalPercentage': houseRentalPercentage,
    };
  }

  factory SalaryBenefits.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SalaryBenefits(
      id: doc.id,
      staffId: data['staffId'] as String,
      baseSalary: (data['baseSalary'] as num).toDouble(),
      overtimeRate: data['overtimeRate'] != null
          ? (data['overtimeRate'] as num).toDouble()
          : null,
      bonus: data['bonus'] != null ? (data['bonus'] as num).toDouble() : null,
      commission: data['commission'] != null
          ? (data['commission'] as num).toDouble()
          : null,
      allowances: data['allowances'] != null
          ? (data['allowances'] as num).toDouble()
          : null,
      deductions: data['deductions'] != null
          ? (data['deductions'] as num).toDouble()
          : null,
      providentFundPercentage: data['providentFundPercentage'] != null
          ? (data['providentFundPercentage'] as num).toDouble()
          : null,
      healthInsurancePercentage: data['healthInsurancePercentage'] != null
          ? (data['healthInsurancePercentage'] as num).toDouble()
          : null,
      socialSecurityPercentage: data['socialSecurityPercentage'] != null
          ? (data['socialSecurityPercentage'] as num).toDouble()
          : null,
      salaryGrade: data['salaryGrade'] as String?,
      payGrade: data['payGrade'] as String?,
      currency: data['currency'] as String? ?? 'THB',
      isActive: data['isActive'] as bool? ?? true,
      effectiveDate: (data['effectiveDate'] as firestore.Timestamp).toDate(),
      endDate: data['endDate'] != null
          ? (data['endDate'] as firestore.Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as firestore.Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
      // New fields for updated salary structure
      wageFactor: data['wageFactor'] != null
          ? (data['wageFactor'] as num?)?.toDouble()
          : null,
      salaryPercentage: data['salaryPercentage'] != null
          ? (data['salaryPercentage'] as num?)?.toDouble()
          : null,
      phoneAllowance: data['phoneAllowance'] != null
          ? (data['phoneAllowance'] as num?)?.toDouble()
          : null,
      continueEducationAllowance: data['continueEducationAllowance'] != null
          ? (data['continueEducationAllowance'] as num?)?.toDouble()
          : null,
      equipmentAllowance: data['equipmentAllowance'] != null
          ? (data['equipmentAllowance'] as num?)?.toDouble()
          : null,
      tithePercentage: data['tithePercentage'] != null
          ? (data['tithePercentage'] as num?)?.toDouble()
          : null,
      // Health Benefits
      outPatientPercentage: data['outPatientPercentage'] != null
          ? (data['outPatientPercentage'] as num?)?.toDouble()
          : null,
      inPatientPercentage: data['inPatientPercentage'] != null
          ? (data['inPatientPercentage'] as num?)?.toDouble()
          : null,
      annualLeaveDays: data['annualLeaveDays'] != null
          ? (data['annualLeaveDays'] as num?)?.toInt()
          : null,
      housingAllowance: data['housingAllowance'] != null
          ? (data['housingAllowance'] as num?)?.toDouble()
          : null,
      // House Rental
      houseRentalPercentage: data['houseRentalPercentage'] != null
          ? (data['houseRentalPercentage'] as num?)?.toDouble()
          : null,
    );
  }

  SalaryBenefits copyWith({
    String? id,
    String? staffId,
    double? baseSalary,
    double? overtimeRate,
    double? bonus,
    double? commission,
    double? allowances,
    double? deductions,
    double? providentFundPercentage,
    double? healthInsurancePercentage,
    double? socialSecurityPercentage,
    String? salaryGrade,
    String? payGrade,
    String? currency,
    bool? isActive,
    DateTime? effectiveDate,
    DateTime? endDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? wageFactor,
    double? salaryPercentage,
    double? phoneAllowance,
    double? continueEducationAllowance,
    double? equipmentAllowance,
    double? tithePercentage,
    double? outPatientPercentage,
    double? inPatientPercentage,
    int? annualLeaveDays,
    double? housingAllowance,
    double? houseRentalPercentage,
  }) {
    return SalaryBenefits(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      baseSalary: baseSalary ?? this.baseSalary,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      bonus: bonus ?? this.bonus,
      commission: commission ?? this.commission,
      allowances: allowances ?? this.allowances,
      deductions: deductions ?? this.deductions,
      providentFundPercentage:
          providentFundPercentage ?? this.providentFundPercentage,
      healthInsurancePercentage:
          healthInsurancePercentage ?? this.healthInsurancePercentage,
      socialSecurityPercentage:
          socialSecurityPercentage ?? this.socialSecurityPercentage,
      salaryGrade: salaryGrade ?? this.salaryGrade,
      payGrade: payGrade ?? this.payGrade,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // New fields for updated salary structure
      wageFactor: wageFactor ?? this.wageFactor,
      salaryPercentage: salaryPercentage ?? this.salaryPercentage,
      phoneAllowance: phoneAllowance ?? this.phoneAllowance,
      continueEducationAllowance:
          continueEducationAllowance ?? this.continueEducationAllowance,
      equipmentAllowance: equipmentAllowance ?? this.equipmentAllowance,
      tithePercentage: tithePercentage ?? this.tithePercentage,
      // Health Benefits
      outPatientPercentage: outPatientPercentage ?? this.outPatientPercentage,
      inPatientPercentage: inPatientPercentage ?? this.inPatientPercentage,
      annualLeaveDays: annualLeaveDays ?? this.annualLeaveDays,
      housingAllowance: housingAllowance ?? this.housingAllowance,
      // House Rental
      houseRentalPercentage:
          houseRentalPercentage ?? this.houseRentalPercentage,
    );
  }
}
