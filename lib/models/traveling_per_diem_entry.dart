import 'package:cloud_firestore/cloud_firestore.dart';

class TravelingPerDiemEntry {
  final String id;
  final String reportId;
  final DateTime date;
  final bool hasBreakfast;
  final bool hasLunch;
  final bool hasSupper;
  final bool hasIncidentMeal;
  final String notes; // Description/notes for the day
  final double breakfastAmount;
  final double lunchAmount;
  final double supperAmount;
  final double incidentMealAmount;
  final double dailyTotal; // Sum of all meals for one person
  final double dailyTotalAllMembers; // dailyTotal * totalMembers
  final DateTime createdAt;
  final DateTime? updatedAt;

  TravelingPerDiemEntry({
    required this.id,
    required this.reportId,
    required this.date,
    this.hasBreakfast = false,
    this.hasLunch = false,
    this.hasSupper = false,
    this.hasIncidentMeal = false,
    this.notes = '',
    required this.breakfastAmount,
    required this.lunchAmount,
    required this.supperAmount,
    required this.incidentMealAmount,
    required this.dailyTotal,
    required this.dailyTotalAllMembers,
    required this.createdAt,
    this.updatedAt,
  });

  // Helper method to calculate amounts based on meal selection and rate
  static TravelingPerDiemEntry create({
    required String id,
    required String reportId,
    required DateTime date,
    required bool hasBreakfast,
    required bool hasLunch,
    required bool hasSupper,
    required bool hasIncidentMeal,
    required String notes,
    required double mealRate,
    required int totalMembers,
  }) {
    final breakfastAmount = hasBreakfast ? mealRate : 0.0;
    final lunchAmount = hasLunch ? mealRate : 0.0;
    final supperAmount = hasSupper ? mealRate : 0.0;
    final incidentMealAmount = hasIncidentMeal ? mealRate : 0.0;
    final dailyTotal = breakfastAmount + lunchAmount + supperAmount + incidentMealAmount;
    final dailyTotalAllMembers = dailyTotal * totalMembers;

    return TravelingPerDiemEntry(
      id: id,
      reportId: reportId,
      date: date,
      hasBreakfast: hasBreakfast,
      hasLunch: hasLunch,
      hasSupper: hasSupper,
      hasIncidentMeal: hasIncidentMeal,
      notes: notes,
      breakfastAmount: breakfastAmount,
      lunchAmount: lunchAmount,
      supperAmount: supperAmount,
      incidentMealAmount: incidentMealAmount,
      dailyTotal: dailyTotal,
      dailyTotalAllMembers: dailyTotalAllMembers,
      createdAt: DateTime.now(),
    );
  }

  int get mealsCount =>
      (hasBreakfast ? 1 : 0) + (hasLunch ? 1 : 0) + (hasSupper ? 1 : 0) + (hasIncidentMeal ? 1 : 0);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportId': reportId,
      'date': Timestamp.fromDate(date),
      'hasBreakfast': hasBreakfast,
      'hasLunch': hasLunch,
      'hasSupper': hasSupper,
      'hasIncidentMeal': hasIncidentMeal,
      'notes': notes,
      'breakfastAmount': breakfastAmount,
      'lunchAmount': lunchAmount,
      'supperAmount': supperAmount,
      'incidentMealAmount': incidentMealAmount,
      'dailyTotal': dailyTotal,
      'dailyTotalAllMembers': dailyTotalAllMembers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory TravelingPerDiemEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TravelingPerDiemEntry(
      id: data['id'] ?? doc.id,
      reportId: data['reportId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      hasBreakfast: data['hasBreakfast'] ?? false,
      hasLunch: data['hasLunch'] ?? false,
      hasSupper: data['hasSupper'] ?? false,
      hasIncidentMeal: data['hasIncidentMeal'] ?? false,
      notes: data['notes'] ?? data['incident'] ?? '', // Backward compatibility
      breakfastAmount: (data['breakfastAmount'] ?? 0.0).toDouble(),
      lunchAmount: (data['lunchAmount'] ?? 0.0).toDouble(),
      supperAmount: (data['supperAmount'] ?? 0.0).toDouble(),
      incidentMealAmount: (data['incidentMealAmount'] ?? 0.0).toDouble(),
      dailyTotal: (data['dailyTotal'] ?? 0.0).toDouble(),
      dailyTotalAllMembers: (data['dailyTotalAllMembers'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory TravelingPerDiemEntry.fromJson(Map<String, dynamic> json) {
    return TravelingPerDiemEntry(
      id: json['id'] ?? '',
      reportId: json['reportId'] ?? '',
      date: json['date'] is Timestamp
          ? (json['date'] as Timestamp).toDate()
          : DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      hasBreakfast: json['hasBreakfast'] ?? false,
      hasLunch: json['hasLunch'] ?? false,
      hasSupper: json['hasSupper'] ?? false,
      hasIncidentMeal: json['hasIncidentMeal'] ?? false,
      notes: json['notes'] ?? json['incident'] ?? '', // Backward compatibility
      breakfastAmount: (json['breakfastAmount'] ?? 0.0).toDouble(),
      lunchAmount: (json['lunchAmount'] ?? 0.0).toDouble(),
      supperAmount: (json['supperAmount'] ?? 0.0).toDouble(),
      incidentMealAmount: (json['incidentMealAmount'] ?? 0.0).toDouble(),
      dailyTotal: (json['dailyTotal'] ?? 0.0).toDouble(),
      dailyTotalAllMembers: (json['dailyTotalAllMembers'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.parse(json['updatedAt']))
          : null,
    );
  }

  TravelingPerDiemEntry copyWith({
    String? id,
    String? reportId,
    DateTime? date,
    bool? hasBreakfast,
    bool? hasLunch,
    bool? hasSupper,
    bool? hasIncidentMeal,
    String? notes,
    double? breakfastAmount,
    double? lunchAmount,
    double? supperAmount,
    double? incidentMealAmount,
    double? dailyTotal,
    double? dailyTotalAllMembers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TravelingPerDiemEntry(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      date: date ?? this.date,
      hasBreakfast: hasBreakfast ?? this.hasBreakfast,
      hasLunch: hasLunch ?? this.hasLunch,
      hasSupper: hasSupper ?? this.hasSupper,
      hasIncidentMeal: hasIncidentMeal ?? this.hasIncidentMeal,
      notes: notes ?? this.notes,
      breakfastAmount: breakfastAmount ?? this.breakfastAmount,
      lunchAmount: lunchAmount ?? this.lunchAmount,
      supperAmount: supperAmount ?? this.supperAmount,
      incidentMealAmount: incidentMealAmount ?? this.incidentMealAmount,
      dailyTotal: dailyTotal ?? this.dailyTotal,
      dailyTotalAllMembers: dailyTotalAllMembers ?? this.dailyTotalAllMembers,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
