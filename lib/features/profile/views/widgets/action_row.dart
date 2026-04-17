import 'package:flutter/material.dart';

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.isOwnProfile,
    required this.onEdit,
  });
  final bool isOwnProfile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: isOwnProfile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: cs.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: cs.onSurface,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
