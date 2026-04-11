import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/screens/home_screen.dart';
import 'package:flutter_education_app/features/app/screens/login_screen.dart';
import 'package:flutter_education_app/features/app/screens/error_screen.dart';
import 'package:flutter_education_app/features/app/widgets/loading_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthRepository authRepo = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: authRepo.authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: LoadingIndicator()));
        }

        if (snapshot.hasError) {
          return ErrorScreen(
            errorType: ErrorType.server,
            message: snapshot.error?.toString(),
            onRetry: () {
              AppNavigator(screen: AuthScreen()).navigate(context);
            },
          );
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
