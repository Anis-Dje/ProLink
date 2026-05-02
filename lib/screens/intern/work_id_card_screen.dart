import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/intern_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';

/// Intern profile screen. Shows the digital Work-ID card (with QR code)
/// alongside the intern's profile picture and lets them change it via
/// either a local upload or a remote image URL. The route is the same
/// `/intern/id-card` that used to host the card-only view, so existing
/// navigation keeps working — the screen itself just grew.
class WorkIdCardScreen extends StatefulWidget {
  const WorkIdCardScreen({super.key});

  @override
  State<WorkIdCardScreen> createState() => _WorkIdCardScreenState();
}

class _WorkIdCardScreenState extends State<WorkIdCardScreen> {
  UserModel? _user;
  InternModel? _intern;
  bool _loading = true;
  bool _saving = false;

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

  /// Persists a new profile photo URL on the backend then refreshes the
  /// in-memory user so every screen (avatar shortcut, drawer, card) picks
  /// up the change immediately.
  Future<void> _saveProfilePhotoUrl(String url) async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      final auth = context.read<AuthService>();
      await auth.updateProfile(userId: _user!.id, profilePhotoUrl: url);
      final refreshed = auth.currentUser;
      if (mounted) {
        setState(() {
          _user = refreshed;
          _saving = false;
        });
        AppUtils.showSnackBar(context, 'Profile picture updated');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppUtils.showSnackBar(context, 'Could not update photo: $e',
            isError: true);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null || _user == null) return;
    setState(() => _saving = true);
    try {
      final url = await context
          .read<StorageService>()
          .uploadProfilePhoto(_user!.id, picked);
      await _saveProfilePhotoUrl(url);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppUtils.showSnackBar(context, 'Upload failed: $e', isError: true);
      }
    }
  }

  Future<void> _pickFromUrl() async {
    final controller = TextEditingController(text: _user?.profilePhotoUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Use image URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      AppUtils.showSnackBar(context, 'URL must start with http(s)://',
          isError: true);
      return;
    }
    await _saveProfilePhotoUrl(url);
  }

  void _openChangePhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Change profile picture',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.accent),
              title: const Text('Upload from device',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Choose an image from your gallery',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link, color: AppColors.accent),
              title: const Text('Use image URL',
                  style: TextStyle(color: AppColors.textPrimary)),
              subtitle: const Text('Paste a public link to an image',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromUrl();
              },
            ),
            if (_user?.profilePhotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: const Text('Remove current picture',
                    style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveProfilePhotoUrl('');
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context)
              .pushNamedAndRemoveUntil('/intern/dashboard', (route) => false),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : _user == null || _intern == null
              ? const _MissingData()
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            children: [
                              _buildAvatarSection(),
                              const SizedBox(height: 22),
                              _buildCard(),
                              const SizedBox(height: 22),
                              _buildInfo(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_saving)
                      Container(
                        color: Colors.black.withAlpha(120),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                            color: AppColors.accent),
                      ),
                  ],
                ),
    );
  }

  // ─── Avatar section ────────────────────────────────────────────

  Widget _buildAvatarSection() {
    final user = _user!;
    final hasPhoto = user.profilePhotoUrl != null &&
        user.profilePhotoUrl!.isNotEmpty;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.gold],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withAlpha(80),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                ),
                child: ClipOval(
                  child: hasPhoto
                      ? Image.network(
                          user.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          width: 124,
                          height: 124,
                          errorBuilder: (_, __, ___) =>
                              _avatarInitials(user, 44),
                        )
                      : _avatarInitials(user, 44),
                ),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: Material(
                color: AppColors.accent,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openChangePhotoSheet,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.camera_alt_outlined,
                        color: AppColors.primary, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          user.fullName,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _openChangePhotoSheet,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Change picture'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accent,
            side: const BorderSide(color: AppColors.accent),
          ),
        ),
      ],
    );
  }

  Widget _avatarInitials(UserModel user, double fontSize) {
    return Center(
      child: Text(
        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'I',
        style: TextStyle(
          color: AppColors.accent,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── Work-ID card ──────────────────────────────────────────────

  Widget _buildCard() {
    final user = _user!;
    final intern = _intern!;
    return Container(
      width: double.infinity,
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
                  'Pro-Link · Professional ID',
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
          Container(height: 1, color: AppColors.accent.withAlpha(60)),
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
                child: ClipOval(
                  child: user.profilePhotoUrl != null &&
                          user.profilePhotoUrl!.isNotEmpty
                      ? Image.network(
                          user.profilePhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _avatarInitials(user, 30),
                        )
                      : _avatarInitials(user, 30),
                ),
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
                          ? 'Intern'
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
                _cardRow('ID number', intern.studentId),
                const SizedBox(height: 4),
                _cardRow('Department', intern.department),
                const SizedBox(height: 4),
                _cardRow('University', intern.university),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.textPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ID NUMBER',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PL-${intern.studentId}-${intern.id.substring(0, 6).toUpperCase()}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Scan QR for attendance',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: QrImageView(
                    data: jsonEncode({
                      'type': 'prolink-id',
                      'internId': intern.id,
                      'studentId': intern.studentId,
                      'name': user.fullName,
                    }),
                    version: QrVersions.auto,
                    size: 80,
                    backgroundColor: Colors.white,
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
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Valid from ${AppUtils.formatDate(intern.startDate ?? intern.registrationDate)}'
            '${intern.endDate != null ? ' to ${AppUtils.formatDate(intern.endDate!)}' : ''}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
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
              'Show this card (or its QR code) at the '
              '${AppConstants.appName} reception when entering/leaving.',
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
          Text('Cannot load profile',
              style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
