import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/media_production.dart';
import '../models/media_season.dart';
import '../models/media_episode.dart';
import '../models/media_engagement.dart';
import '../models/enums.dart';
import '../services/media_production_service.dart';
import '../services/media_engagement_service.dart';

class MediaProductionProvider extends ChangeNotifier {
  final MediaProductionService _productionService = MediaProductionService();
  final MediaEngagementService _engagementService = MediaEngagementService();
  final Uuid _uuid = const Uuid();

  List<MediaProduction> _productions = [];
  MediaProduction? _currentProduction;
  List<MediaSeason> _currentSeasons = [];
  List<MediaEpisode> _currentEpisodes = [];
  List<MediaEngagement> _currentEngagements = [];
  Map<String, dynamic>? _currentEngagementStats;
  bool _isLoading = false;
  String? _error;

  // User's assigned languages for filtering
  List<String> _userLanguages = [];

  // Getters
  List<MediaProduction> get productions => _productions;
  MediaProduction? get currentProduction => _currentProduction;
  List<MediaSeason> get currentSeasons => _currentSeasons;
  List<MediaEpisode> get currentEpisodes => _currentEpisodes;
  List<MediaEngagement> get currentEngagements => _currentEngagements;
  Map<String, dynamic>? get currentEngagementStats => _currentEngagementStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filter productions by type
  List<MediaProduction> get seriesProductions =>
      _productions.where((p) => p.productionType == ProductionType.series.name).toList();

  List<MediaProduction> get standaloneProductions =>
      _productions.where((p) => p.productionType == ProductionType.standalone.name).toList();

  // Filter productions by status
  List<MediaProduction> get publishedProductions =>
      _productions.where((p) => p.status == ProductionStatus.published.name).toList();

  List<MediaProduction> get inProductionProductions =>
      _productions.where((p) => p.status == ProductionStatus.inProduction.name).toList();

  // Filter by language
  List<MediaProduction> getProductionsByLanguage(String languageCode) =>
      _productions.where((p) => p.language == languageCode).toList();

  // Set user's assigned languages
  void setUserLanguages(List<String> languages) {
    _userLanguages = languages;
  }

  // ========== LOAD METHODS ==========

  /// Load all productions (for admins)
  Future<void> loadAllProductions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _productions = await _productionService.getAllProductionsOnce();
    } catch (e) {
      _error = 'Failed to load productions: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load productions for user's assigned languages
  Future<void> loadProductionsForUser(List<String> languageCodes) async {
    _isLoading = true;
    _error = null;
    _userLanguages = languageCodes;
    notifyListeners();

    try {
      if (languageCodes.isEmpty) {
        _productions = [];
      } else {
        _productions = await _productionService.getProductionsByLanguages(languageCodes);
      }
    } catch (e) {
      _error = 'Failed to load productions: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load a single production with all details
  Future<void> loadProductionWithDetails(String productionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentProduction = await _productionService.getProductionById(productionId);

      if (_currentProduction != null) {
        // Load seasons
        _currentSeasons = await _productionService.getSeasonsForProductionOnce(productionId);

        // Load all episodes for this production
        _currentEpisodes = await _productionService.getEpisodesForProductionOnce(productionId);

        // Load engagements
        _currentEngagements = await _engagementService.getEngagementsForProductionOnce(productionId);

        // Get aggregated stats
        _currentEngagementStats = await _engagementService.getAggregatedStatsForProduction(productionId);
      }
    } catch (e) {
      _error = 'Failed to load production details: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load episodes for a specific season
  Future<List<MediaEpisode>> loadEpisodesForSeason(String seasonId) async {
    try {
      return await _productionService.getEpisodesForSeasonOnce(seasonId);
    } catch (e) {
      debugPrint('Failed to load episodes for season: $e');
      return [];
    }
  }

  // ========== PRODUCTION CRUD ==========

  /// Create a new production
  Future<MediaProduction?> createProduction({
    required String title,
    String? description,
    required String language,
    required String productionType,
    String? projectId,
    String? projectName,
    String? thumbnailUrl,
    int? totalSeasons,
    int? totalEpisodes,
    double? budget,
    int? productionYear,
    List<String>? productionUrls,
    int? durationMinutes,
    String? category,
    List<String>? customCategories,
    required String createdById,
    required String createdByName,
    List<String>? teamMemberIds,
    List<String>? teamMemberNames,
    String? notes,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final production = MediaProduction(
        id: _uuid.v4(),
        title: title,
        description: description,
        language: language,
        productionType: productionType,
        status: ProductionStatus.planning.name,
        projectId: projectId,
        projectName: projectName,
        totalSeasons: totalSeasons ?? 0,
        totalEpisodes: totalEpisodes ?? 0,
        thumbnailUrl: thumbnailUrl,
        budget: budget,
        productionYear: productionYear,
        productionUrls: productionUrls ?? [],
        durationMinutes: durationMinutes,
        category: category,
        customCategories: customCategories ?? [],
        createdById: createdById,
        createdByName: createdByName,
        teamMemberIds: teamMemberIds ?? [],
        teamMemberNames: teamMemberNames ?? [],
        createdAt: DateTime.now(),
        notes: notes,
      );

      await _productionService.createProduction(production);
      final createdProduction = production.copyWith();

      // Add to local list
      _productions.insert(0, createdProduction);
      notifyListeners();

      return createdProduction;
    } catch (e) {
      _error = 'Failed to create production: $e';
      debugPrint(_error);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update production
  Future<bool> updateProduction(MediaProduction production) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedProduction = production.copyWith(
        updatedAt: DateTime.now(),
      );

      await _productionService.updateProduction(updatedProduction);

      // Update local list
      final index = _productions.indexWhere((p) => p.id == production.id);
      if (index >= 0) {
        _productions[index] = updatedProduction;
      }

      // Update current production if it's the same
      if (_currentProduction?.id == production.id) {
        _currentProduction = updatedProduction;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update production: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete production
  Future<bool> deleteProduction(String productionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Delete engagements first
      await _engagementService.deleteEngagementsForProduction(productionId);

      // Delete production (service handles seasons/episodes cascade)
      await _productionService.deleteProduction(productionId);

      // Remove from local list
      _productions.removeWhere((p) => p.id == productionId);

      // Clear current if deleted
      if (_currentProduction?.id == productionId) {
        clearCurrentProduction();
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete production: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== SEASON CRUD ==========

  /// Create a new season
  Future<MediaSeason?> createSeason({
    required String productionId,
    required int seasonNumber,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final season = MediaSeason(
        id: _uuid.v4(),
        productionId: productionId,
        seasonNumber: seasonNumber,
        title: title,
        description: description,
        episodeCount: 0,
        status: ProductionStatus.planning.name,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
      );

      await _productionService.createSeason(season);

      // Add to local list
      _currentSeasons.add(season);
      _currentSeasons.sort((a, b) => a.seasonNumber.compareTo(b.seasonNumber));
      notifyListeners();

      return season;
    } catch (e) {
      _error = 'Failed to create season: $e';
      debugPrint(_error);
      return null;
    }
  }

  /// Update season
  Future<bool> updateSeason(MediaSeason season) async {
    try {
      final updatedSeason = season.copyWith(updatedAt: DateTime.now());
      await _productionService.updateSeason(updatedSeason);

      final index = _currentSeasons.indexWhere((s) => s.id == season.id);
      if (index >= 0) {
        _currentSeasons[index] = updatedSeason;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update season: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Delete season
  Future<bool> deleteSeason(String seasonId, String productionId) async {
    try {
      await _productionService.deleteSeason(seasonId, productionId);

      _currentSeasons.removeWhere((s) => s.id == seasonId);
      _currentEpisodes.removeWhere((e) => e.seasonId == seasonId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete season: $e';
      debugPrint(_error);
      return false;
    }
  }

  // ========== EPISODE CRUD ==========

  /// Create a new episode
  Future<MediaEpisode?> createEpisode({
    required String productionId,
    required String seasonId,
    required int episodeNumber,
    required String title,
    String? description,
    int? durationMinutes,
    String? thumbnailUrl,
    String? videoUrl,
  }) async {
    try {
      final episode = MediaEpisode(
        id: _uuid.v4(),
        productionId: productionId,
        seasonId: seasonId,
        episodeNumber: episodeNumber,
        title: title,
        description: description,
        durationMinutes: durationMinutes,
        status: EpisodeStatus.draft.name,
        thumbnailUrl: thumbnailUrl,
        videoUrl: videoUrl,
        createdAt: DateTime.now(),
      );

      await _productionService.createEpisode(episode);

      _currentEpisodes.add(episode);
      _currentEpisodes.sort((a, b) {
        final seasonCompare = a.seasonId.compareTo(b.seasonId);
        if (seasonCompare != 0) return seasonCompare;
        return a.episodeNumber.compareTo(b.episodeNumber);
      });

      notifyListeners();
      return episode;
    } catch (e) {
      _error = 'Failed to create episode: $e';
      debugPrint(_error);
      return null;
    }
  }

  /// Update episode
  Future<bool> updateEpisode(MediaEpisode episode) async {
    try {
      final updatedEpisode = episode.copyWith(updatedAt: DateTime.now());
      await _productionService.updateEpisode(updatedEpisode);

      final index = _currentEpisodes.indexWhere((e) => e.id == episode.id);
      if (index >= 0) {
        _currentEpisodes[index] = updatedEpisode;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update episode: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Delete episode
  Future<bool> deleteEpisode(String episodeId, String seasonId, String productionId) async {
    try {
      await _productionService.deleteEpisode(episodeId, seasonId, productionId);

      _currentEpisodes.removeWhere((e) => e.id == episodeId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete episode: $e';
      debugPrint(_error);
      return false;
    }
  }

  // ========== ENGAGEMENT CRUD ==========

  /// Add engagement record
  Future<MediaEngagement?> addEngagement({
    required String productionId,
    String? episodeId,
    required String platform,
    required DateTime recordedDate,
    required DateTime periodStart,
    required DateTime periodEnd,
    required int views,
    required int likes,
    required int comments,
    required int shares,
    int? subscribers,
    int? watchTimeHours,
    int? avgViewDurationSeconds,
    int? impressions,
    int? reach,
    int? saves,
    int? profileVisits,
    int? videoCompletions,
    int? followers,
    required String enteredById,
    required String enteredByName,
    String? notes,
  }) async {
    try {
      final engagement = MediaEngagement(
        id: _uuid.v4(),
        productionId: productionId,
        episodeId: episodeId,
        platform: platform,
        recordedDate: recordedDate,
        periodStart: periodStart,
        periodEnd: periodEnd,
        views: views,
        likes: likes,
        comments: comments,
        shares: shares,
        subscribers: subscribers,
        watchTimeHours: watchTimeHours,
        avgViewDurationSeconds: avgViewDurationSeconds,
        impressions: impressions,
        reach: reach,
        saves: saves,
        profileVisits: profileVisits,
        videoCompletions: videoCompletions,
        followers: followers,
        enteredById: enteredById,
        enteredByName: enteredByName,
        createdAt: DateTime.now(),
        notes: notes,
      );

      await _engagementService.addEngagement(engagement);

      _currentEngagements.insert(0, engagement);

      // Refresh stats
      _currentEngagementStats = await _engagementService.getAggregatedStatsForProduction(productionId);

      notifyListeners();
      return engagement;
    } catch (e) {
      _error = 'Failed to add engagement: $e';
      debugPrint(_error);
      return null;
    }
  }

  /// Update engagement
  Future<bool> updateEngagement(MediaEngagement engagement) async {
    try {
      final updatedEngagement = engagement.copyWith(updatedAt: DateTime.now());
      await _engagementService.updateEngagement(updatedEngagement);

      final index = _currentEngagements.indexWhere((e) => e.id == engagement.id);
      if (index >= 0) {
        _currentEngagements[index] = updatedEngagement;
      }

      // Refresh stats
      _currentEngagementStats = await _engagementService.getAggregatedStatsForProduction(engagement.productionId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update engagement: $e';
      debugPrint(_error);
      return false;
    }
  }

  /// Delete engagement
  Future<bool> deleteEngagement(String engagementId, String productionId) async {
    try {
      await _engagementService.deleteEngagement(engagementId);

      _currentEngagements.removeWhere((e) => e.id == engagementId);

      // Refresh stats
      _currentEngagementStats = await _engagementService.getAggregatedStatsForProduction(productionId);

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete engagement: $e';
      debugPrint(_error);
      return false;
    }
  }

  // ========== STATISTICS ==========

  /// Get overall production statistics
  Future<Map<String, dynamic>> getProductionStats() async {
    return _productionService.getProductionStats();
  }

  /// Get statistics for user's assigned languages
  Future<Map<String, dynamic>> getProductionStatsForUser() async {
    if (_userLanguages.isEmpty) {
      return {};
    }
    return _productionService.getProductionStatsByLanguages(_userLanguages);
  }

  /// Get yearly engagement statistics
  Future<Map<String, dynamic>> getYearlyEngagementStats(int year) async {
    return _engagementService.getYearlyStats(year);
  }

  // ========== CLEAR METHODS ==========

  /// Clear current production and related data
  void clearCurrentProduction() {
    _currentProduction = null;
    _currentSeasons = [];
    _currentEpisodes = [];
    _currentEngagements = [];
    _currentEngagementStats = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Clear all data
  void clearAll() {
    _productions = [];
    _currentProduction = null;
    _currentSeasons = [];
    _currentEpisodes = [];
    _currentEngagements = [];
    _currentEngagementStats = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Refresh productions (invalidate cache and reload)
  Future<void> refreshProductions() async {
    _productionService.invalidateCache();
    if (_userLanguages.isNotEmpty) {
      await loadProductionsForUser(_userLanguages);
    } else {
      await loadAllProductions();
    }
  }
}
