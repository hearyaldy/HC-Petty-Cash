import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Media Episode model for tracking individual episodes within a season
class MediaEpisode {
  final String id;
  final String productionId; // Parent production (series)
  final String seasonId; // Parent season
  final int episodeNumber;
  final String title;
  final String? description;
  final int? durationMinutes; // Episode duration in minutes
  final String status; // draft, editing, scheduled, published
  final DateTime? publishedAt;
  final String? thumbnailUrl;
  final String? videoUrl; // Optional link to the video
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaEpisode({
    required this.id,
    required this.productionId,
    required this.seasonId,
    required this.episodeNumber,
    required this.title,
    this.description,
    this.durationMinutes,
    required this.status,
    this.publishedAt,
    this.thumbnailUrl,
    this.videoUrl,
    required this.createdAt,
    this.updatedAt,
  });

  // Get status enum
  EpisodeStatus get statusEnum => status.toEpisodeStatus();
  String get statusDisplayName => status.episodeStatusDisplayName;

  // Display name for the episode
  String get displayName => 'EP $episodeNumber: $title';

  // Duration display
  String get durationDisplay {
    if (durationMinutes == null) return 'N/A';
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productionId': productionId,
      'seasonId': seasonId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'status': status,
      'publishedAt': publishedAt != null ? firestore.Timestamp.fromDate(publishedAt!) : null,
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MediaEpisode.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaEpisode document ${doc.id} has no data');
    }

    return MediaEpisode(
      id: doc.id,
      productionId: data['productionId'] as String? ?? '',
      seasonId: data['seasonId'] as String? ?? '',
      episodeNumber: data['episodeNumber'] as int? ?? 1,
      title: data['title'] as String? ?? 'Untitled Episode',
      description: data['description'] as String?,
      durationMinutes: data['durationMinutes'] as int?,
      status: data['status'] as String? ?? 'draft',
      publishedAt: data['publishedAt'] != null
          ? (data['publishedAt'] as firestore.Timestamp).toDate()
          : null,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      videoUrl: data['videoUrl'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }

  factory MediaEpisode.fromMap(Map<String, dynamic> map) {
    return MediaEpisode(
      id: map['id'] as String,
      productionId: map['productionId'] as String? ?? '',
      seasonId: map['seasonId'] as String? ?? '',
      episodeNumber: map['episodeNumber'] as int? ?? 1,
      title: map['title'] as String? ?? 'Untitled Episode',
      description: map['description'] as String?,
      durationMinutes: map['durationMinutes'] as int?,
      status: map['status'] as String? ?? 'draft',
      publishedAt: map['publishedAt'] != null
          ? (map['publishedAt'] is firestore.Timestamp
              ? (map['publishedAt'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['publishedAt'] as String))
          : null,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
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
      'seasonId': seasonId,
      'episodeNumber': episodeNumber,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'status': status,
      'publishedAt': publishedAt?.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'videoUrl': videoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  MediaEpisode copyWith({
    int? episodeNumber,
    String? title,
    String? description,
    int? durationMinutes,
    String? status,
    DateTime? publishedAt,
    String? thumbnailUrl,
    String? videoUrl,
    DateTime? updatedAt,
  }) {
    return MediaEpisode(
      id: id,
      productionId: productionId,
      seasonId: seasonId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      publishedAt: publishedAt ?? this.publishedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MediaEpisode(id: $id, productionId: $productionId, seasonId: $seasonId, ep: $episodeNumber, title: $title)';
  }
}
