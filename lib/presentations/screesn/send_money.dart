import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers/payment_provider.dart';
import '../../domain/providers/connectivity_provider.dart';
import '../widget/send_money_form.dart';

class SendMoneyScreen extends StatelessWidget {
  const SendMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final connectivityProvider = Provider.of<ConnectivityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Money'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: connectivityProvider.isConnected ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      connectivityProvider.isConnected ? Icons.wifi : Icons.wifi_off,
                      color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connectivityProvider.isConnected
                          ? 'Online - Transactions will process immediately'
                          : 'Offline - Transactions will queue until connection\nis restored',
                      style: TextStyle(
                       fontSize: 12,
                        color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Available Balance
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        'Available Balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€${paymentProvider.effectiveBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Server Balance: €${paymentProvider.serverBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Send Money Form
              const SendMoneyForm(),

              const SizedBox(height: 32),

              // Pending Transactions
              if (paymentProvider.pendingTransactions.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Transactions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...paymentProvider.pendingTransactions.map((transaction) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: transaction.statusColor,
                          child: Icon(
                            _getStatusIcon(transaction.status),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        title: Text(transaction.recipientName),
                        subtitle: Text(
                          '€${transaction.amount.toStringAsFixed(2)} - ${transaction.statusText}',
                        ),
                        trailing: transaction.retryCount > 0
                            ? Chip(
                          label: Text('Retry ${transaction.retryCount}'),
                          backgroundColor: Colors.orange[100],
                        )
                            : null,
                      );
                    }).toList(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Icons.pending;
      case TransactionStatus.processing:
        return Icons.sync;
      case TransactionStatus.completed:
        return Icons.check_circle;
      case TransactionStatus.failed:
        return Icons.error;
    }
  }
}