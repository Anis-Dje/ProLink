import '../core/constants/app_constants.dart';
import '../models/attendance_model.dart';
import '../models/department_model.dart';
import '../models/evaluation_model.dart';
import '../models/intern_model.dart';
import '../models/notification_model.dart';
import '../models/schedule_model.dart';
import '../models/training_file_model.dart';
import '../models/user_model.dart';
import 'api_client.dart';

/// Wrapper around the Pro-Link PHP REST API. The class name is a legacy
/// leftover from an earlier Firestore-based prototype; today every method
/// hits a PHP endpoint that talks to Neon Postgres via PDO.
class FirestoreService {
  FirestoreService(this._api);
  final ApiClient _api;

  // ─── Users ────────────────────────────────────────────────────

  Future<List<UserModel>> getAllUsers() async {
    final res = await _api.get('/users/');
    return (res['users'] as List)
        .map((e) => UserModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<UserModel>> getUsersByRole(String role) async {
    final res = await _api.get('/users/', query: {'role': role});
    return (res['users'] as List)
        .map((e) => UserModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<UserModel?> getUserById(String id) async {
    try {
      final res = await _api.get('/users/$id');
      return UserModel.fromJson((res['user'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _api.patch('/users/$userId', body: data);
  }

  Future<void> setUserActiveStatus(String userId, bool isActive) async {
    await _api.post('/users/$userId/active', body: {'isActive': isActive});
  }

  // ─── Interns ──────────────────────────────────────────────────

  Future<List<InternModel>> getAllInterns() async {
    final res = await _api.get('/interns/');
    return _internsFrom(res);
  }

  Future<List<InternModel>> getPendingInterns() {
    return getInternsByStatus(AppConstants.statusPending);
  }

  Future<List<InternModel>> getInternsByStatus(String status) async {
    final res = await _api.get('/interns/', query: {'status': status});
    return _internsFrom(res);
  }

  Future<List<InternModel>> getInternsByMentor(String mentorId) async {
    final res = await _api.get('/interns/', query: {'mentorId': mentorId});
    return _internsFrom(res);
  }

  Future<List<InternModel>> getInternsByDepartment(String department) async {
    final all = await getAllInterns();
    return all.where((i) => i.department == department).toList();
  }

  Future<InternModel?> getInternById(String id) async {
    try {
      final res = await _api.get('/interns/$id');
      return InternModel.fromJson(
          (res['intern'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<InternModel?> getInternByUserId(String userId) async {
    try {
      final res = await _api.get('/interns/by-user/$userId');
      return InternModel.fromJson(
          (res['intern'] as Map).cast<String, dynamic>());
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> approveIntern(String internId,
      {DateTime? startDate, DateTime? endDate}) async {
    await _api.post('/interns/$internId/approve', body: {
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    });
  }

  Future<void> rejectIntern(String internId, {String? reason}) async {
    await _api.post('/interns/$internId/reject', body: {
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> updateInternStatus(String internId, String status) async {
    await _api.patch('/interns/$internId', body: {'status': status});
  }

  Future<void> assignInternToMentor(
    String internId,
    String mentorId,
    String department,
  ) async {
    await _api.post('/interns/$internId/assign', body: {
      'mentorId': mentorId,
      'department': department,
    });
  }

  Future<List<InternModel>> searchInterns(String query) async {
    final res = await _api.get('/interns/', query: {'q': query});
    return _internsFrom(res);
  }

  Future<void> updateIntern(String internId, Map<String, dynamic> data) async {
    await _api.patch('/interns/$internId', body: data);
  }

  // ─── Departments ──────────────────────────────────────────────

  Future<List<DepartmentModel>> getAllDepartments() async {
    final res = await _api.get('/departments/');
    return (res['departments'] as List)
        .map((e) =>
            DepartmentModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<DepartmentModel?> getDepartmentById(String id) async {
    final all = await getAllDepartments();
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String> createDepartment(DepartmentModel dept) async {
    final res = await _api.post('/departments/', body: {
      'name': dept.name,
      'description': dept.description,
    });
    return ((res['department'] as Map).cast<String, dynamic>())['id']
        as String;
  }

  /// Departments don't yet expose a PATCH endpoint; recreate is the only
  /// supported "update". Throw to make this obvious to callers.
  Future<void> updateDepartment(String id, Map<String, dynamic> data) {
    throw UnimplementedError(
      'PATCH /departments/<id> is not yet implemented on the backend.',
    );
  }

  // ─── Evaluations ──────────────────────────────────────────────

  Future<List<EvaluationModel>> getEvaluationsByIntern(String internId) async {
    final res =
        await _api.get('/evaluations/', query: {'internId': internId});
    return _evalsFrom(res);
  }

  Future<List<EvaluationModel>> getEvaluationsByMentor(String mentorId) async {
    final res =
        await _api.get('/evaluations/', query: {'mentorId': mentorId});
    return _evalsFrom(res);
  }

  Future<String> createEvaluation(EvaluationModel evaluation) async {
    final res = await _api.post('/evaluations/', body: {
      'internId': evaluation.internId,
      'title': evaluation.title,
      'description': evaluation.description,
      'criteria': evaluation.criteria,
      'overallScore': evaluation.overallScore,
      'comment': evaluation.comment,
    });
    return ((res['evaluation'] as Map).cast<String, dynamic>())['id']
        as String;
  }

  Future<void> updateEvaluation(String id, Map<String, dynamic> data) {
    throw UnimplementedError(
      'PATCH /evaluations/<id> is not yet implemented on the backend.',
    );
  }

  // ─── Attendance ───────────────────────────────────────────────

  Future<List<AttendanceModel>> getAttendanceByIntern(String internId) async {
    final res =
        await _api.get('/attendance/', query: {'internId': internId});
    return _attendanceFrom(res);
  }

  Future<List<AttendanceModel>> getAttendanceByMentorAndWeek(
    String mentorId,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final res = await _api.get('/attendance/', query: {
      'mentorId': mentorId,
      'from': _isoDate(weekStart),
      'to': _isoDate(weekEnd),
    });
    return _attendanceFrom(res);
  }

  Future<void> saveAttendanceBatch(List<AttendanceModel> records) async {
    // The REST API upserts one row at a time keyed by (intern_id, date).
    for (final r in records) {
      await _api.post('/attendance/', body: {
        'internId': r.internId,
        'date': _isoDate(r.date),
        'status': r.status,
        if (r.note != null) 'notes': r.note,
      });
    }
  }

  Future<String> createAttendance(AttendanceModel attendance) async {
    final res = await _api.post('/attendance/', body: {
      'internId': attendance.internId,
      'date': _isoDate(attendance.date),
      'status': attendance.status,
      if (attendance.note != null) 'notes': attendance.note,
    });
    return ((res['attendance'] as Map).cast<String, dynamic>())['id']
        as String;
  }

  Future<void> updateAttendance(String id, Map<String, dynamic> data) async {
    // Upsert by (internId, date) — caller must include those.
    await _api.post('/attendance/', body: data);
  }

  // ─── Schedules ────────────────────────────────────────────────

  Future<List<ScheduleModel>> getSchedules({String? departmentId}) async {
    final res = await _api.get('/schedules/');
    final all = (res['schedules'] as List)
        .map((e) =>
            ScheduleModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return departmentId == null
        ? all
        : all.where((s) => s.departmentId == departmentId).toList();
  }

  Future<String> createSchedule(ScheduleModel schedule) async {
    final res = await _api.post('/schedules/', body: {
      'title': schedule.title,
      'description': schedule.description,
      'fileUrl': schedule.fileUrl,
      'weekLabel': schedule.weekLabel,
      // The admin chooses the audience scope when uploading; the backend
      // uses these two fields to filter subsequent GET /schedules calls.
      'scopeType': schedule.scopeType.value,
      'scopeValue': schedule.scopeValue,
    });
    return ((res['schedule'] as Map).cast<String, dynamic>())['id']
        as String;
  }

  Future<void> deleteSchedule(String id) async {
    await _api.delete('/schedules/$id');
  }

  // ─── Training Files ───────────────────────────────────────────

  Future<List<TrainingFileModel>> getTrainingFiles({
    String? departmentId,
  }) async {
    final res = await _api.get('/training-files/');
    final all = (res['trainingFiles'] as List)
        .map((e) =>
            TrainingFileModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return departmentId == null
        ? all
        : all.where((f) => f.departmentId == departmentId).toList();
  }

  Future<String> createTrainingFile(TrainingFileModel file) async {
    final res = await _api.post('/training-files/', body: {
      'title': file.title,
      'description': file.description,
      'fileUrl': file.fileUrl,
      'fileType': file.fileType,
      'tags': file.tags,
    });
    return ((res['trainingFile'] as Map).cast<String, dynamic>())['id']
        as String;
  }

  Future<void> deleteTrainingFile(String id) async {
    await _api.delete('/training-files/$id');
  }

  Future<List<TrainingFileModel>> searchTrainingFiles(String query) async {
    final res = await _api.get('/training-files/', query: {'q': query});
    return (res['trainingFiles'] as List)
        .map((e) =>
            TrainingFileModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ─── Notifications ────────────────────────────────────────────

  /// Fetch the current user's notifications, newest first.
  Future<List<NotificationModel>> getNotifications() async {
    final res = await _api.get('/notifications/');
    return (res['notifications'] as List)
        .map((e) =>
            NotificationModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Mark a single notification as read (or unread when [isRead] is false).
  Future<void> markNotificationRead(String id, {bool isRead = true}) async {
    await _api.patch('/notifications/$id', body: {'isRead': isRead});
  }

  /// Mark all unread notifications of the current user as read.
  Future<void> markAllNotificationsRead() async {
    await _api.post('/notifications/read-all');
  }

  // ─── Helpers ──────────────────────────────────────────────────

  List<InternModel> _internsFrom(Map<String, dynamic> res) {
    return (res['interns'] as List)
        .map((e) => InternModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<EvaluationModel> _evalsFrom(Map<String, dynamic> res) {
    return (res['evaluations'] as List)
        .map((e) =>
            EvaluationModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<AttendanceModel> _attendanceFrom(Map<String, dynamic> res) {
    return (res['attendance'] as List)
        .map((e) =>
            AttendanceModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
