import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/screens/login_screen.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';
import 'package:flutter_education_app/features/app/widgets/snackbar_widget.dart';
import 'package:flutter_education_app/features/app/widgets/mfa_widget.dart';

enum _DeleteStep { confirm, deleted }

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void open(BuildContext context, AuthRepository authRepository) =>
      AppNavigator(
        screen: DeleteAccountScreen(authRepository: authRepository),
      ).navigate(context);

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen>
    with SingleTickerProviderStateMixin {
  _DeleteStep _step = _DeleteStep.confirm;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _checkedUnderstood = false;

  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarWidget(message: message).showSnackbar(context);
  }

  Future<bool?> _showFinalConfirmDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        color: Colors.red.shade600,
        size: 40,
      ),
      title: const Text('Final confirmation'),
      content: const Text(
        'This will permanently delete your account and all associated data. '
        'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete my account'),
        ),
      ],
    ),
  );

  Future<void> _submitDeletionRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_checkedUnderstood) {
      _showError(
        'Please confirm that you understand this action is irreversible.',
      );
      return;
    }

    final confirmed = await _showFinalConfirmDialog();
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await widget.authRepository.deleteAccount(
        _passwordController.text.trim(),
      );
      await widget.authRepository.logout();

      if (mounted) {
        AppNavigator(screen: LoginScreen()).navigate(context);
        setState(() => _step = _DeleteStep.deleted);
      }
    } on Exception {
      if (mounted) {
        _showError('Could not delete your account. Please try again.');
      }
      _showError('Could not delete your account. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Delete Account'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: MfaWidget(
          authRepository: widget.authRepository,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: switch (_step) {
                    _DeleteStep.confirm => _buildConfirmView(),
                    _DeleteStep.deleted => _buildDeletedView(),
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _WarningBanner(theme: theme),
          const SizedBox(height: 28),
          Text(
            'Confirm your password',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your current password to verify your identity before deleting your account.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) =>
                _isLoading ? null : _submitDeletionRequest(),
            decoration: InputDecoration(
              labelText: 'Current password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Password is required';
              if (v.trim().length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () =>
                setState(() => _checkedUnderstood = !_checkedUnderstood),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _checkedUnderstood,
                    activeColor: Colors.red.shade600,
                    onChanged: (v) =>
                        setState(() => _checkedUnderstood = v ?? false),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand that deleting my account is permanent and cannot be undone.',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _submitDeletionRequest,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever_rounded),
              label: Text(_isLoading ? 'Deleting…' : 'Delete My Account'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDeletedView() {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 56),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            size: 44,
            color: Colors.red.shade600,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Account Deleted',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your account and all associated data have been permanently deleted. '
          'You have been signed out of all devices.',
          style: textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.65),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 52),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () =>
                AppNavigator(screen: LoginScreen()).navigate(context),
            child: const Text('Go to Login'),
          ),
        ),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action is permanent',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Deleting your account will permanently remove all your data, '
                'progress, and subscriptions.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
