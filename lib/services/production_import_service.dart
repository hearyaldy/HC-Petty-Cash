import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/media_production.dart';

/// Service to import production data from HC SEA Production List
class ProductionImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'media_productions';
  final _uuid = const Uuid();

  /// Get the list of productions to import from HC SEA Production List
  List<Map<String, dynamic>> getProductionData() {
    return [
      // Main Productions
      {'title': 'Pengharapan Di Rumah', 'language': 'ms', 'duration': 150, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Hope Worship', 'language': 'th', 'duration': 120, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Values', 'language': 'en', 'duration': 2, 'seasons': 1, 'episodes': 5, 'category': 'Values'},
      {'title': 'Youth Live', 'language': 'en', 'duration': 60, 'seasons': 1, 'episodes': 8, 'category': 'Youth'},
      {'title': 'G316', 'language': 'th', 'duration': 60, 'seasons': 1, 'episodes': 6, 'category': 'Youth'},
      {'title': 'Sharing Hope', 'language': 'en', 'duration': 15, 'seasons': 2, 'episodes': 52, 'category': 'Religion'},
      {'title': 'Randau Kehidupan', 'language': 'ms', 'duration': 75, 'seasons': 1, 'episodes': 95, 'category': 'Religion'},
      {'title': 'Pause+ve', 'language': 'en', 'duration': 15, 'seasons': 1, 'episodes': 16, 'category': 'Education'},
      {'title': 'Mom2Mom', 'language': 'en', 'duration': 30, 'seasons': 1, 'episodes': 15, 'category': 'Women'},
      {'title': 'The Little Preacher', 'language': 'en', 'duration': 15, 'seasons': 1, 'episodes': 12, 'category': 'Children'},
      {'title': 'Hope Music', 'language': 'en', 'duration': 5, 'seasons': 2, 'episodes': 1, 'category': 'Music'},
      {'title': 'One Step', 'language': 'en', 'duration': 5, 'seasons': 1, 'episodes': 15, 'category': 'Youth'},
      {'title': 'Eat Good with Kirly-Sue', 'language': 'en', 'duration': 30, 'seasons': 1, 'episodes': 12, 'category': 'Health'},
      {'title': 'The Faith I Live By', 'language': 'en', 'duration': 5, 'seasons': 1, 'episodes': 300, 'category': 'Religion'},
      {'title': 'Perspektif Podcast', 'language': 'ms', 'duration': 45, 'seasons': 2, 'episodes': 16, 'category': 'Religion'},
      {'title': 'Dapur Harapan', 'language': 'ms', 'duration': 30, 'seasons': 1, 'episodes': 15, 'category': 'Health'},
      {'title': 'Satu Langkah', 'language': 'ms', 'duration': 5, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Sarapan Kasih', 'language': 'ms', 'duration': 60, 'seasons': 1, 'episodes': 155, 'category': 'Religion'},
      {'title': 'Mimbar Pengharapan', 'language': 'ms', 'duration': 30, 'seasons': 2, 'episodes': 31, 'category': 'Religion'},
      {'title': 'Wacana Firman', 'language': 'ms', 'duration': 60, 'seasons': 3, 'episodes': 37, 'category': 'Religion'},
      {'title': 'Alkitab Menjawab', 'language': 'ms', 'duration': 15, 'seasons': 1, 'episodes': 16, 'category': 'Religion'},
      {'title': 'Tanya Kawan', 'language': 'ms', 'duration': 10, 'seasons': 2, 'episodes': 28, 'category': 'Youth'},
      {'title': 'Mimbar Pintas', 'language': 'ms', 'duration': 1, 'seasons': 1, 'episodes': 45, 'category': 'Religion'},
      {'title': 'Mari Berdoa', 'language': 'ms', 'duration': 60, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Pencarian Pengharapan', 'language': 'ms', 'duration': 60, 'seasons': 1, 'episodes': 7, 'category': 'Religion'},
      {'title': 'Jom Sembang', 'language': 'ms', 'duration': 60, 'seasons': 1, 'episodes': 15, 'category': 'Youth'},
      {'title': 'Selangkah Harapan', 'language': 'ms', 'duration': 3, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Pelita Wanita', 'language': 'ms', 'duration': 5, 'seasons': 2, 'episodes': 106, 'category': 'Women'},
      {'title': 'Fakta Menakjubkan', 'language': 'ms', 'duration': 30, 'seasons': 1, 'episodes': 23, 'category': 'Religion'},
      {'title': 'Lessons of Life', 'language': 'th', 'duration': 30, 'seasons': 1, 'episodes': 5195, 'category': 'Religion'},
      {'title': 'Heat The Word', 'language': 'th', 'duration': 5, 'seasons': 1, 'episodes': 10, 'category': 'Religion'},
      {'title': 'Embraced Testimonies', 'language': 'th', 'duration': 5, 'seasons': 1, 'episodes': 8, 'category': 'Community'},
      {'title': 'Music Videos', 'language': 'th', 'duration': 5, 'seasons': 1, 'episodes': 12, 'category': 'Music'},
      {'title': 'Youth Devotionals', 'language': 'th', 'duration': 5, 'seasons': 2, 'episodes': 30, 'category': 'Religion'},
      {'title': 'Health Is Wealth', 'language': 'th', 'duration': 10, 'seasons': 1, 'episodes': 22, 'category': 'Health'},
      {'title': "Let's Pray", 'language': 'th', 'duration': 60, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Quest Of Hope', 'language': 'th', 'duration': 60, 'seasons': 1, 'episodes': 7, 'category': 'Religion'},
      {'title': "Dr. Noi's Kitchen", 'language': 'th', 'duration': 30, 'seasons': 1, 'episodes': 15, 'category': 'Health'},
      {'title': 'Bridge Of Hope', 'language': 'th', 'duration': 15, 'seasons': 1, 'episodes': 21, 'category': 'Religion'},
      {'title': 'Prophecy Studies', 'language': 'km', 'duration': 60, 'seasons': 1, 'episodes': 11, 'category': 'Religion'},
      {'title': 'Pulpit Of Hope', 'language': 'km', 'duration': 15, 'seasons': 1, 'episodes': 20, 'category': 'Religion'},
      {'title': 'The Only Hope', 'language': 'km', 'duration': 60, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': '10 Days of Prayer', 'language': 'en', 'duration': 30, 'seasons': 1, 'episodes': 10, 'category': 'Religion'},
      {'title': '10 Days of Prayer (Thai)', 'language': 'th', 'duration': 30, 'seasons': 1, 'episodes': 10, 'category': 'Religion'},
      {'title': '10 Hari Berdoa', 'language': 'ms', 'duration': 30, 'seasons': 1, 'episodes': 10, 'category': 'Religion'},
      {'title': '10 Days of Prayer (Khmer)', 'language': 'km', 'duration': 30, 'seasons': 1, 'episodes': 10, 'category': 'Religion'},
      {'title': 'One Step (Chinese)', 'language': 'zh', 'duration': 5, 'seasons': 1, 'episodes': 15, 'category': 'Youth'},
      {'title': 'Journey to The Life', 'language': 'zh', 'duration': 20, 'seasons': 1, 'episodes': 15, 'category': 'Religion'},
      {'title': 'Sharing Hope (Chinese)', 'language': 'zh', 'duration': 5, 'seasons': 1, 'episodes': 22, 'category': 'Women'},
      {'title': 'Sarapan Kasih Daily Devotional', 'language': 'ms', 'duration': 5, 'seasons': 1, 'episodes': 200, 'category': 'Religion'},
    ];
  }

  /// Convert raw data to MediaProduction objects
  List<MediaProduction> createProductions({
    required String createdById,
    required String createdByName,
  }) {
    final productionData = getProductionData();
    final now = DateTime.now();

    return productionData.map((data) {
      final episodes = data['episodes'] as int;
      final seasons = data['seasons'] as int;

      return MediaProduction(
        id: _uuid.v4(),
        title: data['title'] as String,
        language: data['language'] as String,
        productionType: episodes > 1 ? 'series' : 'standalone',
        status: 'published',
        totalSeasons: seasons,
        totalEpisodes: episodes,
        durationMinutes: data['duration'] as int,
        category: data['category'] as String,
        productionYear: now.year,
        createdById: createdById,
        createdByName: createdByName,
        createdAt: now,
        publishedAt: now,
      );
    }).toList();
  }

  /// Import all productions to Firestore
  Future<int> importProductions({
    required String createdById,
    required String createdByName,
    bool skipExisting = true,
  }) async {
    final productions = createProductions(
      createdById: createdById,
      createdByName: createdByName,
    );

    int imported = 0;

    for (final production in productions) {
      try {
        if (skipExisting) {
          // Check if production with same title and language exists
          final existing = await _firestore
              .collection(collectionName)
              .where('title', isEqualTo: production.title)
              .where('language', isEqualTo: production.language)
              .limit(1)
              .get();

          if (existing.docs.isNotEmpty) {
            continue; // Skip existing
          }
        }

        await _firestore
            .collection(collectionName)
            .doc(production.id)
            .set(production.toFirestore());
        imported++;
      } catch (e) {
        // Continue with next production on error
        continue;
      }
    }

    return imported;
  }

  /// Get count of productions to import
  int getProductionCount() => getProductionData().length;
}
