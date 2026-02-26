import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class MediaYearlyStats {
  final String id;
  final int year;
  final String? title;
  final String? notes;
  final String language;
  final String platform;
  final String pageName;

  // Result
  final int? resultTotalFollower;
  final int? resultNetFollowerGain;
  final int? resultView;
  final int? resultViewers;
  final int? resultContentInteraction;
  final int? resultLinkClick;
  final int? resultVisit;
  final int? resultFollow;

  // Audience
  final int? audienceFollow;
  final int? audienceReturningViewers;
  final int? audienceEngageFollower;

  // Content Overview
  final int? contentOverviewView;
  final int? contentOverviewThreeSecondView;
  final int? contentOverviewOneMinuteView;
  final int? contentOverviewContentInteraction;
  final int? contentOverviewWatchTime;

  // View Breakdown
  final int? viewBreakdownTotal;
  final int? viewBreakdownFromOrganic;
  final int? viewBreakdownFromFollower;
  final int? viewBreakdownViewers;

  // Content
  final int? contentReach;
  final int? contentWatchTime;
  final double? contentVideoAverage;
  final int? contentLikeReaction;
  final int? contentViewers;

  final Map<String, Map<String, num>> platformStats;

  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaYearlyStats({
    required this.id,
    required this.year,
    this.title,
    this.notes,
    required this.language,
    required this.platform,
    required this.pageName,
    this.resultTotalFollower,
    this.resultNetFollowerGain,
    this.resultView,
    this.resultViewers,
    this.resultContentInteraction,
    this.resultLinkClick,
    this.resultVisit,
    this.resultFollow,
    this.audienceFollow,
    this.audienceReturningViewers,
    this.audienceEngageFollower,
    this.contentOverviewView,
    this.contentOverviewThreeSecondView,
    this.contentOverviewOneMinuteView,
    this.contentOverviewContentInteraction,
    this.contentOverviewWatchTime,
    this.viewBreakdownTotal,
    this.viewBreakdownFromOrganic,
    this.viewBreakdownFromFollower,
    this.viewBreakdownViewers,
    this.contentReach,
    this.contentWatchTime,
    this.contentVideoAverage,
    this.contentLikeReaction,
    this.contentViewers,
    this.platformStats = const {},
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'year': year,
      'title': title,
      'notes': notes,
      'language': language,
      'platform': platform,
      'pageName': pageName,
      'resultTotalFollower': resultTotalFollower,
      'resultNetFollowerGain': resultNetFollowerGain,
      'resultView': resultView,
      'resultViewers': resultViewers,
      'resultContentInteraction': resultContentInteraction,
      'resultLinkClick': resultLinkClick,
      'resultVisit': resultVisit,
      'resultFollow': resultFollow,
      'audienceFollow': audienceFollow,
      'audienceReturningViewers': audienceReturningViewers,
      'audienceEngageFollower': audienceEngageFollower,
      'contentOverviewView': contentOverviewView,
      'contentOverviewThreeSecondView': contentOverviewThreeSecondView,
      'contentOverviewOneMinuteView': contentOverviewOneMinuteView,
      'contentOverviewContentInteraction': contentOverviewContentInteraction,
      'contentOverviewWatchTime': contentOverviewWatchTime,
      'viewBreakdownTotal': viewBreakdownTotal,
      'viewBreakdownFromOrganic': viewBreakdownFromOrganic,
      'viewBreakdownFromFollower': viewBreakdownFromFollower,
      'viewBreakdownViewers': viewBreakdownViewers,
      'contentReach': contentReach,
      'contentWatchTime': contentWatchTime,
      'contentVideoAverage': contentVideoAverage,
      'contentLikeReaction': contentLikeReaction,
      'contentViewers': contentViewers,
      'platformStats': platformStats,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : null,
    };
  }

  factory MediaYearlyStats.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaYearlyStats document ${doc.id} has no data');
    }

    return MediaYearlyStats(
      id: doc.id,
      year: data['year'] as int? ?? DateTime.now().year,
      title: data['title'] as String?,
      notes: data['notes'] as String?,
      language: data['language'] as String? ?? 'en',
      platform: data['platform'] as String? ?? 'youtube',
      pageName: data['pageName'] as String? ?? '',
      resultTotalFollower: data['resultTotalFollower'] as int?,
      resultNetFollowerGain: data['resultNetFollowerGain'] as int?,
      resultView: data['resultView'] as int?,
      resultViewers: data['resultViewers'] as int?,
      resultContentInteraction: data['resultContentInteraction'] as int?,
      resultLinkClick: data['resultLinkClick'] as int?,
      resultVisit: data['resultVisit'] as int?,
      resultFollow: data['resultFollow'] as int?,
      audienceFollow: data['audienceFollow'] as int?,
      audienceReturningViewers: data['audienceReturningViewers'] as int?,
      audienceEngageFollower: data['audienceEngageFollower'] as int?,
      contentOverviewView: data['contentOverviewView'] as int?,
      contentOverviewThreeSecondView: data['contentOverviewThreeSecondView'] as int?,
      contentOverviewOneMinuteView: data['contentOverviewOneMinuteView'] as int?,
      contentOverviewContentInteraction:
          data['contentOverviewContentInteraction'] as int?,
      contentOverviewWatchTime: data['contentOverviewWatchTime'] as int?,
      viewBreakdownTotal: data['viewBreakdownTotal'] as int?,
      viewBreakdownFromOrganic: data['viewBreakdownFromOrganic'] as int?,
      viewBreakdownFromFollower: data['viewBreakdownFromFollower'] as int?,
      viewBreakdownViewers: data['viewBreakdownViewers'] as int?,
      contentReach: data['contentReach'] as int?,
      contentWatchTime: data['contentWatchTime'] as int?,
      contentVideoAverage: (data['contentVideoAverage'] as num?)?.toDouble(),
      contentLikeReaction: data['contentLikeReaction'] as int?,
      contentViewers: data['contentViewers'] as int?,
      platformStats:
          (data['platformStats'] as Map<String, dynamic>? ?? {})
              .map(
                (key, value) => MapEntry(
                  key,
                  (value as Map<String, dynamic>)
                      .map((k, v) => MapEntry(k, v as num)),
                ),
              ),
      createdById: data['createdById'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? 'Unknown',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as firestore.Timestamp).toDate()
          : null,
    );
  }
}
