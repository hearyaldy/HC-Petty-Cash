import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/project_report.dart';
import '../models/user.dart';
import '../utils/logger.dart';

class ProjectReportProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<ProjectReport> _projectReports = [];
  ProjectReport? _selectedProjectReport;
  bool _isLoading = false;
  String? _errorMessage;

  List<ProjectReport> get projectReports => _projectReports;
  ProjectReport? get selectedProjectReport => _selectedProjectReport;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadProjectReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _projectReports = await _firestoreService.getAllProjectReports();
    } catch (e) {
      AppLogger.severe('Error loading project reports: $e');
      _projectReports = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ProjectReport> createProjectReport({
    required String projectName,
    required double budgetAmount,
    required DateTime startDate,
    required DateTime endDate,
    required User custodian,
    String? description,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final projectReport = await _firestoreService.createProjectReport(
        projectName: projectName,
        budgetAmount: budgetAmount,
        startDate: startDate,
        endDate: endDate,
        custodian: custodian,
        description: description,
      );

      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
      return projectReport;
    } catch (e) {
      _errorMessage = 'Failed to create project report: ${e.toString()}';
      AppLogger.severe('Error creating project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProjectReport(ProjectReport projectReport) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.updateProjectReport(projectReport);
      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to update project report: ${e.toString()}';
      AppLogger.severe('Error updating project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProjectReport(String projectReportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deleteProjectReport(projectReportId);
      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to delete project report: ${e.toString()}';
      AppLogger.severe('Error deleting project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void selectProjectReport(ProjectReport? projectReport) {
    _selectedProjectReport = projectReport;
    notifyListeners();
  }

  Future<void> submitProjectReport(String projectReportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _firestoreService.getProjectReport(projectReportId);
      if (report != null) {
        final updated = report.copyWith(
          status: 'submitted',
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateProjectReport(updated);
      }
      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to submit project report: ${e.toString()}';
      AppLogger.severe('Error submitting project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> approveProjectReport(String projectReportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _firestoreService.getProjectReport(projectReportId);
      if (report != null) {
        final updated = report.copyWith(
          status: 'approved',
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateProjectReport(updated);
      }
      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to approve project report: ${e.toString()}';
      AppLogger.severe('Error approving project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> closeProjectReport(String projectReportId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _firestoreService.getProjectReport(projectReportId);
      if (report != null) {
        final updated = report.copyWith(
          status: 'closed',
          updatedAt: DateTime.now(),
        );
        await _firestoreService.updateProjectReport(updated);
      }
      await loadProjectReports();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to close project report: ${e.toString()}';
      AppLogger.severe('Error closing project report: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
