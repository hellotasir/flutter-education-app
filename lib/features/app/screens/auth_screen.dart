// lib/features/app/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/app/screens/notification_screen.dart';
import 'package:flutter_education_app/features/chat/repositories/chat_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/screens/home_screen.dart';
import 'package:flutter_education_app/features/app/screens/login_screen.dart';
import 'package:flutter_education_app/features/app/screens/error_screen.dart';
import 'package:flutter_education_app/features/app/widgets/loading_widget.dart';
import 'package:flutter_education_app/others/services/in_app_notification_overlay.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthRepository _authRepo = AuthRepository();
  String? _lastUserId; // track to avoid redundant service calls

  void _onAuthChanged(AuthState? authState) {
    final session = authState?.session;
    final userId = session?.user.id;

    if (userId != null && userId != _lastUserId) {
      // User logged in — tell background isolate who to watch
      _lastUserId = userId;
      FlutterBackgroundService().invoke('setUser', {'userId': userId});
    } else if (userId == null && _lastUserId != null) {
      // User logged out — tell background isolate to stop watching
      _lastUserId = null;
      FlutterBackgroundService().invoke('clearUser');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authRepo.authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError) {
          return ErrorScreen(
            errorType: ErrorType.server,
            message: snapshot.error?.toString(),
            onRetry: () =>
                AppNavigator(screen: const AuthScreen()).navigate(context),
          );
        }

        // Side-effect: sync background service whenever auth changes
        _onAuthChanged(snapshot.data);

        final session = snapshot.data?.session;
        return session != null
            ? InAppNotificationOverlay(
                onTap: (payload) {
                  if (payload.startsWith('friend_request::')) {
                    // Navigate to NotificationScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificationScreen(
                          currentUserId: AuthRepository().currentUser?.id ?? '',
                          chatRepository: ChatRepository(),
                        ),
                      ),
                    );
                  }
                },
                child: HomeScreen(),
              )
            : LoginScreen();
      },
    );
  }
}
