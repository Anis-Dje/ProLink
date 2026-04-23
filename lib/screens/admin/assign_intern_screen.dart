import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/intern_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/loading_overlay.dart';

class AssignInternScreen extends StatefulWidget {
  const AssignInternScreen({super.key});

  @override
  State<AssignInternScreen> createState() => _AssignInternScreenState();
}

class _AssignInternScreenState extends State<AssignInternScreen> {
  List<InternModel> _interns = [];
  List<UserModel> _mentors = [];
  InternModel? _selectedIntern;
  UserModel? _selectedMentor;
  String? _selectedDepartment;
  bool _loading = true;
  bool _saving = false;
  String _searchIntern = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fs = context.read<FirestoreService>();
      final interns = await fs.getInternsByStatus(AppConstants.statusActive);
      final mentors = await fs.getUsersByRole(AppConstants.roleMentor);
      if (mounted) {
        setState(() {
          _interns = interns;
          _mentors = mentors;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<InternModel> get _filteredInterns {
    if (_searchIntern.isEmpty) return _interns;
    return _interns.where((i) =>
        i.fullName.toLowerCase().contains(_searchIntern.toLowerCase()) ||
        i.studentId.toLowerCase().contains(_searchIntern.toLowerCase())).toList();
  }

  Future<void> _assign() async {
    if (_selectedIntern == null) {
      AppUtils.showSnackBar(context, 'Sélectionner un stagiaire', isError: true);
      return;
    }
    if (_selectedMentor == null) {
      AppUtils.showSnackBar(context, 'Sélectionner un encadreur', isError: true);
      return;
    }
    if (_selectedDepartment == null) {
      AppUtils.showSnackBar(context, 'Sélectionner un département', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<FirestoreService>().assignInternToMentor(
            _selectedIntern!.id,
            _selectedMentor!.id,
            _selectedDepartment!,
          );
      if (mounted) {
        AppUtils.showSnackBar(context, 'Affectation réussie');
        setState(() {
          _selectedIntern = null;
          _selectedMentor = null;
          _selectedDepartment = null;
        });
        _loadData();
      }
    } catch (_) {
      if (mounted) AppUtils.showSnackBar(context, 'Erreur lors de l\'affectation', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      message: 'Affectation en cours...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Affecter un Stagiaire'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/admin/dashboard'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      title: 'Sélectionner un Stagiaire',
                      icon: Icons.person_outlined,
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (v) => setState(() => _searchIntern = v),
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'Rechercher...',
                              prefixIcon: Icon(Icons.search),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: _filteredInterns.length,
                              itemBuilder: (_, i) {
                                final intern = _filteredInterns[i];
                                final selected = _selectedIntern?.id == intern.id;
                                return ListTile(
                                  dense: true,
                                  selected: selected,
                                  selectedTileColor: AppColors.accent.withAlpha(26),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      intern.fullName[0],
                                      style: const TextStyle(color: AppColors.accent),
                                    ),
                                  ),
                                  title: Text(intern.fullName,
                                      style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(intern.studentId,
                                      style: const TextStyle(fontSize: 12)),
                                  trailing: selected
                                      ? const Icon(Icons.check_circle, color: AppColors.accent)
                                      : null,
                                  onTap: () => setState(() => _selectedIntern = intern),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Sélectionner un Encadreur',
                      icon: Icons.supervisor_account_outlined,
                      child: DropdownButtonFormField<UserModel>(
                        value: _selectedMentor,
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins'),
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          hintText: 'Choisir un encadreur',
                          prefixIcon: Icon(Icons.person_search_outlined),
                        ),
                        items: _mentors.map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.fullName, overflow: TextOverflow.ellipsis),
                            )).toList(),
                        onChanged: (v) => setState(() => _selectedMentor = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Département',
                      icon: Icons.business_outlined,
                      child: DropdownButtonFormField<String>(
                        value: _selectedDepartment,
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Poppins'),
                        dropdownColor: AppColors.surface,
                        decoration: const InputDecoration(
                          hintText: 'Choisir un département',
                          prefixIcon: Icon(Icons.corporate_fare_outlined),
                        ),
                        items: AppConstants.departments.map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            )).toList(),
                        onChanged: (v) => setState(() => _selectedDepartment = v),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_selectedIntern != null || _selectedMentor != null)
                      _buildSummary(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _assign,
                      icon: const Icon(Icons.assignment_turned_in_outlined),
                      label: const Text('Confirmer l\'affectation', style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Résumé de l\'affectation',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
          const SizedBox(height: 8),
          if (_selectedIntern != null)
            _SummaryRow('Stagiaire', _selectedIntern!.fullName),
          if (_selectedMentor != null)
            _SummaryRow('Encadreur', _selectedMentor!.fullName),
          if (_selectedDepartment != null)
            _SummaryRow('Département', _selectedDepartment!),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
