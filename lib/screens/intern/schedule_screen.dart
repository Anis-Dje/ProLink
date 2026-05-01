import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/schedule_model.dart';
import '../../services/firestore_service.dart';

/// Lists schedules published by administrators in a calendar view. The
/// calendar marks the days that have a schedule attached; tapping a day
/// shows the matching schedule(s) below the calendar.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<ScheduleModel> _schedules = const [];
  bool _loading = true;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _format = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await context.read<FirestoreService>().getSchedules();
      if (mounted) {
        setState(() {
          _schedules = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ScheduleModel> _eventsFor(DateTime day) {
    return _schedules.where((s) => _isSameDay(s.uploadDate, day)).toList();
  }

  void _open(ScheduleModel s) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(s.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.weekLabel,
                  style: const TextStyle(color: AppColors.accent)),
              const SizedBox(height: 8),
              if (s.description.isNotEmpty)
                Text(s.description,
                    style: const TextStyle(color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('File link:',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              SelectableText(
                s.fileUrl,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedules'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil('/intern/dashboard', (route) => false),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.accent,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCalendar(),
                  const SizedBox(height: 16),
                  ..._buildSelectedDayList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: TableCalendar<ScheduleModel>(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            _selectedDay != null && _isSameDay(day, _selectedDay!),
        eventLoader: _eventsFor,
        calendarFormat: _format,
        onFormatChanged: (f) => setState(() => _format = f),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) => _focusedDay = focused,
        headerStyle: const HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          formatButtonTextStyle: TextStyle(color: AppColors.accent),
          formatButtonDecoration: BoxDecoration(
            border: Border.fromBorderSide(
                BorderSide(color: AppColors.accent)),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.accent),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: AppColors.accent),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(color: AppColors.textSecondary),
          weekendStyle: TextStyle(color: AppColors.textSecondary),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle:
              const TextStyle(color: AppColors.textPrimary),
          weekendTextStyle:
              const TextStyle(color: AppColors.textPrimary),
          outsideTextStyle:
              const TextStyle(color: AppColors.textSecondary),
          todayDecoration: BoxDecoration(
            color: AppColors.accent.withAlpha(60),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSelectedDayList() {
    final day = _selectedDay ?? _focusedDay;
    final events = _eventsFor(day);
    if (events.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.event_busy,
                    color: AppColors.textSecondary, size: 48),
                const SizedBox(height: 8),
                Text(
                  'No schedule on ${AppUtils.formatDate(day)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                if (_schedules.isNotEmpty)
                  const Text(
                    'Days with schedules are marked in gold.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      Text(
        'Schedules on ${AppUtils.formatDate(day)}',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      ...events.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScheduleTile(schedule: s, onOpen: () => _open(s)),
          )),
    ];
  }
}

class _ScheduleTile extends StatelessWidget {
  final ScheduleModel schedule;
  final VoidCallback onOpen;
  const _ScheduleTile({required this.schedule, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today,
                  color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    schedule.weekLabel,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Published on ${AppUtils.formatDate(schedule.uploadDate)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new,
                color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}
