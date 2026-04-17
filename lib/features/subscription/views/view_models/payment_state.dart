enum PaymentStatus { idle, loading, success, failed }

class PaymentState {
  final PaymentStatus status;
  final String? selectedMethod;
  final String? errorMessage;

  const PaymentState({
    this.status = PaymentStatus.idle,
    this.selectedMethod,
    this.errorMessage,
  });

  bool get canPay => selectedMethod != null && status != PaymentStatus.loading;

  bool get isLoading => status == PaymentStatus.loading;

  PaymentState copyWith({
    PaymentStatus? status,
    String? selectedMethod,
    String? errorMessage,
    bool clearError = false,
    bool clearMethod = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      selectedMethod: clearMethod
          ? null
          : (selectedMethod ?? this.selectedMethod),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
