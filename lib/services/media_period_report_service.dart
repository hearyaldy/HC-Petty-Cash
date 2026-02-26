import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/media_period_report.dart';

class MediaPeriodReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'media_period_reports';

  Future<List<MediaPeriodReport>> listReports({
    required int year,
    String? language,
    String? platform,
    String? pageName,
  }) async {
    try {
      final yearStart = DateTime(year, 1, 1);
      final yearEnd = DateTime(year, 12, 31, 23, 59, 59);

      // Build query with equality filters only to avoid composite index requirements
      Query<Map<String, dynamic>> query = _firestore.collection(collectionName);

      if (language != null && language.isNotEmpty) {
        query = query.where('language', isEqualTo: language);
      }
      if (platform != null && platform.isNotEmpty) {
        query = query.where('platform', isEqualTo: platform);
      }
      if (pageName != null && pageName.isNotEmpty) {
        query = query.where('pageName', isEqualTo: pageName);
      }

      final snapshot = await query.get();

      // Filter by year and sort in memory to avoid composite index issues
      var reports = snapshot.docs
          .map((doc) =>
              MediaPeriodReport.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .where((report) =>
              report.periodStart.isAfter(yearStart.subtract(const Duration(days: 1))) &&
              report.periodStart.isBefore(yearEnd.add(const Duration(days: 1))))
          .toList();

      // Sort by periodStart descending
      reports.sort((a, b) => b.periodStart.compareTo(a.periodStart));

      return reports;
    } catch (e) {
      debugPrint('Error listing media period reports: $e');
      rethrow;
    }
  }

  Future<void> createReport(MediaPeriodReport report) async {
    await _ensureNoOverlap(report);
    await _firestore
        .collection(collectionName)
        .doc(report.id)
        .set(report.toFirestore());
  }

  Future<void> updateReport(MediaPeriodReport report) async {
    await _ensureNoOverlap(report, excludeId: report.id);
    await _firestore
        .collection(collectionName)
        .doc(report.id)
        .set(report.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteReport(String reportId) async {
    await _firestore.collection(collectionName).doc(reportId).delete();
  }

  Future<void> _ensureNoOverlap(MediaPeriodReport report, {String? excludeId}) async {
    // Simplified query to avoid requiring composite index - filter in memory
    final query = _firestore
        .collection(collectionName)
        .where('language', isEqualTo: report.language)
        .where('platform', isEqualTo: report.platform)
        .where('pageName', isEqualTo: report.pageName);

    final snapshot = await query.get();
    for (final doc in snapshot.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final existing =
          MediaPeriodReport.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
      // Two periods overlap if: A starts before B ends AND A ends after B starts
      final overlaps = existing.periodStart.isBefore(report.periodEnd) &&
          existing.periodEnd.isAfter(report.periodStart);
      if (overlaps) {
        throw Exception(
          'Report overlaps existing period: ${existing.periodStart} - ${existing.periodEnd}',
        );
      }
    }
  }
}
