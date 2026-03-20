// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/user/auth/login_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';
import 'package:flutter_education_app/ui/widgets/settings/settings_widget.dart';
import 'package:flutter_education_app/ui/widgets/app/snackbar_widget.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/appearance_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/feedback_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/about_app_sheet.dart';
import 'package:flutter_education_app/ui/widgets/settings/sheets/user/account_sheet.dart';

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
            const SectionHeader(label: 'Account'),
            SettingsTile(
              icon: Icons.manage_accounts_outlined,
              label: 'Account Settings',
              onTap: () => AccountSheet.show(context, authRepository),
            ),
            SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => _NotificationsSheet.show(context),
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
              onTap: () => FeedbackSheet.show(context, authRepository),
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

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();

  static void show(BuildContext context) =>
      openFullSheet(context, const _NotificationsSheet());

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _courseReminders = true;
  bool _newContent = true;
  bool _weeklyDigest = false;
  bool _achievements = true;

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Notifications',
      child: Column(
        children: [
          SwitchTile(
            icon: Icons.phonelink_ring_outlined,
            label: 'Push Notifications',
            subtitle: 'Receive alerts on this device',
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
          ),
          SwitchTile(
            icon: Icons.email_outlined,
            label: 'Email Notifications',
            subtitle: 'Receive updates via email',
            value: _emailEnabled,
            onChanged: (v) => setState(() => _emailEnabled = v),
          ),
          const SubSectionHeader(label: 'What to Notify'),
          SwitchTile(
            icon: Icons.alarm_outlined,
            label: 'Course Reminders',
            subtitle: 'Daily reminders to continue learning',
            value: _courseReminders,
            onChanged: (v) => setState(() => _courseReminders = v),
          ),
          SwitchTile(
            icon: Icons.new_releases_outlined,
            label: 'New Content',
            subtitle: 'When new courses or lessons are added',
            value: _newContent,
            onChanged: (v) => setState(() => _newContent = v),
          ),
          SwitchTile(
            icon: Icons.newspaper_outlined,
            label: 'Weekly Digest',
            subtitle: 'A weekly summary of your progress',
            value: _weeklyDigest,
            onChanged: (v) => setState(() => _weeklyDigest = v),
          ),
          SwitchTile(
            icon: Icons.emoji_events_outlined,
            label: 'Achievements',
            subtitle: 'When you earn badges or milestones',
            value: _achievements,
            onChanged: (v) => setState(() => _achievements = v),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification preferences saved'),
                  ),
                );
              },
              child: const Text('Save Preferences'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
