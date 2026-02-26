import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/media_yearly_stats.dart';

class MediaYearlyStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'media_yearly_stats';

  Future<MediaYearlyStats?> getByKey({
    required int year,
    required String language,
    required String platform,
    required String pageName,
  }) async {
    try {
      final docId = _buildDocId(
        year: year,
        language: language,
        platform: platform,
        pageName: pageName,
      );
      final doc = await _firestore.collection(collectionName).doc(docId).get();
      if (doc.exists) {
        return MediaYearlyStats.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting yearly stats: $e');
      rethrow;
    }
  }

  Future<void> saveStats(MediaYearlyStats stats) async {
    try {
      final docId = _buildDocId(
        year: stats.year,
        language: stats.language,
        platform: stats.platform,
        pageName: stats.pageName,
      );
      await _firestore
          .collection(collectionName)
          .doc(docId)
          .set(stats.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving yearly stats: $e');
      rethrow;
    }
  }

  Future<List<MediaYearlyStats>> listByYear(int year) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('year', isEqualTo: year)
          .get();
      return snapshot.docs
          .map(
            (doc) => MediaYearlyStats.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error listing yearly stats: $e');
      rethrow;
    }
  }

  String _buildDocId({
    required int year,
    required String language,
    required String platform,
    required String pageName,
  }) {
    final normalizedPage = pageName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    final safePage = normalizedPage.isEmpty ? 'page' : normalizedPage;
    return '${year}_${language}_${platform}_$safePage';
  }
}
