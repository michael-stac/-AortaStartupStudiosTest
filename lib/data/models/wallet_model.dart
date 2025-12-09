import 'package:offlinepayment/data/models/transaction_model.dart';


class Wallet {
  final double serverBalance;
  final double effectiveBalance;
  final List<Transaction> pendingTransactions;

  const Wallet({
    required this.serverBalance,
    required this.effectiveBalance,
    required this.pendingTransactions,
  });

  Wallet copyWith({
    double? serverBalance,
    double? effectiveBalance,
    List<Transaction>? pendingTransactions,
  }) {
    return Wallet(
      serverBalance: serverBalance ?? this.serverBalance,
      effectiveBalance: effectiveBalance ?? this.effectiveBalance,
      pendingTransactions: pendingTransactions ?? this.pendingTransactions,
    );
  }
}