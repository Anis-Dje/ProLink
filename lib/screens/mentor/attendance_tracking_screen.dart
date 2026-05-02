import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/attendance_model.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_overlay.dart';

/// Weekly attendance tracking for the mentor's assigned interns.
/// Displays a matrix (intern × weekday) that can be toggled between
/// present / absent / late / justified.
class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() =>
      _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  List<InternModel> _interns = [];
  DateTime _weekStart = _startOfWeek(DateTime.now());
  Map<String, AttendanceModel> _attendance = {};
  String? _mentorId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _startOfWeek(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  DateTime get _weekEnd =>
      _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final mentor = await context.read<AuthService>().getCurrentUser();
      if (mentor == null) {
        setState(() {
          _interns = [];
          _loading = false;
        });
        return;
      }
      final fs = context.read<FirestoreService>();
      final interns = await fs.getInternsByMentor(mentor.id);
      final records =
          await fs.getAttendanceByMentorAndWeek(mentor.id, _weekStart, _weekEnd);
      final map = <String, AttendanceModel>{};
      for (final r in records) {
        map[_key(r.internId, r.date)] = r;
      }
      if (mounted) {
        setState(() {
          _mentorId = mentor.id;
          _interns = interns;
          _attendance = map;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _key(String internId, DateTime date) =>
      '$internId-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  void _changeWeek(int delta) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
    });
    _load();
  }

  void _cycleStatus(InternModel intern, DateTime date) {
    if (_mentorId == null) return;
    final key = _key(intern.id, DateTime(date.year, date.month, date.day));
    final current = _attendance[key]?.status ?? AppConstants.attendancePresent;
    final nextStatus = switch (current) {
      AppConstants.attendancePresent => AppConstants.attendanceAbsent,
      AppConstants.attendanceAbsent => AppConstants.attendanceLate,
      AppConstants.attendanceLate => AppConstants.attendanceJustified,
      _ => AppConstants.attendancePresent,
    };
    setState(() {
      _attendance[key] = AttendanceModel(
        id: key,
        internId: intern.id,
        mentorId: _mentorId!,
        date: DateTime(date.year, date.month, date.day),
        status: nextStatus,
      );
    });
  }

  Future<void> _save() async {
    if (_attendance.isEmpty) {
      AppUtils.showSnackBar(context, 'Nothing to save', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await context
          .read<FirestoreService>()
          .saveAttendanceBatch(_attendance.values.toList());
      if (mounted) {
        AppUtils.showSnackBar(context, 'Attendance saved');
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      message: 'Saving...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Attendance Tracking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : _interns.isEmpty
                ? const _NoInterns()
                : Column(
                    children: [
                      _buildWeekSelector(),
                      _buildLegend(),
                      Expanded(child: _buildGrid()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.accent),
            onPressed: () => _changeWeek(-1),
          ),
          Expanded(
            child: Center(
              child: Text(
                AppUtils.getWeekLabel(_weekStart),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.accent),
            onPressed: () => _changeWeek(1),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _legendChip(AppConstants.attendancePresent),
          _legendChip(AppConstants.attendanceAbsent),
          _legendChip(AppConstants.attendanceLate),
          _legendChip(AppConstants.attendanceJustified),
        ],
      ),
    );
  }

  Widget _legendChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppUtils.getAttendanceColor(status).withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppUtils.getAttendanceColor(status).withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppUtils.getAttendanceColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppUtils.getAttendanceLabel(status),
            style: TextStyle(
              fontSize: 10,
              color: AppUtils.getAttendanceColor(status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final days = _weekDays;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              const SizedBox(
                width: 120,
                child: Text('Intern',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ),
              ...days.map(
                (d) => Expanded(
                  child: Column(
                    children: [
                      Text(
                        _weekdayLabel(d.weekday),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                      Text(
                        '${d.day}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._interns.map((intern) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        intern.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ...days.map((d) {
                      final key = _key(intern.id,
                          DateTime(d.year, d.month, d.day));
                      final status = _attendance[key]?.status;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _cycleStatus(intern, d),
                          child: Container(
                            height: 32,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: status == null
                                  ? AppColors.cardBorder.withAlpha(40)
                                  : AppUtils.getAttendanceColor(status)
                                      .withAlpha(80),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: status == null
                                    ? AppColors.cardBorder
                                    : AppUtils.getAttendanceColor(status),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _statusIcon(status),
                                size: 14,
                                color: status == null
                                    ? AppColors.textSecondary
                                    : AppUtils.getAttendanceColor(status),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  IconData _statusIcon(String? status) {
    return switch (status) {
      AppConstants.attendancePresent => Icons.check,
      AppConstants.attendanceAbsent => Icons.close,
      AppConstants.attendanceLate => Icons.schedule,
      AppConstants.attendanceJustified => Icons.assignment_turned_in,
      _ => Icons.remove,
    };
  }

  String _weekdayLabel(int wd) {
    const labels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[wd];
  }
}

class _NoInterns extends StatelessWidget {
  const _NoInterns();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('No interns assigned',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
