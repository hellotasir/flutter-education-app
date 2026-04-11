import 'package:flutter/material.dart';

class SnackbarWidget {
  final String message;

  SnackbarWidget({required this.message});

  void showSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
