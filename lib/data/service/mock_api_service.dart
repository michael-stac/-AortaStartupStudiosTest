import 'dart:async';
import 'dart:math';
import '../../core/errors/expection.dart';
import '../models/api_response.dart';

class MockApiService {
  static const double _initialBalance = 500.0;
  double _serverBalance = _initialBalance;

  /// Simulate random failures
  final Random _random = Random();

  /// Track processed idempotency keys
  final Set<String> _processedKeys = {};

  Future<double> getBalance() async {
    /// Simulate network delay (0.5-2 seconds)
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(1500)));

    /// Simulate 10% chance of server error
    if (_random.nextDouble() < 0.1) {
      throw ServerException('Server temporarily unavailable');
    }

    return _serverBalance;
  }

  Future<ApiResponse<void>> sendTransaction({
    required String idempotencyKey,
    required double amount,
    required String recipientId,
  }) async {
    /// Simulate network delay (1-3 seconds)
    await Future.delayed(Duration(milliseconds: 1000 + _random.nextInt(2000)));

    /// Check if already processed (idempotency)
    if (_processedKeys.contains(idempotencyKey)) {
      return  ApiResponse.success(null);
    }

    /// Simulate 15% chance of no connection
    if (_random.nextDouble() < 0.15) {
      throw NoConnectionException('Network connection lost');
    }

    /// Simulate 10% chance of server error (retryable)
    if (_random.nextDouble() < 0.1) {
      throw ServerException('Internal server error');
    }

    /// Simulate 5% chance of bank decline (non-retryable)
    if (_random.nextDouble() < 0.05) {
      throw BankDeclineException('Transaction declined by bank');
    }

    /// Check if sufficient funds on server
    if (amount > _serverBalance) {
      throw InsufficientFundsException('Insufficient funds on server');
    }

    /// Simulate 3% chance of generic failure
    if (_random.nextDouble() < 0.03) {
      throw TransactionFailedException('Transaction failed unexpectedly');
    }

    /// Successful transaction
    _serverBalance -= amount;
    _processedKeys.add(idempotencyKey);

    return  ApiResponse.success(null);
  }

  /// For testing: reset to initial state
  void reset() {
    _serverBalance = _initialBalance;
    _processedKeys.clear();
  }
}