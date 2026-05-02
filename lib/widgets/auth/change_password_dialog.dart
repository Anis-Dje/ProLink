import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Modal dialog that forces a user to change their password before they
/// can use the rest of the app. Shown on first login for any account
/// flagged with [UserModel.mustChangePassword] (admin-created mentor /
/// admin accounts).
///
/// The dialog is non-dismissible: tapping outside or hitting back is
/// blocked. The only way out is to either submit a valid new password
/// or sign out via the explicit "Sign out" button. On success the
/// dialog [Navigator.pop]s with the refreshed [UserModel].
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.temporaryPassword});

  /// Pre-fill the "current password" field with the temp password the
  /// user just used to log in. They never had to type it from memory,
  /// so making them re-type it would be friction without any security
  /// benefit.
  final String temporaryPassword;

  static Future<UserModel?> show(
    BuildContext context, {
    required String temporaryPassword,
  }) {
    return showDialog<UserModel>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(temporaryPassword: temporaryPassword),
    );
  }

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = await context.read<AuthService>().changePassword(
            currentPassword: widget.temporaryPassword,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, e.messageOrError, isError: true);
    } catch (_) {
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'Could not update password. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancel() async {
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Block the system back gesture / button — the user must either set
    // a new password or explicitly sign out.
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock_reset, color: AppColors.accent),
            const SizedBox(width: 12),
            const Expanded(child: Text('Set a new password')),
          ],
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your administrator created this account with a temporary '
                'password. Please choose a new password before continuing.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Must be at least 6 characters';
                  if (v == widget.temporaryPassword) {
                    return 'Cannot match the temporary password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _cancel,
            child: const Text('Sign out'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
