import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/features/app/widgets/app_snackbar.dart';
import 'package:flutter_education_app/features/subscription/models/subscription_plan.dart';
import 'package:flutter_education_app/features/subscription/repositories/subscription_repository.dart';
import 'package:flutter_education_app/features/subscription/screens/subscription_screen.dart';
import 'package:flutter_education_app/features/user/models/profile_model.dart';
import 'package:flutter_education_app/features/user/repositories/profile_repository.dart';
import 'package:flutter_education_app/features/user/screens/profile_screen.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_sslcommerz/model/SSLCCustomerInfoInitializer.dart'
    show SSLCCustomerInfoInitializer;
import 'package:flutter_sslcommerz/model/SSLCommerzInitialization.dart';
import 'package:flutter_sslcommerz/model/SSLCurrencyType.dart';
import 'package:flutter_sslcommerz/model/SSLCSdkType.dart';
import 'package:flutter_sslcommerz/model/SSLCTransactionInfoModel.dart';
import 'package:flutter_sslcommerz/model/sslproductinitilizer/NonPhysicalGoods.dart'
    show NonPhysicalGoods;
import 'package:flutter_sslcommerz/model/sslproductinitilizer/SSLCProductInitializer.dart'
    show SSLCProductInitializer;
import 'package:flutter_sslcommerz/sslcommerz.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

final storeID = dotenv.env['SSL_COMMERZ_STORE_ID']!;
final storePassword = dotenv.env['SSL_COMMERZ_STORE_PASSWORD']!;

enum PaymentStatus { idle, loading, success, failed }

class PaymentScreen extends StatefulWidget {
  final SubscriptionPlan plan;

  const PaymentScreen({
    super.key,
    required this.plan,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedMethod;
  PaymentStatus _status = PaymentStatus.idle;
  String? _errorMessage;

  final _repo = SubscriptionRepository();
  final _authRepository = AuthRepository();
  final _profileRepository = ProfileRepository();
  Stream<ProfileModel?>? _profileStream;

  bool get _canPay => _selectedMethod != null && _status == PaymentStatus.idle;

  @override
  void initState() {
    super.initState();
    _initProfileStream();
  }

  void _initProfileStream() {
    final userId = _authRepository.currentUser?.id ?? '';
    final collectionPath = _profileRepository.collectionPath.first;

    _profileStream = FirebaseFirestore.instance
        .collection(collectionPath)
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return _profileRepository.fromSnapshot(snapshot.docs.first);
        });
  }

  void _onMethodChanged(String? value) {
    setState(() {
      _selectedMethod = value;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileModel?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  AppNavigator(
                    screen: const SubscriptionScreen(),
                  ).navigate(context);
                }
              },
              icon: const Icon(Icons.chevron_left_outlined),
            ),
            title: const Text('Checkout'),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : profile == null
              ? const Center(child: Text('Profile not found'))
              : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            _PlanSummary(plan: widget.plan),
                            const SizedBox(height: 28),
                            const Text(
                              'Payment Method',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            _PaymentMethodTile(
                              value: 'stripe',
                              title: 'Credit / Debit Card',
                              subtitle: 'Powered by Stripe',
                              icon: Icons.credit_card_outlined,
                              selectedValue: _selectedMethod,
                              onChanged: _onMethodChanged,
                            ),
                            _PaymentMethodTile(
                              value: 'sslcommerz',
                              title: 'SSLCommerz',
                              subtitle: 'Mobile banking & cards',
                              icon: Icons.mobile_friendly_outlined,
                              selectedValue: _selectedMethod,
                              onChanged: _onMethodChanged,
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 16),
                              _ErrorBanner(message: _errorMessage!),
                            ],
                          ],
                        ),
                      ),
                      _BottomPayBar(
                        price: widget.plan.price,
                        canPay: _canPay,
                        isLoading: _status == PaymentStatus.loading,
                        onPay: () => _handlePayment(profile),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _handlePayment(ProfileModel profile) async {
    if (_selectedMethod == null) return;

    setState(() {
      _status = PaymentStatus.loading;
      _errorMessage = null;
    });

    try {
      switch (_selectedMethod) {
        case 'stripe':
          await _handleStripePayment();
          break;
        case 'sslcommerz':
          await _handleSSLCommerzPayment(profile);
          break;
        default:
          throw Exception('Unknown payment method: $_selectedMethod');
      }
    } on StripeException catch (e) {
      final msg =
          e.error.localizedMessage ?? e.error.message ?? 'Payment cancelled.';
      final isCancelled = e.error.code == FailureCode.Canceled;

      if (!isCancelled) {
        await _repo.recordFailedPayment(
          plan: widget.plan,
          gateway: 'stripe',
          status: 'error',
          errorMessage: msg,
        );
      }

      if (mounted) {
        setState(() {
          _status = isCancelled ? PaymentStatus.idle : PaymentStatus.failed;
          _errorMessage = isCancelled ? null : msg;
        });
        if (!isCancelled) _showResultDialog(success: false);
      }
    } catch (e) {
      await _repo.recordFailedPayment(
        plan: widget.plan,
        gateway: _selectedMethod ?? 'unknown',
        status: 'error',
        errorMessage: e.toString(),
      );

      if (mounted) {
        setState(() {
          _status = PaymentStatus.failed;
          _errorMessage = e.toString();
        });
        _showResultDialog(success: false);
      }
    } finally {
      if (mounted && _status != PaymentStatus.success) {
        setState(() => _status = PaymentStatus.idle);
      }
    }
  }

  Future<void> _handleStripePayment() async {
    final clientSecret = await _repo.createStripePaymentIntent(
      amount: (widget.plan.price * 100).toInt(),
      currency: 'usd',
    );

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'EDUMAP PORTFOLIO',
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'US',
          currencyCode: 'USD',
        ),
        applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
        style: ThemeMode.system,
        billingDetailsCollectionConfiguration:
            const BillingDetailsCollectionConfiguration(
              name: CollectionMode.automatic,
              email: CollectionMode.automatic,
            ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    await _repo.activateSubscription(plan: widget.plan, gateway: 'stripe');
    _onPaymentSuccess();
  }

  Future<void> _handleSSLCommerzPayment(ProfileModel profile) async {
    final tranId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

    final Sslcommerz sslcommerz = Sslcommerz(
      initializer: SSLCommerzInitialization(
        multi_card_name: 'visa,master,bkash,nagad',
        currency: SSLCurrencyType.USD,
        language: 'en',
        product_category: 'Education',
        sdkType: SSLCSdkType.TESTBOX,
        store_id: storeID,
        store_passwd: storePassword,
        total_amount: widget.plan.price.toDouble(),
        tran_id: tranId,
      ),
    );

  

    final SSLCTransactionInfoModel result = await sslcommerz.payNow();

    final status = result.status?.toLowerCase().trim() ?? '';

    if (status == 'valid' || status == 'validated') {
      await _repo.verifyAndActivateSSLCommerzSubscription(
        plan: widget.plan,
        transactionId: result.tranId ?? tranId,
        valId: result.valId ?? '',
      );

      AppSnackbar.show(
        context,
        message: 'Payment successful 🎉',
        type: SnackType.success,
      );

      _onPaymentSuccess();
    } else if (status == 'cancelled') {
      AppSnackbar.show(
        context,
        message: 'Payment cancelled by user',
        type: SnackType.warning,
      );
    } else if (status == 'failed') {
      AppSnackbar.show(
        context,
        message: 'Payment failed. Please try again.',
        type: SnackType.error,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'Unknown payment status: $status',
        type: SnackType.info,
      );
    }
  }

  void _onPaymentSuccess() {
    if (!mounted) return;
    setState(() => _status = PaymentStatus.success);
    _showResultDialog(success: true);
  }

  void _showResultDialog({required bool success}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(
        success: success,
        planName: widget.plan.name,
        onDone: () {
          if (success) {
            AppNavigator(screen: ProfileScreen()).navigate(context);
          } else {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  final SubscriptionPlan plan;
  const _PlanSummary({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.features.join('  ·  '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${plan.price.toStringAsFixed(2)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('/ ${plan.duration}', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;

  const _PaymentMethodTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selectedValue,
    required this.onChanged,
  });

  bool get _selected => selectedValue == value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: _selected
            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: selectedValue,
        onChanged: onChanged,
        secondary: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

class _BottomPayBar extends StatelessWidget {
  final double price;
  final bool canPay;
  final bool isLoading;
  final VoidCallback onPay;

  const _BottomPayBar({
    required this.price,
    required this.canPay,
    required this.isLoading,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Total', style: TextStyle(fontSize: 12)),
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: canPay && !isLoading ? onPay : null,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Pay Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final bool success;
  final String planName;
  final VoidCallback onDone;

  const _ResultDialog({
    required this.success,
    required this.planName,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 56,
            color: success
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'Payment Successful!' : 'Payment Failed',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            success
                ? "You're now subscribed to $planName. Enjoy learning!"
                : 'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: Text(success ? 'Start Learning' : 'Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}
