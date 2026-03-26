// lib/ui/screens/user/settings/settings_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/repositories/supabase_auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/user/auth/login_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/feedback_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/profile_settings_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';
import 'package:flutter_education_app/ui/widgets/settings/settings_widget.dart';
import 'package:flutter_education_app/ui/widgets/app/snackbar_widget.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/appearance_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/about_app_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/user/account_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/user/notification_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static void open(BuildContext context) {
    AppNavigator(screen: const SettingsScreen()).navigate(context);
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();

    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ),
        body: ListView(
          children: [
            const SectionHeader(label: 'Profile'),
            SettingsTile(
              icon: Icons.person,
              label: 'Profile Settings',
              onTap: () => AppNavigator(
                screen: ProfileSettingsScreen(),
              ).navigate(context),
            ),
            const SectionHeader(label: 'Account'),
            SettingsTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Account Settings',
              onTap: () => AccountSheet.show(context, authRepository),
            ),
            SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => NotificationsSheet.show(context),
            ),
            const SectionHeader(label: 'Preferences'),
            SettingsTile(
              icon: Icons.dark_mode_outlined,
              label: 'Appearance',
              onTap: () => AppearanceSheet.show(context),
            ),
            const SectionHeader(label: 'Support'),
            SettingsTile(
              icon: Icons.feedback_outlined,
              label: 'Send Feedback',
              onTap: () => FeedbackScreen.open(context, authRepository),
            ),
            SettingsTile(
              icon: Icons.info_outlined,
              label: 'About',
              onTap: () => AboutSheet.show(context),
            ),
            const SectionHeader(label: 'Session'),
            SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              color: Colors.red.shade600,
              onTap: () async {
                try {
                  await authRepository.logout();
                  AppNavigator(screen: LoginScreen()).navigate(context);
                } catch (e) {
                  SnackbarWidget(message: 'Logout failed');
                }
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

Future<T?> openFullSheet<T>(
  BuildContext context,
  Widget child, {
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) =>
          SingleChildScrollView(controller: scrollController, child: child),
    ),
  );
}

class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ).copyWith(top: 8, bottom: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          child,
        ],
      ),
    );
  }
}
