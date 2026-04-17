import 'package:flutter/material.dart';

class BottomPayBar extends StatelessWidget {
  final double price;
  final bool canPay;
  final bool isLoading;
  final VoidCallback onPay;

  const BottomPayBar({
    super.key,
    required this.price,
    required this.canPay,
    required this.isLoading,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12)),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: canPay && !isLoading ? onPay : null,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );
  }
}
