import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';
import '../models/user.dart';
import '../models/enums.dart';
import '../utils/logger.dart';
import '../utils/validation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  String? _errorMessage;

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;
  String? get errorMessage => _errorMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Initialize and listen to auth state changes
  Future<void> initialize() async {
    await _authService.initialize();

    // Listen to auth state changes
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        await _authService.initialize();
      }
      notifyListeners();
    });

    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      // Sanitize inputs
      final sanitizedEmail = ValidationUtils.sanitizeString(email);
      final sanitizedPassword = ValidationUtils.sanitizeString(password);

      final result = await _authService.login(sanitizedEmail, sanitizedPassword);
      _errorMessage = null;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      AppLogger.severe('Login error in provider: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Restore session is now handled by initialize()
  Future<bool> restoreSession() async {
    await initialize();
    return isAuthenticated;
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }

  // Register user with Firebase Auth
  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    required String department,
  }) async {
    try {
      // Sanitize inputs
      final sanitizedEmail = ValidationUtils.sanitizeString(email);
      final sanitizedPassword = ValidationUtils.sanitizeString(password);
      final sanitizedName = ValidationUtils.sanitizeString(name);
      final sanitizedDepartment = ValidationUtils.sanitizeString(department);

      return await _authService.registerUser(
        email: sanitizedEmail,
        password: sanitizedPassword,
        name: sanitizedName,
        role: role,
        department: sanitizedDepartment,
      );
    } catch (e) {
      AppLogger.severe('Registration error in provider: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  bool hasRole(UserRole role) {
    return _authService.hasRole(role);
  }

  bool canApprove() {
    return _authService.canApprove();
  }

  bool canManageUsers() {
    return _authService.canManageUsers();
  }

  bool canCreateReports() {
    return _authService.canCreateReports();
  }

  bool canViewAllReports() {
    return currentUser?.roleEnum == UserRole.admin ||
        currentUser?.roleEnum == UserRole.manager ||
        currentUser?.roleEnum == UserRole.finance;
  }
}
