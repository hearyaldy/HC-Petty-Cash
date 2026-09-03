import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

class EmailAttachmentService {
  static const String _functionsRegion = 'us-central1';

  Uri get _sendEmailWithAttachmentUri => Uri.parse(
        'https://$_functionsRegion-${DefaultFirebaseOptions.currentPlatform.projectId}.cloudfunctions.net/sendEmailWithAttachment',
      );

  Future<void> sendEmailWithAttachment({
    required String requestId,
    required String recipientEmail,
    String? recipientName,
    required String subject,
    required String htmlBody,
    required List<int> attachmentBytes,
    required String attachmentName,
  }) async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      throw Exception('You must be signed in to send emails.');
    }

    final idToken = await firebaseUser.getIdToken();
    final response = await http.post(
      _sendEmailWithAttachmentUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'requestId': requestId,
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'subject': subject,
        'htmlBody': htmlBody,
        'attachmentBase64': base64Encode(attachmentBytes),
        'attachmentName': attachmentName,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Failed to send email.';
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
