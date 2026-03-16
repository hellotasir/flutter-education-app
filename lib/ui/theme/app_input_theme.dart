import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppInputTheme {
  static InputDecorationTheme lightInputTheme = InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.black),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.black, width: 2),
    ),
  );

  static InputDecorationTheme darkInputTheme = InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.white),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppColors.white, width: 2),
    ),
  );
}
