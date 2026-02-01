import 'package:cloud_firestore/cloud_firestore.dart';

// Task type options for student work
enum TaskType {
  videoEditing,
  contentCreation,
  translation,
  research,
  production,
  languageEditing,
  other,
}

extension TaskTypeExtension on TaskType {
  String get displayName {
    switch (this) {
      case TaskType.videoEditing:
        return 'Video Editing';
      case TaskType.contentCreation:
        return 'Content Creation';
      case TaskType.translation:
        return 'Translation';
      case TaskType.research:
        return 'Research';
      case TaskType.production:
        return 'Production';
      case TaskType.languageEditing:
        return 'Language Editing';
      case TaskType.other:
        return 'Other';
    }
  }

  String get value => name;

  static TaskType fromString(String? value) {
    if (value == null) return TaskType.other;
    return TaskType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskType.other,
    );
  }
}

// Task status options
enum TaskStatus {
  notStarted,
  inProgress,
  completed,
  onHold,
}

extension TaskStatusExtension on TaskStatus {
  String get displayName {
    switch (this) {
      case TaskStatus.notStarted:
        return 'Not Started';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.onHold:
        return 'On Hold';
    }
  }

  String get value => name;

  static TaskStatus fromString(String? value) {
    if (value == null) return TaskStatus.notStarted;
    return TaskStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskStatus.notStarted,
    );
  }
}

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
  final String task; // Task/work done description (required) - kept for backward compatibility
  final String? taskType; // Task type from dropdown (e.g., 'videoEditing', 'contentCreation')
  final String? taskTitle; // Specific title for the work
  final String? taskDescription; // Detailed description of the task
  final int taskProgress; // Progress percentage (0-100)
  final String? taskStatus; // Task completion status ('notStarted', 'inProgress', 'completed', 'onHold')
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
    required this.task,
    this.taskType,
    this.taskTitle,
    this.taskDescription,
    this.taskProgress = 0,
    this.taskStatus,
    this.notes,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.reportId,
    this.reportMonth,
  });

  // Helper getters for enums
  TaskType get taskTypeEnum => TaskTypeExtension.fromString(taskType);
  TaskStatus get taskStatusEnum => TaskStatusExtension.fromString(taskStatus);

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
      'task': task,
      'taskType': taskType,
      'taskTitle': taskTitle,
      'taskDescription': taskDescription,
      'taskProgress': taskProgress,
      'taskStatus': taskStatus,
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

    // Helper function to safely parse Timestamp
    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    return StudentTimesheet(
      id: data['id'] ?? doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      department: data['department'] ?? '',
      studentNumber: data['studentNumber'] ?? '',
      date: parseTimestamp(data['date'], now),
      startTime: parseTimestamp(data['startTime'], now),
      endTime: parseTimestamp(data['endTime'], now),
      totalHours: (data['totalHours'] ?? 0.0).toDouble(),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'draft',
      task: data['task'] ?? '',
      taskType: data['taskType'],
      taskTitle: data['taskTitle'],
      taskDescription: data['taskDescription'],
      taskProgress: (data['taskProgress'] ?? 0).toInt(),
      taskStatus: data['taskStatus'],
      notes: data['notes'],
      createdAt: parseTimestamp(data['createdAt'], now),
      approvedAt: data['approvedAt'] != null
          ? parseTimestamp(data['approvedAt'], now)
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
    String? task,
    String? taskType,
    String? taskTitle,
    String? taskDescription,
    int? taskProgress,
    String? taskStatus,
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
      task: task ?? this.task,
      taskType: taskType ?? this.taskType,
      taskTitle: taskTitle ?? this.taskTitle,
      taskDescription: taskDescription ?? this.taskDescription,
      taskProgress: taskProgress ?? this.taskProgress,
      taskStatus: taskStatus ?? this.taskStatus,
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
  final String? language;
  final String? role;
  final String? grade; // 'A', 'B', 'C', 'D'
  final double hourlyRate;
  final DateTime? onboardedAt;
  final String? photoUrl;

  StudentProfile({
    required this.userId,
    required this.studentNumber,
    required this.phoneNumber,
    required this.course,
    required this.yearLevel,
    this.language,
    this.role,
    this.grade,
    this.hourlyRate = 0.0,
    this.onboardedAt,
    this.photoUrl,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'studentNumber': studentNumber,
      'phoneNumber': phoneNumber,
      'course': course,
      'yearLevel': yearLevel,
      'language': language,
      'role': role,
      'grade': grade,
      'hourlyRate': hourlyRate,
      'onboardedAt': onboardedAt != null
          ? Timestamp.fromDate(onboardedAt!)
          : null,
      'photoUrl': photoUrl,
    };
  }

  factory StudentProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper function to safely parse Timestamp
    DateTime? parseTimestampOptional(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return StudentProfile(
      userId: data['userId'] ?? doc.id,
      studentNumber: data['studentNumber'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      course: data['course'] ?? '',
      yearLevel: data['yearLevel'] ?? '',
      language: data['language'],
      role: data['role'],
      grade: data['grade'],
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      onboardedAt: parseTimestampOptional(data['onboardedAt']),
      photoUrl: data['photoUrl'],
    );
  }

  StudentProfile copyWith({
    String? userId,
    String? studentNumber,
    String? phoneNumber,
    String? course,
    String? yearLevel,
    String? language,
    String? role,
    String? grade,
    double? hourlyRate,
    DateTime? onboardedAt,
    String? photoUrl,
  }) {
    return StudentProfile(
      userId: userId ?? this.userId,
      studentNumber: studentNumber ?? this.studentNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      course: course ?? this.course,
      yearLevel: yearLevel ?? this.yearLevel,
      language: language ?? this.language,
      role: role ?? this.role,
      grade: grade ?? this.grade,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

// Monthly Report Model
class StudentMonthlyReport {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentNumber;
  final String department;
  final String month; // Format: "YYYY-MM"
  final String monthDisplay; // Format: "January 2026"
  final int timesheetCount;
  final double totalHours;
  final double hourlyRate;
  final double totalAmount;
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'paid'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? paidAt;
  final String? paidBy;
  final String? notes;

  StudentMonthlyReport({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    this.studentNumber = '',
    this.department = '',
    required this.month,
    required this.monthDisplay,
    required this.timesheetCount,
    required this.totalHours,
    required this.hourlyRate,
    required this.totalAmount,
    this.status = 'draft',
    required this.createdAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    this.paidAt,
    this.paidBy,
    this.notes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'studentEmail': studentEmail,
      'studentNumber': studentNumber,
      'department': department,
      'month': month,
      'monthDisplay': monthDisplay,
      'timesheetCount': timesheetCount,
      'totalHours': totalHours,
      'hourlyRate': hourlyRate,
      'totalAmount': totalAmount,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'submittedBy': submittedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paidBy': paidBy,
      'notes': notes,
    };
  }

  factory StudentMonthlyReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Helper function to safely parse Timestamp
    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    final now = DateTime.now();

    return StudentMonthlyReport(
      id: data['id'] ?? doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentEmail: data['studentEmail'] ?? '',
      studentNumber: data['studentNumber'] ?? '',
      department: data['department'] ?? '',
      month: data['month'] ?? '',
      monthDisplay: data['monthDisplay'] ?? '',
      timesheetCount: data['timesheetCount'] ?? 0,
      totalHours: (data['totalHours'] ?? 0.0).toDouble(),
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      status: data['status'] ?? 'draft',
      createdAt: parseTimestamp(data['createdAt'], now),
      submittedAt: data['submittedAt'] != null
          ? parseTimestamp(data['submittedAt'], now)
          : null,
      submittedBy: data['submittedBy'],
      approvedAt: data['approvedAt'] != null
          ? parseTimestamp(data['approvedAt'], now)
          : null,
      approvedBy: data['approvedBy'],
      paidAt: data['paidAt'] != null
          ? parseTimestamp(data['paidAt'], now)
          : null,
      paidBy: data['paidBy'],
      notes: data['notes'],
    );
  }
}
