import 'package:flutter/material.dart';
import 'package:flutter_education_app/ui/theme/app_theme.dart';

class MaterialWidget extends StatelessWidget {
  final String title;
  final Widget child;
  const MaterialWidget({required this.child, required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      home: child,
    );
  }
}
