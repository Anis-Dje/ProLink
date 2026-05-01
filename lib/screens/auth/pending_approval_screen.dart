import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning.withAlpha(26),
                    border: Border.all(color: AppColors.warning, width: 2),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 48,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Account Pending',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your internship request has been received.\n\nAn administrator will review your file and notify you by email once your account is approved.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This process can take 24 to 48 business hours.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Back to login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
