import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/intern_model.dart';

class InternCard extends StatelessWidget {
  final InternModel intern;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final bool compact;

  const InternCard({
    super.key,
    required this.intern,
    this.onTap,
    this.actions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(child: _buildInfo()),
            if (actions != null)
              Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: compact ? 40 : 48,
      height: compact ? 40 : 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: AppColors.accent.withAlpha(77), width: 2),
      ),
      child: intern.profilePhotoUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: intern.profilePhotoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
                errorWidget: (_, __, ___) => _defaultAvatar(),
              ),
            )
          : _defaultAvatar(),
    );
  }

  Widget _defaultAvatar() {
    return Center(
      child: Text(
        intern.fullName.isNotEmpty ? intern.fullName[0].toUpperCase() : 'S',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          intern.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          intern.studentId,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (!compact) ...[
          const SizedBox(height: 2),
          Text(
            intern.department,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        _StatusBadge(status: intern.status),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppUtils.getStatusColor(status);
    final label = AppUtils.getStatusLabel(status);
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
