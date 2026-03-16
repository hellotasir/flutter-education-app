import 'package:flutter/material.dart';
import 'package:flutter_education_app/model/constants/app_details.dart';
import 'package:flutter_education_app/ui/theme/app_theme.dart';

class MaterialWidget extends StatelessWidget {
  final Widget child;
  const MaterialWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.system,
      home: child,
    );
  }
}
