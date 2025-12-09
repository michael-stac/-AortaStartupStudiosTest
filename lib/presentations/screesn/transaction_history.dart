import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/payment_provider.dart';
import '../widget/transaction_item.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: SafeArea(
        child: paymentProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : paymentProvider.transactions.isEmpty
            ? const Center(
          child: Text('No transactions yet'),
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: paymentProvider.transactions.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final transaction = paymentProvider.transactions[index];
            return TransactionItem(transaction: transaction);
          },
        ),
      ),
    );
  }
}