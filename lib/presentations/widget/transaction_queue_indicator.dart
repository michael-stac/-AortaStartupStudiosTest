import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/payment_provider.dart';

class TransactionQueueIndicator extends StatelessWidget {
  const TransactionQueueIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final pendingCount = paymentProvider.pendingTransactions.length;

    if (pendingCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange[50],
      child: Row(
        children: [
          const Icon(Icons.pending, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$pendingCount transaction${pendingCount > 1 ? 's' : ''} pending',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          if (pendingCount > 0)
            Chip(
              label: Text('$pendingCount'),
              backgroundColor: Colors.orange[100],
            ),
        ],
      ),
    );
  }
}