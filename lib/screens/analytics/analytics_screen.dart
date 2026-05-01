import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/evaluation_model.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Performance analytics dashboard with two visualisations:
/// - Bar chart of evaluation scores per intern
/// - Pie chart of intern distribution by department
///
/// Available to admins (sees everyone) and mentors (sees only their own
/// assigned interns). Uses `fl_chart`, the de-facto chart library for
/// Flutter.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  List<InternModel> _interns = const [];
  List<EvaluationModel> _evaluations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final auth = context.read<AuthService>();
      final user = auth.currentUser;

      List<InternModel> interns;
      List<EvaluationModel> evaluations;
      if (user?.role.name == 'mentor') {
        interns = await fs.getInternsByMentor(user!.id);
        evaluations = await fs.getEvaluationsByMentor(user.id);
      } else {
        interns = await fs.getAllInterns();
        // Pull evaluations for each intern in the active set. The PHP
        // backend doesn't expose a `GET /evaluations/` endpoint without a
        // filter, so we fan out per-intern and merge.
        final all = <EvaluationModel>[];
        for (final intern in interns) {
          all.addAll(await fs.getEvaluationsByIntern(intern.id));
        }
        evaluations = all;
      }

      if (!mounted) return;
      setState(() {
        _interns = interns;
        _evaluations = evaluations;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, double> _avgScoresByIntern() {
    final byIntern = <String, List<double>>{};
    for (final e in _evaluations) {
      byIntern.putIfAbsent(e.internId, () => []).add(e.overallScore);
    }
    final byName = <String, double>{};
    for (final entry in byIntern.entries) {
      final name = _interns
              .firstWhere(
                (i) => i.id == entry.key,
                orElse: () => InternModel(
                  id: entry.key,
                  userId: '',
                  fullName: 'Intern',
                  email: '',
                  phone: '',
                  studentId: '',
                  department: '',
                  status: '',
                  registrationDate: DateTime.now(),
                  university: '',
                  specialization: '',
                ),
              )
              .fullName;
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      byName[name.length > 12 ? '${name.substring(0, 12)}…' : name] = avg;
    }
    return byName;
  }

  Map<String, int> _internsByDepartment() {
    final counts = <String, int>{};
    for (final i in _interns) {
      final dep = i.department.isEmpty ? 'Unassigned' : i.department;
      counts[dep] = (counts[dep] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 800;
                final scores = _avgScoresByIntern();
                final byDept = _internsByDepartment();
                final cards = [
                  _ChartCard(
                    title: 'Average Evaluation Score per Intern',
                    subtitle: '${_evaluations.length} evaluations',
                    child: _BarChart(scores: scores),
                  ),
                  _ChartCard(
                    title: 'Interns by Department',
                    subtitle: '${_interns.length} active interns',
                    child: _PieChart(counts: byDept),
                  ),
                ];
                final body = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: cards
                            .map((c) =>
                                Expanded(child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: c,
                                )))
                            .toList(),
                      )
                    : Column(
                        children: cards
                            .map((c) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: c,
                                ))
                            .toList(),
                      );
                return RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    child: body,
                  ),
                );
              },
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(height: 280, child: child),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({required this.scores});
  final Map<String, double> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) {
      return const Center(
        child: Text(
          'No evaluations yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final entries = scores.entries.toList();
    return BarChart(
      BarChartData(
        maxY: 20,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.cardBorder,
            strokeWidth: 0.4,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 5,
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    entries[i].key,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  color: AppColors.accent,
                  width: 18,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PieChart extends StatefulWidget {
  const _PieChart({required this.counts});
  final Map<String, int> counts;

  @override
  State<_PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<_PieChart> {
  int? _touchedIndex;

  static const _palette = [
    AppColors.accent,
    AppColors.gold,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    Color(0xFF8E7CC3),
    Color(0xFF45B7D1),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.counts.isEmpty) {
      return const Center(
        child: Text(
          'No interns yet.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final entries = widget.counts.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response == null ||
                        response.touchedSection == null) {
                      _touchedIndex = null;
                    } else {
                      _touchedIndex =
                          response.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    radius: _touchedIndex == i ? 78 : 70,
                    title:
                        '${((entries[i].value / total) * 100).toStringAsFixed(0)}%',
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entries[i].key} (${entries[i].value})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
