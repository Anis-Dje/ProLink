import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/app_utils.dart';
import '../../models/notification_model.dart';
import '../../services/firestore_service.dart';

/// Full-screen list of the current user's notifications.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationModel>> _future;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NotificationModel>> _load() {
    return context.read<FirestoreService>().getNotifications();
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    await f;
  }

  Future<void> _toggleRead(NotificationModel n) async {
    final svc = context.read<FirestoreService>();
    try {
      await svc.markNotificationRead(n.id, isRead: !n.isRead);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not update: $e', isError: true);
    }
  }

  Future<void> _markAll() async {
    final svc = context.read<FirestoreService>();
    setState(() => _markingAll = true);
    try {
      await svc.markAllNotificationsRead();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Could not update: $e', isError: true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _markingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markingAll ? null : _markAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<NotificationModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                const SizedBox(height: 60),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load notifications.\n${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ]);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.notifications_off_outlined,
                    size: 56, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _NotificationTile(
                notification: items[i],
                onToggleRead: () => _toggleRead(items[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onToggleRead});

  final NotificationModel notification;
  final VoidCallback onToggleRead;

  IconData get _icon {
    switch (notification.type) {
      case 'intern_pending':
        return Icons.person_add_alt_1_outlined;
      case 'approval':
        return Icons.verified_user_outlined;
      case 'assignment':
        return Icons.group_add_outlined;
      case 'schedule':
        return Icons.calendar_today_outlined;
      case 'training':
        return Icons.menu_book_outlined;
      case 'evaluation':
        return Icons.assessment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            unread ? AppColors.accent : AppColors.surface,
        child: Icon(_icon,
            color: unread ? Colors.white : AppColors.textSecondary),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(notification.body),
          const SizedBox(height: 4),
          Text(
            _formatRelative(notification.createdAt),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        tooltip: unread ? 'Mark as read' : 'Mark as unread',
        icon: Icon(unread ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined),
        onPressed: onToggleRead,
      ),
      onTap: unread ? onToggleRead : null,
    );
  }

  String _formatRelative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppUtils.formatDate(when);
  }
}
