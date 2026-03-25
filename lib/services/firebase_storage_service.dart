import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload attachment and return download URL (mobile)
  Future<String> uploadAttachment({
    required String transactionId,
    required File file,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'attachments/$transactionId/${timestamp}_$fileName';
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      AppLogger.severe('Upload error: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload attachment from bytes (web)
  Future<String> uploadAttachmentFromBytes({
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'attachments/$transactionId/${timestamp}_$fileName';
      final ref = _storage.ref().child(storagePath);

      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      AppLogger.severe('Upload error: $e');
      throw Exception('Failed to upload file: $e');
    }
  }

  // Upload multiple attachments
  Future<List<String>> uploadMultipleAttachments({
    required String transactionId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      try {
        final url = await uploadAttachment(
          transactionId: transactionId,
          file: file,
        );
        urls.add(url);
      } catch (e) {
        AppLogger.warning('Error uploading file ${file.path}: $e');
        // Continue with other files even if one fails
      }
    }
    return urls;
  }

  // Delete attachment by URL
  Future<void> deleteAttachment(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (e) {
      AppLogger.warning('Delete error: $e');
      // Don't throw - file might already be deleted or URL invalid
    }
  }

  // Delete all attachments for a transaction
  Future<void> deleteAllAttachments(String transactionId) async {
    try {
      final ref = _storage.ref().child('attachments/$transactionId');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (e) {
          AppLogger.warning('Error deleting item ${item.name}: $e');
        }
      }
    } catch (e) {
      AppLogger.warning('Delete all error: $e');
    }
  }

  // Delete multiple attachments by URLs
  Future<void> deleteMultipleAttachments(List<String> urls) async {
    for (final url in urls) {
      await deleteAttachment(url);
    }
  }

  // Get download URL for a file path
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      AppLogger.warning('Error getting download URL: $e');
      return null;
    }
  }

  // Check if file exists in storage
  Future<bool> fileExists(String storagePath) async {
    try {
      final ref = _storage.ref().child(storagePath);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Upload support document from bytes (web)
  Future<String> uploadSupportDocument({
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      debugPrint('=== STORAGE SERVICE: UPLOAD DEBUG START ===');
      debugPrint('Transaction ID: $transactionId');
      debugPrint('File name: $fileName');
      debugPrint('File size: ${bytes.length} bytes');

      AppLogger.info('=== UPLOAD DEBUG START ===');
      AppLogger.info('Transaction ID: $transactionId');
      AppLogger.info('File name: $fileName');
      AppLogger.info('File size: ${bytes.length} bytes');

      // Check authentication
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      debugPrint(
        'Firebase Auth User ID: ${currentUser?.uid ?? "NOT AUTHENTICATED"}',
      );
      debugPrint('Firebase Auth User Email: ${currentUser?.email ?? "N/A"}');

      AppLogger.info(
        'Current user: ${currentUser?.uid ?? "NOT AUTHENTICATED"}',
      );
      AppLogger.info('User email: ${currentUser?.email ?? "N/A"}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final storagePath =
          'support_documents/$transactionId/${timestamp}_support.$extension';

      debugPrint('Storage path: $storagePath');
      AppLogger.info('Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);
      debugPrint('Storage reference created, bucket: ${_storage.bucket}');
      AppLogger.info('Storage reference created');

      debugPrint('Starting upload...');
      AppLogger.info('Starting upload...');
      final uploadTask = ref.putData(bytes);

      // Listen to upload state changes
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes * 100;
          AppLogger.info('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (error) {
          AppLogger.severe('Upload stream error: $error');
        },
      );

      final snapshot = await uploadTask.whenComplete(() {});
      AppLogger.info('Upload completed');

      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.info('Download URL obtained: $downloadUrl');
      AppLogger.info('=== UPLOAD DEBUG END ===');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('=== STORAGE SERVICE: UPLOAD ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=====================================');

      AppLogger.severe('Upload support document error: $e');
      AppLogger.severe('Stack trace: $stackTrace');
      AppLogger.severe('Error type: ${e.runtimeType}');
      throw Exception('Failed to upload support document: $e');
    }
  }

  // Upload support document from file (mobile)
  Future<String> uploadSupportDocumentFile({
    required String transactionId,
    required File file,
  }) async {
    try {
      AppLogger.info('=== UPLOAD DEBUG START (Mobile) ===');
      AppLogger.info('Transaction ID: $transactionId');
      AppLogger.info('File path: ${file.path}');

      // Check authentication
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      AppLogger.info(
        'Current user: ${currentUser?.uid ?? "NOT AUTHENTICATED"}',
      );
      AppLogger.info('User email: ${currentUser?.email ?? "N/A"}');

      final fileName = file.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final storagePath =
          'support_documents/$transactionId/${timestamp}_support.$extension';

      AppLogger.info('Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);
      AppLogger.info('Storage reference created');

      AppLogger.info('Starting upload...');
      final uploadTask = ref.putFile(file);

      // Listen to upload state changes
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes * 100;
          AppLogger.info('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (error) {
          AppLogger.severe('Upload stream error: $error');
        },
      );

      final snapshot = await uploadTask.whenComplete(() {});
      AppLogger.info('Upload completed');

      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.info('Download URL obtained: $downloadUrl');
      AppLogger.info('=== UPLOAD DEBUG END (Mobile) ===');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('=== STORAGE SERVICE: UPLOAD ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=====================================');

      AppLogger.severe('Upload support document error: $e');
      AppLogger.severe('Stack trace: $stackTrace');
      AppLogger.severe('Error type: ${e.runtimeType}');
      throw Exception('Failed to upload support document: $e');
    }
  }

  // Delete support document for a transaction
  Future<void> deleteSupportDocument(String transactionId) async {
    try {
      final ref = _storage.ref().child('support_documents/$transactionId');
      final listResult = await ref.listAll();

      for (final item in listResult.items) {
        try {
          await item.delete();
        } catch (e) {
          AppLogger.warning('Error deleting support document ${item.name}: $e');
        }
      }
    } catch (e) {
      AppLogger.warning('Delete support document error: $e');
    }
  }

  // Download image data directly from Firebase Storage using the storage path
  Future<Uint8List?> downloadImageData(String downloadUrl) async {
    const timeout = Duration(seconds: 30);

    try {
      debugPrint('Attempting to download image data from URL: $downloadUrl');

      // Extract the storage path from the download URL
      final uri = Uri.parse(downloadUrl);
      final pathSegments = uri.pathSegments;

      debugPrint('URI path segments: $pathSegments');

      // Find the storage path from the URL
      int storageIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        debugPrint('Checking segment $i: ${pathSegments[i]}');
        if (pathSegments[i] == 'o') {
          // 'o' is for objects in Firebase Storage URLs
          storageIndex = i + 1;
          debugPrint('Found storage path starting at index: $storageIndex');
          break;
        }
      }

      if (storageIndex != -1 && storageIndex < pathSegments.length) {
        final storagePath = pathSegments.sublist(storageIndex).join('/');
        // Decode URL-encoded characters
        final decodedPath = Uri.decodeComponent(storagePath);
        debugPrint('Decoded storage path: $decodedPath');

        final ref = _storage.ref().child(decodedPath);
        debugPrint('Created reference: ${ref.fullPath}');

        // Check if file exists first with timeout
        try {
          final metadata = await ref.getMetadata().timeout(timeout);
          debugPrint(
            'File metadata retrieved: ${metadata.contentType}, size: ${metadata.size}',
          );
        } catch (metaError) {
          debugPrint('Error getting metadata: $metaError');
        }

        // Download with timeout
        final imageData = await ref.getData().timeout(timeout);
        debugPrint('Successfully downloaded ${imageData?.length ?? 0} bytes');
        return imageData;
      } else {
        debugPrint('Could not extract storage path from URL');
        // If we can't extract the path, try using the download URL directly
        return await _downloadImageDataFromUrl(downloadUrl);
      }
    } catch (e) {
      debugPrint('Download image data error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      AppLogger.severe('Download image data error: $e');
      // If the direct approach fails, try using the download URL directly
      try {
        return await _downloadImageDataFromUrl(downloadUrl);
      } catch (fallbackError) {
        debugPrint('Fallback download also failed: $fallbackError');
        return null;
      }
    }
  }

  // Fallback method to download image data using the download URL directly
  Future<Uint8List?> _downloadImageDataFromUrl(String downloadUrl) async {
    const timeout = Duration(seconds: 30);

    try {
      debugPrint('Trying fallback method with direct download URL: $downloadUrl');

      // For web platform, try using http package to fetch the image
      if (kIsWeb) {
        final uri = Uri.parse(downloadUrl);
        final response = await http.get(uri).timeout(timeout);
        if (response.statusCode == 200) {
          debugPrint(
            'HTTP download succeeded, downloaded ${response.bodyBytes.length} bytes',
          );
          return response.bodyBytes;
        } else {
          debugPrint('HTTP download failed with status: ${response.statusCode}');
          throw Exception(
            'HTTP request failed with status: ${response.statusCode}',
          );
        }
      }

      // Use the download URL directly to get a fresh reference for mobile
      final ref = _storage.refFromURL(downloadUrl);
      final imageData = await ref.getData().timeout(timeout);
      debugPrint(
        'Firebase Storage download succeeded, downloaded ${imageData?.length ?? 0} bytes',
      );
      return imageData;
    } catch (e) {
      debugPrint('Fallback method failed: $e');
      return null;
    }
  }
}
