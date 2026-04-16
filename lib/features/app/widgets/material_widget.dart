// features/app/widgets/material_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/others/constants/app_details.dart';
import 'package:flutter_education_app/others/theme/app_theme.dart';
import 'package:flutter_education_app/others/providers/app_theme_provider.dart';
import 'package:flutter_education_app/features/app/widgets/network_widget.dart';

class MaterialWidget extends ConsumerWidget {
  final Widget child;
  const MaterialWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

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
