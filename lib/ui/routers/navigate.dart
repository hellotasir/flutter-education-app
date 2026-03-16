import 'package:flutter/material.dart';

class Navigate {
  final Widget screen;
  final BuildContext context;

  Navigate({required this.screen, required this.context});

  navigate() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }
}
