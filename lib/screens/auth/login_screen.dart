import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../widgets/auth/change_password_dialog.dart';
import '../../widgets/common/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _consumedRouteArguments = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If we were redirected here from a registration / pending intern
    // login, surface the message that came along with the route as a
    // snackbar on first frame.
    if (_consumedRouteArguments) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['pendingMessage'] is String) {
      _consumedRouteArguments = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppUtils.showSnackBar(context, args['pendingMessage'] as String);
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      var user = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      // Force a password change on first login for admin-provisioned
      // accounts. The dialog will sign the user out if they cancel.
      if (user.mustChangePassword) {
        final updated = await ChangePasswordDialog.show(
          context,
          temporaryPassword: _passwordController.text,
        );
        if (!mounted) return;
        if (updated == null) {
          // User cancelled — they have been signed out by the dialog.
          return;
        }
        user = updated;
        AppUtils.showSnackBar(context, 'Password updated. Welcome!');
      }

      _navigateByRole(user);
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, _getErrorMessage(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateByRole(UserModel user) {
    switch (user.role) {
      case UserRole.admin:
        Navigator.of(context).pushNamedAndRemoveUntil('/admin/dashboard', (route) => false);
        break;
      case UserRole.mentor:
        Navigator.of(context).pushNamedAndRemoveUntil('/mentor/dashboard', (route) => false);
        break;
      case UserRole.intern:
        Navigator.of(context).pushNamedAndRemoveUntil('/intern/dashboard', (route) => false);
        break;
    }
  }

  String _getErrorMessage(Object e) {
    // Prefer the structured error returned by the API so users see the
    // correct, server-defined message (e.g. "account pending approval").
    if (e is ApiException) {
      switch (e.error) {
        case 'invalid_credentials':
          return 'Incorrect email or password';
        case 'account_disabled':
          return 'This account has been disabled';
        case 'account_pending':
        case 'account_rejected':
          return e.messageOrError;
        case 'server_misconfigured':
          return 'The backend server is not configured (DATABASE_URL missing).';
      }
      return e.messageOrError;
    }
    final error = e.toString();
    if (error.contains('invalid_credentials')) {
      return 'Incorrect email or password';
    } else if (error.contains('account_disabled')) {
      return 'This account has been disabled';
    } else if (error.contains('account_pending')) {
      return 'Your account is awaiting admin approval.';
    } else if (error.contains('account_rejected')) {
      return 'Your registration was rejected by the administrator.';
    } else if (error.contains('SocketException') ||
        error.contains('Failed host lookup') ||
        error.contains('Connection refused')) {
      return 'Network connection error';
    }
    return 'An error occurred. Please try again.';
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Enter your email first', isError: true);
      return;
    }
    try {
      await context.read<AuthService>().resetPassword(_emailController.text.trim());
      if (mounted) {
        AppUtils.showSnackBar(context, 'Password reset email sent');
      }
    } on UnimplementedError {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'This feature is not yet available. '
          'Please contact your administrator.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Error sending reset email', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Logging in...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // Cap the width on tablets / web so the form doesn't span
              // the entire viewport.
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
              children: [
                const SizedBox(height: 60),
                _buildLogo(),
                const SizedBox(height: 48),
                _buildForm(),
                const SizedBox(height: 24),
                _buildRegisterLink(),
                const SizedBox(height: 40),
              ],
            ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accent.withAlpha(77), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withAlpha(51),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'PL',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Pro-Link',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: 'Poppins',
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Professional Internship Management',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Login',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log in to your workspace',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!v.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Log in', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'New intern?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/register'),
          child: const Text('Create account'),
        ),
      ],
    );
  }
}
