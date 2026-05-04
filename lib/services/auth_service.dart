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

  /// No on-device persistence: the session lives in memory for the life
  /// of the process. Call once at app start to flip the "initializing"
  /// flag to false.
  Future<void> init() async {
    _initializing = false;
    notifyListeners();
  }

  Future<UserModel> login(String email, String password) async {
    final res = await _api.post('/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    _api.setToken(res['token'] as String);
    final user =
        UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// Self-service intern registration. The backend creates a `pending`
  /// intern row and does NOT issue a session token — the intern has to
  /// wait for an admin approval before they can log in. The returned
  /// [InternRegistrationResult] carries the freshly created user plus
  /// the auto-generated student id (`STU-YYYY-NNN`) the server
  /// assigned, so the registration screen can show it to the user.
  Future<InternRegistrationResult> registerIntern({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String university,
    required String specialization,
    required String department,
    required bool acceptedLegal,
    String? profilePhotoUrl,
  }) async {
    final res = await _api.post('/auth/register', body: {
      'email': email.trim(),
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'university': university,
      'specialization': specialization,
      'department': department,
      'acceptedLegal': acceptedLegal,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
    });
    return InternRegistrationResult(
      user: UserModel.fromJson((res['user'] as Map).cast<String, dynamic>()),
      studentId: res['studentId'] as String?,
    );
  }

  /// Admin-only: provision a mentor or admin user. Does not sign the caller in
  /// as the new user.
  ///
  /// [specialization] is required when [role] is mentor (so the admin
  /// can later assign interns by matching specializations); ignored
  /// for admins.
  Future<UserModel> createMentorOrAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
    String specialization = '',
  }) async {
    final res = await _api.post('/users/', body: {
      'email': email.trim(),
      'password': password,
      'fullName': fullName,
      'phone': phone,
      'role': role.value,
      'specialization': specialization,
    });
    return UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
  }

  Future<void> logout() async {
    _api.setToken(null);
    _currentUser = null;
    notifyListeners();
  }

  /// Change the current user's password. Verifies [currentPassword],
  /// updates the hash on the server, rotates the session token (server
  /// returns a fresh one) and clears the must_change_password flag.
  Future<UserModel> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _api.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    _api.setToken(res['token'] as String);
    final user =
        UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    _currentUser = user;
    notifyListeners();
    return user;
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

/// Result of [AuthService.registerIntern].
class InternRegistrationResult {
  const InternRegistrationResult({required this.user, this.studentId});

  /// Freshly created (still-pending) user.
  final UserModel user;

  /// Server-assigned student id in `STU-YYYY-NNN` format. Null if the
  /// server is older than this client (no `studentId` field in the
  /// response).
  final String? studentId;
}
