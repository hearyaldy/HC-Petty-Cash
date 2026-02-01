import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/salary_benefits.dart';
import '../services/staff_service.dart';

class SalaryBenefitsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'salary_benefits';

  // Create a new salary benefits record
  Future<String> createSalaryBenefits(SalaryBenefits salaryBenefits) async {
    print(
      'Debug: Creating salary benefits record for staffId: ${salaryBenefits.staffId}',
    ); // Debug message
    print(
      'Debug: Salary amount: ${salaryBenefits.baseSalary}',
    ); // Debug message

    try {
      final docRef = await _firestore
          .collection(collectionName)
          .add(salaryBenefits.toFirestore());

      print(
        'Debug: Salary benefits record created with ID: ${docRef.id}',
      ); // Debug message

      // Sync salary data to staff record so staff can see updated data
      final createdSalaryBenefits = salaryBenefits.copyWith(id: docRef.id);
      await _syncSalaryDataToStaff(createdSalaryBenefits);

      print('Debug: Staff record synced with salary data'); // Debug message
      return docRef.id;
    } catch (e) {
      print(
        'Debug: Error creating salary benefits record: $e',
      ); // Debug message
      throw Exception('Failed to create salary benefits record: $e');
    }
  }

  // Update existing salary benefits record
  Future<void> updateSalaryBenefits(SalaryBenefits salaryBenefits) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(salaryBenefits.id)
          .update(salaryBenefits.toFirestore());

      // Sync salary data to staff record so staff can see updated data
      await _syncSalaryDataToStaff(salaryBenefits);

      print(
        'Debug: Salary benefits updated and synced to staff record',
      ); // Debug message
    } catch (e) {
      throw Exception('Failed to update salary benefits record: $e');
    }
  }

  // Sync salary data to staff record
  Future<void> _syncSalaryDataToStaff(SalaryBenefits salaryBenefits) async {
    try {
      await _firestore
          .collection(StaffService.collectionName)
          .doc(salaryBenefits.staffId)
          .update({
            'monthlySalary': salaryBenefits.grossSalary,
            'allowances':
                (salaryBenefits.housingAllowance ?? 0) +
                (salaryBenefits.phoneAllowance ?? 0) +
                (salaryBenefits.continueEducationAllowance ?? 0) +
                (salaryBenefits.equipmentAllowance ?? 0),
            'tithePercentage': salaryBenefits.tithePercentage,
            'titheAmount': salaryBenefits.titheAmount,
            'socialSecurityAmount': salaryBenefits.socialSecurityAmount,
            'providentFundPercentage': salaryBenefits.providentFundPercentage,
            'providentFundAmount': salaryBenefits.providentFundAmount,
            'houseRentalPercentage': salaryBenefits.houseRentalPercentage,
            'houseRentalAmount': salaryBenefits.houseRentalAmount,
            'currentSalaryBenefitsId': salaryBenefits.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('Debug: Staff record synced with salary data'); // Debug message
    } catch (e) {
      print('Warning: Failed to sync salary data to staff record: $e');
    }
  }

  // Delete salary benefits record
  Future<void> deleteSalaryBenefits(String salaryBenefitsId) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(salaryBenefitsId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete salary benefits record: $e');
    }
  }

  // Get salary benefits by ID
  Future<SalaryBenefits?> getSalaryBenefitsById(String salaryBenefitsId) async {
    try {
      final doc = await _firestore
          .collection(collectionName)
          .doc(salaryBenefitsId)
          .get();
      if (doc.exists) {
        return SalaryBenefits.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get salary benefits record: $e');
    }
  }

  // Get all salary benefits for a specific staff member
  Stream<List<SalaryBenefits>> getSalaryBenefitsForStaff(String staffId) {
    return _firestore
        .collection(collectionName)
        .where('staffId', isEqualTo: staffId)
        .orderBy('effectiveDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryBenefits.fromFirestore(doc))
              .toList(),
        );
  }

  // Get current active salary benefits for a staff member (stream)
  Stream<SalaryBenefits?> getCurrentSalaryBenefitsForStaff(String staffId) {
    return _firestore
        .collection(collectionName)
        .where('staffId', isEqualTo: staffId)
        .where('isActive', isEqualTo: true)
        .orderBy('effectiveDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return SalaryBenefits.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  // Get latest salary benefits for a staff member (stream, regardless of active flag)
  Stream<SalaryBenefits?> getLatestSalaryBenefitsForStaff(String staffId) {
    return _firestore
        .collection(collectionName)
        .where('staffId', isEqualTo: staffId)
        .orderBy('effectiveDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            return SalaryBenefits.fromFirestore(snapshot.docs.first);
          }
          return null;
        });
  }

  // Prefer active record, but fall back to latest if the active query fails (e.g. missing index)
  Stream<SalaryBenefits?> getCurrentOrLatestSalaryBenefitsForStaff(String staffId) {
    final controller = StreamController<SalaryBenefits?>();
    StreamSubscription<SalaryBenefits?>? subscription;

    void listenToLatest() {
      subscription?.cancel();
      subscription = getLatestSalaryBenefitsForStaff(staffId).listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    }

    subscription = getCurrentSalaryBenefitsForStaff(staffId).listen(
      controller.add,
      onError: (error, stackTrace) {
        print(
          'Warning: Active salary benefits query failed, falling back to latest. Error: $error',
        );
        listenToLatest();
      },
      onDone: controller.close,
    );

    controller.onCancel = () => subscription?.cancel();
    return controller.stream;
  }

  // Get current active salary benefits for a staff member (one-time fetch)
  Future<SalaryBenefits?> getCurrentSalaryBenefitsOnce(String staffId) async {
    try {
      final snapshot = await _firestore
          .collection(collectionName)
          .where('staffId', isEqualTo: staffId)
          .where('isActive', isEqualTo: true)
          .orderBy('effectiveDate', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return SalaryBenefits.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get current salary benefits: $e');
    }
  }

  // Get all salary benefits records
  Stream<List<SalaryBenefits>> getAllSalaryBenefits() {
    return _firestore
        .collection(collectionName)
        .orderBy('effectiveDate', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryBenefits.fromFirestore(doc))
              .toList(),
        );
  }

  // Activate a salary benefits record (set others to inactive)
  Future<void> activateSalaryBenefits(String salaryBenefitsId) async {
    try {
      // Get the salary benefits record to determine staff ID
      final salaryBenefits = await getSalaryBenefitsById(salaryBenefitsId);
      if (salaryBenefits == null) {
        throw Exception('Salary benefits record not found');
      }

      // Deactivate all other salary benefits records for this staff member
      final batch = _firestore.batch();

      final allRecords = await _firestore
          .collection(collectionName)
          .where('staffId', isEqualTo: salaryBenefits.staffId)
          .get();

      for (final doc in allRecords.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Activate the selected record
      batch.update(
        _firestore.collection(collectionName).doc(salaryBenefitsId),
        {'isActive': true},
      );

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to activate salary benefits record: $e');
    }
  }

  // Update staff record to reference current salary benefits
  Future<void> _updateStaffCurrentSalaryBenefitsId(
    String staffId,
    String salaryBenefitsId,
  ) async {
    try {
      await _firestore
          .collection(StaffService.collectionName)
          .doc(staffId)
          .update({
            'currentSalaryBenefitsId': salaryBenefitsId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // This is not critical, so we'll just log the error
      print('Warning: Failed to update staff current salary benefits ID: $e');
    }
  }

  // Get salary history for a staff member (all records ordered by date)
  Stream<List<SalaryBenefits>> getSalaryHistoryForStaff(String staffId) {
    return _firestore
        .collection(collectionName)
        .where('staffId', isEqualTo: staffId)
        .orderBy('effectiveDate', descending: false) // Oldest first
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SalaryBenefits.fromFirestore(doc))
              .toList(),
        );
  }

  // Calculate total compensation for a staff member
  Future<double> getTotalCompensationForStaff(String staffId) async {
    try {
      final currentSalaryBenefits = await getCurrentSalaryBenefitsForStaff(
        staffId,
      ).first; // Get the first (and likely only) value from the stream

      if (currentSalaryBenefits != null) {
        return currentSalaryBenefits.grossSalary;
      }

      return 0.0;
    } catch (e) {
      print('Warning: Failed to calculate total compensation: $e');
      return 0.0;
    }
  }
}
