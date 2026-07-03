import 'package:cloud_firestore/cloud_firestore.dart';

class TransportationMileageEntry {
  final String id;
  final String requestId;
  final DateTime date;
  final double mileageStart;
  final double mileageEnd;
  final double ratePerKm;
  final double amount;
  final String? airport; // TaxiAirport.name, only set when this is a taxi fare
  final String? remark;
  final DateTime createdAt;

  TransportationMileageEntry({
    required this.id,
    required this.requestId,
    required this.date,
    required this.mileageStart,
    required this.mileageEnd,
    required this.ratePerKm,
    required this.amount,
    this.airport,
    this.remark,
    required this.createdAt,
  });

  double get totalKm => mileageEnd - mileageStart;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requestId': requestId,
      'date': Timestamp.fromDate(date),
      'mileageStart': mileageStart,
      'mileageEnd': mileageEnd,
      'ratePerKm': ratePerKm,
      'amount': amount,
      'airport': airport,
      'remark': remark,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransportationMileageEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();
    final mileageStart = (data['mileageStart'] ?? 0.0).toDouble();
    final mileageEnd = (data['mileageEnd'] ?? 0.0).toDouble();
    final ratePerKm = (data['ratePerKm'] ?? 5.0).toDouble();
    return TransportationMileageEntry(
      id: data['id'] ?? doc.id,
      requestId: data['requestId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? now,
      mileageStart: mileageStart,
      mileageEnd: mileageEnd,
      ratePerKm: ratePerKm,
      // Backward compatible: older docs didn't store `amount` explicitly.
      amount: (data['amount'] as num?)?.toDouble() ??
          ((mileageEnd - mileageStart) * ratePerKm),
      airport: data['airport'],
      remark: data['remark'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
    );
  }
}

class TransportationPerDiemEntry {
  final String id;
  final String requestId;
  final DateTime date;
  final bool hasBreakfast;
  final bool hasLunch;
  final bool hasSupper;
  final bool hasIncidentMeal;
  final double mealRate;
  final DateTime createdAt;

  TransportationPerDiemEntry({
    required this.id,
    required this.requestId,
    required this.date,
    this.hasBreakfast = false,
    this.hasLunch = false,
    this.hasSupper = false,
    this.hasIncidentMeal = false,
    required this.mealRate,
    required this.createdAt,
  });

  int get mealsCount =>
      (hasBreakfast ? 1 : 0) +
      (hasLunch ? 1 : 0) +
      (hasSupper ? 1 : 0) +
      (hasIncidentMeal ? 1 : 0);

  double get amount => mealsCount * mealRate;

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requestId': requestId,
      'date': Timestamp.fromDate(date),
      'hasBreakfast': hasBreakfast,
      'hasLunch': hasLunch,
      'hasSupper': hasSupper,
      'hasIncidentMeal': hasIncidentMeal,
      'mealRate': mealRate,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransportationPerDiemEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();
    return TransportationPerDiemEntry(
      id: data['id'] ?? doc.id,
      requestId: data['requestId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? now,
      hasBreakfast: data['hasBreakfast'] ?? false,
      hasLunch: data['hasLunch'] ?? false,
      hasSupper: data['hasSupper'] ?? false,
      hasIncidentMeal: data['hasIncidentMeal'] ?? false,
      mealRate: (data['mealRate'] ?? 125.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
    );
  }
}

class TransportationHotelEntry {
  final String id;
  final String requestId;
  final DateTime date;
  final String hotelName;
  final double amount;
  final DateTime createdAt;

  TransportationHotelEntry({
    required this.id,
    required this.requestId,
    required this.date,
    required this.hotelName,
    required this.amount,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requestId': requestId,
      'date': Timestamp.fromDate(date),
      'hotelName': hotelName,
      'amount': amount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TransportationHotelEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();
    return TransportationHotelEntry(
      id: data['id'] ?? doc.id,
      requestId: data['requestId'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? now,
      hotelName: data['hotelName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
    );
  }
}

class TransportationRequest {
  final String id;
  final String requestNumber; // Format: TRQ-YYYYMMDD-XXX
  final String requesterId;
  final String requesterName;
  final String department;
  final DateTime requestDate;
  final String purpose;
  final String destinationPlace;
  final DateTime travelDateTime;
  final DateTime returnDateTime;
  final String travelLocation; // 'local' or 'abroad'
  final String vehicleType; // 'personalVehicle', 'van', 'pickupTruck'
  final String? departureFlightNumber;
  final String? departureFlightTime;
  final String? returnFlightNumber;
  final String? returnFlightTime;
  final String? notes;

  // Denormalized totals, recalculated from sub-entries
  final double totalKm;
  final double totalMileageAmount;
  final double totalPerDiemAmount;
  final double totalHotelAmount;
  final double grandTotal;

  final List<String> supportDocumentUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TransportationRequest({
    required this.id,
    required this.requestNumber,
    required this.requesterId,
    required this.requesterName,
    required this.department,
    required this.requestDate,
    required this.purpose,
    required this.destinationPlace,
    required this.travelDateTime,
    required this.returnDateTime,
    this.travelLocation = 'local',
    this.vehicleType = 'personalVehicle',
    this.departureFlightNumber,
    this.departureFlightTime,
    this.returnFlightNumber,
    this.returnFlightTime,
    this.notes,
    this.totalKm = 0.0,
    this.totalMileageAmount = 0.0,
    this.totalPerDiemAmount = 0.0,
    this.totalHotelAmount = 0.0,
    this.grandTotal = 0.0,
    List<String>? supportDocumentUrls,
    required this.createdAt,
    this.updatedAt,
  }) : supportDocumentUrls = supportDocumentUrls ?? [];

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'requestNumber': requestNumber,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'department': department,
      'requestDate': Timestamp.fromDate(requestDate),
      'purpose': purpose,
      'destinationPlace': destinationPlace,
      'travelDateTime': Timestamp.fromDate(travelDateTime),
      'returnDateTime': Timestamp.fromDate(returnDateTime),
      'travelLocation': travelLocation,
      'vehicleType': vehicleType,
      'departureFlightNumber': departureFlightNumber,
      'departureFlightTime': departureFlightTime,
      'returnFlightNumber': returnFlightNumber,
      'returnFlightTime': returnFlightTime,
      'notes': notes,
      'totalKm': totalKm,
      'totalMileageAmount': totalMileageAmount,
      'totalPerDiemAmount': totalPerDiemAmount,
      'totalHotelAmount': totalHotelAmount,
      'grandTotal': grandTotal,
      'supportDocumentUrls': supportDocumentUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory TransportationRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final now = DateTime.now();

    DateTime parseTimestamp(dynamic value, DateTime fallback) {
      if (value is Timestamp) return value.toDate();
      return fallback;
    }

    DateTime? parseTimestampOptional(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return TransportationRequest(
      id: data['id'] ?? doc.id,
      requestNumber: data['requestNumber'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'] ?? '',
      department: data['department'] ?? '',
      requestDate: parseTimestamp(data['requestDate'], now),
      purpose: data['purpose'] ?? '',
      destinationPlace: data['destinationPlace'] ?? '',
      travelDateTime: parseTimestamp(data['travelDateTime'], now),
      returnDateTime: parseTimestamp(data['returnDateTime'], now),
      travelLocation: data['travelLocation'] ?? 'local',
      vehicleType: data['vehicleType'] ?? 'personalVehicle',
      departureFlightNumber: data['departureFlightNumber'],
      departureFlightTime: data['departureFlightTime'],
      returnFlightNumber: data['returnFlightNumber'],
      returnFlightTime: data['returnFlightTime'],
      notes: data['notes'],
      totalKm: (data['totalKm'] ?? 0.0).toDouble(),
      totalMileageAmount: (data['totalMileageAmount'] ?? 0.0).toDouble(),
      totalPerDiemAmount: (data['totalPerDiemAmount'] ?? 0.0).toDouble(),
      totalHotelAmount: (data['totalHotelAmount'] ?? 0.0).toDouble(),
      grandTotal: (data['grandTotal'] ?? 0.0).toDouble(),
      supportDocumentUrls:
          (data['supportDocumentUrls'] as List<dynamic>?)?.cast<String>() ??
              [],
      createdAt: parseTimestamp(data['createdAt'], now),
      updatedAt: parseTimestampOptional(data['updatedAt']),
    );
  }

  static const _unset = Object();

  TransportationRequest copyWith({
    String? id,
    String? requestNumber,
    String? requesterId,
    String? requesterName,
    String? department,
    DateTime? requestDate,
    String? purpose,
    String? destinationPlace,
    DateTime? travelDateTime,
    DateTime? returnDateTime,
    String? travelLocation,
    String? vehicleType,
    Object? departureFlightNumber = _unset,
    Object? departureFlightTime = _unset,
    Object? returnFlightNumber = _unset,
    Object? returnFlightTime = _unset,
    Object? notes = _unset,
    double? totalKm,
    double? totalMileageAmount,
    double? totalPerDiemAmount,
    double? totalHotelAmount,
    double? grandTotal,
    List<String>? supportDocumentUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransportationRequest(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      department: department ?? this.department,
      requestDate: requestDate ?? this.requestDate,
      purpose: purpose ?? this.purpose,
      destinationPlace: destinationPlace ?? this.destinationPlace,
      travelDateTime: travelDateTime ?? this.travelDateTime,
      returnDateTime: returnDateTime ?? this.returnDateTime,
      travelLocation: travelLocation ?? this.travelLocation,
      vehicleType: vehicleType ?? this.vehicleType,
      departureFlightNumber: departureFlightNumber == _unset
          ? this.departureFlightNumber
          : departureFlightNumber as String?,
      departureFlightTime: departureFlightTime == _unset
          ? this.departureFlightTime
          : departureFlightTime as String?,
      returnFlightNumber: returnFlightNumber == _unset
          ? this.returnFlightNumber
          : returnFlightNumber as String?,
      returnFlightTime: returnFlightTime == _unset
          ? this.returnFlightTime
          : returnFlightTime as String?,
      notes: notes == _unset ? this.notes : notes as String?,
      totalKm: totalKm ?? this.totalKm,
      totalMileageAmount: totalMileageAmount ?? this.totalMileageAmount,
      totalPerDiemAmount: totalPerDiemAmount ?? this.totalPerDiemAmount,
      totalHotelAmount: totalHotelAmount ?? this.totalHotelAmount,
      grandTotal: grandTotal ?? this.grandTotal,
      supportDocumentUrls: supportDocumentUrls ?? this.supportDocumentUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
