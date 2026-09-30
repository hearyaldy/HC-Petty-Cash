import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Aggregated engagement totals returned by the [mediaEngagementSync]
/// Cloud Function for a batch of scraped Facebook posts.
class FacebookSyncResult {
  final int postCount;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final DateTime? earliestPostDate;

  FacebookSyncResult({
    required this.postCount,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    this.earliestPostDate,
  });

  factory FacebookSyncResult.fromJson(Map<String, dynamic> json) {
    return FacebookSyncResult(
      postCount: json['postCount'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      earliestPostDate: json['earliestPostDate'] != null
          ? DateTime.tryParse(json['earliestPostDate'] as String)
          : null,
    );
  }
}

/// Calls through the `mediaEngagementSync` Cloud Function (see
/// `functions/index.js`) rather than Apify directly — the client never
/// holds APIFY_TOKEN, same proxy pattern as [MediaPlanningAiService].
class MediaEngagementSyncService {
  MediaEngagementSyncService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  Uri _endpoint() {
    if (kIsWeb) {
      final host = Uri.base.host;
      final isLocalhost = host == 'localhost' ||
          host == '127.0.0.1' ||
          host == '::1' ||
          host.endsWith('.local');
      if (!isLocalhost) {
        return Uri.parse('${Uri.base.origin}/api/media-engagement-sync');
      }
    }
    return Uri.parse(
      'https://us-central1-hc-petty-cash-report.cloudfunctions.net/mediaEngagementSync',
    );
  }

  /// Scrapes recent posts from [productionId]'s Facebook Page (the URL is
  /// looked up server-side from that production's own Firestore doc, not
  /// sent by the client) via Apify's Facebook Posts Scraper, and returns
  /// aggregated engagement totals for the caller to save.
  Future<FacebookSyncResult> syncFacebookPage({
    required String productionId,
    int resultsLimit = 20,
  }) async {
    final idToken = await firebase_auth.FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw StateError('You must be signed in to sync engagement data.');
    }

    final response = await _http.post(
      _endpoint(),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({'productionId': productionId, 'resultsLimit': resultsLimit}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) detail = data['error'].toString();
      } catch (_) {}
      throw StateError('Engagement sync failed: ${response.statusCode} $detail');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FacebookSyncResult.fromJson(data['data'] as Map<String, dynamic>? ?? {});
  }
}
