import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/evaluation_model.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_overlay.dart';

/// Allows mentors to create a new performance evaluation for one of
/// their assigned interns. Scores each criterion from 0-20.
class EvaluateInternScreen extends StatefulWidget {
  const EvaluateInternScreen({super.key});

  @override
  State<EvaluateInternScreen> createState() => _EvaluateInternScreenState();
}

class _EvaluateInternScreenState extends State<EvaluateInternScreen> {
  List<InternModel> _interns = [];
  InternModel? _selected;
  final Map<String, double> _scores = {
    for (final c in AppConstants.evaluationCriteria) c: 15,
  };
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

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
      final interns =
          await context.read<FirestoreService>().getInternsByMentor(mentor.id);
      if (mounted) {
        setState(() {
          _interns = interns;
          _selected = interns.isNotEmpty ? interns.first : null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _overall {
    if (_scores.isEmpty) return 0;
    final sum = _scores.values.reduce((a, b) => a + b);
    return sum / _scores.length;
  }

  Future<void> _save() async {
    if (_selected == null) {
      AppUtils.showSnackBar(context, 'Sélectionner un stagiaire', isError: true);
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Titre requis', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final mentor = await context.read<AuthService>().getCurrentUser();
      if (mentor == null) return;

      final evaluation = EvaluationModel(
        id: '',
        internId: _selected!.id,
        mentorId: mentor.id,
        title: _titleController.text.trim(),
        description: '',
        criteria: Map<String, double>.from(_scores),
        overallScore: _overall,
        comment: _commentController.text.trim(),
        evaluationDate: DateTime.now(),
      );

      await context.read<FirestoreService>().createEvaluation(evaluation);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Évaluation enregistrée');
        _titleController.clear();
        _commentController.clear();
        setState(() {
          for (final c in AppConstants.evaluationCriteria) {
            _scores[c] = 15;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      message: 'Enregistrement...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Évaluer un Stagiaire'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/mentor/dashboard', (route) => false),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent))
            : _interns.isEmpty
                ? const _NoInterns()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInternSelector(),
                        const SizedBox(height: 20),
                        _buildTitleField(),
                        const SizedBox(height: 20),
                        _buildScoring(),
                        const SizedBox(height: 20),
                        _buildOverall(),
                        const SizedBox(height: 20),
                        _buildComment(),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('Enregistrer l\'évaluation'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildInternSelector() {
    return _Section(
      title: 'Stagiaire',
      icon: Icons.person_outlined,
      child: DropdownButtonFormField<InternModel>(
        initialValue: _selected,
        dropdownColor: AppColors.surface,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.badge_outlined),
        ),
        items: _interns
            .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text('${i.fullName} · ${i.studentId}'),
                ))
            .toList(),
        onChanged: (v) => setState(() => _selected = v),
      ),
    );
  }

  Widget _buildTitleField() {
    return _Section(
      title: 'Titre de l\'évaluation',
      icon: Icons.title,
      child: TextField(
        controller: _titleController,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Évaluation mensuelle – Mars',
          prefixIcon: Icon(Icons.edit_outlined),
        ),
      ),
    );
  }

  Widget _buildScoring() {
    return _Section(
      title: 'Critères (0-20)',
      icon: Icons.star_outline,
      child: Column(
        children: AppConstants.evaluationCriteria.map((criterion) {
          final value = _scores[criterion] ?? 15;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        criterion,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _scoreColor(value).withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          color: _scoreColor(value),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: value,
                  min: 0,
                  max: 20,
                  divisions: 40,
                  activeColor: _scoreColor(value),
                  inactiveColor: AppColors.cardBorder,
                  onChanged: (v) => setState(() => _scores[criterion] = v),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverall() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: AppColors.textPrimary, size: 32),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Note globale',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Moyenne des critères',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_overall.toStringAsFixed(1)} / 20',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment() {
    return _Section(
      title: 'Commentaire',
      icon: Icons.comment_outlined,
      child: TextField(
        controller: _commentController,
        maxLines: 3,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          hintText: 'Observations, points à améliorer...',
        ),
      ),
    );
  }

  Color _scoreColor(double v) {
    if (v >= 16) return AppColors.success;
    if (v >= 12) return AppColors.accent;
    if (v >= 8) return AppColors.warning;
    return AppColors.error;
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
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
          Icon(Icons.assessment_outlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Aucun stagiaire affecté à évaluer',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
