// ignore_for_file: strict_top_level_inference

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/profile/providers/profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_education_app/features/app/screens/home_screen.dart';
import 'package:flutter_education_app/features/app/widgets/loading_widget.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';
import 'package:flutter_education_app/features/profile/screens/profile_settings_screen.dart';
import 'package:flutter_education_app/features/profile/widgets/error_view.dart';
import 'package:flutter_education_app/features/profile/widgets/profile_body.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.viewUserId});

  final String? viewUserId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    if (!_hasAnimated) {
      _hasAnimated = true;
      _animCtrl.forward();
    }
  }

  ProfileNotifier get _notifier =>
      ref.read(profileProvider(widget.viewUserId).notifier);

  Future<void> _handleAvatarChange() async {
    try {
      await _notifier.changeAvatar(context);
      _showSnack('Profile photo updated');
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    }
  }

  Future<void> _handleCoverChange() async {
    try {
      await _notifier.changeCover(context);
      _showSnack('Cover photo updated');
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    }
  }

  void _openSettings(profile) {
    if (!_notifier.isOwnProfile || profile == null) return;
    AppNavigator(
      screen: ProfileSettingsScreen(profile: profile),
    ).navigate(context);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: error
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider(widget.viewUserId));

    if (!profileState.loading && profileState.profile != null) {
      _triggerAnimation();
    }

    return MaterialWidget(
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBody(profileState),
        ),
      ),
    );
  }

  Widget _buildBody(ProfileState profileState) {
    if (profileState.loading) {
      return const Center(key: ValueKey('loading'), child: LoadingIndicator());
    }

    if (profileState.errorMessage != null) {
      return ErrorView(
        key: const ValueKey('error'),
        message: profileState.errorMessage!,
        onRetry: _notifier.loadProfile,
      );
    }

    return FadeTransition(
      key: const ValueKey('content'),
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: ProfileBody(
          profile: profileState.profile!,
          isOwnProfile: _notifier.isOwnProfile,
          uploadingAvatar: profileState.uploadingAvatar,
          uploadingCover: profileState.uploadingCover,
          onChangeAvatar: _handleAvatarChange,
          onChangeCover: _handleCoverChange,
          onOpenSettings: () => _openSettings(profileState.profile),
          initials: _initials,
          capitalize: _capitalize,
          onBack: () => AppNavigator(screen: HomeScreen()).navigate(context),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
