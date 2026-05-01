import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:cross_file/cross_file.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/loading_overlay.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _specializationController = TextEditingController();

  String _selectedUniversity = AppConstants.universities.first;
  String _selectedDepartment = AppConstants.departments.first;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  XFile? _profilePhoto;
  Uint8List? _profilePhotoBytes;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _studentIdController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 600,
    );
    if (picked != null) {
      // Read bytes here so the preview works on every platform (web in
      // particular, where `Image.file` can't be used).
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profilePhoto = picked;
        _profilePhotoBytes = bytes;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // The /upload endpoint requires a JWT, so we must register first to
      // obtain one. Upload the photo and patch the user record afterwards.
      final authService = context.read<AuthService>();
      final user = await authService.registerIntern(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        studentId: _studentIdController.text.trim(),
        university: _selectedUniversity,
        specialization: _specializationController.text.trim(),
        department: _selectedDepartment,
      );

      if (_profilePhoto != null) {
        try {
          final storageService = context.read<StorageService>();
          final photoUrl =
              await storageService.uploadProfilePhoto(user.id, _profilePhoto!);
          await authService.updateProfile(
            userId: user.id,
            profilePhotoUrl: photoUrl,
          );
        } catch (_) {
          // The account is already created; surface the photo failure but
          // don't block the user on the signup screen.
          if (mounted) {
            AppUtils.showSnackBar(
              context,
              'Account created, but the photo could not be uploaded.',
              isError: true,
            );
          }
        }
      }

      if (!mounted) return;
      // After successful intern signup the JWT is issued, but the account is
      // pending admin approval; route to the holding screen until approved.
      Navigator.of(context).pushNamedAndRemoveUntil('/pending', (route) => false);
    } catch (e) {
      if (mounted) {
        String msg = 'Registration error. Please try again.';

        if (e is ApiException) {
          if (e.error == 'email_in_use') {
            msg = 'This email is already in use';
          } else if (e.statusCode == 400) {
            msg = e.messageOrError;
          } else if (e.statusCode >= 500) {
            msg = 'Server error. Make sure the backend and database are running.';
          } else {
            msg = e.messageOrError;
          }
        } else {
          final raw = e.toString();
          if (raw.contains('email_in_use') ||
              raw.contains('Email already registered')) {
            msg = 'This email is already in use';
          } else if (raw.contains('>=6 chars') ||
              raw.contains('weak-password')) {
            msg = 'Password too weak';
          } else if (raw.contains('SocketException') ||
              raw.contains('Connection refused') ||
              raw.contains('Failed host lookup')) {
            msg = 'Cannot reach the server. Make sure the backend is running.';
          }
        }

        AppUtils.showSnackBar(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Creating account...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('New intern account'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoBanner(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 24),
                  _buildSection('Personal information', [
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full name',
                      icon: Icons.person_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _emailController,
                      label: 'University email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Academic information', [
                    _buildTextField(
                      controller: _studentIdController,
                      label: 'Student ID',
                      icon: Icons.badge_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'University',
                      icon: Icons.school_outlined,
                      value: _selectedUniversity,
                      items: AppConstants.universities,
                      onChanged: (v) => setState(() => _selectedUniversity = v!),
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _specializationController,
                      label: 'Specialization',
                      icon: Icons.book_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Desired department',
                      icon: Icons.business_outlined,
                      value: _selectedDepartment,
                      items: AppConstants.departments,
                      onChanged: (v) => setState(() => _selectedDepartment = v!),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection('Security', [
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Password',
                      obscure: _obscurePassword,
                      onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm password',
                      obscure: _obscureConfirmPassword,
                      onToggle: () =>
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text(
                      'Submit request',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?', style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withAlpha(77)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.accent, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account will be activated after validation by an administrator.',
              style: TextStyle(fontSize: 12, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickProfilePhoto,
        child: Stack(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: _profilePhotoBytes != null
                  ? ClipOval(
                      child: Image.memory(_profilePhotoBytes!,
                          fit: BoxFit.cover, width: 100, height: 100),
                    )
                  : const Icon(Icons.person, color: AppColors.textSecondary, size: 40),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.primary,
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outlined),
        filled: true,
        fillColor: AppColors.primary,
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontFamily: 'Poppins',
        fontSize: 14,
      ),
      dropdownColor: AppColors.surface,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: AppColors.primary,
      ),
      selectedItemBuilder: (context) {
        return items
            .map(
              (item) => Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
            .toList();
      },
      items: items
          .map(
            (item) => DropdownMenuItem(
          value: item,
          child: Text(
            item,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
          .toList(),
      onChanged: onChanged,
    );
  }
}
