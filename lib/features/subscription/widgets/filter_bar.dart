import 'package:flutter/material.dart';

const _kStatuses = {
  'all': 'All Statuses',
  'success': 'Success',
  'failed': 'Failed',
};

const _kGateways = {
  'all': (label: 'All Gateways', icon: Icons.all_inclusive_rounded),
  'stripe': (label: 'Stripe', icon: Icons.credit_card_outlined),
  'sslcommerz': (label: 'SSLCommerz', icon: Icons.mobile_friendly_outlined),
};

class FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String gatewayFilter;
  final ValueChanged<String> onGatewayChanged;
  final String statusFilter;
  final ValueChanged<String> onStatusChanged;

  const FilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.gatewayFilter,
    required this.onGatewayChanged,
    required this.statusFilter,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by plan, gateway or ref…',
              hintStyle: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StyledDropdown<String>(
                  value: gatewayFilter,
                  items: _kGateways.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(
                                e.value.icon,
                                size: 16,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                e.value.label,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onGatewayChanged(v ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StyledDropdown<String>(
                  value: statusFilter,
                  items: _kStatuses.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(
                            e.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => onStatusChanged(v ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
