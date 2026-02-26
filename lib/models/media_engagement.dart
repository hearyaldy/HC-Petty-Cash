import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'enums.dart';

/// Media Engagement model for tracking social media metrics
class MediaEngagement {
  final String id;
  final String productionId; // Link to MediaProduction
  final String? episodeId; // Optional: if tracking per episode
  final String platform; // youtube, facebook, instagram, tiktok
  final DateTime recordedDate; // Date the metrics were recorded/entered
  final DateTime periodStart; // Start of reporting period
  final DateTime periodEnd; // End of reporting period

  // Common metrics (all platforms)
  final int views;
  final int likes;
  final int comments;
  final int shares;

  // Platform-specific metrics
  // YouTube
  final int? subscribers; // New subscribers gained
  final int? watchTimeHours; // Total watch time in hours
  final int? avgViewDurationSeconds; // Average view duration in seconds

  // Facebook/Instagram
  final int? impressions; // Number of times content was displayed
  final int? reach; // Unique accounts that saw the content

  // Instagram specific
  final int? saves; // Number of saves
  final int? profileVisits; // Profile visits from this content

  // TikTok specific
  final int? videoCompletions; // Number of times video was watched to completion
  final int? followers; // New followers gained

  // Metadata
  final String enteredById;
  final String enteredByName;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? notes;

  MediaEngagement({
    required this.id,
    required this.productionId,
    this.episodeId,
    required this.platform,
    required this.recordedDate,
    required this.periodStart,
    required this.periodEnd,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.subscribers,
    this.watchTimeHours,
    this.avgViewDurationSeconds,
    this.impressions,
    this.reach,
    this.saves,
    this.profileVisits,
    this.videoCompletions,
    this.followers,
    required this.enteredById,
    required this.enteredByName,
    required this.createdAt,
    this.updatedAt,
    this.notes,
  });

  // Get platform enum
  MediaPlatform get platformEnum => platform.toMediaPlatform();
  String get platformDisplayName => platform.mediaPlatformDisplayName;

  // Calculate engagement rate (likes + comments + shares) / views * 100
  double get engagementRate {
    if (views == 0) return 0;
    return ((likes + comments + shares) / views) * 100;
  }

  // Total engagement count
  int get totalEngagement => likes + comments + shares;

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productionId': productionId,
      'episodeId': episodeId,
      'platform': platform,
      'recordedDate': firestore.Timestamp.fromDate(recordedDate),
      'periodStart': firestore.Timestamp.fromDate(periodStart),
      'periodEnd': firestore.Timestamp.fromDate(periodEnd),
      'views': views,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'subscribers': subscribers,
      'watchTimeHours': watchTimeHours,
      'avgViewDurationSeconds': avgViewDurationSeconds,
      'impressions': impressions,
      'reach': reach,
      'saves': saves,
      'profileVisits': profileVisits,
      'videoCompletions': videoCompletions,
      'followers': followers,
      'enteredById': enteredById,
      'enteredByName': enteredByName,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? firestore.Timestamp.fromDate(updatedAt!) : null,
      'notes': notes,
    };
  }

  factory MediaEngagement.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaEngagement document ${doc.id} has no data');
    }

    return MediaEngagement(
      id: doc.id,
      productionId: data['productionId'] as String? ?? '',
      episodeId: data['episodeId'] as String?,
      platform: data['platform'] as String? ?? 'youtube',
      recordedDate: data['recordedDate'] != null
          ? (data['recordedDate'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      periodStart: data['periodStart'] != null
          ? (data['periodStart'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      periodEnd: data['periodEnd'] != null
          ? (data['periodEnd'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      views: data['views'] as int? ?? 0,
      likes: data['likes'] as int? ?? 0,
      comments: data['comments'] as int? ?? 0,
      shares: data['shares'] as int? ?? 0,
      subscribers: data['subscribers'] as int?,
      watchTimeHours: data['watchTimeHours'] as int?,
      avgViewDurationSeconds: data['avgViewDurationSeconds'] as int?,
      impressions: data['impressions'] as int?,
      reach: data['reach'] as int?,
      saves: data['saves'] as int?,
      profileVisits: data['profileVisits'] as int?,
      videoCompletions: data['videoCompletions'] as int?,
      followers: data['followers'] as int?,
      enteredById: data['enteredById'] as String? ?? '',
      enteredByName: data['enteredByName'] as String? ?? 'Unknown',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
    );
  }

  factory MediaEngagement.fromMap(Map<String, dynamic> map) {
    return MediaEngagement(
      id: map['id'] as String,
      productionId: map['productionId'] as String? ?? '',
      episodeId: map['episodeId'] as String?,
      platform: map['platform'] as String? ?? 'youtube',
      recordedDate: map['recordedDate'] is firestore.Timestamp
          ? (map['recordedDate'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['recordedDate'] as String),
      periodStart: map['periodStart'] is firestore.Timestamp
          ? (map['periodStart'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['periodStart'] as String),
      periodEnd: map['periodEnd'] is firestore.Timestamp
          ? (map['periodEnd'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['periodEnd'] as String),
      views: map['views'] as int? ?? 0,
      likes: map['likes'] as int? ?? 0,
      comments: map['comments'] as int? ?? 0,
      shares: map['shares'] as int? ?? 0,
      subscribers: map['subscribers'] as int?,
      watchTimeHours: map['watchTimeHours'] as int?,
      avgViewDurationSeconds: map['avgViewDurationSeconds'] as int?,
      impressions: map['impressions'] as int?,
      reach: map['reach'] as int?,
      saves: map['saves'] as int?,
      profileVisits: map['profileVisits'] as int?,
      videoCompletions: map['videoCompletions'] as int?,
      followers: map['followers'] as int?,
      enteredById: map['enteredById'] as String? ?? '',
      enteredByName: map['enteredByName'] as String? ?? 'Unknown',
      createdAt: map['createdAt'] is firestore.Timestamp
          ? (map['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is firestore.Timestamp
              ? (map['updatedAt'] as firestore.Timestamp).toDate()
              : DateTime.parse(map['updatedAt'] as String))
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productionId': productionId,
      'episodeId': episodeId,
      'platform': platform,
      'recordedDate': recordedDate.toIso8601String(),
      'periodStart': periodStart.toIso8601String(),
      'periodEnd': periodEnd.toIso8601String(),
      'views': views,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'subscribers': subscribers,
      'watchTimeHours': watchTimeHours,
      'avgViewDurationSeconds': avgViewDurationSeconds,
      'impressions': impressions,
      'reach': reach,
      'saves': saves,
      'profileVisits': profileVisits,
      'videoCompletions': videoCompletions,
      'followers': followers,
      'enteredById': enteredById,
      'enteredByName': enteredByName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  MediaEngagement copyWith({
    String? episodeId,
    String? platform,
    DateTime? recordedDate,
    DateTime? periodStart,
    DateTime? periodEnd,
    int? views,
    int? likes,
    int? comments,
    int? shares,
    int? subscribers,
    int? watchTimeHours,
    int? avgViewDurationSeconds,
    int? impressions,
    int? reach,
    int? saves,
    int? profileVisits,
    int? videoCompletions,
    int? followers,
    DateTime? updatedAt,
    String? notes,
  }) {
    return MediaEngagement(
      id: id,
      productionId: productionId,
      episodeId: episodeId ?? this.episodeId,
      platform: platform ?? this.platform,
      recordedDate: recordedDate ?? this.recordedDate,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      views: views ?? this.views,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      subscribers: subscribers ?? this.subscribers,
      watchTimeHours: watchTimeHours ?? this.watchTimeHours,
      avgViewDurationSeconds: avgViewDurationSeconds ?? this.avgViewDurationSeconds,
      impressions: impressions ?? this.impressions,
      reach: reach ?? this.reach,
      saves: saves ?? this.saves,
      profileVisits: profileVisits ?? this.profileVisits,
      videoCompletions: videoCompletions ?? this.videoCompletions,
      followers: followers ?? this.followers,
      enteredById: enteredById,
      enteredByName: enteredByName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'MediaEngagement(id: $id, productionId: $productionId, platform: $platform, views: $views, engagement: $totalEngagement)';
  }
}
