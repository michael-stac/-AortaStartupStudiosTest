import 'dart:math';
import 'package:flutter/material.dart';
import 'package:offlinepayment/presentations/screesn/send_money.dart';
import 'package:offlinepayment/presentations/screesn/transaction_history.dart';
import 'package:provider/provider.dart';
import '../../domain/providers/payment_provider.dart';
import '../../domain/providers/connectivity_provider.dart';
import '../widget/balance_card.dart';
import '../widget/transaction_item.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to detect app state changes
    WidgetsBinding.instance.addObserver(this);

    // Force connectivity check when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivityProvider = context.read<ConnectivityProvider>();
      connectivityProvider.refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This gets called when app lifecycle changes (e.g., coming back from settings)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      print('📱 App resumed - refreshing connectivity');
      final connectivityProvider = context.read<ConnectivityProvider>();
      connectivityProvider.refresh();

      // Also trigger queue processing if we have pending transactions
      final paymentProvider = context.read<PaymentProvider>();
      if (paymentProvider.pendingTransactions.isNotEmpty) {
        print('🔄 App resumed with pending transactions - attempting to process');
        paymentProvider.processQueueManually();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer2 to listen to both providers and rebuild when they change
    return Consumer2<PaymentProvider, ConnectivityProvider>(
      builder: (context, paymentProvider, connectivityProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.primaryColor,
          appBar: _buildAppBar(context, paymentProvider, connectivityProvider),
          body: Column(
            children: [
              // Balance Card
              const Padding(
                padding: EdgeInsets.all(20),
                child: BalanceCard(),
              ),

              // Queue Status Card with Manual Retry
              if (paymentProvider.pendingTransactions.isNotEmpty)
                _buildQueueStatusCard(context, paymentProvider, connectivityProvider),

              const SizedBox(height: 20),

              // Recent Transactions Header
              _buildTransactionsHeader(context, paymentProvider),

              const SizedBox(height: 12),

              // Recent Transactions List
              Expanded(
                child: _buildTransactionsList(paymentProvider),
              ),

              // Error Message
              if (paymentProvider.error != null)
                _buildErrorMessage(paymentProvider),
            ],
          ),
          floatingActionButton: _buildFloatingActionButton(context),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context,
      PaymentProvider paymentProvider,
      ConnectivityProvider connectivityProvider,
      ) {
    return AppBar(
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      title: const Text(
        'Euro Transfer',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: false,
      actions: [
        // Network Status Indicator - Now updates automatically
        _buildNetworkStatusIndicator(connectivityProvider),

        // History Button
        IconButton(
          icon: const Icon(Icons.history, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TransactionHistoryScreen(),
              ),
            );
          },
        ),

        // Manual Sync Button (only show when offline with pending transactions)
        if (!connectivityProvider.isConnected &&
            paymentProvider.pendingTransactions.isNotEmpty)
          _buildManualSyncButton(context, paymentProvider, connectivityProvider),

        // Debug Menu
        _buildDebugMenu(context, paymentProvider, connectivityProvider),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: Colors.grey[800], height: 1.0),
      ),
    );
  }

  Widget _buildNetworkStatusIndicator(ConnectivityProvider connectivityProvider) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: connectivityProvider.isConnected
              ? Colors.green.withOpacity(0.2)
              : Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: connectivityProvider.isConnected
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              connectivityProvider.isConnected ? Icons.wifi : Icons.wifi_off,
              size: 16,
              color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              connectivityProvider.isConnected ? 'Online' : 'Offline',
              style: TextStyle(
                color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualSyncButton(
      BuildContext context,
      PaymentProvider paymentProvider,
      ConnectivityProvider connectivityProvider,
      ) {
    return IconButton(
      icon: const Icon(Icons.sync, color: Colors.orange),
      onPressed: () async {
        // Force connectivity refresh first
        await connectivityProvider.refresh();

        if (!mounted) return;

        if (connectivityProvider.isConnected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Processing queued transactions...'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          try {
            await paymentProvider.processQueueManually();

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Queue processing completed!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Still offline. Please check your connection.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      tooltip: 'Sync pending transactions',
    );
  }

  Widget _buildDebugMenu(
      BuildContext context,
      PaymentProvider paymentProvider,
      ConnectivityProvider connectivityProvider,
      ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'debug_info',
          child: Text('Debug Info'),
        ),
        const PopupMenuItem<String>(
          value: 'force_check',
          child: Text('Force Connectivity Check'),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'debug_info':
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Debug Information'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Connectivity: ${connectivityProvider.connectionStatus}'),
                      Text('Raw Results: ${connectivityProvider.connectivityResults}'),
                      const SizedBox(height: 8),
                      Text('Pending Transactions: ${paymentProvider.pendingTransactions.length}'),
                      Text('All Transactions: ${paymentProvider.transactions.length}'),
                      const SizedBox(height: 8),
                      Text('Effective Balance: €${paymentProvider.effectiveBalance.toStringAsFixed(2)}'),
                      Text('Server Balance: €${paymentProvider.serverBalance.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),
                      if (paymentProvider.pendingTransactions.isNotEmpty) ...[
                        const Text('Pending:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...paymentProvider.pendingTransactions.map((t) =>
                            Text('  • ${t.recipientName}: €${t.amount} (${t.statusText}, retry: ${t.retryCount})')
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
            break;

          case 'force_check':
            await connectivityProvider.refresh();
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connectivity: ${connectivityProvider.connectionStatus}'),
                duration: const Duration(seconds: 2),
              ),
            );
            break;
        }
      },
    );
  }

  Widget _buildTransactionsHeader(BuildContext context, PaymentProvider paymentProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Transactions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (paymentProvider.transactions.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionHistoryScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(PaymentProvider paymentProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: paymentProvider.isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppTheme.accentColor,
        ),
      )
          : paymentProvider.transactions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 60,
              color: Colors.grey[700],
            ),
            const SizedBox(height: 16),
            const Text(
              'No transactions yet',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start by sending money',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : ListView.separated(
        physics: const BouncingScrollPhysics(),
        itemCount: min(5, paymentProvider.transactions.length),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final transaction = paymentProvider.transactions[index];
          return TransactionItem(transaction: transaction);
        },
      ),
    );
  }

  Widget _buildErrorMessage(PaymentProvider paymentProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: Colors.red, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              paymentProvider.error!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 20),
            onPressed: paymentProvider.clearError,
          ),
        ],
      ),
    );
  }

  Widget _buildQueueStatusCard(
      BuildContext context,
      PaymentProvider paymentProvider,
      ConnectivityProvider connectivityProvider,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: connectivityProvider.isConnected
              ? Colors.green.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: connectivityProvider.isConnected
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connectivityProvider.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connectivityProvider.isConnected ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: connectivityProvider.isConnected ? Colors.green : Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        connectivityProvider.isConnected
                            ? 'Auto-sync enabled (checks every 10s)'
                            : '${paymentProvider.pendingTransactions.length} transaction${paymentProvider.pendingTransactions.length > 1 ? 's' : ''} pending',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!connectivityProvider.isConnected)
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Transactions will auto-process when connection is restored (checks every 10s)'),
                          backgroundColor: Colors.blue,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Info',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),

            // Show retry count if any transaction has been retried
            if (paymentProvider.pendingTransactions.any((t) => t.retryCount > 0))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Some transactions have been retried (max 5 retries)',
                  style: TextStyle(
                    color: Colors.orange[300],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Show manual sync option when offline
            if (!connectivityProvider.isConnected &&
                paymentProvider.pendingTransactions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      // Force connectivity check
                      await connectivityProvider.refresh();

                      if (!mounted) return;

                      if (connectivityProvider.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Processing queued transactions...'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );

                        await paymentProvider.processQueueManually();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('No connection available. Please check your network.'),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Try Processing Now'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SendMoneyScreen(),
          ),
        );
      },
      backgroundColor: AppTheme.accentColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      icon: const Icon(Icons.send),
      label: const Text(
        'Send Money',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}