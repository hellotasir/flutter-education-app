import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/home_screen.dart';
import 'package:flutter_education_app/ui/screens/user/auth/login_screen.dart';
import 'package:flutter_education_app/ui/screens/app/error_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/loading_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatelessWidget {
  AuthScreen({super.key});

  final authRepo = AuthRepository();

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
