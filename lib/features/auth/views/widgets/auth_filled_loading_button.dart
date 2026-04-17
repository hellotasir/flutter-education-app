import 'package:flutter/material.dart';

class AuthFilledLoadingButton extends StatelessWidget {
  const AuthFilledLoadingButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    this.style,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  final IconData? icon;
  final ButtonStyle? style;

  static const _kSpinner = SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );

  @override
  Widget build(BuildContext context) {
    final showIcon = icon != null || isLoading;
    return SizedBox(
      width: double.infinity,
      child: showIcon
          ? FilledButton.icon(
              onPressed: isLoading ? null : onPressed,
              style: style,
              icon: isLoading ? _kSpinner : Icon(icon),
              label: Text(isLoading ? loadingLabel : label),
            )
          : FilledButton(
              onPressed: isLoading ? null : onPressed,
              style: style,
              child: Text(label),
            ),
    );
  }
}
