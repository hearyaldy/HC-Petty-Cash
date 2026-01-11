import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firebase_storage_service.dart';
import '../services/image_compression_service.dart';
import '../services/voucher_export_service.dart';
import '../utils/logger.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

/// Dialog for uploading support documents with image compression
class SupportDocumentUploadDialog extends StatefulWidget {
  final String transactionId;
  final List<String> existingDocumentUrls;
  final Function(List<String>) onDocumentsUploaded;

  const SupportDocumentUploadDialog({
    super.key,
    required this.transactionId,
    List<String>? existingDocumentUrls,
    required this.onDocumentsUploaded,
  }) : existingDocumentUrls = existingDocumentUrls ?? const [];

  @override
  State<SupportDocumentUploadDialog> createState() =>
      _SupportDocumentUploadDialogState();
}

class _SupportDocumentUploadDialogState
    extends State<SupportDocumentUploadDialog> {
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploading = false;
  List<String> _uploadedUrls = [];
  String? _errorMessage;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    _uploadedUrls = List.from(widget.existingDocumentUrls);
  }

  Future<void> _pickFromGallery() async {
    await _pickAndUploadFile(fromCamera: false);
  }

  Future<void> _pickFromCamera() async {
    await _pickAndUploadFile(fromCamera: true);
  }

  Future<void> _pickAndUploadFile({bool fromCamera = false}) async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _uploadProgress = 0;
    });

    try {
      // Check authentication first
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      print('============ UPLOAD DEBUG START ============');
      print('User ID: ${currentUser?.uid ?? "NOT AUTHENTICATED"}');
      print('User Email: ${currentUser?.email ?? "N/A"}');
      print('Transaction ID: ${widget.transactionId}');

      AppLogger.info(
        'User attempting upload: ${currentUser?.uid ?? "NOT AUTHENTICATED"}',
      );
      AppLogger.info('User email: ${currentUser?.email ?? "N/A"}');

      if (currentUser == null) {
        print('ERROR: User is not authenticated!');
        throw Exception('User is not authenticated. Please log in again.');
      }

      Uint8List? imageBytes;
      String? fileName;

      if (kIsWeb) {
        // Web platform - use file picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result == null || result.files.isEmpty) {
          setState(() => _isUploading = false);
          return;
        }

        final file = result.files.first;
        imageBytes = file.bytes;
        fileName = file.name;
      } else {
        // Mobile platform - use image_picker
        XFile? pickedFile;

        if (fromCamera) {
          pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );
        } else {
          pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1200,
            maxHeight: 1200,
            imageQuality: 85,
          );
        }

        if (pickedFile == null) {
          setState(() => _isUploading = false);
          return;
        }

        imageBytes = await pickedFile.readAsBytes();
        fileName = pickedFile.name;
      }

      print('File picked: $fileName');
      print('File size: ${imageBytes?.length ?? 0} bytes');
      setState(() => _uploadProgress = 0.2);

      // Compress image
      print('Compressing image...');
      final compressedBytes = await ImageCompressionService.compressImageBytes(
        imageBytes!,
      );
      print('Compressed size: ${compressedBytes.length} bytes');
      setState(() => _uploadProgress = 0.5);

      // Upload to Firebase Storage
      print('Starting upload to Firebase Storage...');
      final downloadUrl = await _storageService.uploadSupportDocument(
        transactionId: widget.transactionId,
        bytes: compressedBytes,
        fileName: fileName!,
      );
      print('Upload successful! URL: $downloadUrl');

      setState(() {
        _uploadProgress = 1.0;
        _uploadedUrls.add(downloadUrl);
        _isUploading = false;
      });

      widget.onDocumentsUploaded(_uploadedUrls);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Support document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('============ UPLOAD ERROR ============');
      print('Error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack trace: $stackTrace');
      print('======================================');

      AppLogger.severe('Error uploading support document: $e');
      AppLogger.severe('Stack trace: $stackTrace');

      String errorMsg = e.toString();

      // Provide more specific error messages
      if (errorMsg.contains('unauthorized') ||
          errorMsg.contains('permission')) {
        errorMsg =
            'Permission denied. Please ensure you are logged in and have the correct permissions.';
      } else if (errorMsg.contains('network')) {
        errorMsg = 'Network error. Please check your internet connection.';
      } else if (errorMsg.contains('not found')) {
        errorMsg = 'Upload failed. Storage configuration may be incorrect.';
      }

      setState(() {
        _errorMessage =
            'Failed to upload: $errorMsg\n\nFull error: ${e.toString()}';
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $errorMsg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String> _getDownloadUrl(String originalUrl) async {
    try {
      // Extract the path from the original URL to get a fresh download URL
      // This helps when the original URL's token has expired
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;

      // Find the storage path from the URL
      int storageIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i] == 'o') {
          // 'o' is for objects in Firebase Storage URLs
          storageIndex = i + 1;
          break;
        }
      }

      if (storageIndex != -1 && storageIndex < pathSegments.length) {
        final storagePath = pathSegments.sublist(storageIndex).join('/');
        // Decode URL-encoded characters
        final decodedPath = Uri.decodeComponent(storagePath);

        final ref = FirebaseStorage.instance.ref().child(decodedPath);
        final freshUrl = await ref.getDownloadURL();
        return freshUrl;
      }
    } catch (e) {
      print('Error getting fresh download URL: $e');
      print('Original URL: $originalUrl');
      // If we can't get a fresh URL, return the original one
    }
    return originalUrl;
  }

  // Method to download image data directly from Firebase Storage
  Future<Uint8List?> _getImageData(String originalUrl) async {
    try {
      // Use the Firebase Storage service to download image data directly
      final storageService = FirebaseStorageService();
      return await storageService.downloadImageData(originalUrl);
    } catch (e) {
      print('Error downloading image data: $e');
      return null;
    }
  }

  Future<void> _deleteDocument(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text(
          'Are you sure you want to delete this support document?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      print('Deleting document from storage: $url');

      // Delete from Firebase Storage
      await _storageService.deleteAttachment(url);
      print('Document deleted from storage successfully');

      // Update local state
      setState(() {
        _uploadedUrls.remove(url);
        _isUploading = false;
      });

      // Notify parent to update Firestore
      print('Notifying parent with updated URLs: $_uploadedUrls');
      widget.onDocumentsUploaded(_uploadedUrls);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Support document deleted. ${_uploadedUrls.length} document${_uploadedUrls.length != 1 ? "s" : ""} remaining.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error deleting document: $e');
      setState(() {
        _errorMessage = 'Failed to delete: ${e.toString()}';
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to download image data directly from Firebase Storage
  Future<Uint8List?> _getImageDataGrid(String originalUrl) async {
    try {
      print('Widget requesting image data for URL: $originalUrl');
      // Use the Firebase Storage service to download image data directly
      final storageService = FirebaseStorageService();
      final result = await storageService.downloadImageData(originalUrl);
      print(
        'Widget received result: ${result != null ? "Success (${result.length} bytes)" : "Null"}',
      );
      return result;
    } catch (e) {
      print('Error downloading image data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return AlertDialog(
      title: const Text('Support Document'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Display all uploaded documents
            if (_uploadedUrls.isNotEmpty) ...[
              Text(
                '${_uploadedUrls.length} Support Document${_uploadedUrls.length > 1 ? "s" : ""}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _uploadedUrls.length,
                  itemBuilder: (context, index) {
                    final url = _uploadedUrls[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Builder(
                              builder: (context) {
                                // For web, try to use Image.network directly to avoid CORS issues
                                if (kIsWeb) {
                                  return Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print('Image load error: $error');
                                      print('URL: $url');
                                      print('Stack trace: $stackTrace');
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.broken_image,
                                              size: 32,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Could not load',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextButton(
                                              onPressed: () {
                                                if (kIsWeb) {
                                                  html.window.open(url, '_blank');
                                                }
                                              },
                                              child: const Text('Open', style: TextStyle(fontSize: 10)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                } else {
                                  // For mobile, use the Firebase Storage approach
                                  return FutureBuilder<Uint8List?>(
                                    future: _getImageDataGrid(url),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }

                                      if (snapshot.hasError || snapshot.data == null) {
                                        // If Firebase Storage fails, fall back to network image
                                        return Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            print('Image load error: $error');
                                            print('URL: $url');
                                            print('Stack trace: $stackTrace');
                                            return Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.broken_image,
                                                    size: 32,
                                                    color: Colors.grey.shade400,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Could not load',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade600,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  TextButton(
                                                    onPressed: () {
                                                      if (kIsWeb) {
                                                        html.window.open(url, '_blank');
                                                      }
                                                    },
                                                    child: const Text('Open', style: TextStyle(fontSize: 10)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      }

                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Image load error: $error');
                                          print('URL: $url');
                                          print('Stack trace: $stackTrace');
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  size: 32,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Could not load',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                TextButton(
                                                  onPressed: () {
                                                    if (kIsWeb) {
                                                      html.window.open(url, '_blank');
                                                    }
                                                  },
                                                  child: const Text('Open', style: TextStyle(fontSize: 10)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                }
                              },
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filled(
                                onPressed: _isUploading
                                    ? null
                                    : () => _deleteDocument(url),
                                icon: const Icon(Icons.delete, size: 16),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(24, 24),
                                ),
                                tooltip: 'Delete document',
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload another document to add more',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
            if (_uploadedUrls.isEmpty) ...[
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No support document attached',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upload progress
            if (_isUploading) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text(
                _uploadProgress < 0.5 ? 'Compressing image...' : 'Uploading...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],

            // Upload buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
                if (isMobile) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Images will be automatically compressed to save space',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Dialog for selecting support documents to print
class SupportDocumentSelectionDialog extends StatefulWidget {
  final List<String> documentUrls;
  final String transactionReceiptNo;
  final String description;
  final double amount;

  const SupportDocumentSelectionDialog({
    super.key,
    required this.documentUrls,
    required this.transactionReceiptNo,
    required this.description,
    required this.amount,
  });

  @override
  State<SupportDocumentSelectionDialog> createState() => _SupportDocumentSelectionDialogState();
}

class _SupportDocumentSelectionDialogState extends State<SupportDocumentSelectionDialog> {
  late Set<int> selectedIndices;
  bool isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Select all by default
    selectedIndices = Set.from(List.generate(widget.documentUrls.length, (i) => i));
  }

  Future<void> _getImageData(String originalUrl) async {
    final storageService = FirebaseStorageService();
    await storageService.downloadImageData(originalUrl);
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedIndices.length;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Documents to Print',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Voucher: ${widget.transactionReceiptNo}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: isPrinting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Up to 4 images will be printed per page to save paper',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

            // Selection controls
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$selectedCount of ${widget.documentUrls.length} selected',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: isPrinting ? null : () {
                          setState(() {
                            selectedIndices = Set.from(
                              List.generate(widget.documentUrls.length, (i) => i),
                            );
                          });
                        },
                        icon: const Icon(Icons.select_all, size: 16),
                        label: const Text('Select All'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: isPrinting ? null : () {
                          setState(() {
                            selectedIndices.clear();
                          });
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Document grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: widget.documentUrls.length,
                itemBuilder: (context, index) {
                  final isSelected = selectedIndices.contains(index);
                  return GestureDetector(
                    onTap: isPrinting ? null : () {
                      setState(() {
                        if (isSelected) {
                          selectedIndices.remove(index);
                        } else {
                          selectedIndices.add(index);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: kIsWeb
                                ? Image.network(
                                    widget.documentUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(Icons.image, color: Colors.grey.shade400),
                                      );
                                    },
                                  )
                                : FutureBuilder<Uint8List?>(
                                    future: FirebaseStorageService()
                                        .downloadImageData(widget.documentUrls[index]),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Image.memory(
                                          snapshot.data!,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: Icon(Icons.image, color: Colors.grey.shade400),
                                      );
                                    },
                                  ),
                          ),
                          // Selection overlay
                          if (isSelected)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.white, size: 24),
                                ),
                              ),
                            ),
                          // Document number
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedCount > 0
                        ? '${(selectedCount / 4).ceil()} page${(selectedCount / 4).ceil() > 1 ? "s" : ""} (${selectedCount > 4 ? "4 images/page" : "$selectedCount image${selectedCount > 1 ? "s" : ""}/page"})'
                        : 'No documents selected',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: isPrinting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: isPrinting || selectedCount == 0
                            ? null
                            : () async {
                                setState(() => isPrinting = true);

                                try {
                                  final selectedUrls = selectedIndices
                                      .map((i) => widget.documentUrls[i])
                                      .toList()
                                    ..sort((a, b) => selectedIndices.toList().indexOf(
                                          widget.documentUrls.indexOf(a),
                                        ).compareTo(
                                          selectedIndices.toList().indexOf(
                                            widget.documentUrls.indexOf(b),
                                          ),
                                        ));

                                  final voucherService = VoucherExportService();
                                  await voucherService.printMultipleSupportDocumentsGrid(
                                    selectedUrls,
                                    widget.transactionReceiptNo,
                                    widget.description,
                                    widget.amount,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Printing $selectedCount document${selectedCount > 1 ? "s" : ""} on ${(selectedCount / 4).ceil()} page${(selectedCount / 4).ceil() > 1 ? "s" : ""}...',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => isPrinting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error printing: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isPrinting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print),
                        label: Text(isPrinting ? 'Printing...' : 'Print Selected'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show multiple support documents in a gallery
class SupportDocumentGallery extends StatefulWidget {
  final List<String> documentUrls;
  final String transactionReceiptNo;
  final VoidCallback? onClose;

  const SupportDocumentGallery({
    super.key,
    required this.documentUrls,
    required this.transactionReceiptNo,
    this.onClose,
  });

  @override
  State<SupportDocumentGallery> createState() => _SupportDocumentGalleryState();
}

class _SupportDocumentGalleryState extends State<SupportDocumentGallery> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Method to download image data directly from Firebase Storage
  Future<Uint8List?> _getImageData(String originalUrl) async {
    try {
      print('Fetching support document: $originalUrl');

      // Use the Firebase Storage service to download image data directly
      final storageService = FirebaseStorageService();
      final result = await storageService.downloadImageData(originalUrl);

      if (result != null) {
        print('Successfully downloaded image data: ${result.length} bytes');
        return result;
      } else {
        print('Firebase Storage download returned null');
        return null;
      }
    } catch (e) {
      print('Error downloading image data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Support Documents',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Voucher: ${widget.transactionReceiptNo}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '${_currentPage + 1} / ${widget.documentUrls.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onClose ?? () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Image Gallery with PageView
            Flexible(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: widget.documentUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Builder(
                          builder: (context) {
                            // For web, try to use Image.network directly to avoid CORS issues
                            if (kIsWeb) {
                              return Image.network(
                                widget.documentUrls[index],
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  print('Image load error: $error');
                                  print('URL: ${widget.documentUrls[index]}');
                                  return Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Could not load image',
                                          style: TextStyle(color: Colors.grey.shade600),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            if (kIsWeb) {
                                              html.window.open(
                                                widget.documentUrls[index],
                                                '_blank',
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text('Open in New Tab'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            } else {
                              // For mobile, use the Firebase Storage approach
                              return FutureBuilder<Uint8List?>(
                                future: _getImageData(widget.documentUrls[index]),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  if (snapshot.hasError || snapshot.data == null) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 64,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Could not load image',
                                            style: TextStyle(color: Colors.grey.shade600),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.contain,
                                  );
                                },
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                  // Navigation arrows
                  if (widget.documentUrls.length > 1) ...[
                    // Left arrow
                    if (_currentPage > 0)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton.filled(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.chevron_left, size: 32),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    // Right arrow
                    if (_currentPage < widget.documentUrls.length - 1)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton.filled(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.chevron_right, size: 32),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            // Footer with thumbnail navigation and instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // Thumbnail navigation
                  if (widget.documentUrls.length > 1) ...[
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.documentUrls.length,
                        itemBuilder: (context, index) {
                          final isSelected = index == _currentPage;
                          return GestureDetector(
                            onTap: () {
                              _pageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: kIsWeb
                                    ? Image.network(
                                        widget.documentUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: Icon(
                                              Icons.image,
                                              color: Colors.grey.shade400,
                                            ),
                                          );
                                        },
                                      )
                                    : FutureBuilder<Uint8List?>(
                                        future: _getImageData(widget.documentUrls[index]),
                                        builder: (context, snapshot) {
                                          if (snapshot.hasData && snapshot.data != null) {
                                            return Image.memory(
                                              snapshot.data!,
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: Icon(
                                              Icons.image,
                                              color: Colors.grey.shade400,
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Pinch to zoom • Drag to pan • Swipe to navigate',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show support document preview
class SupportDocumentPreview extends StatefulWidget {
  final String documentUrl;
  final VoidCallback? onClose;

  const SupportDocumentPreview({
    super.key,
    required this.documentUrl,
    this.onClose,
  });

  @override
  State<SupportDocumentPreview> createState() => _SupportDocumentPreviewState();
}

class _SupportDocumentPreviewState extends State<SupportDocumentPreview> {
  Future<String> _getDownloadUrl(String originalUrl) async {
    try {
      // Extract the path from the original URL to get a fresh download URL
      // This helps when the original URL's token has expired
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments;

      // Find the storage path from the URL
      int storageIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i] == 'o') {
          // 'o' is for objects in Firebase Storage URLs
          storageIndex = i + 1;
          break;
        }
      }

      if (storageIndex != -1 && storageIndex < pathSegments.length) {
        final storagePath = pathSegments.sublist(storageIndex).join('/');
        // Decode URL-encoded characters
        final decodedPath = Uri.decodeComponent(storagePath);

        final ref = FirebaseStorage.instance.ref().child(decodedPath);
        final freshUrl = await ref.getDownloadURL();
        return freshUrl;
      }
    } catch (e) {
      print('Error getting fresh download URL: $e');
      print('Original URL: $originalUrl');
      // If we can't get a fresh URL, return the original one
    }
    return originalUrl;
  }

  // Method to download image data directly from Firebase Storage
  Future<Uint8List?> _getImageData(String originalUrl) async {
    try {
      print('Widget requesting image data for URL: $originalUrl');
      // Use the Firebase Storage service to download image data directly
      final storageService = FirebaseStorageService();
      final result = await storageService.downloadImageData(originalUrl);
      print(
        'Widget received result: ${result != null ? "Success (${result.length} bytes)" : "Null"}',
      );
      return result;
    } catch (e) {
      print('Error downloading image data: $e');
      return null;
    }
  }

  // Method to download image data directly from Firebase Storage
  Future<Uint8List?> _getImageDataPreview(String originalUrl) async {
    try {
      print('Fetching support document: $originalUrl');

      // Use the Firebase Storage service to download image data directly
      final storageService = FirebaseStorageService();
      final result = await storageService.downloadImageData(originalUrl);

      if (result != null) {
        print('Successfully downloaded image data: ${result.length} bytes');
        return result;
      } else {
        print('Firebase Storage download returned null');
        return null;
      }
    } catch (e) {
      print('Error downloading image data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Support Document',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: widget.onClose ?? () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Image
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Builder(
                  builder: (context) {
                    // For web, try to use Image.network directly to avoid CORS issues
                    if (kIsWeb) {
                      return Image.network(
                        widget.documentUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Preview image load error: $error');
                          print('Stack trace: $stackTrace');
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Could not load image',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'CORS may not be configured',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    if (kIsWeb) {
                                      html.window.open(
                                        widget.documentUrl,
                                        '_blank',
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Open in New Tab'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    } else {
                      // For mobile, use the Firebase Storage approach
                      return FutureBuilder<Uint8List?>(
                        future: _getImageDataPreview(widget.documentUrl),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError || snapshot.data == null) {
                            // If Firebase Storage fails, fall back to network image
                            return Image.network(
                              widget.documentUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                print('Preview image load error: $error');
                                print('Stack trace: $stackTrace');
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Could not load image',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'CORS may not be configured',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (kIsWeb) {
                                            html.window.open(
                                              widget.documentUrl,
                                              '_blank',
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.open_in_new),
                                        label: const Text('Open in New Tab'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }

                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              print('Preview image load error: $error');
                              print('Stack trace: $stackTrace');
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Could not load image',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'CORS may not be configured',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (kIsWeb) {
                                          html.window.open(
                                            widget.documentUrl,
                                            '_blank',
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.open_in_new),
                                      label: const Text('Open in New Tab'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ),
            // Footer with actions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Pinch to zoom • Drag to pan',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
