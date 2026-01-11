import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Service for compressing images before upload to save storage space
class ImageCompressionService {
  /// Maximum width for compressed images
  static const int maxWidth = 1200;

  /// Maximum height for compressed images
  static const int maxHeight = 1200;

  /// Quality for JPEG compression (0-100)
  static const int compressionQuality = 75;

  /// Maximum file size in bytes (500KB)
  static const int maxFileSizeBytes = 500 * 1024;

  /// Compress image bytes for web platform
  static Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int? quality,
    int? maxWidthOverride,
    int? maxHeightOverride,
  }) async {
    try {
      // Quality parameter is reserved for future JPEG encoding implementation
      final _ = quality ?? compressionQuality;

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Calculate new dimensions while maintaining aspect ratio
      final originalWidth = image.width;
      final originalHeight = image.height;
      final effectiveMaxWidth = maxWidthOverride ?? maxWidth;
      final effectiveMaxHeight = maxHeightOverride ?? maxHeight;

      double scale = 1.0;
      if (originalWidth > effectiveMaxWidth ||
          originalHeight > effectiveMaxHeight) {
        final widthScale = effectiveMaxWidth / originalWidth;
        final heightScale = effectiveMaxHeight / originalHeight;
        scale = widthScale < heightScale ? widthScale : heightScale;
      }

      final newWidth = (originalWidth * scale).round();
      final newHeight = (originalHeight * scale).round();

      // If image is already small enough and quality is acceptable, return original
      if (scale == 1.0 && bytes.length <= maxFileSizeBytes) {
        return bytes;
      }

      // Create a picture recorder and canvas
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Draw the scaled image
      final srcRect = ui.Rect.fromLTWH(
        0,
        0,
        originalWidth.toDouble(),
        originalHeight.toDouble(),
      );
      final dstRect = ui.Rect.fromLTWH(
        0,
        0,
        newWidth.toDouble(),
        newHeight.toDouble(),
      );

      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      canvas.drawImageRect(image, srcRect, dstRect, paint);

      // Convert to image
      final picture = recorder.endRecording();
      final resizedImage = await picture.toImage(newWidth, newHeight);

      // Convert to bytes
      final byteData = await resizedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        return bytes;
      }

      final compressedBytes = byteData.buffer.asUint8List();

      AppLogger.info(
        'Image compressed: ${bytes.length} -> ${compressedBytes.length} bytes '
        '(${((1 - compressedBytes.length / bytes.length) * 100).toStringAsFixed(1)}% reduction)',
      );

      // Clean up
      image.dispose();
      resizedImage.dispose();

      return compressedBytes;
    } catch (e) {
      AppLogger.warning('Image compression failed, using original: $e');
      return bytes;
    }
  }

  /// Compress an image file (for mobile platforms)
  static Future<File> compressImageFile(
    File file, {
    int? quality,
    int? maxWidthOverride,
    int? maxHeightOverride,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final compressedBytes = await compressImageBytes(
        bytes,
        quality: quality,
        maxWidthOverride: maxWidthOverride,
        maxHeightOverride: maxHeightOverride,
      );

      // If compression didn't help, return original file
      if (compressedBytes.length >= bytes.length) {
        return file;
      }

      // Create a new temporary file with compressed data
      final tempDir = file.parent;
      final fileName = file.path.split(Platform.pathSeparator).last;
      final compressedFileName = 'compressed_$fileName';
      final compressedFile = File('${tempDir.path}/$compressedFileName');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      AppLogger.warning('File compression failed, using original: $e');
      return file;
    }
  }

  /// Check if file is an image based on extension
  static bool isImageFile(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(extension);
  }

  /// Get file size in human readable format
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
