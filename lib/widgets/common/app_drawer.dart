import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class AppDrawer extends StatelessWidget {
  final UserModel user;

  const AppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.primary,
      child: Column(
        children: [
          _DrawerHeader(user: user),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildNavItems(context),
            ),
          ),
          _DrawerFooter(user: user),
        ],
      ),
    );
  }

  List<Widget> _buildNavItems(BuildContext context) {
    switch (user.role) {
      case UserRole.admin:
        return [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Tableau de bord',
            route: '/admin/dashboard',
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Gérer les stagiaires',
            route: '/admin/interns',
          ),
          _NavItem(
            icon: Icons.assignment_ind_outlined,
            label: 'Affectations',
            route: '/admin/assign',
          ),
          _NavItem(
            icon: Icons.folder_outlined,
            label: 'Documents',
            route: '/admin/documents',
          ),
          _NavItem(
            icon: Icons.manage_accounts_outlined,
            label: 'Gestion utilisateurs',
            route: '/admin/users',
          ),
        ];
      case UserRole.mentor:
        return [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Tableau de bord',
            route: '/mentor/dashboard',
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Mes stagiaires',
            route: '/mentor/interns',
          ),
          _NavItem(
            icon: Icons.star_outline,
            label: 'Évaluations',
            route: '/mentor/evaluate',
          ),
          _NavItem(
            icon: Icons.calendar_today_outlined,
            label: 'Présences',
            route: '/mentor/attendance',
          ),
          _NavItem(
            icon: Icons.upload_file_outlined,
            label: 'Supports de formation',
            route: '/mentor/training',
          ),
        ];
      case UserRole.intern:
        return [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Tableau de bord',
            route: '/intern/dashboard',
          ),
          _NavItem(
            icon: Icons.badge_outlined,
            label: 'Carte de stagiaire',
            route: '/intern/id-card',
          ),
          _NavItem(
            icon: Icons.schedule_outlined,
            label: 'Planning',
            route: '/intern/schedule',
          ),
          _NavItem(
            icon: Icons.library_books_outlined,
            label: 'Supports de cours',
            route: '/intern/training',
          ),
          _NavItem(
            icon: Icons.assessment_outlined,
            label: 'Mes évaluations',
            route: '/intern/evaluations',
          ),
        ];
    }
  }
}

class _DrawerHeader extends StatelessWidget {
  final UserModel user;
  const _DrawerHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
              color: AppColors.surface,
            ),
            child: user.profilePhotoUrl != null
                ? ClipOval(
                    child: Image.network(
                      user.profilePhotoUrl!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Center(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppUtils.getRoleColor(user.role.value).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppUtils.getRoleColor(user.role.value).withAlpha(77),
                    ),
                  ),
                  child: Text(
                    AppUtils.getRoleLabel(user.role.value),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppUtils.getRoleColor(user.role.value),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    // Compare against the current route name so the drawer highlights
    // the active section. Navigator pushes named routes via
    // RouteSettings, so ModalRoute.of(context)?.settings.name gives us
    // the path we registered in MaterialApp.routes.
    final isActive = ModalRoute.of(context)?.settings.name == route;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isActive ? AppColors.accent : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? AppColors.accent : AppColors.textPrimary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
        },
      ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  final UserModel user;
  const _DrawerFooter({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error, size: 22),
            title: const Text(
              'Déconnexion',
              style: TextStyle(fontSize: 13, color: AppColors.error),
            ),
            onTap: () async {
              final confirm = await AppUtils.showConfirmDialog(
                context,
                title: 'Déconnexion',
                content: 'Voulez-vous vraiment vous déconnecter ?',
                confirmText: 'Déconnecter',
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthService>().logout();
                if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${AppConstants.appName} v${AppConstants.appVersion}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
