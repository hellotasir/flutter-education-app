// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';
import 'package:flutter_education_app/ui/widgets/app/snackbar_widget.dart';
import 'package:flutter_education_app/ui/widgets/safety/mfa_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void open(BuildContext context, AuthRepository authRepository) {
    AppNavigator(
      screen: MfaScreen(authRepository: authRepository),
    ).navigate(context);
  }

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final authRepository = AuthRepository();
  _MfaStep _step = _MfaStep.checking;
  bool _isLoading = false;

  String? _factorId;
  String? _totpSecret;
  String? _qrSvg;
  List<Factor> _factors = [];

  final _codeController = TextEditingController();

  AuthRepository get _repo => widget.authRepository;

  @override
  void initState() {
    super.initState();
    _checkMfaStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    SnackbarWidget(message: message).showSnackbar(context);
  }

  Future<void> _checkMfaStatus() async {
    setState(() => _isLoading = true);
    try {
      _factors = await _repo.mfaListVerifiedFactors();
      setState(() {
        _step = _factors.isNotEmpty ? _MfaStep.enabled : _MfaStep.intro;
      });
    } catch (e) {
      _showError('Could not load MFA status');
      setState(() => _step = _MfaStep.intro);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startEnrollment() async {
    setState(() => _isLoading = true);
    try {
      final response = await _repo.mfaEnroll(issuer: 'EduApp');
      _factorId = response.id;
      _totpSecret = response.totp?.secret;
      _qrSvg = response.totp?.qrCode;
      setState(() => _step = _MfaStep.scan);
    } catch (e) {
      _showError('Enrollment failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndActivate() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('Please enter the 6-digit code from your authenticator app.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _repo.mfaVerifyEnrollment(factorId: _factorId!, code: code);
      _codeController.clear();
      setState(() => _step = _MfaStep.enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication enabled!')),
        );
      }
    } catch (e) {
      _showError('Verification failed. Please check the code and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unenroll() async {
    final confirm = await _showConfirmDialog(
      title: 'Disable 2FA?',
      body:
          'This will remove two-factor authentication from your account. Are you sure?',
      confirmLabel: 'Disable',
      isDestructive: true,
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _repo.mfaUnenroll(_factors.first.id);
      setState(() {
        _factors = [];
        _step = _MfaStep.intro;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-factor authentication disabled.')),
        );
      }
    } catch (e) {
      _showError('Failed to disable 2FA: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: Colors.red.shade600)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Two-Factor Authentication'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: MfaWidget(
          authRepository: authRepository,
          child: SafeArea(
            child: _isLoading && _step == _MfaStep.checking
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_step) {
      _MfaStep.checking => const Center(child: CircularProgressIndicator()),
      _MfaStep.intro => _buildIntroView(),
      _MfaStep.scan => _buildScanView(),
      _MfaStep.enabled => _buildEnabledView(),
    };
  }

  Widget _buildIntroView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.security_rounded,
              size: 32,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Two-Factor Authentication',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add an extra layer of security to your account. After enabling 2FA, you'll need to enter a 6-digit code from your authenticator app when signing in.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 32),
          _BenefitTile(
            icon: Icons.shield_outlined,
            title: 'Stronger account security',
            subtitle:
                'Even if your password is compromised, your account stays safe.',
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.phonelink_lock_outlined,
            title: 'Authenticator app',
            subtitle:
                'Works with Google Authenticator, Authy, and any TOTP-compatible app.',
          ),
          const SizedBox(height: 12),
          _BenefitTile(
            icon: Icons.timer_outlined,
            title: 'Time-based codes',
            subtitle: 'Generates a new secure code every 30 seconds.',
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _startEnrollment,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_rounded),
              label: Text(_isLoading ? 'Setting up…' : 'Enable 2FA'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanView() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Scan QR Code',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open your authenticator app and scan the QR code below, or enter the secret key manually.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
                color: colorScheme.surfaceVariant,
              ),
              child: _qrSvg != null
                  ? const Center(
                      child: Icon(Icons.qr_code_2_rounded, size: 120),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: 20),
          if (_totpSecret != null) ...[
            Text(
              'Manual entry key',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _totpSecret!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _totpSecret!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Secret key copied')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
          Text(
            'Enter 6-digit code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After scanning, enter the 6-digit code shown in your authenticator app to confirm setup.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: '••••••',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _verifyAndActivate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_rounded),
              label: Text(_isLoading ? 'Verifying…' : 'Verify & Enable'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => setState(() => _step = _MfaStep.intro),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnabledView() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              size: 40,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '2FA is Active',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Your account is protected with two-factor authentication. You'll be asked for a code each time you sign in.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _unenroll,
              icon: const Icon(Icons.remove_circle_outline_rounded),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade600,
              ),
              label: Text(_isLoading ? 'Disabling…' : 'Disable 2FA'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MfaStep { checking, intro, scan, enabled }

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colorScheme.onSecondaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
