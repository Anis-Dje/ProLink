import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Authentication helpers (password hashing + JWT).
class AuthHelper {
  AuthHelper(this.jwtSecret);
  final String jwtSecret;

  String hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  bool verifyPassword(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (_) {
      return false;
    }
  }

  /// Issues a 7-day JWT with the user's id, email and role.
  String issueToken({
    required String userId,
    required String email,
    required String role,
  }) {
    final jwt = JWT({
      'sub': userId,
      'email': email,
      'role': role,
    });
    return jwt.sign(
      SecretKey(jwtSecret),
      expiresIn: const Duration(days: 7),
    );
  }

  /// Returns the decoded payload, or null if the token is invalid/expired.
  Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(jwtSecret));
      final payload = jwt.payload;
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
