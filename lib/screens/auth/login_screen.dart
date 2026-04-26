import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final user = await authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      _navigateByRole(user);
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, _getErrorMessage(e.toString()), isError: true);
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

  String _getErrorMessage(String error) {
    if (error.contains('invalid_credentials')) {
      return 'Email ou mot de passe incorrect';
    } else if (error.contains('account_disabled')) {
      return 'Ce compte a été désactivé';
    } else if (error.contains('server_misconfigured') ||
        error.contains('DATABASE_URL environment variable is not set')) {
      return 'Le serveur backend n\'est pas configuré (DATABASE_URL manquant).';
    } else if (error.contains('SocketException') ||
        error.contains('Failed host lookup') ||
        error.contains('Connection refused')) {
      return 'Erreur de connexion réseau';
    }
    return 'Une erreur est survenue. Réessayez.';
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Entrez votre email d\'abord', isError: true);
      return;
    }
    try {
      await context.read<AuthService>().resetPassword(_emailController.text.trim());
      if (mounted) {
        AppUtils.showSnackBar(context, 'Email de réinitialisation envoyé');
      }
    } on UnimplementedError {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Cette fonctionnalité n\'est pas encore disponible. '
          'Contactez votre administrateur.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Erreur lors de l\'envoi', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Connexion en cours...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
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
          'Gestion des Stages Professionnels',
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
            'Connexion',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous à votre espace',
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
              labelText: 'Adresse email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email requis';
              if (!v.contains('@')) return 'Email invalide';
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
              labelText: 'Mot de passe',
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
              if (v == null || v.isEmpty) return 'Mot de passe requis';
              if (v.length < 6) return 'Minimum 6 caractères';
              return null;
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              child: const Text('Mot de passe oublié ?'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _login,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Se connecter', style: TextStyle(fontSize: 16)),
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
          'Nouveau stagiaire ?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/register'),
          child: const Text('Créer un compte'),
        ),
      ],
    );
  }
}
