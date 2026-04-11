import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.displayName,
    this.photoUrl,
    this.isGroup = false,
    this.isOnline = false,
    this.showPresence = false,
  });

  final String displayName;
  final String? photoUrl;
  final bool isGroup;
  final bool isOnline;
  final bool showPresence;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? isGroup
                    ? Icon(
                        Icons.group_rounded,
                        size: 22,
                        color: colorScheme.onSurface.withValues(alpha: 0.55),
                      )
                    : Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      )
              : null,
        ),
        if (showPresence)
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF4CAF50)
                    : colorScheme.onSurface.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.surface, width: 1.8),
              ),
            ),
          ),
      ],
    );
  }
}
