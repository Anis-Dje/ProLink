import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/intern_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel?> login(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user == null) return null;
    final userModel = await getUserById(credential.user!.uid);
    if (userModel != null) {
      await _saveUserPrefs(userModel);
    }
    return userModel;
  }

  Future<UserModel?> registerIntern({
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
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user == null) return null;

    final uid = credential.user!.uid;
    final now = DateTime.now();

    final userModel = UserModel(
      id: uid,
      email: email.trim(),
      fullName: fullName,
      phone: phone,
      role: UserRole.intern,
      profilePhotoUrl: profilePhotoUrl,
      createdAt: now,
      isActive: true,
    );

    final internModel = InternModel(
      id: uid,
      userId: uid,
      fullName: fullName,
      email: email.trim(),
      phone: phone,
      studentId: studentId,
      department: department,
      profilePhotoUrl: profilePhotoUrl,
      status: AppConstants.statusPending,
      registrationDate: now,
      university: university,
      specialization: specialization,
    );

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection(AppConstants.usersCollection).doc(uid),
      userModel.toFirestore(),
    );
    batch.set(
      _firestore.collection(AppConstants.internsCollection).doc(uid),
      internModel.toFirestore(),
    );
    await batch.commit();

    await _saveUserPrefs(userModel);
    return userModel;
  }

  Future<UserModel?> createMentorOrAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user == null) return null;

    final uid = credential.user!.uid;
    final userModel = UserModel(
      id: uid,
      email: email.trim(),
      fullName: fullName,
      phone: phone,
      role: role,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(userModel.toFirestore());

    return userModel;
  }

  Future<void> logout() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserModel?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return getUserById(firebaseUser.uid);
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['fullName'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (profilePhotoUrl != null) updates['profilePhotoUrl'] = profilePhotoUrl;
    if (updates.isEmpty) return;
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update(updates);
  }

  Future<void> updateEmail(String newEmail, String password) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  Future<void> updatePassword(String oldPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: oldPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> _saveUserPrefs(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefUserRole, user.role.value);
    await prefs.setString(AppConstants.prefUserId, user.id);
    await prefs.setString(AppConstants.prefUserEmail, user.email);
  }

  Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.prefUserRole);
  }
}
