import 'package:flutter/material.dart';

class SummaryBanner extends StatelessWidget {
  final ({double totalSpent, int successCount, int failedCount}) stats;
  const SummaryBanner({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Spent',
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${stats.totalSpent.toStringAsFixed(2)}',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            flex: 3,
            child: _MiniStat(
              label: 'Success',
              value: '${stats.successCount}',
              valueColor: Colors.green.shade600,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
          Expanded(
            flex: 3,
            child: _MiniStat(
              label: 'Failed',
              value: '${stats.failedCount}',
              valueColor: cs.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}
