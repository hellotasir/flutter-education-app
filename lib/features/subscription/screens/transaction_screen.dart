import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_transaction.dart';
import 'package:flutter_education_app/features/subscription/repositories/transaction_repository.dart';
import 'package:flutter_education_app/features/subscription/screens/subscription_screen.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';

const _kGateways = {
  'all': (label: 'All', icon: Icons.all_inclusive),
  'stripe': (label: 'Stripe', icon: Icons.credit_card_outlined),
  'sslcommerz': (label: 'SSLCommerz', icon: Icons.mobile_friendly_outlined),
};

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final TransactionRepository _repo = TransactionRepository();

  late Future<List<SubscriptionTransaction>> _future;

  String _gatewayFilter = 'all';
  String _statusFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _repo.getTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _future = _repo.getTransactions());
  }

  List<SubscriptionTransaction> _applyFilters(
    List<SubscriptionTransaction> all,
  ) {
    return all.where((tx) {
      final matchGateway =
          _gatewayFilter == 'all' || tx.gateway == _gatewayFilter;
      final matchStatus = _statusFilter == 'all' || tx.status == _statusFilter;
      final query = _searchQuery.toLowerCase();
      final matchSearch =
          query.isEmpty ||
          tx.planName.toLowerCase().contains(query) ||
          tx.gateway.toLowerCase().contains(query) ||
          (tx.gatewayRef?.toLowerCase().contains(query) ?? false);
      return matchGateway && matchStatus && matchSearch;
    }).toList();
  }

  ({double totalSpent, int successCount, int failedCount}) _stats(
    List<SubscriptionTransaction> all,
  ) {
    double total = 0;
    int success = 0;
    int failed = 0;
    for (final tx in all) {
      if (tx.isSuccess) {
        total += tx.amount;
        success++;
      } else {
        failed++;
      }
    }
    return (totalSpent: total, successCount: success, failedCount: failed);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            AppNavigator(screen: SubscriptionScreen()).navigate(context);
          },
          icon: Icon(Icons.chevron_left_outlined),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        title: const Text(
          'Payment History',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: FutureBuilder<List<SubscriptionTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingSkeleton();
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: _refresh,
            );
          }

          final all = snapshot.data ?? [];
          final filtered = _applyFilters(all);
          final stats = _stats(all);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (q) => setState(() => _searchQuery = q),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _StatsRow(stats: stats)),
                SliverToBoxAdapter(
                  child: _GatewayFilterRow(
                    selected: _gatewayFilter,
                    onChanged: (v) => setState(() => _gatewayFilter = v),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _StatusFilterRow(
                    selected: _statusFilter,
                    onChanged: (v) => setState(() => _statusFilter = v),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (filtered.isEmpty)
                  const SliverFillRemaining(child: _EmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _TransactionCard(
                        tx: filtered[i],
                        onTap: () => _showDetail(context, filtered[i]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, SubscriptionTransaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _TransactionDetailSheet(tx: tx),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by plan, gateway, ref…',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final ({double totalSpent, int successCount, int failedCount}) stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _StatChip(
            label: 'Total Spent',
            value: '\$${stats.totalSpent.toStringAsFixed(2)}',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Success',
            value: '${stats.successCount}',
            color: Colors.green,
          ),
          const SizedBox(width: 10),
          _StatChip(
            label: 'Failed',
            value: '${stats.failedCount}',
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayFilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _GatewayFilterRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        scrollDirection: Axis.horizontal,
        children: _kGateways.entries.map((e) {
          final isSelected = selected == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    e.value.icon,
                    size: 15,
                    color: isSelected ? Colors.white : cs.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(e.value.label),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(e.key),
              selectedColor: cs.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StatusFilterRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _StatusTab(
            label: 'All',
            value: 'all',
            selected: selected,
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _StatusTab(
            label: '✓  Success',
            value: 'success',
            selected: selected,
            onTap: onChanged,
          ),
          const SizedBox(width: 8),
          _StatusTab(
            label: '✕  Failed',
            value: 'failed',
            selected: selected,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  const _StatusTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final SubscriptionTransaction tx;
  final VoidCallback onTap;
  const _TransactionCard({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final gatewayIcon = _kGateways[tx.gateway]?.icon ?? Icons.payment_outlined;
    final gatewayLabel = _kGateways[tx.gateway]?.label ?? tx.gateway;

    final statusColor = tx.isSuccess ? Colors.green : cs.error;
    final statusIcon = tx.isSuccess
        ? Icons.check_circle_rounded
        : Icons.cancel_rounded;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tx.isSuccess
                  ? Colors.green.withOpacity(0.20)
                  : cs.error.withOpacity(0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(gatewayIcon, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.planName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, size: 13, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          tx.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·  $gatewayLabel',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _fmtDate(tx.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.50),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _TransactionDetailSheet extends StatelessWidget {
  final SubscriptionTransaction tx;
  const _TransactionDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = tx.isSuccess ? Colors.green : cs.error;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withOpacity(0.35)),
                ),
                child: Text(
                  tx.isSuccess ? '✓  Payment Successful' : '✕  Payment Failed',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '\$${tx.amount.toStringAsFixed(2)} ${tx.currency}',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
            ),
            Center(
              child: Text(
                tx.planName,
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.55),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Gateway',
              value: _kGateways[tx.gateway]?.label ?? tx.gateway,
              valueColor: cs.primary,
            ),
            _DetailRow(label: 'Plan', value: tx.planName),
            _DetailRow(label: 'Date', value: _fmtDateTime(tx.createdAt)),
            if (tx.gatewayRef != null)
              _DetailRow(
                label: 'Reference',
                value: tx.gatewayRef!,
                copyable: true,
              ),
            _DetailRow(label: 'Transaction ID', value: tx.id, copyable: true),
            if (tx.errorMessage != null && !tx.isSuccess)
              _DetailRow(
                label: 'Error',
                value: tx.errorMessage!,
                valueColor: cs.error,
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool copyable;
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.50),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? cs.onSurface,
                      ),
                    ),
                  ),
                  if (copyable)
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: cs.onSurface.withOpacity(0.35),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.50),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withOpacity(0.55),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: cs.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }
}
