import 'package:flutter/material.dart';
import '../../core/errors/expection.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/wallet_model.dart';
import '../../data/repository/payment_reposiotry.dart' show PaymentRepository;

class PaymentProvider extends ChangeNotifier {
  final PaymentRepository repository;

  // State
  bool _isLoading = false;
  String? _error;
  List<Transaction> _transactions = [];
  Wallet? _wallet;

  PaymentProvider({required this.repository});

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Transaction> get transactions => _transactions;
  Wallet? get wallet => _wallet;
  double get effectiveBalance => _wallet?.effectiveBalance ?? 0;
  double get serverBalance => _wallet?.serverBalance ?? 0;
  List<Transaction> get pendingTransactions => _wallet?.pendingTransactions ?? [];
  Wallet? getCurrentWallet() {
    return _wallet;
  }

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Initialize with current state from repository
      _wallet = repository.getCurrentWallet();
      _transactions = repository.getAllTransactions();

      // Listen to repository streams for updates
      repository.walletStream.listen((wallet) {
        _wallet = wallet;
        notifyListeners();
      });

      repository.transactionsStream.listen((transactions) {
        _transactions = transactions;
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<Transaction> sendMoney({
    required double amount,
    required String recipientId,
    required String recipientName,
  }) async {
    try {
      _error = null;
      _isLoading = true;
      notifyListeners();

      final transaction = await repository.sendMoney(
        amount: amount,
        recipientId: recipientId,
        recipientName: recipientName,
      );

      _isLoading = false;
      notifyListeners();

      return transaction;
    } on InsufficientFundsException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> retryTransaction(String transactionId) async {
    try {
      _error = null;
      await repository.retryTransaction(transactionId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  Future<void> processQueueManually() async {
    try {
      _error = null;
      await repository.processQueueManually();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    repository.dispose();
    super.dispose();
  }
}