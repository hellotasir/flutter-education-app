// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/ui/screens/user/settings/account/delete_account_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/account/mfa_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/account/reset_password_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/account/verify_email_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/settings_screen.dart';
import 'package:flutter_education_app/ui/widgets/settings/settings_widget.dart';

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.authRepository});

  final AuthRepository authRepository;

  static void show(BuildContext context, AuthRepository authRepository) =>
      openFullSheet(context, AccountSheet(authRepository: authRepository));

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Account Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const SubSectionHeader(label: 'Security'),
          SettingsTile(
            icon: Icons.lock_reset_rounded,
            label: 'Reset Password',
            onTap: () {
              Navigator.pop(context);
              ResetPasswordScreen.open(context, authRepository);
            },
          ),
          SettingsTile(
            icon: Icons.security_rounded,
            label: 'Two-Factor Authentication',
            onTap: () {
              Navigator.pop(context);
              MfaScreen.open(context, authRepository);
            },
          ),
          const SubSectionHeader(label: 'Verification'),
          SettingsTile(
            icon: Icons.mark_email_read_outlined,
            label: 'Verify Email',
            onTap: () {
              Navigator.pop(context);
              VerifyEmailScreen.open(context, authRepository);
            },
          ),
          const SubSectionHeader(label: 'Danger Zone'),
          SettingsTile(
            icon: Icons.delete_forever_rounded,
            label: 'Delete Account',
            color: Colors.red.shade600,
            onTap: () {
              Navigator.pop(context);
              DeleteAccountScreen.open(context, authRepository);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
