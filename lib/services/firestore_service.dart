import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';
import '../models/intern_model.dart';
import '../models/department_model.dart';
import '../models/evaluation_model.dart';
import '../models/attendance_model.dart';
import '../models/schedule_model.dart';
import '../models/training_file_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Users ────────────────────────────────────────────────────

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _db.collection(AppConstants.usersCollection).get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    final snap = await _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: role)
        .get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _db.collection(AppConstants.usersCollection).doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.usersCollection).doc(userId).update(data);
  }

  Future<void> setUserActiveStatus(String userId, bool isActive) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'isActive': isActive});
  }

  // ─── Interns ──────────────────────────────────────────────────

  Future<List<InternModel>> getAllInterns() async {
    final snap = await _db.collection(AppConstants.internsCollection).get();
    return snap.docs.map(InternModel.fromFirestore).toList();
  }

  Future<List<InternModel>> getPendingInterns() async {
    final snap = await _db
        .collection(AppConstants.internsCollection)
        .where('status', isEqualTo: AppConstants.statusPending)
        .orderBy('registrationDate', descending: true)
        .get();
    return snap.docs.map(InternModel.fromFirestore).toList();
  }

  Future<List<InternModel>> getInternsByStatus(String status) async {
    final snap = await _db
        .collection(AppConstants.internsCollection)
        .where('status', isEqualTo: status)
        .get();
    return snap.docs.map(InternModel.fromFirestore).toList();
  }

  Future<List<InternModel>> getInternsByMentor(String mentorId) async {
    final snap = await _db
        .collection(AppConstants.internsCollection)
        .where('mentorId', isEqualTo: mentorId)
        .get();
    return snap.docs.map(InternModel.fromFirestore).toList();
  }

  Future<List<InternModel>> getInternsByDepartment(String department) async {
    final snap = await _db
        .collection(AppConstants.internsCollection)
        .where('department', isEqualTo: department)
        .get();
    return snap.docs.map(InternModel.fromFirestore).toList();
  }

  Future<InternModel?> getInternById(String id) async {
    final doc = await _db.collection(AppConstants.internsCollection).doc(id).get();
    if (!doc.exists) return null;
    return InternModel.fromFirestore(doc);
  }

  Future<InternModel?> getInternByUserId(String userId) async {
    final snap = await _db
        .collection(AppConstants.internsCollection)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return InternModel.fromFirestore(snap.docs.first);
  }

  Future<void> approveIntern(String internId, {DateTime? startDate, DateTime? endDate}) async {
    final updates = <String, dynamic>{
      'status': AppConstants.statusActive,
    };
    if (startDate != null) updates['startDate'] = Timestamp.fromDate(startDate);
    if (endDate != null) updates['endDate'] = Timestamp.fromDate(endDate);
    await _db.collection(AppConstants.internsCollection).doc(internId).update(updates);
  }

  Future<void> rejectIntern(String internId, {String? reason}) async {
    await _db.collection(AppConstants.internsCollection).doc(internId).update({
      'status': AppConstants.statusRejected,
      if (reason != null) 'rejectionReason': reason,
    });
  }

  Future<void> updateInternStatus(String internId, String status) async {
    await _db.collection(AppConstants.internsCollection).doc(internId).update({
      'status': status,
    });
  }

  Future<void> assignInternToMentor(
    String internId,
    String mentorId,
    String department,
  ) async {
    await _db.collection(AppConstants.internsCollection).doc(internId).update({
      'mentorId': mentorId,
      'department': department,
    });
  }

  Future<List<InternModel>> searchInterns(String query) async {
    final all = await getAllInterns();
    final q = query.toLowerCase();
    return all.where((i) {
      return i.fullName.toLowerCase().contains(q) ||
          i.studentId.toLowerCase().contains(q) ||
          i.email.toLowerCase().contains(q) ||
          i.department.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> updateIntern(String internId, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.internsCollection).doc(internId).update(data);
  }

  // ─── Departments ──────────────────────────────────────────────

  Future<List<DepartmentModel>> getAllDepartments() async {
    final snap = await _db.collection(AppConstants.departmentsCollection).get();
    return snap.docs.map(DepartmentModel.fromFirestore).toList();
  }

  Future<DepartmentModel?> getDepartmentById(String id) async {
    final doc = await _db.collection(AppConstants.departmentsCollection).doc(id).get();
    if (!doc.exists) return null;
    return DepartmentModel.fromFirestore(doc);
  }

  Future<String> createDepartment(DepartmentModel dept) async {
    final ref = await _db
        .collection(AppConstants.departmentsCollection)
        .add(dept.toFirestore());
    return ref.id;
  }

  Future<void> updateDepartment(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.departmentsCollection).doc(id).update(data);
  }

  // ─── Evaluations ──────────────────────────────────────────────

  Future<List<EvaluationModel>> getEvaluationsByIntern(String internId) async {
    final snap = await _db
        .collection(AppConstants.evaluationsCollection)
        .where('internId', isEqualTo: internId)
        .orderBy('evaluationDate', descending: true)
        .get();
    return snap.docs.map(EvaluationModel.fromFirestore).toList();
  }

  Future<List<EvaluationModel>> getEvaluationsByMentor(String mentorId) async {
    final snap = await _db
        .collection(AppConstants.evaluationsCollection)
        .where('mentorId', isEqualTo: mentorId)
        .orderBy('evaluationDate', descending: true)
        .get();
    return snap.docs.map(EvaluationModel.fromFirestore).toList();
  }

  Future<String> createEvaluation(EvaluationModel evaluation) async {
    final ref = await _db
        .collection(AppConstants.evaluationsCollection)
        .add(evaluation.toFirestore());
    return ref.id;
  }

  Future<void> updateEvaluation(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.evaluationsCollection).doc(id).update(data);
  }

  // ─── Attendance ───────────────────────────────────────────────

  Future<List<AttendanceModel>> getAttendanceByIntern(String internId) async {
    final snap = await _db
        .collection(AppConstants.attendanceCollection)
        .where('internId', isEqualTo: internId)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map(AttendanceModel.fromFirestore).toList();
  }

  Future<List<AttendanceModel>> getAttendanceByMentorAndWeek(
    String mentorId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final snap = await _db
        .collection(AppConstants.attendanceCollection)
        .where('mentorId', isEqualTo: mentorId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(weekEnd))
        .get();
    return snap.docs.map(AttendanceModel.fromFirestore).toList();
  }

  Future<void> saveAttendanceBatch(List<AttendanceModel> records) async {
    final batch = _db.batch();
    for (final record in records) {
      final ref = _db.collection(AppConstants.attendanceCollection).doc(record.id);
      batch.set(ref, record.toFirestore(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<String> createAttendance(AttendanceModel attendance) async {
    final ref = await _db
        .collection(AppConstants.attendanceCollection)
        .add(attendance.toFirestore());
    return ref.id;
  }

  Future<void> updateAttendance(String id, Map<String, dynamic> data) async {
    await _db.collection(AppConstants.attendanceCollection).doc(id).update(data);
  }

  // ─── Schedules ────────────────────────────────────────────────

  Future<List<ScheduleModel>> getSchedules({String? departmentId}) async {
    Query query = _db
        .collection(AppConstants.schedulesCollection)
        .orderBy('uploadDate', descending: true);
    if (departmentId != null) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    final snap = await query.get();
    return snap.docs.map((d) => ScheduleModel.fromFirestore(d as DocumentSnapshot)).toList();
  }

  Future<String> createSchedule(ScheduleModel schedule) async {
    final ref = await _db
        .collection(AppConstants.schedulesCollection)
        .add(schedule.toFirestore());
    return ref.id;
  }

  Future<void> deleteSchedule(String id) async {
    await _db.collection(AppConstants.schedulesCollection).doc(id).delete();
  }

  // ─── Training Files ───────────────────────────────────────────

  Future<List<TrainingFileModel>> getTrainingFiles({String? departmentId}) async {
    Query query = _db
        .collection(AppConstants.trainingFilesCollection)
        .orderBy('uploadDate', descending: true);
    if (departmentId != null) {
      query = query.where('departmentId', isEqualTo: departmentId);
    }
    final snap = await query.get();
    return snap.docs.map((d) => TrainingFileModel.fromFirestore(d as DocumentSnapshot)).toList();
  }

  Future<String> createTrainingFile(TrainingFileModel file) async {
    final ref = await _db
        .collection(AppConstants.trainingFilesCollection)
        .add(file.toFirestore());
    return ref.id;
  }

  Future<void> deleteTrainingFile(String id) async {
    await _db.collection(AppConstants.trainingFilesCollection).doc(id).delete();
  }

  Future<List<TrainingFileModel>> searchTrainingFiles(String query) async {
    final all = await getTrainingFiles();
    final q = query.toLowerCase();
    return all.where((f) {
      return f.title.toLowerCase().contains(q) ||
          f.description.toLowerCase().contains(q) ||
          f.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}
