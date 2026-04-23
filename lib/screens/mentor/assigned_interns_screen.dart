import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/intern_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/cards/intern_card.dart';
import '../../widgets/common/custom_search_bar.dart';

/// Lists interns that have been assigned to the currently signed-in mentor.
class AssignedInternsScreen extends StatefulWidget {
  const AssignedInternsScreen({super.key});

  @override
  State<AssignedInternsScreen> createState() => _AssignedInternsScreenState();
}

class _AssignedInternsScreenState extends State<AssignedInternsScreen> {
  List<InternModel> _interns = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<InternModel> get _filtered {
    if (_query.isEmpty) return _interns;
    final q = _query.toLowerCase();
    return _interns
        .where((i) =>
            i.fullName.toLowerCase().contains(q) ||
            i.studentId.toLowerCase().contains(q) ||
            i.department.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes Stagiaires'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/mentor/dashboard'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              hintText: 'Rechercher...',
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.accent,
                    child: _filtered.isEmpty
                        ? const _Empty()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => InternCard(
                              intern: _filtered[i],
                              onTap: () => _showDetails(_filtered[i]),
                              actions: [
                                IconButton(
                                  icon: const Icon(Icons.star_outline,
                                      color: AppColors.gold),
                                  onPressed: () =>
                                      context.go('/mentor/evaluate'),
                                ),
                              ],
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showDetails(InternModel intern) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(intern.fullName,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(intern.email,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            _row('Département', intern.department),
            _row('Spécialité', intern.specialization),
            _row('Téléphone', intern.phone),
            _row('Université', intern.university),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/mentor/evaluate');
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('Évaluer'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go('/mentor/attendance');
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Présence'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Aucun stagiaire affecté',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
