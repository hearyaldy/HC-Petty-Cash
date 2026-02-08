import 'package:cloud_firestore/cloud_firestore.dart';

class AnnualLeaveRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String department;
  final String? employeeId;
  final String? position;
  final String? email;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;
  final String status; // submitted, approved, rejected
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? actionNumber;
  final String? rejectionReason;

  AnnualLeaveRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    this.employeeId,
    this.position,
    this.email,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.approvedBy,
    this.approvedAt,
    this.actionNumber,
    this.rejectionReason,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'employeeId': employeeId,
      'position': position,
      'email': email,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'reason': reason,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'actionNumber': actionNumber,
      'rejectionReason': rejectionReason,
    };
  }

  factory AnnualLeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    DateTime? parseTimestampOptional(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    final now = DateTime.now();

    return AnnualLeaveRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      department: data['department'] ?? '',
      employeeId: data['employeeId'],
      position: data['position'],
      email: data['email'],
      startDate: parseTimestamp(data['startDate'], now),
      endDate: parseTimestamp(data['endDate'], now),
      totalDays: (data['totalDays'] ?? 0) as int,
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'submitted',
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: parseTimestampOptional(data['updatedAt']),
      approvedBy: data['approvedBy'],
      approvedAt: parseTimestampOptional(data['approvedAt']),
      actionNumber: data['actionNumber'],
      rejectionReason: data['rejectionReason'],
    );
  }
}
