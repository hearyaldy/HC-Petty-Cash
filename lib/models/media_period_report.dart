import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class MediaPeriodReport {
  final String id;
  final String periodType; // monthly, quarterly, custom
  final DateTime periodStart;
  final DateTime periodEnd;
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

  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MediaPeriodReport({
    required this.id,
    required this.periodType,
    required this.periodStart,
    required this.periodEnd,
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
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'periodType': periodType,
      'periodStart': firestore.Timestamp.fromDate(periodStart),
      'periodEnd': firestore.Timestamp.fromDate(periodEnd),
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
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? firestore.Timestamp.fromDate(updatedAt!)
          : null,
    };
  }

  factory MediaPeriodReport.fromFirestore(
      firestore.DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('MediaPeriodReport document ${doc.id} has no data');
    }
    return MediaPeriodReport(
      id: doc.id,
      periodType: data['periodType'] as String? ?? 'custom',
      periodStart: data['periodStart'] != null
          ? (data['periodStart'] as firestore.Timestamp).toDate()
          : DateTime.now(),
      periodEnd: data['periodEnd'] != null
          ? (data['periodEnd'] as firestore.Timestamp).toDate()
          : DateTime.now(),
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
