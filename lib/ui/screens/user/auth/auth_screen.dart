import 'package:flutter/material.dart';
import 'package:flutter_education_app/model/repositories/auth_repository.dart';
import 'package:flutter_education_app/ui/screens/home_screen.dart';
import 'package:flutter_education_app/ui/screens/user/auth/login_screen.dart';
import 'package:flutter_education_app/ui/screens/user/error_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthRepository().authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return ErrorScreen(
            errorType: ErrorType.server,
            message: snapshot.error?.toString(),
            onRetry: () {},
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
