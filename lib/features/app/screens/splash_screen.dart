// ignore_for_file: unrelated_type_equality_checks

import 'package:flutter/material.dart';
import 'package:flutter_education_app/others/constants/messages.dart';
import 'package:flutter_education_app/features/app/screens/auth_screen.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/widgets/snackbar_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      AppNavigator(screen: AuthScreen()).navigate(context);
    } catch (e) {
      SnackbarWidget(message: errorMessage).showSnackbar(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness != Brightness.dark;
    return Scaffold(
      body: Center(
        child: Image.asset(
          isDark
              ? 'assets/edumap-transparent-icon.png'
              : 'assets/edumap-black-transparent-icon.png',
          height: 200,
        ),
      ),
    );
  }
}
