import 'package:flutter/material.dart';

class AppNavigator {
  final Widget screen;

  AppNavigator({required this.screen});

  void navigate(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
