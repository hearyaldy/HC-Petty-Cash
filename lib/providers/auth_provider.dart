import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../models/enums.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;

  Future<bool> login(String email, String password) async {
    final result = await _authService.login(email, password);
    notifyListeners();
    return result;
  }

  Future<bool> restoreSession() async {
    final result = await _authService.restoreSession();
    notifyListeners();
    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }

  Future<bool> register(User user) async {
    return await _authService.register(user);
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
    return currentUser?.role == UserRole.admin ||
        currentUser?.role == UserRole.manager ||
        currentUser?.role == UserRole.finance;
  }
}
