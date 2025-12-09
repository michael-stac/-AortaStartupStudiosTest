class PaymentException implements Exception {
  final String message;
  final String? code;

  PaymentException(this.message, {this.code});
}

class InsufficientFundsException extends PaymentException {
  InsufficientFundsException(String message) : super(message);
}

class NoConnectionException extends PaymentException {
  NoConnectionException(String message) : super(message);
}

class ServerException extends PaymentException {
  final bool isRetryable;

  ServerException(String message, {this.isRetryable = true}) : super(message);
}

class BankDeclineException extends PaymentException {
  BankDeclineException(String message) : super(message);
}

class TransactionFailedException extends PaymentException {
  TransactionFailedException(String message) : super(message);
}