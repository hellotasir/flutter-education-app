import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'local_notification_service.dart';

/// Drop this widget at the root of your navigator (e.g. inside MaterialWidget
/// or wrapping HomeScreen) to get in-app toast banners and notification tap
/// routing — the same way NotificationBadgeIcon handles the badge.
///
/// Usage:
///   InAppNotificationOverlay(
///     onTap: (payload) => _handleTap(context, payload),
///     child: HomeScreen(),
///   )
class InAppNotificationOverlay extends StatefulWidget {
  const InAppNotificationOverlay({
    super.key,
    required this.child,
    this.onTap,
  });

  final Widget child;

  /// Called when the user taps a system notification (foreground or cold-start).
  /// Parse `payload` (e.g. "friend_request::abc") and navigate accordingly.
  final void Function(String payload)? onTap;

  @override
  State<InAppNotificationOverlay> createState() =>
      _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  StreamSubscription<String>? _tapSub;
  StreamSubscription<Map<String, dynamic>?>? _bgSub;

  // In-app toast state
  _ToastData? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();

    // 1. System notification taps → onTap callback
    _tapSub = LocalNotificationService.instance.tapStream.listen((payload) {
      widget.onTap?.call(payload);
    });

    // 2. Background isolate pushes new notifications → show in-app toast
    //    (mirrors NotificationBadgeIcon listening to 'badgeCount')
    _bgSub = FlutterBackgroundService()
        .on('newFriendRequest')
        .listen((data) {
      if (!mounted || data == null) return;
      _showToast(
        title: 'New friend request',
        body: data['senderName'] as String? ?? 'Someone sent you a request',
        payload: data['payload'] as String? ?? '',
      );
    });
  }

  @override
  void dispose() {
    _tapSub?.cancel();
    _bgSub?.cancel();
    _toastTimer?.cancel();
    super.dispose();
  }

  void _showToast({
    required String title,
    required String body,
    required String payload,
  }) {
    _toastTimer?.cancel();
    setState(() => _toast = _ToastData(title: title, body: body, payload: payload));
    _toastTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _dismissToast() {
    _toastTimer?.cancel();
    if (mounted) setState(() => _toast = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_toast != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: _InAppToast(
              data: _toast!,
              onTap: () {
                _dismissToast();
                if (_toast?.payload.isNotEmpty == true) {
                  widget.onTap?.call(_toast!.payload);
                }
              },
              onDismiss: _dismissToast,
            ),
          ),
      ],
    );
  }
}

class _ToastData {
  const _ToastData({
    required this.title,
    required this.body,
    required this.payload,
  });
  final String title;
  final String body;
  final String payload;
}

class _InAppToast extends StatefulWidget {
  const _InAppToast({
    required this.data,
    required this.onTap,
    required this.onDismiss,
  });

  final _ToastData data;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_InAppToast> createState() => _InAppToastState();
}

class _InAppToastState extends State<_InAppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<double>(begin: -1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => FractionalTranslation(
        translation: Offset(0, _slide.value),
        child: Opacity(opacity: _fade.value, child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.dividerColor.withOpacity(0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.data.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.data.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: widget.onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}