import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextTheme {
  static const TextTheme lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.lightText,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.lightText,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.lightText,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.lightText),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.lightText),
  );

  static const TextTheme darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.darkText,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.darkText,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.darkText,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.darkText),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.darkText),
  );
}
