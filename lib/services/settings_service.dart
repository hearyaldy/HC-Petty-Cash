import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_settings.dart';
import '../utils/logger.dart';

class SettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String SETTINGS_DOC_ID = 'app_settings';
  static const String CATEGORIES_DOC_ID = 'custom_categories';
  static const String PROJECT_LANGUAGES_DOC_ID = 'project_languages';

  CollectionReference<Map<String, dynamic>> get _settingsCollection =>
      _firestore.collection('settings');

  // Get app settings
  Future<AppSettings> getSettings() async {
    try {
      final doc = await _settingsCollection.doc(SETTINGS_DOC_ID).get();
      if (doc.exists) {
        return AppSettings.fromFirestore(doc);
      } else {
        // Create default settings
        final defaultSettings = AppSettings(id: SETTINGS_DOC_ID);
        await saveSettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      AppLogger.severe('Error getting settings: $e');
      return AppSettings(id: SETTINGS_DOC_ID);
    }
  }

  // Save app settings
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final updatedSettings = settings.copyWith(updatedAt: DateTime.now());
      await _settingsCollection
          .doc(SETTINGS_DOC_ID)
          .set(updatedSettings.toFirestore());
    } catch (e) {
      AppLogger.severe('Error saving settings: $e');
      rethrow;
    }
  }

  // Update specific setting
  Future<void> updateSetting(String key, dynamic value) async {
    try {
      await _settingsCollection.doc(SETTINGS_DOC_ID).update({
        key: value,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      AppLogger.severe('Error updating setting $key: $e');
      rethrow;
    }
  }

  // Get custom categories
  Future<List<CustomCategory>> getCustomCategories() async {
    try {
      final doc = await _settingsCollection.doc(CATEGORIES_DOC_ID).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final categoriesList = data['categories'] as List<dynamic>? ?? [];
        return categoriesList
            .map((item) => CustomCategory.fromMap(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.severe('Error getting custom categories: $e');
      return [];
    }
  }

  // Save custom categories
  Future<void> saveCustomCategories(List<CustomCategory> categories) async {
    try {
      final categoriesData = categories.map((c) => c.toMap()).toList();
      await _settingsCollection.doc(CATEGORIES_DOC_ID).set({
        'categories': categoriesData,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      AppLogger.severe('Error saving custom categories: $e');
      rethrow;
    }
  }

  // Add custom category
  Future<void> addCustomCategory(CustomCategory category) async {
    try {
      final categories = await getCustomCategories();
      categories.add(category);
      await saveCustomCategories(categories);
    } catch (e) {
      AppLogger.severe('Error adding custom category: $e');
      rethrow;
    }
  }

  // Update custom category
  Future<void> updateCustomCategory(CustomCategory category) async {
    try {
      final categories = await getCustomCategories();
      final index = categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        categories[index] = category;
        await saveCustomCategories(categories);
      }
    } catch (e) {
      AppLogger.severe('Error updating custom category: $e');
      rethrow;
    }
  }

  // Delete custom category
  Future<void> deleteCustomCategory(String categoryId) async {
    try {
      final categories = await getCustomCategories();
      categories.removeWhere((c) => c.id == categoryId);
      await saveCustomCategories(categories);
    } catch (e) {
      AppLogger.severe('Error deleting custom category: $e');
      rethrow;
    }
  }

  // Get project languages (defaults + custom from Firestore)
  Future<List<ProjectLanguage>> getProjectLanguages() async {
    try {
      final defaults = ProjectLanguage.defaults;
      final doc = await _settingsCollection.doc(PROJECT_LANGUAGES_DOC_ID).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final customList = data['languages'] as List<dynamic>? ?? [];
        final customLanguages = customList
            .map((item) => ProjectLanguage.fromMap(item as Map<String, dynamic>))
            .toList();
        return [...defaults, ...customLanguages];
      }
      return defaults;
    } catch (e) {
      AppLogger.severe('Error getting project languages: $e');
      return ProjectLanguage.defaults;
    }
  }

  // Add a custom project language
  Future<void> addProjectLanguage(ProjectLanguage language) async {
    try {
      final doc = await _settingsCollection.doc(PROJECT_LANGUAGES_DOC_ID).get();
      List<Map<String, dynamic>> existing = [];
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final list = data['languages'] as List<dynamic>? ?? [];
        existing = list.cast<Map<String, dynamic>>();
      }
      existing.add(language.toMap());
      await _settingsCollection.doc(PROJECT_LANGUAGES_DOC_ID).set({
        'languages': existing,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      AppLogger.severe('Error adding project language: $e');
      rethrow;
    }
  }

  // Stream for real-time settings updates
  Stream<AppSettings> settingsStream() {
    return _settingsCollection.doc(SETTINGS_DOC_ID).snapshots().map(
      (doc) {
        if (doc.exists) {
          return AppSettings.fromFirestore(doc);
        }
        return AppSettings(id: SETTINGS_DOC_ID);
      },
    );
  }
}
