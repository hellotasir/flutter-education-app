 
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_education_app/core/services/local/notification_listener_service.dart';
import 'package:flutter_education_app/features/auth/views/view_models/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/core/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/views/screens/home_screen.dart';
import 'package:flutter_education_app/features/auth/views/screens/login_screen.dart';
import 'package:flutter_education_app/features/app/views/screens/error_screen.dart';
import 'package:flutter_education_app/core/widgets/loading_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';         // NEW
import 'package:supabase_flutter/supabase_flutter.dart';
 
// Key must match workmanager_dispatcher.dart
const String _userIdKey = 'background_service_user_id';
 
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
 
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}
 
class _AuthScreenState extends ConsumerState<AuthScreen> {
  String? _lastUserId;
 
  void _syncBackgroundService(AuthState authState) async {
    final userId = authState.session?.user.id;
 
    if (userId != null && userId != _lastUserId) {
      _lastUserId = userId;
      FlutterBackgroundService().invoke('setUser', {'userId': userId});
      FirestoreListenerService.instance.startListening(userId);
 
      // ── NEW: persist userId for Workmanager background task ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
 
    } else if (userId == null && _lastUserId != null) {
      _lastUserId = null;
      FlutterBackgroundService().invoke('clearUser');
      FirestoreListenerService.instance.stopListening();
 
      // ── NEW: clear userId on logout ──
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
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
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}