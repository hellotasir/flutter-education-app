import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';
import 'app_button_theme.dart';
import 'app_input_theme.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    textTheme: AppTextTheme.lightTextTheme,
    elevatedButtonTheme: AppButtonTheme.lightElevatedButton,
    inputDecorationTheme: AppInputTheme.lightInputTheme,
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: false,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    textTheme: AppTextTheme.darkTextTheme,
    elevatedButtonTheme: AppButtonTheme.darkElevatedButton,
    inputDecorationTheme: AppInputTheme.darkInputTheme,
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
    ),
  );
}
