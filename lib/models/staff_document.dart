import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

enum DocumentType {
  idCard,
  passport,
  drivingLicense,
  certificate,
  contract,
  resume,
  other;

  String get displayName {
    switch (this) {
      case DocumentType.idCard:
        return 'ID Card';
      case DocumentType.passport:
        return 'Passport';
      case DocumentType.drivingLicense:
        return 'Driving License';
      case DocumentType.certificate:
        return 'Certificate';
      case DocumentType.contract:
        return 'Employment Contract';
      case DocumentType.resume:
        return 'Resume/CV';
      case DocumentType.other:
        return 'Other Document';
    }
  }

  String get icon {
    switch (this) {
      case DocumentType.idCard:
        return '🪪';
      case DocumentType.passport:
        return '📘';
      case DocumentType.drivingLicense:
        return '🚗';
      case DocumentType.certificate:
        return '📜';
      case DocumentType.contract:
        return '📄';
      case DocumentType.resume:
        return '📝';
      case DocumentType.other:
        return '📎';
    }
  }
}

class StaffDocument {
  final String id;
  final String staffId;
  final DocumentType type;
  final String fileName;
  final String fileUrl;
  final String? description;
  final int? fileSizeBytes;
  final String? mimeType;
  final DateTime uploadedAt;
  final String? uploadedBy; // User ID who uploaded the document

  StaffDocument({
    required this.id,
    required this.staffId,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    this.description,
    this.fileSizeBytes,
    this.mimeType,
    required this.uploadedAt,
    this.uploadedBy,
  });

  // Get file extension
  String get fileExtension {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  // Get formatted file size
  String get formattedFileSize {
    if (fileSizeBytes == null) return 'Unknown size';

    final kb = fileSizeBytes! / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  // Firestore serialization
  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'type': type.name,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'description': description,
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
      'uploadedAt': firestore.Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
    };
  }

  factory StaffDocument.fromFirestore(
    firestore.DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return StaffDocument(
      id: doc.id,
      staffId: data['staffId'] as String,
      type: DocumentType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => DocumentType.other,
      ),
      fileName: data['fileName'] as String,
      fileUrl: data['fileUrl'] as String,
      description: data['description'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int?,
      mimeType: data['mimeType'] as String?,
      uploadedAt: (data['uploadedAt'] as firestore.Timestamp).toDate(),
      uploadedBy: data['uploadedBy'] as String?,
    );
  }

  StaffDocument copyWith({
    String? staffId,
    DocumentType? type,
    String? fileName,
    String? fileUrl,
    String? description,
    int? fileSizeBytes,
    String? mimeType,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return StaffDocument(
      id: id,
      staffId: staffId ?? this.staffId,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      description: description ?? this.description,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      mimeType: mimeType ?? this.mimeType,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }
}
