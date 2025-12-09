import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/expection.dart';
import '../../core/utils/connectivity_helper.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../service/local_storage.dart';
import '../service/mock_api_service.dart';

class PaymentRepository {
  final MockApiService _apiService;
  final LocalStorageService _storageService;
  final Connectivity _connectivity;

  /// State
  double _serverBalance = 500.0;
  final List<Transaction> _allTransactions = [];
  final List<Transaction> _pendingQueue = [];

  /// Streams for reactive UI
  final _walletController = StreamController<Wallet>.broadcast();
  final _transactionsController =
      StreamController<List<Transaction>>.broadcast();

  bool _isProcessingQueue = false;
  StreamSubscription? _connectivitySubscription;
  Timer? _queueCheckerTimer;
  bool _isInitialized = false;

  PaymentRepository({
    MockApiService? apiService,
    LocalStorageService? storageService,
    Connectivity? connectivity,
  }) : _apiService = apiService ?? MockApiService(),
       _storageService = storageService ?? LocalStorageService(),
       _connectivity = connectivity ?? Connectivity() {
    _initialize();
  }

  /// Initialize: Load persisted data and start connectivity listener
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing PaymentRepository...');

      /// Load cached balance
      final cachedBalance = await _storageService.loadBalance();
      if (cachedBalance != null) {
        _serverBalance = cachedBalance;
        debugPrint('Loaded cached balance: €$_serverBalance');
      }

      /// Load all transactions
      final allTransactions = await _storageService.loadAllTransactions();
      _allTransactions.addAll(allTransactions);
      debugPrint('Loaded ${allTransactions.length} transactions');

      /// Load pending transactions
      final pendingTransactions = await _storageService
          .loadPendingTransactions();
      _pendingQueue.addAll(pendingTransactions);
      debugPrint('Loaded ${pendingTransactions.length} pending transactions');

      /// Try to fetch latest balance from server
      try {
        _serverBalance = await _apiService.getBalance();
        await _storageService.saveBalance(_serverBalance);
        debugPrint('Updated server balance: €$_serverBalance');
      } catch (e) {
        debugPrint('Could not fetch balance from server: $e');
      }

      /// Start connectivity listener with error handling
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
          /// Try to restart the listener
          _restartConnectivityListener();
        },
        cancelOnError: false,
      );

      /// Start periodic queue checker
      _startQueueChecker();

      /// Emit initial state
      _emitWalletState();
      _emitTransactionsState();

      /// Process queue if online
      await _processQueueWithRetry();

      _isInitialized = true;
      debugPrint('PaymentRepository initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing PaymentRepository: $e');
    }
  }

  void _restartConnectivityListener() async {
    debugPrint('Restarting connectivity listener...');
    await _connectivitySubscription?.cancel();

    await Future.delayed(const Duration(seconds: 2));

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        debugPrint('Connectivity stream error (retry): $error');
        _restartConnectivityListener();
      },
    );
  }

  void _startQueueChecker() {
    _queueCheckerTimer?.cancel();

    _queueCheckerTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isProcessingQueue || _pendingQueue.isEmpty) return;

      try {
        debugPrint('Periodic queue check...');
        debugPrint('Pending transactions: ${_pendingQueue.length}');

        /// Strategy: Try actual internet test first, then fallback to connectivity
        bool shouldProcess = false;

        /// Test 1: Actual internet connection (most reliable)
        debugPrint('Testing actual internet connection...');
        final hasInternet = await _testActualNetworkConnection();

        if (hasInternet) {
          debugPrint('Internet test passed - will process queue');
          shouldProcess = true;
        } else {
          debugPrint('Internet test failed, checking connectivity package...');

          /// Test 2: Connectivity package as fallback
          final connectivity = await _checkConnectivityWithRetry();
          debugPrint('Connectivity results: $connectivity');

          final isConnected = ConnectivityHelper.isConnected(connectivity);
          debugPrint('Connectivity helper says: $isConnected');

          if (isConnected) {
            debugPrint('Connectivity package says connected - will process queue');
            shouldProcess = true;
          }
        }

        if (shouldProcess) {
          debugPrint('Initiating queue processing...');
          await _processQueue();
        } else {
          debugPrint('No network detected - queue processing skipped');
        }
      } catch (e) {
        debugPrint('Error in periodic queue check: $e');
      }
    });

    debugPrint('Started periodic queue checker (every 10 seconds)');
  }

  Future<List<ConnectivityResult>> _checkConnectivityWithRetry() async {
    List<ConnectivityResult> results = [ConnectivityResult.none];

    /// Try checking connectivity up to 3 times
    for (int i = 0; i < 3; i++) {
      try {
        results = await _connectivity.checkConnectivity();
        debugPrint('Connectivity check attempt ${i + 1}: $results');

        /// If we get a non-none result, return immediately
        if (results.isNotEmpty &&
            results.any((r) => r != ConnectivityResult.none)) {
          debugPrint('Got valid connectivity result on attempt ${i + 1}');
          return results;
        }

        if (i < 2) {
          debugPrint('Waiting 1 second before retry...');
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        debugPrint('Connectivity check error on attempt ${i + 1}: $e');
        if (i < 2) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    return results;
  }

  /// Get current wallet state
  Wallet getCurrentWallet() {
    return Wallet(
      serverBalance: _serverBalance,
      effectiveBalance: _effectiveBalance,
      pendingTransactions: List.unmodifiable(_pendingQueue),
    );
  }

  /// Get all transactions
  List<Transaction> getAllTransactions() {
    return List.unmodifiable(_allTransactions);
  }

  /// Connectivity change handler
  void _onConnectivityChanged(List<ConnectivityResult> results) async {
    debugPrint('Connectivity changed: $results');

    bool shouldProcess = false;

    /// First check actual internet
    final hasInternet = await _testActualNetworkConnection();

    if (hasInternet) {
      debugPrint('Internet detected via connection test');
      shouldProcess = true;
    } else {
      /// Fallback to connectivity package
      final isConnected = ConnectivityHelper.isConnected(results);
      if (isConnected) {
        debugPrint('Internet detected via connectivity package');
        shouldProcess = true;
      }
    }

    if (shouldProcess) {
      debugPrint('Connection available - processing queue in 2 seconds...');
      await Future.delayed(const Duration(seconds: 2));
      await _processQueue();
    } else {
      debugPrint('Connection lost');
    }
  }

  /// Get wallet stream
  Stream<Wallet> get walletStream => _walletController.stream;

  /// Get transactions stream
  Stream<List<Transaction>> get transactionsStream =>
      _transactionsController.stream;

  /// Calculate effective balance
  double get _effectiveBalance {
    final pendingAmount = _pendingQueue
        .where(
          (t) =>
              t.status == TransactionStatus.pending ||
              t.status == TransactionStatus.processing,
        )
        .fold(0.0, (sum, t) => sum + t.amount);

    return _serverBalance - pendingAmount;
  }

  /// Emit wallet state
  void _emitWalletState() {
    _walletController.add(
      Wallet(
        serverBalance: _serverBalance,
        effectiveBalance: _effectiveBalance,
        pendingTransactions: List.unmodifiable(_pendingQueue),
      ),
    );
  }

  /// Emit transactions state
  void _emitTransactionsState() {
    final sorted = List<Transaction>.from(_allTransactions)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _transactionsController.add(sorted);

    // Persist all transactions
    _storageService.saveAllTransactions(_allTransactions);
  }

  /// Send Money
  Future<Transaction> sendMoney({
    required double amount,
    required String recipientId,
    required String recipientName,
  }) async {
    /// ANTI-FRAUD GUARD: Check effective balance FIRST
    if (amount > _effectiveBalance) {
      throw InsufficientFundsException(
        'Insufficient balance. Available: €${_effectiveBalance.toStringAsFixed(2)}',
      );
    }

    /// Generate idempotency key
    final transactionId = const Uuid().v4();

    /// Create transaction
    final transaction = Transaction(
      id: transactionId,
      amount: amount,
      recipientId: recipientId,
      recipientName: recipientName,
      status: TransactionStatus.pending,
      createdAt: DateTime.now(),
    );

    /// Add to queue and all transactions
    _pendingQueue.add(transaction);
    _allTransactions.add(transaction);

    /// Persist to storage
    await _storageService.savePendingTransactions(_pendingQueue);
    await _storageService.saveAllTransactions(_allTransactions);

    /// Emit updated state (UI updates immediately)
    _emitWalletState();
    _emitTransactionsState();

    /// Try to process immediately if online
    await _processQueueWithRetry();

    return transaction;
  }

  /// QUEUE PROCESSOR (FIFO with Retry Logic) - Private implementation
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _pendingQueue.isEmpty) return;

    _isProcessingQueue = true;
    debugPrint('Processing queue (${_pendingQueue.length} pending)...');

    try {
      /// Check connectivity with retry
      final connectivity = await _checkConnectivityWithRetry();
      if (!ConnectivityHelper.isConnected(connectivity)) {
        debugPrint('No connection after retries - queue processing paused');
        return;
      }

      /// Process FIFO: Take first transaction only
      final transaction = _pendingQueue.first;
      debugPrint(
        'Processing transaction: ${transaction.id} (€${transaction.amount})',
      );

      /// Skip if already processing or completed
      if (transaction.status == TransactionStatus.processing ||
          transaction.status == TransactionStatus.completed) {
        debugPrint('Transaction already processing/completed, skipping');
        return;
      }

      /// Check max retries
      if (transaction.retryCount >= 5) {
        debugPrint(' Max retries exceeded for transaction: ${transaction.id}');
        await _markTransactionAsFailed(transaction, 'Max retries exceeded');
        return;
      }

      /// Update status to processing
      await _updateTransaction(
        transaction,
        status: TransactionStatus.processing,
        retryCount: transaction.retryCount + 1,
      );

      /// Calculate exponential backoff delay
      final backoffMs = pow(2, transaction.retryCount) * 1000;
      await Future.delayed(Duration(milliseconds: backoffMs.toInt()));

      /// Attempt to send transaction
      try {
        debugPrint(' Sending transaction to server...');
        await _apiService.sendTransaction(
          idempotencyKey: transaction.id,
          amount: transaction.amount,
          recipientId: transaction.recipientId,
        );

        /// SUCCESS: Deduct from server balance and mark completed
        _serverBalance -= transaction.amount;
        await _storageService.saveBalance(_serverBalance);

        await _updateTransaction(
          transaction,
          status: TransactionStatus.completed,
        );

        /// Remove from pending queue
        _pendingQueue.removeWhere((t) => t.id == transaction.id);
        await _storageService.savePendingTransactions(_pendingQueue);

        debugPrint('Transaction ${transaction.id} completed successfully');

        /// Process next in queue
        await Future.delayed(const Duration(milliseconds: 500));
        _isProcessingQueue = false;
        await _processQueue(); // Recursive call for next transaction
      } on NoConnectionException catch (e) {
        /// Network dropped - revert to pending and wait
        await _updateTransaction(
          transaction,
          status: TransactionStatus.pending,
        );
        debugPrint('Connection lost during processing: ${e.message}');
      } on ServerException catch (e) {
        if (e.isRetryable) {
          /// Retryable error - revert to pending and retry
          await _updateTransaction(
            transaction,
            status: TransactionStatus.pending,
          );
          debugPrint('Server error (will retry): ${e.message}');

          /// Retry after delay
          await Future.delayed(const Duration(seconds: 2));
          _isProcessingQueue = false;
          await _processQueue();
        } else {
          /// Non-retryable - fail permanently
          await _markTransactionAsFailed(transaction, e.message);
        }
      } on InsufficientFundsException catch (e) {
        /// ROLLBACK: Server says insufficient funds
        await _markTransactionAsFailed(transaction, e.message);
      } on BankDeclineException catch (e) {
        /// ROLLBACK: Bank declined
        await _markTransactionAsFailed(transaction, e.message);
      } catch (e) {
        /// Unknown error - fail
        await _markTransactionAsFailed(transaction, e.toString());
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Update transaction status
  Future<void> _updateTransaction(
    Transaction transaction, {
    TransactionStatus? status,
    int? retryCount,
  }) async {
    final updated = transaction.copyWith(
      status: status,
      retryCount: retryCount,
      updatedAt: DateTime.now(),
    );

    /// Update in all transactions list
    final index = _allTransactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _allTransactions[index] = updated;
    }

    /// Update in pending queue
    final queueIndex = _pendingQueue.indexWhere((t) => t.id == transaction.id);
    if (queueIndex != -1) {
      _pendingQueue[queueIndex] = updated;
      await _storageService.savePendingTransactions(_pendingQueue);
    }

    _emitWalletState();
    _emitTransactionsState();
  }

  /// Mark transaction as permanently failed (rollback)
  Future<void> _markTransactionAsFailed(
    Transaction transaction,
    String errorMessage,
  ) async {
    debugPrint('Transaction ${transaction.id} failed: $errorMessage');

    final failed = transaction.copyWith(
      status: TransactionStatus.failed,
      errorMessage: errorMessage,
      updatedAt: DateTime.now(),
    );

    /// Update in all transactions
    final index = _allTransactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      _allTransactions[index] = failed;
    }

    // Remove from pending queue (balance automatically restored via effectiveBalance)
    _pendingQueue.removeWhere((t) => t.id == transaction.id);
    await _storageService.savePendingTransactions(_pendingQueue);

    _emitWalletState();
    _emitTransactionsState();
  }

  /// Manual retry for failed transaction
  Future<void> retryTransaction(String transactionId) async {
    final transaction = _allTransactions.firstWhere(
      (t) => t.id == transactionId,
    );

    if (transaction.status != TransactionStatus.failed) {
      throw Exception('Only failed transactions can be retried');
    }

    // Remove old transaction
    _allTransactions.removeWhere((t) => t.id == transactionId);

    // Create new transaction with same details
    await sendMoney(
      amount: transaction.amount,
      recipientId: transaction.recipientId,
      recipientName: transaction.recipientName,
    );
  }

  /// Public method to manually trigger queue processing
  Future<void> processQueueManually() async {
    debugPrint('Manual queue processing triggered');
    await _processQueueWithRetry();
  }

  /// Public wrapper for queue processing with better connectivity checks
  Future<void> processQueue() async {
    await _processQueueWithRetry();
  }

  /// Enhanced queue processing with connectivity retry
  Future<void> _processQueueWithRetry() async {
    if (_isProcessingQueue || _pendingQueue.isEmpty) return;

    try {
      debugPrint('Starting queue processing with retry logic...');

      bool shouldProcess = false;

      // Test 1: Actual internet connection
      debugPrint('Testing actual internet connection...');
      final hasInternet = await _testActualNetworkConnection();

      if (hasInternet) {
        debugPrint('Internet test passed');
        shouldProcess = true;
      } else {
        debugPrint('Internet test failed, checking connectivity package...');

        // Test 2: Connectivity package as fallback
        final connectivity = await _checkConnectivityWithRetry();

        if (ConnectivityHelper.isConnected(connectivity)) {
          debugPrint('Connectivity package says connected');
          shouldProcess = true;
        }
      }

      if (!shouldProcess) {
        debugPrint('No network available - skipping queue processing');
        return;
      }

      debugPrint('Network available - processing queue');
      await _processQueue();
    } catch (e) {
      debugPrint('Error in enhanced queue processing: $e');
    }
  }

  /// Test actual internet connection (not just network interface)
  Future<bool> _testActualNetworkConnection() async {
    // List of hosts to try (in order of reliability)
    final testHosts = [
      'https://www.google.com',
      'https://www.cloudflare.com',
      'https://1.1.1.1', // Cloudflare DNS (IP-based, no DNS needed)
      'https://8.8.8.8', // Google DNS (IP-based, no DNS needed)
    ];

    for (final host in testHosts) {
      try {
        debugPrint('Testing connection to: $host');
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);

        final uri = Uri.parse(host);
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 5),
        );

        await response.drain(); // Consume response
        client.close();

        if (response.statusCode >= 200 && response.statusCode < 500) {
          debugPrint(
            'Internet connection verified via $host (status: ${response.statusCode})',
          );
          return true;
        }
      } catch (e) {
        debugPrint('Connection test failed for $host: $e');
        // Continue to next host
      }
    }

    debugPrint('All internet connection tests failed');
    return false;
  }

  /// Dispose resources
  Future<void> dispose() async {
    debugPrint('Disposing PaymentRepository...');
    _queueCheckerTimer?.cancel();
    await _connectivitySubscription?.cancel();
    await _walletController.close();
    await _transactionsController.close();
    _isInitialized = false;
    debugPrint('PaymentRepository disposed');
  }
}
