import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../screens/notifications/notifications_screen.dart';

/// AppBar action that shows a bell with an unread-count badge and opens
/// the [NotificationsScreen] when tapped. Polls every 30 seconds in the
/// background so the badge stays roughly in sync with the server.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key, this.iconColor});

  /// Override the default icon color (used on dashboards with custom
  /// AppBar tints).
  final Color? iconColor;

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  Timer? _poll;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<List<NotificationModel>> _refresh() async {
    final svc = context.read<FirestoreService>();
    try {
      final list = await svc.getNotifications();
      final unread = list.where((n) => !n.isRead).length;
      if (mounted && unread != _unread) {
        setState(() => _unread = unread);
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? AppColors.textPrimary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          onPressed: _open,
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
