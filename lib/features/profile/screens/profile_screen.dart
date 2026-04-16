import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/screens/home_screen.dart';
import 'package:flutter_education_app/features/profile/models/profile_model.dart';
import 'package:flutter_education_app/features/profile/repositories/profile_repository.dart';
import 'package:flutter_education_app/others/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/screens/settings_screen.dart';
import 'package:flutter_education_app/others/services/cloud/database_service.dart';
import 'package:flutter_education_app/others/services/cloud/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.viewUserId});
  final String? viewUserId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _authRepo = AuthRepository();
  final _service = FirestoreService<ProfileModel>(ProfileRepository());
  final _storage = SupabaseStorageService();
  final _picker = ImagePicker();

  ProfileModel? _profile;
  bool _loading = true;
  String? _errorMessage;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  String? get _currentUserId => _authRepo.currentUser?.id;
  String? get _targetUserId => widget.viewUserId ?? _currentUserId;
  bool get _isOwnProfile =>
      widget.viewUserId == null || widget.viewUserId == _currentUserId;

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
    _loadProfile();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final uid = _targetUserId;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Not logged in.';
        });
      }
      return;
    }

    try {
      final results = await _service.getAll(
        query: (col) => col.where('user_id', isEqualTo: uid).limit(1),
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        setState(() {
          _profile = results.first;
          _loading = false;
        });
        _animCtrl.forward();
      } else if (_isOwnProfile) {
        await _createDefaultProfile(uid);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = 'Profile not found.';
        });
      }
    } catch (e, st) {
      debugPrint('[ProfileScreen] error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _createDefaultProfile(String uid) async {
    final user = _authRepo.currentUser!;
    final meta = user.userMetadata ?? {};
    final String rawName = (meta['full_name'] as String? ?? '').trim();
    final String emailPrefix = (user.email ?? '')
        .split('@')
        .first
        .replaceAll('.', '_');
    final String username = rawName.isNotEmpty
        ? rawName.replaceAll(' ', '_').toLowerCase()
        : emailPrefix;
    final now = DateTime.now();

    final defaultProfile = ProfileModel(
      userId: uid,
      username: username,
      email: user.email ?? '',
      phone: user.phone ?? '',
      passwordHash: '',
      currentMode: 'student',
      availableModes: const ['student'],
      isVerified: user.emailConfirmedAt != null,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastLogin: now,
      profile: ProfileInfo(
        fullName: rawName,
        profilePhoto: meta['avatar_url'] as String? ?? '',
        coverPhoto: '',
        bio: '',
        dateOfBirth: null,
        gender: '',
        location: const Location(country: '', city: '', timezone: ''),
        languages: const [],
        socialLinks: const SocialLinks(linkedin: '', github: '', website: ''),
      ),
      studentProfile: const StudentProfile(
        isActive: true,
        interests: [],
        currentLevel: 'beginner',
      ),
      instructorProfile: const InstructorProfile(
        isActive: false,
        headline: '',
        expertise: [],
        yearsOfExperience: 0,
      ),
      system: const SystemInfo(isBanned: false, isFeaturedInstructor: false),
    );

    final newDocId = await _service.add(defaultProfile);
    if (!mounted) return;
    setState(() {
      _profile = defaultProfile.copyWith(id: newDocId);
      _loading = false;
    });
    _animCtrl.forward();
  }

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _ImageSourceSheet(),
    );
    if (source == null) return null;
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    return xfile == null ? null : File(xfile.path);
  }

  Future<void> _changeAvatar() async {
    if (!_isOwnProfile || _uploadingAvatar) return;
    final file = await _pickImage();
    if (file == null || _profile?.id == null) return;
    if (!mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final rawUrl = await _storage.uploadAvatar(
        _profile!.userId,
        _profile!.currentMode,
        file,
      );
      final oldUrl = _profile!.profile.profilePhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();
      final freshUrl = _cacheBust(rawUrl);
      await _service.update(_profile!.id!, {'profile.profile_photo': freshUrl});
      if (!mounted) return;
      setState(
        () => _profile = _rebuildInfo(_profile!, profilePhoto: freshUrl),
      );
      _showSnack('Profile photo updated');
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _changeCover() async {
    if (!_isOwnProfile || _uploadingCover) return;
    final file = await _pickImage();
    if (file == null || _profile?.id == null) return;
    if (!mounted) return;
    setState(() => _uploadingCover = true);
    try {
      final rawUrl = await _storage.uploadCoverPhoto(_profile!.userId, file);
      final oldUrl = _profile!.profile.coverPhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();
      final freshUrl = _cacheBust(rawUrl);
      await _service.update(_profile!.id!, {'profile.cover_photo': freshUrl});
      if (!mounted) return;
      setState(() => _profile = _rebuildInfo(_profile!, coverPhoto: freshUrl));
      _showSnack('Cover photo updated');
    } catch (e) {
      _showSnack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _openSettings() async {
    if (!_isOwnProfile || _profile == null) return;
    AppNavigator(screen: SettingsScreen(profile: _profile!)).navigate(context);
  }

  static String _cacheBust(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            '_cb': '${DateTime.now().millisecondsSinceEpoch}',
          },
        )
        .toString();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static ProfileModel _rebuildInfo(
    ProfileModel p, {
    String? profilePhoto,
    String? coverPhoto,
  }) {
    final o = p.profile;
    return ProfileModel(
      id: p.id,
      userId: p.userId,
      username: p.username,
      email: p.email,
      phone: p.phone,
      passwordHash: p.passwordHash,
      currentMode: p.currentMode,
      availableModes: p.availableModes,
      isVerified: p.isVerified,
      status: p.status,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
      lastLogin: p.lastLogin,
      profile: ProfileInfo(
        fullName: o.fullName,
        profilePhoto: profilePhoto ?? o.profilePhoto,
        coverPhoto: coverPhoto ?? o.coverPhoto,
        bio: o.bio,
        dateOfBirth: o.dateOfBirth,
        gender: o.gender,
        location: o.location,
        languages: o.languages,
        socialLinks: o.socialLinks,
      ),
      studentProfile: p.studentProfile,
      instructorProfile: p.instructorProfile,
      system: p.system,
    );
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

  String _initials(String name) {
    final parts = name.trim().split(' ')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _loading
              ? const _LoadingView()
              : _errorMessage != null
              ? _ErrorView(message: _errorMessage!, onRetry: _loadProfile)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _ProfileBody(
                      profile: _profile!,
                      isOwnProfile: _isOwnProfile,
                      uploadingAvatar: _uploadingAvatar,
                      uploadingCover: _uploadingCover,
                      onChangeAvatar: _changeAvatar,
                      onChangeCover: _changeCover,
                      onOpenSettings: _openSettings,
                      initials: _initials,
                      capitalize: _capitalize,
                      onBack: () =>
                          AppNavigator(screen: HomeScreen()).navigate(context),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Loading ──────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 32,
                color: cs.onErrorContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Could not load profile',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try again'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingAvatar,
    required this.uploadingCover,
    required this.onChangeAvatar,
    required this.onChangeCover,
    required this.onOpenSettings,
    required this.initials,
    required this.capitalize,
    required this.onBack,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingAvatar;
  final bool uploadingCover;
  final VoidCallback onChangeAvatar;
  final VoidCallback onChangeCover;
  final VoidCallback onOpenSettings;
  final String Function(String) initials;
  final String Function(String) capitalize;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _ProfileAppBar(
          profile: profile,
          isOwnProfile: isOwnProfile,
          uploadingCover: uploadingCover,
          onChangeCover: onChangeCover,
          onOpenSettings: onOpenSettings,
          onBack: onBack,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AvatarRow(
                profile: profile,
                isOwnProfile: isOwnProfile,
                uploadingAvatar: uploadingAvatar,
                onChangeAvatar: onChangeAvatar,
                initials: initials,
              ),
              _BioSection(profile: profile, capitalize: capitalize),
              _ActionRow(isOwnProfile: isOwnProfile, onEdit: onOpenSettings),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              _DetailsSection(
                profile: profile,
                isOwnProfile: isOwnProfile,
                capitalize: capitalize,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AppBar (pinned, with collapsing cover photo) ───────────────────────────────

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingCover,
    required this.onChangeCover,
    required this.onOpenSettings,
    required this.onBack,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingCover;
  final VoidCallback onChangeCover;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: cs.surface,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '@${profile.username}',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (profile.isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified_rounded, size: 15, color: cs.primary),
          ],
        ],
      ),
      leading: IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      actions: [
        if (isOwnProfile)
          IconButton(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined, size: 22),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: _CoverPhoto(
          info: info,
          isOwnProfile: isOwnProfile,
          uploading: uploadingCover,
          onTap: onChangeCover,
        ),
      ),
    );
  }
}

// ── Cover Photo ───────────────────────────────────────────────────────────────

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({
    required this.info,
    required this.isOwnProfile,
    required this.uploading,
    required this.onTap,
  });

  final ProfileInfo info;
  final bool isOwnProfile;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: info.coverPhoto.isNotEmpty
              ? Image.network(
                  info.coverPhoto,
                  fit: BoxFit.cover,
                  key: ValueKey(info.coverPhoto),
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: cs.secondaryContainer),
                )
              : DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primaryContainer, cs.secondaryContainer],
                    ),
                  ),
                ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, cs.scrim.withOpacity(0.45)],
            ),
          ),
        ),
        if (uploading)
          ColoredBox(
            color: cs.scrim.withOpacity(0.4),
            child: const Center(child: CircularProgressIndicator()),
          ),
        if (isOwnProfile)
          Positioned(
            right: 16,
            bottom: 16,
            child: _EditCoverButton(uploading: uploading, onTap: onTap),
          ),
      ],
    );
  }
}

class _EditCoverButton extends StatelessWidget {
  const _EditCoverButton({required this.uploading, required this.onTap});
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: uploading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.white,
              ),
            )
          : const Icon(
              Icons.camera_alt_outlined,
              size: 14,
              color: Colors.white,
            ),
      label: const Text(
        'Edit cover',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.black.withOpacity(0.4),
      side: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

// ── Avatar Row ────────────────────────────────────────────────────────────────

class _AvatarRow extends StatelessWidget {
  const _AvatarRow({
    required this.profile,
    required this.isOwnProfile,
    required this.uploadingAvatar,
    required this.onChangeAvatar,
    required this.initials,
  });

  final ProfileModel profile;
  final bool isOwnProfile;
  final bool uploadingAvatar;
  final VoidCallback onChangeAvatar;
  final String Function(String) initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;
    final name = info.fullName.isNotEmpty ? info.fullName : profile.username;
    final isInstructor = profile.currentMode == 'instructor';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: isOwnProfile ? onChangeAvatar : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.primaryContainer,
                    key: ValueKey(info.profilePhoto),
                    backgroundImage: info.profilePhoto.isNotEmpty
                        ? NetworkImage(info.profilePhoto)
                        : null,
                    child: uploadingAvatar
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimaryContainer,
                          )
                        : info.profilePhoto.isEmpty
                        ? Text(
                            initials(name),
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                ),
                if (isOwnProfile)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 11,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(
                  value: isInstructor
                      ? '${profile.instructorProfile.yearsOfExperience}yr'
                      : profile.studentProfile.currentLevel
                            .substring(0, 3)
                            .toUpperCase(),
                  label: isInstructor ? 'Experience' : 'Level',
                ),
                _StatCard(
                  value: isInstructor
                      ? '${profile.instructorProfile.expertise.length}'
                      : '${profile.studentProfile.interests.length}',
                  label: isInstructor ? 'Expertise' : 'Interests',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Bio Section ───────────────────────────────────────────────────────────────

class _BioSection extends StatelessWidget {
  const _BioSection({required this.profile, required this.capitalize});
  final ProfileModel profile;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = profile.profile;
    final name = info.fullName.isNotEmpty ? info.fullName : profile.username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                profile.currentMode == 'instructor'
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                size: 13,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                capitalize(profile.currentMode),
                style: tt.bodySmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 8),
                Icon(Icons.verified_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 2),
                Text(
                  'Verified',
                  style: tt.bodySmall?.copyWith(color: cs.primary),
                ),
              ],
            ],
          ),
          if (info.bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(info.bio, style: tt.bodyMedium?.copyWith(height: 1.5)),
          ],
          if (info.location.city.isNotEmpty ||
              info.location.country.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  [
                    info.location.city,
                    info.location.country,
                  ].where((s) => s.isNotEmpty).join(', '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (_hasSocialLinks(info)) ...[
            const SizedBox(height: 10),
            _SocialRow(info: info),
          ],
        ],
      ),
    );
  }

  static bool _hasSocialLinks(ProfileInfo info) =>
      info.socialLinks.linkedin.isNotEmpty ||
      info.socialLinks.github.isNotEmpty ||
      info.socialLinks.website.isNotEmpty;
}

// ── Social Row (from second screen pattern) ───────────────────────────────────

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.info});
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (info.socialLinks.linkedin.isNotEmpty)
          ActionChip(
            avatar: Icon(
              Icons.work_outline_rounded,
              size: 14,
              color: cs.primary,
            ),
            label: const Text('LinkedIn'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        if (info.socialLinks.github.isNotEmpty)
          ActionChip(
            avatar: Icon(Icons.code_rounded, size: 14, color: cs.primary),
            label: const Text('GitHub'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
        if (info.socialLinks.website.isNotEmpty)
          ActionChip(
            avatar: Icon(Icons.language_rounded, size: 14, color: cs.primary),
            label: const Text('Website'),
            onPressed: () {},
            side: BorderSide(color: cs.outlineVariant),
            backgroundColor: Colors.transparent,
            shape: const StadiumBorder(),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

// ── Action Row ────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.isOwnProfile, required this.onEdit});
  final bool isOwnProfile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: isOwnProfile
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Edit Profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: cs.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  foregroundColor: cs.onSurface,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

// ── Details Section (tabbed) ──────────────────────────────────────────────────

class _DetailsSection extends StatefulWidget {
  const _DetailsSection({
    required this.profile,
    required this.isOwnProfile,
    required this.capitalize,
  });
  final ProfileModel profile;
  final bool isOwnProfile;
  final String Function(String) capitalize;

  @override
  State<_DetailsSection> createState() => _DetailsSectionState();
}

class _DetailsSectionState extends State<_DetailsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.isOwnProfile ? 2 : 1, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isInstructor = widget.profile.currentMode == 'instructor';

    return Column(
      children: [
        TabBar(
          controller: _tab,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorColor: cs.primary,
          labelColor: cs.onSurface,
          unselectedLabelColor: cs.onSurfaceVariant,
          dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
          indicatorWeight: 2,
          tabs: [
            Tab(
              icon: Icon(
                isInstructor
                    ? Icons.school_outlined
                    : Icons.person_outline_rounded,
                size: 20,
              ),
              text: isInstructor ? 'Instructor' : 'Student',
            ),
            if (widget.isOwnProfile)
              const Tab(
                icon: Icon(Icons.info_outline_rounded, size: 20),
                text: 'Details',
              ),
          ],
        ),
        IndexedStack(
          index: _tab.index,
          children: [
            isInstructor
                ? _InstructorListView(
                    profile: widget.profile.instructorProfile,
                    capitalize: widget.capitalize,
                  )
                : _StudentListView(
                    profile: widget.profile.studentProfile,
                    capitalize: widget.capitalize,
                  ),
            if (widget.isOwnProfile)
              _ContactListView(
                profile: widget.profile,
                info: widget.profile.profile,
              ),
          ],
        ),
      ],
    );
  }
}

// ── List Views ────────────────────────────────────────────────────────────────

class _InstructorListView extends StatelessWidget {
  const _InstructorListView({required this.profile, required this.capitalize});
  final InstructorProfile profile;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final items = <_DetailItem>[
      if (profile.headline.isNotEmpty)
        _DetailItem(
          icon: Icons.format_quote_rounded,
          title: 'Headline',
          subtitle: profile.headline,
        ),
      _DetailItem(
        icon: Icons.workspace_premium_outlined,
        title: 'Experience',
        subtitle: '${profile.yearsOfExperience} years',
      ),
      _DetailItem(
        icon: Icons.toggle_on_outlined,
        title: 'Status',
        subtitle: profile.isActive ? 'Active' : 'Inactive',
      ),
      if (profile.expertise.isNotEmpty)
        _DetailItem(
          icon: Icons.star_outline_rounded,
          title: 'Expertise',
          subtitle: profile.expertise.map(capitalize).join(', '),
          isTags: true,
          tags: profile.expertise,
        ),
    ];
    return _DetailListView(items: items);
  }
}

class _StudentListView extends StatelessWidget {
  const _StudentListView({required this.profile, required this.capitalize});
  final StudentProfile profile;
  final String Function(String) capitalize;

  static const _levels = ['beginner', 'intermediate', 'advanced', 'expert'];

  @override
  Widget build(BuildContext context) {
    final idx = _levels.indexOf(profile.currentLevel.toLowerCase());
    final progress = idx < 0 ? 0.25 : (idx + 1) / _levels.length;

    final items = <_DetailItem>[
      _DetailItem(
        icon: Icons.bar_chart_rounded,
        title: 'Current Level',
        subtitle: capitalize(profile.currentLevel),
        progress: progress,
      ),
      _DetailItem(
        icon: Icons.toggle_on_outlined,
        title: 'Status',
        subtitle: profile.isActive ? 'Active' : 'Inactive',
      ),
      if (profile.interests.isNotEmpty)
        _DetailItem(
          icon: Icons.interests_outlined,
          title: 'Interests',
          subtitle: profile.interests.map(capitalize).join(', '),
          isTags: true,
          tags: profile.interests,
        ),
    ];
    return _DetailListView(items: items);
  }
}

class _ContactListView extends StatelessWidget {
  const _ContactListView({required this.profile, required this.info});
  final ProfileModel profile;
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final items = <_DetailItem>[
      if (profile.email.isNotEmpty)
        _DetailItem(
          icon: Icons.mail_outline_rounded,
          title: 'Email',
          subtitle: profile.email,
        ),
      if (profile.phone.isNotEmpty)
        _DetailItem(
          icon: Icons.phone_outlined,
          title: 'Phone',
          subtitle: profile.phone,
        ),
      if (info.gender.isNotEmpty && info.gender != 'Prefer not to say')
        _DetailItem(
          icon: Icons.person_outline_rounded,
          title: 'Gender',
          subtitle: info.gender,
        ),
      if (info.dateOfBirth != null)
        _DetailItem(
          icon: Icons.cake_outlined,
          title: 'Birth Year',
          subtitle: '${info.dateOfBirth!.year}',
        ),
      if (info.location.timezone.isNotEmpty)
        _DetailItem(
          icon: Icons.schedule_outlined,
          title: 'Timezone',
          subtitle: info.location.timezone,
        ),
      if (info.languages.isNotEmpty)
        _DetailItem(
          icon: Icons.translate_rounded,
          title: 'Languages',
          subtitle: info.languages.join(', '),
        ),
      if (info.socialLinks.linkedin.isNotEmpty)
        _DetailItem(
          icon: Icons.work_outline_rounded,
          title: 'LinkedIn',
          subtitle: info.socialLinks.linkedin,
          isLink: true,
        ),
      if (info.socialLinks.github.isNotEmpty)
        _DetailItem(
          icon: Icons.code_rounded,
          title: 'GitHub',
          subtitle: info.socialLinks.github,
          isLink: true,
        ),
      if (info.socialLinks.website.isNotEmpty)
        _DetailItem(
          icon: Icons.language_rounded,
          title: 'Website',
          subtitle: info.socialLinks.website,
          isLink: true,
        ),
    ];
    return _DetailListView(items: items);
  }
}

// ── Detail Items & Cards ──────────────────────────────────────────────────────

class _DetailItem {
  const _DetailItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.progress,
    this.isTags = false,
    this.tags = const [],
    this.isLink = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;
  final bool isTags;
  final List<String> tags;
  final bool isLink;
}

class _DetailListView extends StatelessWidget {
  const _DetailListView({required this.items});
  final List<_DetailItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No details yet',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _DetailCard(item: items[i]),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.item});
  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: item.isTags || item.progress != null
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                if (item.isTags) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: item.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              t,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else if (item.progress != null) ...[
                  Text(
                    item.subtitle,
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 6,
                      backgroundColor: cs.surface,
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  ),
                ] else
                  Text(
                    item.subtitle,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: item.isLink ? cs.primary : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image Source Sheet ────────────────────────────────────────────────────────

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose Photo',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _SourceTile(
              icon: Icons.camera_alt_outlined,
              title: 'Camera',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Photo Library',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: cs.surfaceContainerHighest,
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 14),
              Text(
                title,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
