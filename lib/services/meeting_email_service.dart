import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

class MeetingEmailService {
  static const String _functionsRegion = 'us-central1';

  Uri get _sendStyledInvitationUri => Uri.parse(
    'https://$_functionsRegion-${DefaultFirebaseOptions.currentPlatform.projectId}.cloudfunctions.net/sendStyledMeetingInvitation',
  );

  Future<void> sendStyledInvitation({
    required String recipientEmail,
    required String recipientName,
    required String subject,
    required String htmlBody,
  }) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw Exception('You must be signed in to send invitations.');
    }

    final idToken = await firebaseUser.getIdToken();
    final response = await http.post(
      _sendStyledInvitationUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'subject': subject,
        'htmlBody': htmlBody,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to send styled invitation.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'];
        if (error is String && error.trim().isNotEmpty) {
          message = error;
        }
      } catch (_) {
        if (response.body.trim().isNotEmpty) {
          message = response.body.trim();
        }
      }
      throw Exception(message);
    }
  }
}
