// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_education_app/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/features/app/views/screens/notification_screen.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/views/screens/home_screen.dart';
import 'package:flutter_education_app/features/auth/views/screens/login_screen.dart';
import 'package:flutter_education_app/features/app/views/screens/error_screen.dart';
import 'package:flutter_education_app/core/widgets/loading_widget.dart';
import 'package:flutter_education_app/core/services/local/in_app_notification_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  String? _lastUserId;

  void _syncBackgroundService(AuthState authState) {
    final userId = authState.session?.user.id;
    if (userId != null && userId != _lastUserId) {
      _lastUserId = userId;
      FlutterBackgroundService().invoke('setUser', {'userId': userId});
    } else if (userId == null && _lastUserId != null) {
      _lastUserId = null;
      FlutterBackgroundService().invoke('clearUser');
    }
  }

  void _handleNotificationTap(String payload) {
    if (payload.startsWith('friend_request::')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotificationScreen(
            currentUserId: ref.read(currentUserProvider)?.id ?? '',
            chatRepository: ChatRepository(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      next.whenData(_syncBackgroundService);
    });

    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(body: Center(child: LoadingIndicator())),
      error: (err, _) => ErrorScreen(
        errorType: ErrorType.server,
        message: err.toString(),
        onRetry: () =>
            AppNavigator(screen: const AuthScreen()).navigate(context),
      ),
      data: (state) {
        if (state.session != null) {
          return InAppNotificationOverlay(
            onTap: _handleNotificationTap,
            child: const HomeScreen(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
