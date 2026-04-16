// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class PaymentMethodTile extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const PaymentMethodTile({super.key, 
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedValue,
    required this.onChanged,
  });

  bool get _selected => selectedValue == value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _selected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: selectedValue,
        onChanged: onChanged,
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}