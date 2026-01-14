import 'package:cloud_firestore/cloud_firestore.dart';
import 'enums.dart';

class TravelingReport {
  final String id;
  final String reportNumber; // Format: TR-YYYYMMDD-XXX
  final String reporterId;
  final String reporterName;
  final String department;
  final DateTime reportDate;
  final String purpose;
  final String placeName;
  final DateTime departureTime;
  final DateTime destinationTime;
  final int totalMembers;
  final String travelLocation; // 'local' or 'abroad'

  // Mileage fields
  final double mileageStart;
  final double mileageEnd;

  // Per diem totals (calculated from entries)
  final double perDiemTotal;
  final int perDiemDays;

  // Status and approval
  final String status; // 'draft', 'submitted', 'approved', 'rejected', 'closed'
  final DateTime createdAt;
  final DateTime? submittedAt;
  final String? submittedBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? rejectionReason;
  final String? notes;
  final List<String> supportDocumentUrls; // Support document URLs
  final DateTime? updatedAt;

  TravelingReport({
    required this.id,
    required this.reportNumber,
    required this.reporterId,
    required this.reporterName,
    required this.department,
    required this.reportDate,
    required this.purpose,
    required this.placeName,
    required this.departureTime,
    required this.destinationTime,
    required this.totalMembers,
    this.travelLocation = 'local',
    required this.mileageStart,
    required this.mileageEnd,
    this.perDiemTotal = 0.0,
    this.perDiemDays = 0,
    this.status = 'draft',
    required this.createdAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    this.notes,
    List<String>? supportDocumentUrls,
    this.updatedAt,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  // Calculated getters
  double get totalKM => mileageEnd - mileageStart;

  double get mileageAmount => totalKM * 5.0; // 5 Baht per KM

  double get grandTotal => mileageAmount + perDiemTotal;

  ReportStatus get statusEnum => status.toReportStatus();

  TravelLocation get travelLocationEnum => travelLocation.toTravelLocation();

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'reportNumber': reportNumber,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'department': department,
      'reportDate': Timestamp.fromDate(reportDate),
      'purpose': purpose,
      'placeName': placeName,
      'departureTime': Timestamp.fromDate(departureTime),
      'destinationTime': Timestamp.fromDate(destinationTime),
      'totalMembers': totalMembers,
      'travelLocation': travelLocation,
      'mileageStart': mileageStart,
      'mileageEnd': mileageEnd,
      'perDiemTotal': perDiemTotal,
      'perDiemDays': perDiemDays,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'submittedAt': submittedAt != null
          ? Timestamp.fromDate(submittedAt!)
          : null,
      'submittedBy': submittedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'notes': notes,
      'supportDocumentUrls': supportDocumentUrls,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory TravelingReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TravelingReport(
      id: data['id'] ?? doc.id,
      reportNumber: data['reportNumber'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      department: data['department'] ?? '',
      reportDate: (data['reportDate'] as Timestamp).toDate(),
      purpose: data['purpose'] ?? '',
      placeName: data['placeName'] ?? '',
      departureTime: (data['departureTime'] as Timestamp).toDate(),
      destinationTime: (data['destinationTime'] as Timestamp).toDate(),
      totalMembers: data['totalMembers'] ?? 1,
      travelLocation: data['travelLocation'] ?? 'local',
      mileageStart: (data['mileageStart'] ?? 0.0).toDouble(),
      mileageEnd: (data['mileageEnd'] ?? 0.0).toDouble(),
      perDiemTotal: (data['perDiemTotal'] ?? 0.0).toDouble(),
      perDiemDays: data['perDiemDays'] ?? 0,
      status: data['status'] ?? 'draft',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      submittedBy: data['submittedBy'],
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: data['approvedBy'],
      rejectionReason: data['rejectionReason'],
      notes: data['notes'],
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() => toFirestore();

  factory TravelingReport.fromJson(Map<String, dynamic> json) {
    return TravelingReport(
      id: json['id'] ?? '',
      reportNumber: json['reportNumber'] ?? '',
      reporterId: json['reporterId'] ?? '',
      reporterName: json['reporterName'] ?? '',
      department: json['department'] ?? '',
      reportDate: json['reportDate'] is Timestamp
          ? (json['reportDate'] as Timestamp).toDate()
          : DateTime.parse(
              json['reportDate'] ?? DateTime.now().toIso8601String(),
            ),
      purpose: json['purpose'] ?? '',
      placeName: json['placeName'] ?? '',
      departureTime: json['departureTime'] is Timestamp
          ? (json['departureTime'] as Timestamp).toDate()
          : DateTime.parse(
              json['departureTime'] ?? DateTime.now().toIso8601String(),
            ),
      destinationTime: json['destinationTime'] is Timestamp
          ? (json['destinationTime'] as Timestamp).toDate()
          : DateTime.parse(
              json['destinationTime'] ?? DateTime.now().toIso8601String(),
            ),
      totalMembers: json['totalMembers'] ?? 1,
      travelLocation: json['travelLocation'] ?? 'local',
      mileageStart: (json['mileageStart'] ?? 0.0).toDouble(),
      mileageEnd: (json['mileageEnd'] ?? 0.0).toDouble(),
      perDiemTotal: (json['perDiemTotal'] ?? 0.0).toDouble(),
      perDiemDays: json['perDiemDays'] ?? 0,
      status: json['status'] ?? 'draft',
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(
              json['createdAt'] ?? DateTime.now().toIso8601String(),
            ),
      submittedAt: json['submittedAt'] != null
          ? (json['submittedAt'] is Timestamp
                ? (json['submittedAt'] as Timestamp).toDate()
                : DateTime.parse(json['submittedAt']))
          : null,
      submittedBy: json['submittedBy'],
      approvedAt: json['approvedAt'] != null
          ? (json['approvedAt'] is Timestamp
                ? (json['approvedAt'] as Timestamp).toDate()
                : DateTime.parse(json['approvedAt']))
          : null,
      approvedBy: json['approvedBy'],
      rejectionReason: json['rejectionReason'],
      notes: json['notes'],
      supportDocumentUrls:
          (json['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : DateTime.parse(json['updatedAt']))
          : null,
    );
  }

  TravelingReport copyWith({
    String? id,
    String? reportNumber,
    String? reporterId,
    String? reporterName,
    String? department,
    DateTime? reportDate,
    String? purpose,
    String? placeName,
    DateTime? departureTime,
    DateTime? destinationTime,
    int? totalMembers,
    String? travelLocation,
    double? mileageStart,
    double? mileageEnd,
    double? perDiemTotal,
    int? perDiemDays,
    String? status,
    DateTime? createdAt,
    DateTime? submittedAt,
    String? submittedBy,
    DateTime? approvedAt,
    String? approvedBy,
    String? rejectionReason,
    String? notes,
    List<String>? supportDocumentUrls,
    DateTime? updatedAt,
  }) {
    return TravelingReport(
      id: id ?? this.id,
      reportNumber: reportNumber ?? this.reportNumber,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      department: department ?? this.department,
      reportDate: reportDate ?? this.reportDate,
      purpose: purpose ?? this.purpose,
      placeName: placeName ?? this.placeName,
      departureTime: departureTime ?? this.departureTime,
      destinationTime: destinationTime ?? this.destinationTime,
      totalMembers: totalMembers ?? this.totalMembers,
      travelLocation: travelLocation ?? this.travelLocation,
      mileageStart: mileageStart ?? this.mileageStart,
      mileageEnd: mileageEnd ?? this.mileageEnd,
      perDiemTotal: perDiemTotal ?? this.perDiemTotal,
      perDiemDays: perDiemDays ?? this.perDiemDays,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      submittedAt: submittedAt ?? this.submittedAt,
      submittedBy: submittedBy ?? this.submittedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
