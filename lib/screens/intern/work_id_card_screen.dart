import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/intern_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Digital Work ID card for the intern. Shown as a sleek dark card
/// featuring photo, name, student ID, department, QR code and validity.
class WorkIdCardScreen extends StatefulWidget {
  const WorkIdCardScreen({super.key});

  @override
  State<WorkIdCardScreen> createState() => _WorkIdCardScreenState();
}

class _WorkIdCardScreenState extends State<WorkIdCardScreen> {
  UserModel? _user;
  InternModel? _intern;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await context.read<AuthService>().getCurrentUser();
      InternModel? intern;
      if (user != null) {
        intern =
            await context.read<FirestoreService>().getInternByUserId(user.id);
      }
      if (mounted) {
        setState(() {
          _user = user;
          _intern = intern;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carte de Stagiaire'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/intern/dashboard'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _user == null || _intern == null
              ? const _MissingData()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        _buildCard(),
                        const SizedBox(height: 24),
                        _buildInfo(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildCard() {
    final user = _user!;
    final intern = _intern!;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.idCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withAlpha(120)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(60),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PL',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pro-Link · Carte Professionnelle',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Icon(Icons.verified_user_outlined,
                  color: AppColors.accent.withAlpha(180), size: 18),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: AppColors.accent.withAlpha(60),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: user.profilePhotoUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: user.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _fallbackAvatar(user),
                        ),
                      )
                    : _fallbackAvatar(user),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      intern.specialization.isEmpty
                          ? 'Stagiaire'
                          : intern.specialization,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppUtils.getStatusColor(intern.status)
                            .withAlpha(26),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppUtils.getStatusColor(intern.status)
                              .withAlpha(77),
                        ),
                      ),
                      child: Text(
                        AppUtils.getStatusLabel(intern.status).toUpperCase(),
                        style: TextStyle(
                          color: AppUtils.getStatusColor(intern.status),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(160),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _cardRow('Matricule', intern.studentId),
                const SizedBox(height: 4),
                _cardRow('Département', intern.department),
                const SizedBox(height: 4),
                _cardRow('Université', intern.university),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: QrImageView(
              data:
                  'prolink://id/${intern.id}?name=${Uri.encodeComponent(user.fullName)}&mat=${intern.studentId}',
              version: QrVersions.auto,
              size: 120,
              backgroundColor: AppColors.textPrimary,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.primary,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Valide du ${AppUtils.formatDate(intern.startDate ?? intern.registrationDate)}'
            '${intern.endDate != null ? ' au ${AppUtils.formatDate(intern.endDate!)}' : ''}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(UserModel user) {
    return Center(
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _cardRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Présentez cette carte (ou son QR code) à l\'accueil '
              '${AppConstants.appName} lors de vos entrées/sorties.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingData extends StatelessWidget {
  const _MissingData();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Impossible de charger la carte',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
