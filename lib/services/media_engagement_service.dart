import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/media_engagement.dart';

class MediaEngagementService {
  // Singleton pattern
  static final MediaEngagementService _instance = MediaEngagementService._internal();
  factory MediaEngagementService() => _instance;
  MediaEngagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String engagementsCollection = 'media_engagements';

  // ========== ENGAGEMENT CRUD ==========

  /// Add a new engagement record
  Future<String> addEngagement(MediaEngagement engagement) async {
    try {
      final docRef = await _firestore
          .collection(engagementsCollection)
          .add(engagement.toFirestore());
      debugPrint('Debug: Created engagement record: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating engagement: $e');
      rethrow;
    }
  }

  /// Update existing engagement
  Future<void> updateEngagement(MediaEngagement engagement) async {
    try {
      await _firestore
          .collection(engagementsCollection)
          .doc(engagement.id)
          .update(engagement.toFirestore());
      debugPrint('Debug: Updated engagement: ${engagement.id}');
    } catch (e) {
      debugPrint('Error updating engagement: $e');
      rethrow;
    }
  }

  /// Delete engagement
  Future<void> deleteEngagement(String engagementId) async {
    try {
      await _firestore
          .collection(engagementsCollection)
          .doc(engagementId)
          .delete();
      debugPrint('Debug: Deleted engagement: $engagementId');
    } catch (e) {
      debugPrint('Error deleting engagement: $e');
      rethrow;
    }
  }

  /// Get engagement by ID
  Future<MediaEngagement?> getEngagementById(String engagementId) async {
    try {
      final doc = await _firestore
          .collection(engagementsCollection)
          .doc(engagementId)
          .get();
      if (doc.exists) {
        return MediaEngagement.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting engagement: $e');
      rethrow;
    }
  }

  // ========== QUERIES ==========

  /// Stream engagements for a production
  Stream<List<MediaEngagement>> getEngagementsForProduction(String productionId) {
    return _firestore
        .collection(engagementsCollection)
        .where('productionId', isEqualTo: productionId)
        .orderBy('recordedDate', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MediaEngagement.fromFirestore(doc))
              .toList();
        });
  }

  /// Get engagements for production once
  Future<List<MediaEngagement>> getEngagementsForProductionOnce(String productionId) async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .where('productionId', isEqualTo: productionId)
          .orderBy('recordedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting engagements for production: $e');
      rethrow;
    }
  }

  /// Get engagements for a specific episode
  Future<List<MediaEngagement>> getEngagementsForEpisode(String episodeId) async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .where('episodeId', isEqualTo: episodeId)
          .orderBy('recordedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting engagements for episode: $e');
      rethrow;
    }
  }

  /// Get engagements by platform
  Future<List<MediaEngagement>> getEngagementsByPlatform(String platform) async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .where('platform', isEqualTo: platform)
          .orderBy('recordedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting engagements by platform: $e');
      rethrow;
    }
  }

  /// Get engagements by date range
  Future<List<MediaEngagement>> getEngagementsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .where('recordedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('recordedDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('recordedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting engagements by date range: $e');
      rethrow;
    }
  }

  /// Get all engagements
  Future<List<MediaEngagement>> getAllEngagements() async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .orderBy('recordedDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting all engagements: $e');
      rethrow;
    }
  }

  // ========== AGGREGATION ==========

  /// Get aggregated stats for a production
  Future<Map<String, dynamic>> getAggregatedStatsForProduction(String productionId) async {
    try {
      final engagements = await getEngagementsForProductionOnce(productionId);

      int totalViews = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      Map<String, Map<String, int>> byPlatform = {};

      for (final engagement in engagements) {
        totalViews += engagement.views;
        totalLikes += engagement.likes;
        totalComments += engagement.comments;
        totalShares += engagement.shares;

        // Aggregate by platform
        if (!byPlatform.containsKey(engagement.platform)) {
          byPlatform[engagement.platform] = {
            'views': 0,
            'likes': 0,
            'comments': 0,
            'shares': 0,
          };
        }
        byPlatform[engagement.platform]!['views'] =
            (byPlatform[engagement.platform]!['views'] ?? 0) + engagement.views;
        byPlatform[engagement.platform]!['likes'] =
            (byPlatform[engagement.platform]!['likes'] ?? 0) + engagement.likes;
        byPlatform[engagement.platform]!['comments'] =
            (byPlatform[engagement.platform]!['comments'] ?? 0) + engagement.comments;
        byPlatform[engagement.platform]!['shares'] =
            (byPlatform[engagement.platform]!['shares'] ?? 0) + engagement.shares;
      }

      double engagementRate = totalViews > 0
          ? ((totalLikes + totalComments + totalShares) / totalViews) * 100
          : 0;

      return {
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalEngagement': totalLikes + totalComments + totalShares,
        'engagementRate': engagementRate,
        'byPlatform': byPlatform,
        'recordCount': engagements.length,
      };
    } catch (e) {
      debugPrint('Error getting aggregated stats: $e');
      rethrow;
    }
  }

  /// Get aggregated stats for a date range
  Future<Map<String, dynamic>> getAggregatedStats({
    required DateTime periodStart,
    required DateTime periodEnd,
    String? language,
    String? platform,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(engagementsCollection)
          .where('recordedDate', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('recordedDate', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd));

      if (platform != null) {
        query = query.where('platform', isEqualTo: platform);
      }

      final snapshot = await query.get();
      final engagements = snapshot.docs
          .map((doc) => MediaEngagement.fromFirestore(doc))
          .toList();

      int totalViews = 0;
      int totalLikes = 0;
      int totalComments = 0;
      int totalShares = 0;
      Map<String, Map<String, int>> byPlatform = {};

      for (final engagement in engagements) {
        totalViews += engagement.views;
        totalLikes += engagement.likes;
        totalComments += engagement.comments;
        totalShares += engagement.shares;

        if (!byPlatform.containsKey(engagement.platform)) {
          byPlatform[engagement.platform] = {
            'views': 0,
            'likes': 0,
            'comments': 0,
            'shares': 0,
          };
        }
        byPlatform[engagement.platform]!['views'] =
            (byPlatform[engagement.platform]!['views'] ?? 0) + engagement.views;
        byPlatform[engagement.platform]!['likes'] =
            (byPlatform[engagement.platform]!['likes'] ?? 0) + engagement.likes;
        byPlatform[engagement.platform]!['comments'] =
            (byPlatform[engagement.platform]!['comments'] ?? 0) + engagement.comments;
        byPlatform[engagement.platform]!['shares'] =
            (byPlatform[engagement.platform]!['shares'] ?? 0) + engagement.shares;
      }

      double engagementRate = totalViews > 0
          ? ((totalLikes + totalComments + totalShares) / totalViews) * 100
          : 0;

      return {
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'totalViews': totalViews,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'totalEngagement': totalLikes + totalComments + totalShares,
        'engagementRate': engagementRate,
        'byPlatform': byPlatform,
        'recordCount': engagements.length,
      };
    } catch (e) {
      debugPrint('Error getting aggregated stats: $e');
      rethrow;
    }
  }

  /// Get yearly statistics
  Future<Map<String, dynamic>> getYearlyStats(int year) async {
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31, 23, 59, 59);

    return getAggregatedStats(
      periodStart: startOfYear,
      periodEnd: endOfYear,
    );
  }

  /// Get latest engagement for each platform for a production
  Future<Map<String, MediaEngagement>> getLatestEngagementByPlatform(
    String productionId,
  ) async {
    try {
      final engagements = await getEngagementsForProductionOnce(productionId);
      Map<String, MediaEngagement> latestByPlatform = {};

      for (final engagement in engagements) {
        if (!latestByPlatform.containsKey(engagement.platform) ||
            engagement.recordedDate.isAfter(
                latestByPlatform[engagement.platform]!.recordedDate)) {
          latestByPlatform[engagement.platform] = engagement;
        }
      }

      return latestByPlatform;
    } catch (e) {
      debugPrint('Error getting latest engagement by platform: $e');
      rethrow;
    }
  }

  /// Delete all engagements for a production (cascade delete)
  Future<void> deleteEngagementsForProduction(String productionId) async {
    try {
      final snapshot = await _firestore
          .collection(engagementsCollection)
          .where('productionId', isEqualTo: productionId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('Debug: Deleted all engagements for production: $productionId');
    } catch (e) {
      debugPrint('Error deleting engagements for production: $e');
      rethrow;
    }
  }
}
