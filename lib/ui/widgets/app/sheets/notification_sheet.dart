// lib/ui/widgets/settings/sheets/user/notification_sheet.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_education_app/ui/screens/app/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet._();

  static void show(BuildContext context) =>
      openFullSheet(context, const NotificationsSheet._());

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  static const _kPushKey = 'notif_push_enabled';
  static const _kEmailKey = 'notif_email_enabled';

  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushEnabled = prefs.getBool(_kPushKey) ?? true;
      _emailEnabled = prefs.getBool(_kEmailKey) ?? false;
      _isLoading = false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPushKey, _pushEnabled);
    await prefs.setBool(_kEmailKey, _emailEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Notifications',
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
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
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FilledButton(
                    onPressed: () async {
                      await _savePrefs();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Notification preferences saved'),
                          ),
                        );
                      }
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
