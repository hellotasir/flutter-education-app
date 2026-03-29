import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/constants/app_details.dart';
import 'package:flutter_education_app/ui/theme/app_theme.dart';
import 'package:flutter_education_app/logic/providers/app_theme_provider.dart';
import 'package:flutter_education_app/ui/widgets/app/network_widget.dart';
import 'package:provider/provider.dart';

class MaterialWidget extends StatelessWidget {
  final Widget child;
  const MaterialWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeProvider>().themeMode;

    return MaterialApp(
      title: appName,
      darkTheme: AppTheme.darkTheme,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      home: NetworkWidget(child: child),
    );
  }
}
