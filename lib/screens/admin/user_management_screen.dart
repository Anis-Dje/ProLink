import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/custom_search_bar.dart';
import '../../widgets/common/loading_overlay.dart';

/// Admin screen for user management: list all users, create new
/// mentors/admins, enable/disable accounts.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _allUsers = [];
  String _query = '';
  bool _loading = true;
  bool _saving = false;

  final _tabs = const ['Tous', 'Admins', 'Encadreurs', 'Stagiaires'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await context.read<FirestoreService>().getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<UserModel> get _filtered {
    Iterable<UserModel> list = _allUsers;
    switch (_tabController.index) {
      case 1:
        list = list.where((u) => u.role == UserRole.admin);
        break;
      case 2:
        list = list.where((u) => u.role == UserRole.mentor);
        break;
      case 3:
        list = list.where((u) => u.role == UserRole.intern);
        break;
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((u) =>
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q));
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _saving,
      message: 'Traitement...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Gestion des Utilisateurs'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => context.go('/admin/dashboard'),
          ),
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomSearchBar(
                hintText: 'Rechercher un utilisateur...',
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.accent))
                  : RefreshIndicator(
                      onRefresh: _loadUsers,
                      color: AppColors.accent,
                      child: _filtered.isEmpty
                          ? const _EmptyUsers()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, i) =>
                                  _UserTile(
                                    user: _filtered[i],
                                    onToggleActive: () =>
                                        _toggleActive(_filtered[i]),
                                  ),
                            ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createUser,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Créer un compte'),
        ),
      ),
    );
  }

  Future<void> _toggleActive(UserModel user) async {
    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: user.isActive ? 'Désactiver' : 'Activer',
      content: user.isActive
          ? 'Désactiver le compte de ${user.fullName} ?'
          : 'Réactiver le compte de ${user.fullName} ?',
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await context
          .read<FirestoreService>()
          .setUserActiveStatus(user.id, !user.isActive);
      _loadUsers();
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createUser() async {
    final result = await showModalBottomSheet<_NewUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateUserSheet(),
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      await context.read<AuthService>().createMentorOrAdmin(
            email: result.email,
            password: result.password,
            fullName: result.fullName,
            phone: result.phone,
            role: result.role,
          );
      if (mounted) {
        AppUtils.showSnackBar(context, 'Compte créé');
      }
      _loadUsers();
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('email-already-in-use')) {
          msg = 'Email déjà utilisé';
        }
        AppUtils.showSnackBar(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggleActive;
  const _UserTile({required this.user, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final roleColor = AppUtils.getRoleColor(user.role.value);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: roleColor.withAlpha(26),
              border: Border.all(color: roleColor.withAlpha(77)),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                Text(user.email,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Pill(
                      label: AppUtils.getRoleLabel(user.role.value),
                      color: roleColor,
                    ),
                    const SizedBox(width: 6),
                    _Pill(
                      label: user.isActive ? 'Actif' : 'Désactivé',
                      color: user.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              user.isActive ? Icons.block : Icons.check_circle_outline,
              color: user.isActive ? AppColors.error : AppColors.success,
              size: 22,
            ),
            onPressed: onToggleActive,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyUsers extends StatelessWidget {
  const _EmptyUsers();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Aucun utilisateur',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NewUser {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final UserRole role;
  _NewUser({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
  });
}

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.mentor;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 18),
              const Text(
                'Créer un compte',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              SegmentedButton<UserRole>(
                segments: const [
                  ButtonSegment(
                      value: UserRole.mentor,
                      icon: Icon(Icons.supervisor_account),
                      label: Text('Encadreur')),
                  ButtonSegment(
                      value: UserRole.admin,
                      icon: Icon(Icons.admin_panel_settings),
                      label: Text('Admin')),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Email invalide'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Mot de passe temporaire',
                    prefixIcon: Icon(Icons.lock_outlined)),
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Min 6 caractères' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(
                    context,
                    _NewUser(
                      fullName: _fullName.text.trim(),
                      email: _email.text.trim(),
                      phone: _phone.text.trim(),
                      password: _password.text,
                      role: _role,
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Créer le compte'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
