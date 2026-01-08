import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
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
}
