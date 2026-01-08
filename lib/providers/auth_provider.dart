import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';
import '../models/user.dart';
import '../models/enums.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;

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
      final result = await _authService.login(email, password);
      notifyListeners();
      return result;
    } catch (e) {
      print('Login error in provider: $e');
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
      return await _authService.registerUser(
        email: email,
        password: password,
        name: name,
        role: role,
        department: department,
      );
    } catch (e) {
      print('Registration error in provider: $e');
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
