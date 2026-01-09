import 'package:cloud_firestore/cloud_firestore.dart';

class StudentTimesheet {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String department;
  final String studentNumber;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final double totalHours;
  final double hourlyRate;
  final double totalAmount;
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'paid'
  final String? notes;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? reportId; // Reference to the monthly report this belongs to
  final String? reportMonth; // Format: "YYYY-MM" for grouping

  StudentTimesheet({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.department,
    required this.studentNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalHours,
    required this.hourlyRate,
    required this.totalAmount,
    this.status = 'draft',
    this.notes,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.reportId,
    this.reportMonth,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'department': department,
      'studentNumber': studentNumber,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'totalHours': totalHours,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'status': status,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'reportId': reportId,
      'reportMonth': reportMonth,
    };
  }

  factory StudentTimesheet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentTimesheet(
      id: data['id'] ?? doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      department: data['department'] ?? '',
      studentNumber: data['studentNumber'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      totalHours: (data['totalHours'] ?? 0.0).toDouble(),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'draft',
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      reportId: data['reportId'],
      reportMonth: data['reportMonth'],
    );
  }

  StudentTimesheet copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? department,
    String? studentNumber,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    double? totalHours,
    double? hourlyRate,
    double? totalAmount,
    String? status,
    String? notes,
    DateTime? createdAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? reportId,
    String? reportMonth,
  }) {
    return StudentTimesheet(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      department: department ?? this.department,
      studentNumber: studentNumber ?? this.studentNumber,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalHours: totalHours ?? this.totalHours,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      reportId: reportId ?? this.reportId,
      reportMonth: reportMonth ?? this.reportMonth,
    );
  }
}

class StudentProfile {
  final String userId;
  final String studentNumber;
  final String phoneNumber;
  final String course;
  final String yearLevel;
  final double hourlyRate;
  final DateTime? onboardedAt;

  StudentProfile({
    required this.userId,
    required this.studentNumber,
    required this.phoneNumber,
    required this.course,
    required this.yearLevel,
    this.hourlyRate = 0.0,
    this.onboardedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'studentNumber': studentNumber,
      'phoneNumber': phoneNumber,
      'course': course,
      'yearLevel': yearLevel,
      'hourlyRate': hourlyRate,
      'onboardedAt': onboardedAt != null
          ? Timestamp.fromDate(onboardedAt!)
          : null,
    };
  }

  factory StudentProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentProfile(
      userId: data['userId'] ?? doc.id,
      studentNumber: data['studentNumber'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      course: data['course'] ?? '',
      yearLevel: data['yearLevel'] ?? '',
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      onboardedAt: data['onboardedAt'] != null
          ? (data['onboardedAt'] as Timestamp).toDate()
          : null,
    );
  }

  StudentProfile copyWith({
    String? userId,
    String? studentNumber,
    String? phoneNumber,
    String? course,
    String? yearLevel,
    double? hourlyRate,
    DateTime? onboardedAt,
  }) {
    return StudentProfile(
      userId: userId ?? this.userId,
      studentNumber: studentNumber ?? this.studentNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      course: course ?? this.course,
      yearLevel: yearLevel ?? this.yearLevel,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      onboardedAt: onboardedAt ?? this.onboardedAt,
    );
  }
}

// Monthly Report Model
class StudentMonthlyReport {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String month; // Format: "YYYY-MM"
  final String monthDisplay; // Format: "January 2026"
  final int timesheetCount;
  final double totalHours;
  final double hourlyRate;
  final double totalAmount;
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'paid'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? notes;

  StudentMonthlyReport({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.month,
    required this.monthDisplay,
    required this.timesheetCount,
    required this.totalHours,
    required this.hourlyRate,
    required this.totalAmount,
    this.status = 'draft',
    required this.createdAt,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'month': month,
      'monthDisplay': monthDisplay,
      'timesheetCount': timesheetCount,
      'totalHours': totalHours,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'notes': notes,
    };
  }

  factory StudentMonthlyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentMonthlyReport(
      id: data['id'] ?? doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      month: data['month'] ?? '',
      monthDisplay: data['monthDisplay'] ?? '',
      timesheetCount: data['timesheetCount'] ?? 0,
      totalHours: (data['totalHours'] ?? 0.0).toDouble(),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'draft',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      notes: data['notes'],
    );
  }
}
