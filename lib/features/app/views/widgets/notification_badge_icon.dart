// lib/features/notifications/notification_badge_icon.dart

import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_education_app/features/chat/models/friend_request_model.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';

class NotificationBadgeIcon extends StatefulWidget {
  const NotificationBadgeIcon({
    super.key,
    required this.userId,
    required this.chatRepository,
    this.icon = Icons.notifications_outlined,
  });

  final String userId;
  final ChatRepository chatRepository;
  final IconData icon;

  @override
  State<NotificationBadgeIcon> createState() => _NotificationBadgeIconState();
}

class _NotificationBadgeIconState extends State<NotificationBadgeIcon> {
  int _bgCount = 0; // count pushed from background isolate

  @override
  void initState() {
    super.initState();
    // Listen for badge updates coming from the background service
    FlutterBackgroundService().on('badgeCount').listen((data) {
      if (!mounted) return;
      setState(() => _bgCount = (data?['count'] as int?) ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendRequestModel>>(
      stream: widget.chatRepository.watchIncomingRequests(widget.userId),
      builder: (context, snap) {
        // Prefer live stream count; fall back to bg isolate count
        final count = snap.hasData ? snap.data!.length : _bgCount;

        // Sync app icon badge with reality
        AppBadgePlus.updateBadge(count);

        if (count == 0) return Icon(widget.icon);

        return Badge.count(count: count, child: Icon(widget.icon));
      },
    );
  }
}
