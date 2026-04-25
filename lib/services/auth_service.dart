import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'api_client.dart';

/// Authentication state holder + REST client. Acts as a [ChangeNotifier] so
/// the router can listen for sign-in / sign-out transitions.
class AuthService extends ChangeNotifier {
  AuthService(this._api);
  final ApiClient _api;

  UserModel? _currentUser;
  bool _initializing = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get initializing => _initializing;

  /// Loads the persisted JWT and resolves the current user from `/auth/me`.
  /// Call once at app start.
  Future<void> init() async {
    await _api.init();
    if (_api.isAuthenticated) {
      try {
        final res = await _api.get('/auth/me');
        _currentUser = UserModel.fromJson(
            (res['user'] as Map).cast<String, dynamic>());
      } catch (_) {
        // Token invalid/expired -> wipe.
        await _api.setToken(null);
        _currentUser = null;
      }
    }
    _initializing = false;
    notifyListeners();
  }

  Future<UserModel> login(String email, String password) async {
    final res = await _api.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    await _api.setToken(res['token'] as String);
    final user =
        UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<UserModel> registerIntern({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String studentId,
    required String university,
    required String specialization,
    required String department,
    String? profilePhotoUrl,
  }) async {
    final res = await _api.post('/auth/register', body: {
      'email': email.trim(),
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'studentId': studentId,
      'university': university,
      'specialization': specialization,
      'department': department,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    });
    await _api.setToken(res['token'] as String);
    final user =
        UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Admin-only: provision a mentor or admin user. Does not sign the caller in
  /// as the new user.
  Future<UserModel> createMentorOrAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    final res = await _api.post('/users/', body: {
      'email': email.trim(),
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'role': role.value,
    });
    return UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    await _api.setToken(null);
    _currentUser = null;
    notifyListeners();
  }

  /// Compatibility shim for the legacy Firestore-era code: returns the
  /// in-memory current user without hitting the network.
  Future<UserModel?> getCurrentUser() async => _currentUser;

  Future<UserModel?> refreshCurrentUser() async {
    if (!_api.isAuthenticated) return null;
    final res = await _api.get('/auth/me');
    final user =
        UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    _currentUser = user;
    notifyListeners();
    return user;
  }

  Future<UserModel?> getUserById(String id) async {
    final res = await _api.get('/users/$id');
    return UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['fullName'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (profilePhotoUrl != null) body['profilePhotoUrl'] = profilePhotoUrl;
    if (body.isEmpty) return;
    await _api.patch('/users/$userId', body: body);
    if (_currentUser?.id == userId) {
      await refreshCurrentUser();
    }
  }

  /// The new backend doesn't yet ship password reset; surface a clear error
  /// so callers don't silently swallow the case.
  Future<void> resetPassword(String email) {
    throw UnimplementedError(
      'Password reset is not implemented on the new backend yet.',
    );
  }
}
