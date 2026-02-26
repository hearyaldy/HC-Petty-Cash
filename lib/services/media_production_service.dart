import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/media_production.dart';
import '../models/media_season.dart';
import '../models/media_episode.dart';

class MediaProductionService {
  // Singleton pattern
  static final MediaProductionService _instance = MediaProductionService._internal();
  factory MediaProductionService() => _instance;
  MediaProductionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String productionsCollection = 'media_productions';
  static const String seasonsCollection = 'media_seasons';
  static const String episodesCollection = 'media_episodes';

  // In-memory cache
  List<MediaProduction>? _cachedProductions;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Cache invalidation flag
  bool _cacheInvalidated = false;

  /// Check if cache is valid
  bool get _isCacheValid {
    if (_cachedProductions == null || _cacheTimestamp == null) return false;
    if (_cacheInvalidated) return false;
    return DateTime.now().difference(_cacheTimestamp!) < _cacheDuration;
  }

  /// Invalidate cache (call after create/update/delete operations)
  void invalidateCache() {
    _cacheInvalidated = true;
    _cachedProductions = null;
    _cacheTimestamp = null;
    debugPrint('DEBUG MEDIA: Cache invalidated');
  }

  // ========== PRODUCTION CRUD ==========

  /// Create a new media production
  Future<String> createProduction(MediaProduction production) async {
    try {
      final docRef = await _firestore
          .collection(productionsCollection)
          .add(production.toFirestore());
      invalidateCache();
      debugPrint('Debug: Created media production: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating media production: $e');
      rethrow;
    }
  }

  /// Update existing production
  Future<void> updateProduction(MediaProduction production) async {
    try {
      await _firestore
          .collection(productionsCollection)
          .doc(production.id)
          .update(production.toFirestore());
      invalidateCache();
      debugPrint('Debug: Updated media production: ${production.id}');
    } catch (e) {
      debugPrint('Error updating media production: $e');
      rethrow;
    }
  }

  /// Delete production and all related seasons/episodes
  Future<void> deleteProduction(String productionId) async {
    try {
      // Delete all episodes for this production
      final episodesSnapshot = await _firestore
          .collection(episodesCollection)
          .where('productionId', isEqualTo: productionId)
          .get();
      for (final doc in episodesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete all seasons for this production
      final seasonsSnapshot = await _firestore
          .collection(seasonsCollection)
          .where('productionId', isEqualTo: productionId)
          .get();
      for (final doc in seasonsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the production
      await _firestore
          .collection(productionsCollection)
          .doc(productionId)
          .delete();
      invalidateCache();
      debugPrint('Debug: Deleted media production and related data: $productionId');
    } catch (e) {
      debugPrint('Error deleting media production: $e');
      rethrow;
    }
  }

  /// Get production by ID
  Future<MediaProduction?> getProductionById(String productionId) async {
    try {
      final doc = await _firestore
          .collection(productionsCollection)
          .doc(productionId)
          .get();
      if (doc.exists) {
        return MediaProduction.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting media production: $e');
      rethrow;
    }
  }

  /// Stream all productions
  Stream<List<MediaProduction>> getAllProductions() {
    return _firestore
        .collection(productionsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final List<MediaProduction> result = [];
          for (final doc in snapshot.docs) {
            try {
              result.add(MediaProduction.fromFirestore(doc));
            } catch (e) {
              debugPrint('Error parsing media production ${doc.id}: $e');
            }
          }
          return result;
        });
  }

  /// Get all productions once (with caching)
  Future<List<MediaProduction>> getAllProductionsOnce({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isCacheValid) {
      debugPrint('DEBUG MEDIA: Returning ${_cachedProductions!.length} productions from cache');
      return List.from(_cachedProductions!);
    }

    try {
      final snapshot = await _firestore
          .collection(productionsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      _cachedProductions = snapshot.docs
          .map((doc) {
            try {
              return MediaProduction.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing media production ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MediaProduction>()
          .toList();

      _cacheTimestamp = DateTime.now();
      _cacheInvalidated = false;

      debugPrint('DEBUG MEDIA: Cached ${_cachedProductions!.length} productions');
      return List.from(_cachedProductions!);
    } catch (e) {
      debugPrint('Error getting all productions: $e');
      rethrow;
    }
  }

  /// Get productions by language code
  Future<List<MediaProduction>> getProductionsByLanguage(String languageCode) async {
    try {
      final snapshot = await _firestore
          .collection(productionsCollection)
          .where('language', isEqualTo: languageCode)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return MediaProduction.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing media production ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MediaProduction>()
          .toList();
    } catch (e) {
      debugPrint('Error getting productions by language: $e');
      rethrow;
    }
  }

  /// Get productions by multiple language codes (for user permissions)
  Future<List<MediaProduction>> getProductionsByLanguages(List<String> languageCodes) async {
    if (languageCodes.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection(productionsCollection)
          .where('language', whereIn: languageCodes)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) {
            try {
              return MediaProduction.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing media production ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MediaProduction>()
          .toList();
    } catch (e) {
      debugPrint('Error getting productions by languages: $e');
      rethrow;
    }
  }

  /// Get productions by status
  Future<List<MediaProduction>> getProductionsByStatus(String status) async {
    try {
      final snapshot = await _firestore
          .collection(productionsCollection)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MediaProduction.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting productions by status: $e');
      rethrow;
    }
  }

  // ========== SEASON CRUD ==========

  /// Create a new season
  Future<String> createSeason(MediaSeason season) async {
    try {
      final docRef = await _firestore
          .collection(seasonsCollection)
          .add(season.toFirestore());

      // Update production's season count
      await _updateProductionSeasonCount(season.productionId);

      debugPrint('Debug: Created season: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating season: $e');
      rethrow;
    }
  }

  /// Update existing season
  Future<void> updateSeason(MediaSeason season) async {
    try {
      await _firestore
          .collection(seasonsCollection)
          .doc(season.id)
          .update(season.toFirestore());
      debugPrint('Debug: Updated season: ${season.id}');
    } catch (e) {
      debugPrint('Error updating season: $e');
      rethrow;
    }
  }

  /// Delete season and all its episodes
  Future<void> deleteSeason(String seasonId, String productionId) async {
    try {
      // Delete all episodes in this season
      final episodesSnapshot = await _firestore
          .collection(episodesCollection)
          .where('seasonId', isEqualTo: seasonId)
          .get();
      for (final doc in episodesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the season
      await _firestore.collection(seasonsCollection).doc(seasonId).delete();

      // Update production's season and episode counts
      await _updateProductionSeasonCount(productionId);
      await _updateProductionEpisodeCount(productionId);

      debugPrint('Debug: Deleted season and episodes: $seasonId');
    } catch (e) {
      debugPrint('Error deleting season: $e');
      rethrow;
    }
  }

  /// Get season by ID
  Future<MediaSeason?> getSeasonById(String seasonId) async {
    try {
      final doc = await _firestore
          .collection(seasonsCollection)
          .doc(seasonId)
          .get();
      if (doc.exists) {
        return MediaSeason.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting season: $e');
      rethrow;
    }
  }

  /// Stream seasons for a production
  Stream<List<MediaSeason>> getSeasonsForProduction(String productionId) {
    return _firestore
        .collection(seasonsCollection)
        .where('productionId', isEqualTo: productionId)
        .orderBy('seasonNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MediaSeason.fromFirestore(doc))
              .toList();
        });
  }

  /// Get seasons for production once
  Future<List<MediaSeason>> getSeasonsForProductionOnce(String productionId) async {
    try {
      final snapshot = await _firestore
          .collection(seasonsCollection)
          .where('productionId', isEqualTo: productionId)
          .orderBy('seasonNumber')
          .get();

      return snapshot.docs
          .map((doc) => MediaSeason.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting seasons for production: $e');
      rethrow;
    }
  }

  // ========== EPISODE CRUD ==========

  /// Create a new episode
  Future<String> createEpisode(MediaEpisode episode) async {
    try {
      final docRef = await _firestore
          .collection(episodesCollection)
          .add(episode.toFirestore());

      // Update season's episode count
      await _updateSeasonEpisodeCount(episode.seasonId);
      // Update production's total episode count
      await _updateProductionEpisodeCount(episode.productionId);

      debugPrint('Debug: Created episode: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating episode: $e');
      rethrow;
    }
  }

  /// Update existing episode
  Future<void> updateEpisode(MediaEpisode episode) async {
    try {
      await _firestore
          .collection(episodesCollection)
          .doc(episode.id)
          .update(episode.toFirestore());
      debugPrint('Debug: Updated episode: ${episode.id}');
    } catch (e) {
      debugPrint('Error updating episode: $e');
      rethrow;
    }
  }

  /// Delete episode
  Future<void> deleteEpisode(String episodeId, String seasonId, String productionId) async {
    try {
      await _firestore.collection(episodesCollection).doc(episodeId).delete();

      // Update counts
      await _updateSeasonEpisodeCount(seasonId);
      await _updateProductionEpisodeCount(productionId);

      debugPrint('Debug: Deleted episode: $episodeId');
    } catch (e) {
      debugPrint('Error deleting episode: $e');
      rethrow;
    }
  }

  /// Get episode by ID
  Future<MediaEpisode?> getEpisodeById(String episodeId) async {
    try {
      final doc = await _firestore
          .collection(episodesCollection)
          .doc(episodeId)
          .get();
      if (doc.exists) {
        return MediaEpisode.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting episode: $e');
      rethrow;
    }
  }

  /// Stream episodes for a season
  Stream<List<MediaEpisode>> getEpisodesForSeason(String seasonId) {
    return _firestore
        .collection(episodesCollection)
        .where('seasonId', isEqualTo: seasonId)
        .orderBy('episodeNumber')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MediaEpisode.fromFirestore(doc))
              .toList();
        });
  }

  /// Get episodes for season once
  Future<List<MediaEpisode>> getEpisodesForSeasonOnce(String seasonId) async {
    try {
      final snapshot = await _firestore
          .collection(episodesCollection)
          .where('seasonId', isEqualTo: seasonId)
          .orderBy('episodeNumber')
          .get();

      return snapshot.docs
          .map((doc) => MediaEpisode.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting episodes for season: $e');
      rethrow;
    }
  }

  /// Get all episodes for a production
  Future<List<MediaEpisode>> getEpisodesForProductionOnce(String productionId) async {
    try {
      final snapshot = await _firestore
          .collection(episodesCollection)
          .where('productionId', isEqualTo: productionId)
          .orderBy('episodeNumber')
          .get();

      return snapshot.docs
          .map((doc) => MediaEpisode.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting episodes for production: $e');
      rethrow;
    }
  }

  // ========== HELPER METHODS ==========

  /// Update production's season count
  Future<void> _updateProductionSeasonCount(String productionId) async {
    try {
      final seasonsSnapshot = await _firestore
          .collection(seasonsCollection)
          .where('productionId', isEqualTo: productionId)
          .get();

      await _firestore
          .collection(productionsCollection)
          .doc(productionId)
          .update({
            'totalSeasons': seasonsSnapshot.docs.length,
            'updatedAt': Timestamp.now(),
          });
      invalidateCache();
    } catch (e) {
      debugPrint('Error updating production season count: $e');
    }
  }

  /// Update production's total episode count
  Future<void> _updateProductionEpisodeCount(String productionId) async {
    try {
      final episodesSnapshot = await _firestore
          .collection(episodesCollection)
          .where('productionId', isEqualTo: productionId)
          .get();

      await _firestore
          .collection(productionsCollection)
          .doc(productionId)
          .update({
            'totalEpisodes': episodesSnapshot.docs.length,
            'updatedAt': Timestamp.now(),
          });
      invalidateCache();
    } catch (e) {
      debugPrint('Error updating production episode count: $e');
    }
  }

  /// Update season's episode count
  Future<void> _updateSeasonEpisodeCount(String seasonId) async {
    try {
      final episodesSnapshot = await _firestore
          .collection(episodesCollection)
          .where('seasonId', isEqualTo: seasonId)
          .get();

      await _firestore
          .collection(seasonsCollection)
          .doc(seasonId)
          .update({
            'episodeCount': episodesSnapshot.docs.length,
            'updatedAt': Timestamp.now(),
          });
    } catch (e) {
      debugPrint('Error updating season episode count: $e');
    }
  }

  // ========== STATISTICS ==========

  /// Get production statistics
  Future<Map<String, dynamic>> getProductionStats() async {
    try {
      final productions = await getAllProductionsOnce();

      int totalProductions = productions.length;
      int totalEpisodes = 0;
      int publishedCount = 0;
      int inProductionCount = 0;
      Map<String, int> byLanguage = {};
      Map<String, int> byType = {};

      for (final production in productions) {
        totalEpisodes += production.totalEpisodes;

        if (production.status == 'published') publishedCount++;
        if (production.status == 'inProduction') inProductionCount++;

        byLanguage[production.language] = (byLanguage[production.language] ?? 0) + 1;
        byType[production.productionType] = (byType[production.productionType] ?? 0) + 1;
      }

      return {
        'totalProductions': totalProductions,
        'totalEpisodes': totalEpisodes,
        'publishedCount': publishedCount,
        'inProductionCount': inProductionCount,
        'byLanguage': byLanguage,
        'byType': byType,
      };
    } catch (e) {
      debugPrint('Error getting production stats: $e');
      rethrow;
    }
  }

  /// Get statistics for specific languages
  Future<Map<String, dynamic>> getProductionStatsByLanguages(List<String> languageCodes) async {
    try {
      final productions = await getProductionsByLanguages(languageCodes);

      int totalProductions = productions.length;
      int totalEpisodes = 0;
      int publishedCount = 0;
      Map<String, int> byLanguage = {};

      for (final production in productions) {
        totalEpisodes += production.totalEpisodes;
        if (production.status == 'published') publishedCount++;
        byLanguage[production.language] = (byLanguage[production.language] ?? 0) + 1;
      }

      return {
        'totalProductions': totalProductions,
        'totalEpisodes': totalEpisodes,
        'publishedCount': publishedCount,
        'byLanguage': byLanguage,
      };
    } catch (e) {
      debugPrint('Error getting production stats by languages: $e');
      rethrow;
    }
  }
}
