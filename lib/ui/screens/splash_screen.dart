import 'package:flutter/material.dart';
import 'package:flutter_education_app/model/constants/app_details.dart';
import 'package:flutter_education_app/ui/screens/user/auth/auth_screen.dart';
import 'package:flutter_education_app/routers/app_navigator.dart';

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

    AppNavigator(screen: const AuthScreen()).navigate(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          appName,
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width * 0.20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
