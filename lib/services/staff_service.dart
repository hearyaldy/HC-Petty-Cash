import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/staff.dart';
import '../models/staff_document.dart';

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String collectionName = 'staff';
  static const String documentsCollectionName = 'staff_documents';

  // Create a new staff record
  Future<String> createStaff(Staff staff) async {
    try {
      // Generate employee ID if not provided
      String employeeId = staff.employeeId;
      if (employeeId.isEmpty || employeeId.startsWith('EMP')) {
        employeeId = _generateCustomEmployeeId(staff);
      }

      // Create a copy of the staff with the generated employee ID
      final staffWithId = staff.copyWith(employeeId: employeeId);

      final docRef = await _firestore
          .collection(collectionName)
          .add(staffWithId.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create staff record: $e');
    }
  }

  // Generate custom employee ID in format: HC-[year of joining]-[last 2 digits of birth year]
  String _generateCustomEmployeeId(Staff staff) {
    // Get full year of joining
    String yearOfJoining = staff.dateOfJoining.year.toString();
    debugPrint('Debug: Date of Joining: ${staff.dateOfJoining}');
    debugPrint('Debug: Year of Joining: $yearOfJoining');

    // Get last 2 digits of birth year if available
    String birthYearSuffix = '00'; // Default if no birth date
    if (staff.dateOfBirth != null) {
      String fullBirthYear = staff.dateOfBirth!.year.toString();
      debugPrint('Debug: Date of Birth: ${staff.dateOfBirth}');
      debugPrint('Debug: Full Birth Year: $fullBirthYear');
      if (fullBirthYear.length >= 2) {
        birthYearSuffix = fullBirthYear.substring(fullBirthYear.length - 2);
      }
    } else {
      debugPrint('Debug: Date of Birth is null, using default 00');
    }

    // Format: HC-[year of joining]-[last 2 digits of birth year]
    final employeeId = 'HC-$yearOfJoining-$birthYearSuffix';
    debugPrint('Debug: Generated Employee ID: $employeeId');
    return employeeId;
  }

  // Update existing staff record
  Future<void> updateStaff(Staff staff) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(staff.id)
          .update(staff.toFirestore());
    } catch (e) {
      throw Exception('Failed to update staff record: $e');
    }
  }

  // Update staff employee ID only
  Future<void> updateStaffEmployeeId(
    String staffId,
    String newEmployeeId,
  ) async {
    try {
      await _firestore.collection(collectionName).doc(staffId).update({
        'employeeId': newEmployeeId,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update staff employee ID: $e');
    }
  }

  // Delete staff record
  Future<void> deleteStaff(String staffId) async {
    try {
      // Get staff to delete photo if exists
      final staff = await getStaffById(staffId);
      if (staff?.photoUrl != null) {
        await deleteStaffPhoto(staffId);
      }

      // Delete all documents
      await deleteAllStaffDocuments(staffId);

      await _firestore.collection(collectionName).doc(staffId).delete();
    } catch (e) {
      throw Exception('Failed to delete staff record: $e');
    }
  }

  // Get staff by ID
  Future<Staff?> getStaffById(String staffId) async {
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(staffId)
          .get();
      if (doc.exists) {
        return Staff.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get staff record: $e');
    }
  }

  // Get staff by employee ID
  Future<Staff?> getStaffByEmployeeId(String employeeId) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Staff.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get staff by employee ID: $e');
    }
  }

  // Get staff by user ID (Firebase Auth UID)
  Future<Staff?> getStaffByUserId(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Staff.fromFirestore(
          querySnapshot.docs.first as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get staff by user ID: $e');
    }
  }

  // Get all staff
  Stream<List<Staff>> getAllStaff() {
    debugPrint('Debug: StaffService.getAllStaff() called');
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((snapshot) {
          debugPrint(
            'Debug: Got ${snapshot.docs.length} staff documents from Firestore',
          );
          final List<Staff> staffList = [];
          for (final doc in snapshot.docs) {
            try {
              final staff = Staff.fromFirestore(doc);
              staffList.add(staff);
            } catch (e) {
              debugPrint('Debug: Error parsing staff document ${doc.id}: $e');
              debugPrint('Debug: Document data: ${doc.data()}');
              // Continue processing other documents instead of failing
            }
          }
          debugPrint('Debug: Successfully parsed ${staffList.length} staff records');
          // Sort locally instead of using Firestore orderBy
          staffList.sort(
            (a, b) =>
                a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
          );
          return staffList;
        })
        .handleError((error) {
          debugPrint('Debug: Error in getAllStaff stream: $error');
          throw error;
        });
  }

  // Get active staff only
  Stream<List<Staff>> getActiveStaff() {
    return _firestore
        .collection(collectionName)
        .where('employmentStatus', isEqualTo: 'active')
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Staff.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Get staff by department
  Stream<List<Staff>> getStaffByDepartment(String department) {
    return _firestore
        .collection(collectionName)
        .where('department', isEqualTo: department)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Staff.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Get staff by role
  Stream<List<Staff>> getStaffByRole(String role) {
    return _firestore
        .collection(collectionName)
        .where('role', isEqualTo: role)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Staff.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Upload staff photo
  Future<String> uploadStaffPhoto(
    String staffId, {
    File? imageFile,
    Uint8List? bytes,
  }) async {
    try {
      if (imageFile == null && bytes == null) {
        throw Exception('No image provided for upload.');
      }

      final fileName = 'staff_$staffId.jpg';
      final storagePath = 'staff_photos/$fileName';
      final ref = _storage.ref().child(storagePath);

      final UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = ref.putData(bytes ?? await imageFile!.readAsBytes());
      } else {
        uploadTask = ref.putFile(imageFile!);
      }
      final snapshot = await uploadTask.whenComplete(() {});
      final photoUrl = await snapshot.ref.getDownloadURL();

      // Update staff record with photo URL
      await _firestore.collection(collectionName).doc(staffId).update({
        'photoUrl': photoUrl,
        'updatedAt': Timestamp.now(),
      });

      return photoUrl;
    } catch (e) {
      throw Exception('Failed to upload staff photo: $e');
    }
  }

  // Delete staff photo
  Future<void> deleteStaffPhoto(String staffId) async {
    try {
      final staff = await getStaffById(staffId);
      if (staff?.photoUrl != null) {
        // Extract path from URL and delete
        final ref = _storage.refFromURL(staff!.photoUrl!);
        await ref.delete();
      }

      // Update staff record to remove photo URL
      await _firestore.collection(collectionName).doc(staffId).update({
        'photoUrl': null,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to delete staff photo: $e');
    }
  }

  // Search staff by name or employee ID
  Future<List<Staff>> searchStaff(String searchTerm) async {
    try {
      final searchLower = searchTerm.toLowerCase();

      // Get all staff and filter locally (Firestore doesn't support case-insensitive search well)
      final querySnapshot = await _firestore.collection(collectionName).get();

      final results = querySnapshot.docs
          .map(
            (doc) => Staff.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>,
            ),
          )
          .where(
            (staff) =>
                staff.fullName.toLowerCase().contains(searchLower) ||
                staff.employeeId.toLowerCase().contains(searchLower) ||
                staff.email.toLowerCase().contains(searchLower),
          )
          .toList();

      return results;
    } catch (e) {
      throw Exception('Failed to search staff: $e');
    }
  }

  // Get reporting staff (subordinates)
  Stream<List<Staff>> getReportingStaff(String managerId) {
    return _firestore
        .collection(collectionName)
        .where('reportingManagerId', isEqualTo: managerId)
        .orderBy('fullName')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Staff.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Get staff count by status
  Future<Map<String, int>> getStaffCountByStatus() async {
    try {
      final querySnapshot = await _firestore.collection(collectionName).get();

      final Map<String, int> counts = {};
      for (final doc in querySnapshot.docs) {
        final staff = Staff.fromFirestore(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
        final status = staff.employmentStatus.name;
        counts[status] = (counts[status] ?? 0) + 1;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to get staff count by status: $e');
    }
  }

  // Generate next employee ID (simple auto-increment)
  Future<String> generateNextEmployeeId() async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .orderBy('employeeId', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return 'EMP001';
      }

      final lastId = querySnapshot.docs.first.data()['employeeId'] as String;
      final numericPart =
          int.tryParse(lastId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final nextNumber = numericPart + 1;

      return 'EMP${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      // If there's an error or no existing IDs, start from 001
      return 'EMP001';
    }
  }

  // ========== DOCUMENT MANAGEMENT ==========

  // Upload staff document
  Future<String> uploadStaffDocument({
    required String staffId,
    required File file,
    required DocumentType documentType,
    String? description,
    String? uploadedBy,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'staff_documents/$staffId/${timestamp}_$fileName';

      // Upload file to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask.whenComplete(() {});
      final fileUrl = await snapshot.ref.getDownloadURL();

      // Get file size and mime type
      final fileSizeBytes = await file.length();
      final mimeType = _getMimeType(fileName);

      // Create document record
      final document = StaffDocument(
        id: '', // Will be set by Firestore
        staffId: staffId,
        type: documentType,
        fileName: fileName,
        fileUrl: fileUrl,
        description: description,
        fileSizeBytes: fileSizeBytes,
        mimeType: mimeType,
        uploadedAt: DateTime.now(),
        uploadedBy: uploadedBy,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(documentsCollectionName)
          .add(document.toFirestore());

      // Update staff documents count
      await _updateStaffDocumentsCount(staffId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  // Upload staff document from bytes (web-compatible)
  Future<String> uploadStaffDocumentBytes({
    required String staffId,
    required Uint8List bytes,
    required String fileName,
    required DocumentType documentType,
    String? description,
    String? uploadedBy,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'staff_documents/$staffId/${timestamp}_$fileName';

      // Upload bytes to Firebase Storage
      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _getMimeType(fileName)),
      );
      final snapshot = await uploadTask.whenComplete(() {});
      final fileUrl = await snapshot.ref.getDownloadURL();

      // Get file size and mime type
      final fileSizeBytes = bytes.length;
      final mimeType = _getMimeType(fileName);

      // Create document record
      final document = StaffDocument(
        id: '', // Will be set by Firestore
        staffId: staffId,
        type: documentType,
        fileName: fileName,
        fileUrl: fileUrl,
        description: description,
        fileSizeBytes: fileSizeBytes,
        mimeType: mimeType,
        uploadedAt: DateTime.now(),
        uploadedBy: uploadedBy,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(documentsCollectionName)
          .add(document.toFirestore());

      // Update staff documents count
      await _updateStaffDocumentsCount(staffId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  // Get all documents for a staff member
  Stream<List<StaffDocument>> getStaffDocuments(String staffId) {
    return _firestore
        .collection(documentsCollectionName)
        .where('staffId', isEqualTo: staffId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => StaffDocument.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Get documents by type
  Stream<List<StaffDocument>> getStaffDocumentsByType(
    String staffId,
    DocumentType type,
  ) {
    return _firestore
        .collection(documentsCollectionName)
        .where('staffId', isEqualTo: staffId)
        .where('type', isEqualTo: type.name)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => StaffDocument.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ),
              )
              .toList(),
        );
  }

  // Delete a document
  Future<void> deleteStaffDocument(String documentId, String staffId) async {
    try {
      // Get document details first
      final docSnapshot = await _firestore
          .collection(documentsCollectionName)
          .doc(documentId)
          .get();

      if (docSnapshot.exists) {
        final document = StaffDocument.fromFirestore(docSnapshot);

        // Delete from storage
        try {
          final ref = _storage.refFromURL(document.fileUrl);
          await ref.delete();
        } catch (e) {
          // Continue even if storage deletion fails
          debugPrint('Warning: Failed to delete file from storage: $e');
        }

        // Delete from Firestore
        await _firestore
            .collection(documentsCollectionName)
            .doc(documentId)
            .delete();

        // Update staff documents count
        await _updateStaffDocumentsCount(staffId);
      }
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Update document description
  Future<void> updateDocumentDescription(
    String documentId,
    String description,
  ) async {
    try {
      await _firestore
          .collection(documentsCollectionName)
          .doc(documentId)
          .update({'description': description});
    } catch (e) {
      throw Exception('Failed to update document description: $e');
    }
  }

  // Get document count for a staff member
  Future<int> getStaffDocumentCount(String staffId) async {
    try {
      final querySnapshot = await _firestore
          .collection(documentsCollectionName)
          .where('staffId', isEqualTo: staffId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Update staff documents count
  Future<void> _updateStaffDocumentsCount(String staffId) async {
    try {
      final count = await getStaffDocumentCount(staffId);
      await _firestore.collection(collectionName).doc(staffId).update({
        'documentsCount': count,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Warning: Failed to update documents count: $e');
    }
  }

  // Get MIME type from file extension
  String _getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }

  // Delete all documents for a staff member (used when deleting staff)
  Future<void> deleteAllStaffDocuments(String staffId) async {
    try {
      final querySnapshot = await _firestore
          .collection(documentsCollectionName)
          .where('staffId', isEqualTo: staffId)
          .get();

      for (final doc in querySnapshot.docs) {
        await deleteStaffDocument(doc.id, staffId);
      }
    } catch (e) {
      throw Exception('Failed to delete all staff documents: $e');
    }
  }
}
