import 'package:flutter/material.dart';

class PaddingWidget extends StatelessWidget {
  final Widget child;
  const PaddingWidget({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsetsGeometry.all(30), child: child);
  }
}
