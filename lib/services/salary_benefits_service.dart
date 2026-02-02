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
      // Get the staff record to find the userId for HR data sync
      final staffDoc = await _firestore
          .collection(StaffService.collectionName)
          .doc(salaryBenefits.staffId)
          .get();

      final staffData = staffDoc.data();
      final staffUserId = staffData?['userId'] as String?;
      final staffEmail = staffData?['email'] as String?;

      // Update the staff record
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

      // Also sync to HR data submissions if user has submitted HR data
      await _syncSalaryDataToHrSubmission(
        salaryBenefits,
        staffUserId,
        staffEmail,
      );
    } catch (e) {
      print('Warning: Failed to sync salary data to staff record: $e');
    }
  }

  // Sync salary data to HR data submissions
  Future<void> _syncSalaryDataToHrSubmission(
    SalaryBenefits salaryBenefits,
    String? staffUserId,
    String? staffEmail,
  ) async {
    try {
      if (staffUserId == null && staffEmail == null) {
        print('Debug: No userId or email found for HR submission sync');
        return;
      }

      // Find HR data submission by userId or email
      QuerySnapshot<Map<String, dynamic>>? hrSubmissionQuery;

      if (staffUserId != null) {
        hrSubmissionQuery = await _firestore
            .collection('hr_data_submissions')
            .where('submittedBy', isEqualTo: staffUserId)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();
      }

      // If not found by userId, try by email
      if ((hrSubmissionQuery == null || hrSubmissionQuery.docs.isEmpty) &&
          staffEmail != null) {
        hrSubmissionQuery = await _firestore
            .collection('hr_data_submissions')
            .where('email', isEqualTo: staffEmail)
            .orderBy('submittedAt', descending: true)
            .limit(1)
            .get();
      }

      if (hrSubmissionQuery != null && hrSubmissionQuery.docs.isNotEmpty) {
        final hrDoc = hrSubmissionQuery.docs.first;

        // Update the HR submission with salary data
        await _firestore
            .collection('hr_data_submissions')
            .doc(hrDoc.id)
            .update({
              // Salary Structure
              'baseSalary': salaryBenefits.baseSalary,
              'wageFactor': salaryBenefits.wageFactor,
              'salaryPercentage': salaryBenefits.salaryPercentage,
              'calculatedSalary': salaryBenefits.grossSalary,
              'netSalary': salaryBenefits.netSalary,
              'totalCompensation': salaryBenefits.totalCompensation,

              // Allowances
              'phoneAllowance': salaryBenefits.phoneAllowance ?? 0,
              'educationAllowance':
                  salaryBenefits.continueEducationAllowance ?? 0,
              'houseAllowance': salaryBenefits.housingAllowance ?? 0,
              'equipmentAllowance': salaryBenefits.equipmentAllowance ?? 0,
              'totalAllowances':
                  (salaryBenefits.phoneAllowance ?? 0) +
                  (salaryBenefits.housingAllowance ?? 0) +
                  (salaryBenefits.continueEducationAllowance ?? 0) +
                  (salaryBenefits.equipmentAllowance ?? 0),

              // Deductions
              'tithePercentage': salaryBenefits.tithePercentage ?? 0,
              'titheAmount': salaryBenefits.titheAmount,
              'providentFundPercentage':
                  salaryBenefits.providentFundPercentage ?? 0,
              'providentFundAmount': salaryBenefits.providentFundAmount,
              'socialSecurityAmount': salaryBenefits.socialSecurityAmount,
              'houseRentalPercentage':
                  salaryBenefits.houseRentalPercentage ?? 0,
              'houseRentalAmount': salaryBenefits.houseRentalAmount,

              // Health Benefits
              'outPatientPercentage':
                  salaryBenefits.outPatientPercentage ?? 75,
              'inPatientPercentage': salaryBenefits.inPatientPercentage ?? 90,
              'annualLeaveDays': salaryBenefits.annualLeaveDays ?? 10,

              // Metadata
              'salaryUpdatedAt': FieldValue.serverTimestamp(),
              'salaryUpdatedBy': 'admin_sync',
            });

        print(
          'Debug: HR submission synced with salary data for doc ${hrDoc.id}',
        );
      } else {
        print('Debug: No HR submission found to sync salary data');
      }
    } catch (e) {
      print('Warning: Failed to sync salary data to HR submission: $e');
    }
  }

  // Public method to manually sync salary data to HR submission for a staff member
  Future<bool> syncStaffDataToHrSubmission(String staffId) async {
    try {
      // Get the current salary benefits for this staff
      final salaryBenefits = await getCurrentSalaryBenefitsOnce(staffId);

      if (salaryBenefits == null) {
        print('Debug: No salary benefits found for staff $staffId');
        return false;
      }

      // Get staff record to find userId and email
      final staffDoc = await _firestore
          .collection(StaffService.collectionName)
          .doc(staffId)
          .get();

      if (!staffDoc.exists) {
        print('Debug: Staff record not found for $staffId');
        return false;
      }

      final staffData = staffDoc.data();
      String? staffUserId = staffData?['userId'] as String?;
      final staffEmail = staffData?['email'] as String?;

      // If userId is not set in staff record, try to find user by email
      if (staffUserId == null && staffEmail != null) {
        print(
          'Debug: Staff userId not set, looking up user by email: $staffEmail',
        );
        final userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: staffEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          staffUserId = userQuery.docs.first.id;
          print('Debug: Found user ID by email: $staffUserId');

          // Update staff record with the found userId
          await _firestore
              .collection(StaffService.collectionName)
              .doc(staffId)
              .update({'userId': staffUserId});
          print('Debug: Updated staff record with userId');
        }
      }

      // Sync salary data to HR submission
      await _syncSalaryDataToHrSubmission(
        salaryBenefits,
        staffUserId,
        staffEmail,
      );

      // Also update staff record
      await _syncSalaryDataToStaff(salaryBenefits);

      print('Debug: Successfully synced staff data for $staffId');
      return true;
    } catch (e) {
      print('Error syncing staff data to HR submission: $e');
      return false;
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
  Stream<SalaryBenefits?> getCurrentOrLatestSalaryBenefitsForStaff(
    String staffId,
  ) {
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
