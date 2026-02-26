import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Media Production model for tracking video/audio content production
class MediaProduction {
  final String id;
  final String title;
  final String? description;
  final String language; // Language code: 'en', 'th', 'km', etc.
  final String productionType; // series, standalone, liveStream, short
  final String status; // planning, inProduction, postProduction, published, archived

  // Budget linking
  final String? projectId; // Link to ProjectReport for budget
  final String? projectName; // Cached project name for display

  // Series tracking
  final int totalSeasons; // For series: total planned seasons
  final int totalEpisodes; // For series: total episodes across all seasons

  // Thumbnail/Cover
  final String? thumbnailUrl;
  final double? budget;
  final int? productionYear;
  final List<String> productionUrls;
  final int? durationMinutes;
  final String? category;
  final List<String> customCategories;

  // Staff assignments
  final String createdById;
  final String createdByName;
  final List<String> teamMemberIds;
  final List<String> teamMemberNames;

  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  // Notes
  final String? notes;

  MediaProduction({
    required this.id,
    required this.title,
    this.description,
    required this.language,
    required this.productionType,
    required this.status,
    this.projectId,
    this.projectName,
    this.totalSeasons = 0,
    this.totalEpisodes = 0,
    this.thumbnailUrl,
    this.budget,
    this.productionYear,
    this.productionUrls = const [],
    this.durationMinutes,
    this.category,
    this.customCategories = const [],
    required this.createdById,
    required this.createdByName,
    this.teamMemberIds = const [],
    this.teamMemberNames = const [],
    required this.createdAt,
    this.updatedAt,
    this.publishedAt,
    this.notes,
  });

  // Get enums
  MediaLanguage get languageEnum => language.toMediaLanguage();
  ProductionType get productionTypeEnum => productionType.toProductionType();
  ProductionStatus get statusEnum => status.toProductionStatus();

  // Helper getters
  bool get isSeries => productionType == ProductionType.series.name;
  bool get isPublished => status == ProductionStatus.published.name;
  String get languageDisplayName => language.mediaLanguageDisplayName;
  String get typeDisplayName => productionType.productionTypeDisplayName;
  String get statusDisplayName => status.productionStatusDisplayName;

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'language': language,
      'productionType': productionType,
      'status': status,
      'projectId': projectId,
      'projectName': projectName,
      'totalSeasons': totalSeasons,
      'totalEpisodes': totalEpisodes,
      'thumbnailUrl': thumbnailUrl,
      'budget': budget,
      'productionYear': productionYear,
      'productionUrls': productionUrls,
      'durationMinutes': durationMinutes,
      'category': category,
      'customCategories': customCategories,
      'createdById': createdById,
      'createdByName': createdByName,
      'teamMemberIds': teamMemberIds,
      'teamMemberNames': teamMemberNames,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
      'publishedAt': publishedAt != null ? firestore.Timestamp.fromDate(publishedAt!) : null,
      'notes': notes,
    };
  }

  factory MediaProduction.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaProduction document ${doc.id} has no data');
    }

    return MediaProduction(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String?,
      language: data['language'] as String? ?? 'en',
      productionType: data['productionType'] as String? ?? 'standalone',
      status: data['status'] as String? ?? 'planning',
      projectId: data['projectId'] as String?,
      projectName: data['projectName'] as String?,
      totalSeasons: data['totalSeasons'] as int? ?? 0,
      totalEpisodes: data['totalEpisodes'] as int? ?? 0,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      budget: (data['budget'] as num?)?.toDouble(),
      productionYear: (data['productionYear'] as num?)?.toInt(),
      productionUrls: (data['productionUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      durationMinutes: data['durationMinutes'] as int?,
      category: data['category'] as String?,
      customCategories: (data['customCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdById: data['createdById'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Unknown',
      teamMemberIds: (data['teamMemberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      teamMemberNames: (data['teamMemberNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
      publishedAt: data['publishedAt'] != null
          ? (data['publishedAt'] as firestore.Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
    );
  }

  // Create from Map (for local/cached data)
  factory MediaProduction.fromMap(Map<String, dynamic> map) {
    return MediaProduction(
      id: map['id'] as String,
      title: map['title'] as String? ?? 'Untitled',
      description: map['description'] as String?,
      language: map['language'] as String? ?? 'en',
      productionType: map['productionType'] as String? ?? 'standalone',
      status: map['status'] as String? ?? 'planning',
      projectId: map['projectId'] as String?,
      projectName: map['projectName'] as String?,
      totalSeasons: map['totalSeasons'] as int? ?? 0,
      totalEpisodes: map['totalEpisodes'] as int? ?? 0,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      budget: (map['budget'] as num?)?.toDouble(),
      productionYear: (map['productionYear'] as num?)?.toInt(),
      productionUrls: (map['productionUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      durationMinutes: map['durationMinutes'] as int?,
      category: map['category'] as String?,
      customCategories: (map['customCategories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdById: map['createdById'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? 'Unknown',
      teamMemberIds: (map['teamMemberIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      teamMemberNames: (map['teamMemberNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['createdAt'] is firestore.Timestamp
          ? (map['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is firestore.Timestamp
              ? (map['updatedAt'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : null,
      publishedAt: map['publishedAt'] != null
          ? (map['publishedAt'] is firestore.Timestamp
              ? (map['publishedAt'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['publishedAt'] as String))
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'language': language,
      'productionType': productionType,
      'status': status,
      'projectId': projectId,
      'projectName': projectName,
      'totalSeasons': totalSeasons,
      'totalEpisodes': totalEpisodes,
      'thumbnailUrl': thumbnailUrl,
      'budget': budget,
      'productionYear': productionYear,
      'productionUrls': productionUrls,
      'durationMinutes': durationMinutes,
      'category': category,
      'customCategories': customCategories,
      'createdById': createdById,
      'createdByName': createdByName,
      'teamMemberIds': teamMemberIds,
      'teamMemberNames': teamMemberNames,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  MediaProduction copyWith({
    String? title,
    String? description,
    String? language,
    String? productionType,
    String? status,
    String? projectId,
    String? projectName,
    int? totalSeasons,
    int? totalEpisodes,
    String? thumbnailUrl,
    double? budget,
    int? productionYear,
    List<String>? productionUrls,
    int? durationMinutes,
    String? category,
    List<String>? customCategories,
    List<String>? teamMemberIds,
    List<String>? teamMemberNames,
    DateTime? updatedAt,
    DateTime? publishedAt,
    String? notes,
  }) {
    return MediaProduction(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      language: language ?? this.language,
      productionType: productionType ?? this.productionType,
      status: status ?? this.status,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      budget: budget ?? this.budget,
      productionYear: productionYear ?? this.productionYear,
      productionUrls: productionUrls ?? this.productionUrls,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      customCategories: customCategories ?? this.customCategories,
      createdById: createdById,
      createdByName: createdByName,
      teamMemberIds: teamMemberIds ?? this.teamMemberIds,
      teamMemberNames: teamMemberNames ?? this.teamMemberNames,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'MediaProduction(id: $id, title: $title, language: $language, type: $productionType, status: $status)';
  }
}
