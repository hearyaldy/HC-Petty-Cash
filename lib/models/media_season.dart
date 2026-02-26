import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Media Season model for tracking seasons within a series production
class MediaSeason {
  final String id;
  final String productionId; // Parent production (series)
  final int seasonNumber;
  final String? title; // Optional season title (e.g., "The Beginning")
  final String? description;
  final int episodeCount; // Number of episodes in this season
  final String status; // planning, inProduction, postProduction, published, archived
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaSeason({
    required this.id,
    required this.productionId,
    required this.seasonNumber,
    this.title,
    this.description,
    this.episodeCount = 0,
    required this.status,
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.updatedAt,
  });

  // Get status enum
  ProductionStatus get statusEnum => status.toProductionStatus();
  String get statusDisplayName => status.productionStatusDisplayName;

  // Display name for the season
  String get displayName {
    if (title != null && title!.isNotEmpty) {
      return 'Season $seasonNumber: $title';
    }
    return 'Season $seasonNumber';
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productionId': productionId,
      'seasonNumber': seasonNumber,
      'title': title,
      'description': description,
      'episodeCount': episodeCount,
      'status': status,
      'startDate': startDate != null ? firestore.Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? firestore.Timestamp.fromDate(endDate!) : null,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MediaSeason.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaSeason document ${doc.id} has no data');
    }

    return MediaSeason(
      id: doc.id,
      productionId: data['productionId'] as String? ?? '',
      seasonNumber: data['seasonNumber'] as int? ?? 1,
      title: data['title'] as String?,
      description: data['description'] as String?,
      episodeCount: data['episodeCount'] as int? ?? 0,
      status: data['status'] as String? ?? 'planning',
      startDate: data['startDate'] != null
          ? (data['startDate'] as firestore.Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as firestore.Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  factory MediaSeason.fromMap(Map<String, dynamic> map) {
    return MediaSeason(
      id: map['id'] as String,
      productionId: map['productionId'] as String? ?? '',
      seasonNumber: map['seasonNumber'] as int? ?? 1,
      title: map['title'] as String?,
      description: map['description'] as String?,
      episodeCount: map['episodeCount'] as int? ?? 0,
      status: map['status'] as String? ?? 'planning',
      startDate: map['startDate'] != null
          ? (map['startDate'] is firestore.Timestamp
              ? (map['startDate'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['startDate'] as String))
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] is firestore.Timestamp
              ? (map['endDate'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['endDate'] as String))
          : null,
      createdAt: map['createdAt'] is firestore.Timestamp
          ? (map['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is firestore.Timestamp
              ? (map['updatedAt'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productionId': productionId,
      'seasonNumber': seasonNumber,
      'title': title,
      'description': description,
      'episodeCount': episodeCount,
      'status': status,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  MediaSeason copyWith({
    int? seasonNumber,
    String? title,
    String? description,
    int? episodeCount,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return MediaSeason(
      id: id,
      productionId: productionId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      episodeCount: episodeCount ?? this.episodeCount,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MediaSeason(id: $id, productionId: $productionId, seasonNumber: $seasonNumber, episodeCount: $episodeCount)';
  }
}
