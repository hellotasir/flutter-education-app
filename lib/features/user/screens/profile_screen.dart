import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_education_app/features/app/screens/home_screen.dart';
import 'package:flutter_education_app/features/user/models/profile_model.dart';
import 'package:flutter_education_app/features/app/repositories/auth_repository.dart';
import 'package:flutter_education_app/others/routers/app_navigator.dart';
import 'package:flutter_education_app/features/app/screens/settings_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_education_app/features/user/repositories/profile_repository.dart';
import 'package:flutter_education_app/others/services/database_service.dart';
import 'package:flutter_education_app/others/services/storage_service.dart';
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
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final info = profile.profile;
    final isInstructor = profile.currentMode == 'instructor';

    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        _ProfileAppBar(
          info: info,
          isOwnProfile: isOwnProfile,
          uploadingCover: uploadingCover,
          onChangeCover: onChangeCover,
          onOpenSettings: onOpenSettings,
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IdentityCard(
                profile: profile,
                info: info,
                isOwnProfile: isOwnProfile,
                uploadingAvatar: uploadingAvatar,
                onChangeAvatar: onChangeAvatar,
                initials: initials,
              ),
              if (info.bio.isNotEmpty) ...[
                _divider(context),
                _BioSection(bio: info.bio),
              ],
              if (_hasLocationData(info)) ...[
                _divider(context),
                _MetaSection(info: info),
              ],
              if (_hasSocialLinks(info)) ...[
                _divider(context),
                _SocialSection(info: info),
              ],
              _divider(context),
              if (isInstructor)
                _InstructorSection(instructorProfile: profile.instructorProfile)
              else
                _StudentSection(
                  studentProfile: profile.studentProfile,
                  capitalize: capitalize,
                ),
              if (isOwnProfile && _hasPersonalInfo(profile, info)) ...[
                _divider(context),
                _PersonalInfoSection(profile: profile, info: info),
              ],
              const SizedBox(height: 56),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      color: Theme.of(context).colorScheme.outlineVariant,
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
    );
  }

  static bool _hasLocationData(ProfileInfo info) =>
      info.location.city.isNotEmpty ||
      info.location.country.isNotEmpty ||
      info.languages.isNotEmpty ||
      info.location.timezone.isNotEmpty;

  static bool _hasSocialLinks(ProfileInfo info) =>
      info.socialLinks.linkedin.isNotEmpty ||
      info.socialLinks.github.isNotEmpty ||
      info.socialLinks.website.isNotEmpty;

  static bool _hasPersonalInfo(ProfileModel p, ProfileInfo info) =>
      p.email.isNotEmpty ||
      p.phone.isNotEmpty ||
      (info.gender.isNotEmpty && info.gender != 'Prefer not to say');
}

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({
    required this.info,
    required this.isOwnProfile,
    required this.uploadingCover,
    required this.onChangeCover,
    required this.onOpenSettings,
  });

  final ProfileInfo info;
  final bool isOwnProfile;
  final bool uploadingCover;
  final VoidCallback onChangeCover;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: cs.surface,
      leading: _GlassIconButton(
        icon: Icons.chevron_left_rounded,
        onTap: () {
          AppNavigator(screen: HomeScreen()).navigate(context);
        },
      ),
      actions: [
        if (isOwnProfile) ...[
          _GlassIconButton(
            icon: Icons.settings_outlined,
            onTap: onOpenSettings,
          ),
          const SizedBox(width: 8),
        ],
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

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
                  errorBuilder: (_, __, ___) =>
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

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.info,
    required this.isOwnProfile,
    required this.uploadingAvatar,
    required this.onChangeAvatar,
    required this.initials,
  });

  final ProfileModel profile;
  final ProfileInfo info;
  final bool isOwnProfile;
  final bool uploadingAvatar;
  final VoidCallback onChangeAvatar;
  final String Function(String) initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = info.fullName.isNotEmpty ? info.fullName : profile.username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: isOwnProfile ? onChangeAvatar : null,
                child: _Avatar(
                  photoUrl: info.profilePhoto,
                  name: name,
                  uploading: uploadingAvatar,
                  isOwnProfile: isOwnProfile,
                  initials: initials,
                ),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '@${profile.username}',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 5),
                Icon(Icons.verified_rounded, size: 14, color: cs.primary),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _ModeBadge(mode: profile.currentMode),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.photoUrl,
    required this.name,
    required this.uploading,
    required this.isOwnProfile,
    required this.initials,
  });

  final String photoUrl;
  final String name;
  final bool uploading;
  final bool isOwnProfile;
  final String Function(String) initials;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cs.surface, width: 3),
          ),
          child: CircleAvatar(
            radius: 44,
            backgroundColor: cs.primaryContainer,
            key: ValueKey(photoUrl),
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: uploading
                ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onPrimaryContainer,
                  )
                : photoUrl.isEmpty
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
          Container(
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
      ],
    );
  }
}

class _BioSection extends StatelessWidget {
  const _BioSection({required this.bio});
  final String bio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Text(
        bio,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.65),
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.info});
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cityCountry = [
      info.location.city,
      info.location.country,
    ].where((s) => s.isNotEmpty).join(', ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (cityCountry.isNotEmpty)
            Chip(
              avatar: Icon(
                Icons.location_on_outlined,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              label: Text(cityCountry),
              labelStyle: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          if (info.languages.isNotEmpty)
            Chip(
              avatar: Icon(
                Icons.translate_rounded,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              label: Text(info.languages.join(', ')),
              labelStyle: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: cs.surfaceContainerHighest,
            ),
          if (info.location.timezone.isNotEmpty)
            Chip(
              avatar: Icon(
                Icons.schedule_outlined,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              label: Text(info.location.timezone),
              labelStyle: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: cs.surfaceContainerHighest,
            ),
        ],
      ),
    );
  }
}

class _SocialSection extends StatelessWidget {
  const _SocialSection({required this.info});
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
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
            ),
          if (info.socialLinks.github.isNotEmpty)
            ActionChip(
              avatar: Icon(Icons.code_rounded, size: 14, color: cs.primary),
              label: const Text('GitHub'),
              onPressed: () {},
              side: BorderSide(color: cs.outlineVariant),
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
            ),
          if (info.socialLinks.website.isNotEmpty)
            ActionChip(
              avatar: Icon(Icons.language_rounded, size: 14, color: cs.primary),
              label: const Text('Website'),
              onPressed: () {},
              side: BorderSide(color: cs.outlineVariant),
              backgroundColor: Colors.transparent,
              shape: const StadiumBorder(),
            ),
        ],
      ),
    );
  }
}

class _InstructorSection extends StatelessWidget {
  const _InstructorSection({required this.instructorProfile});
  final InstructorProfile instructorProfile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (instructorProfile.headline.isNotEmpty)
          _CardSection(
            label: 'Instructor',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instructorProfile.headline,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (instructorProfile.yearsOfExperience > 0) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      Icons.workspace_premium_outlined,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    label: Text(
                      '${instructorProfile.yearsOfExperience} yrs experience',
                    ),
                    labelStyle: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    backgroundColor: cs.surfaceContainerHighest,
                  ),
                ],
              ],
            ),
          ),
        if (instructorProfile.expertise.isNotEmpty) ...[
          Divider(
            color: cs.outlineVariant,
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
          _CardSection(
            label: 'Areas of Expertise',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: instructorProfile.expertise
                  .map(
                    (e) => Chip(
                      label: Text(e),
                      labelStyle: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _StudentSection extends StatelessWidget {
  const _StudentSection({
    required this.studentProfile,
    required this.capitalize,
  });
  final StudentProfile studentProfile;
  final String Function(String) capitalize;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _CardSection(
      label: 'Learning',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilterChip(
            avatar: Icon(
              Icons.bar_chart_rounded,
              size: 14,
              color: cs.onPrimaryContainer,
            ),
            label: Text(capitalize(studentProfile.currentLevel)),
            labelStyle: tt.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
            selected: true,
            onSelected: (_) {},
            selectedColor: cs.primaryContainer,
            checkmarkColor: cs.onPrimaryContainer,
            showCheckmark: false,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
          if (studentProfile.interests.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: studentProfile.interests
                  .map(
                    (i) => Chip(
                      label: Text(i),
                      labelStyle: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonalInfoSection extends StatelessWidget {
  const _PersonalInfoSection({required this.profile, required this.info});
  final ProfileModel profile;
  final ProfileInfo info;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return _CardSection(
      label: 'Contact',
      child: Column(
        children: [
          if (profile.email.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              title: Text(profile.email, style: tt.bodyMedium),
            ),
          if (profile.phone.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.phone_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              title: Text(profile.phone, style: tt.bodyMedium),
            ),
          if (info.gender.isNotEmpty && info.gender != 'Prefer not to say')
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
              title: Text(info.gender, style: tt.bodyMedium),
            ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (mode) {
      'instructor' => cs.tertiary,
      'admin' => cs.error,
      _ => cs.primary,
    };
    final icon = switch (mode) {
      'instructor' => Icons.school_outlined,
      'admin' => Icons.admin_panel_settings_outlined,
      _ => Icons.person_outline_rounded,
    };
    final label = mode.isEmpty
        ? '?'
        : mode[0].toUpperCase() + mode.substring(1);

    return RawChip(
      avatar: Icon(icon, size: 12, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      onPressed: null,
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Photo',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: cs.onSurface,
                  size: 20,
                ),
              ),
              title: const Text('Take a photo'),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 2,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: cs.onSurface,
                  size: 20,
                ),
              ),
              title: const Text('Choose from library'),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
