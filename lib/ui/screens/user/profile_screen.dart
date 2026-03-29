import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/repositories/profile_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/logic/services/database_service.dart';
import 'package:flutter_education_app/logic/services/storage_service.dart';
import 'package:flutter_education_app/ui/screens/app/settings_screen.dart';
import 'package:flutter_education_app/ui/screens/user/settings/profile_settings_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';

// =============================================================================
// ProfileScreen
//
// Bug fixes vs previous version:
//   1. Cover photo URL is now saved to Firestore and applied to local state.
//      ProfileInfo gains a `coverPhoto` field (see profile_model.dart).
//   2. Avatar/cover NetworkImage URLs carry a `_cb` cache-buster query param
//      and the old image is evicted from Flutter's ImageCache so the widget
//      always renders the newly uploaded file even when the storage path
//      (and therefore the base URL) hasn't changed.
// =============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authRepo = AuthRepository();
  final _service = FirestoreService<ProfileModel>(ProfileRepository());
  final _storage = SupabaseStorageService();
  final _picker = ImagePicker();

  ProfileModel? _profile;
  bool _loading = true;
  String? _errorMessage;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  String? get _currentUserId => _authRepo.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadOrCreateProfile();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadOrCreateProfile() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final uid = _currentUserId;
    if (uid == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'Not logged in. Please sign in and try again.';
      });
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
      } else {
        await _createDefaultProfile(uid);
      }
    } catch (e, st) {
      debugPrint('[ProfileScreen] _loadOrCreateProfile error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Something went wrong: ${e.toString()}';
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
  }

  // ── Photo pickers ─────────────────────────────────────────────────────────

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
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

  // FIX 1 — Avatar cache-busting
  // Supabase upserts to the same path, so the public URL string is identical
  // after upload. Flutter's ImageCache would keep serving the old bitmap.
  // Fix: evict the old URL, then append a `_cb` timestamp to the new URL so
  // the cache treats it as a brand-new image and re-fetches from the network.
  Future<void> _changeAvatar() async {
    final file = await _pickImage();
    if (file == null || _profile?.id == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final rawUrl = await _storage.uploadAvatar(
        _profile!.userId,
        _profile!.currentMode,
        file,
      );

      // Evict the stale image so Flutter fetches the new bytes.
      final oldUrl = _profile!.profile.profilePhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();

      final freshUrl = _cacheBust(rawUrl);

      await _service.update(_profile!.id!, {'profile.profile_photo': freshUrl});

      if (!mounted) return;
      setState(() => _profile = _withProfilePhoto(_profile!, freshUrl));
      _showSnack('Profile photo updated ✓');
    } catch (e, st) {
      debugPrint('[ProfileScreen] _changeAvatar error: $e\n$st');
      _showSnack('Upload failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // FIX 2 — Cover photo URL was discarded
  // Previously: `await _storage.uploadCoverPhoto(...)` — return value ignored,
  // nothing written to Firestore, state never updated, widget never rebuilt.
  Future<void> _changeCover() async {
    final file = await _pickImage();
    if (file == null || _profile?.id == null) return;

    setState(() => _uploadingCover = true);
    try {
      final rawUrl = await _storage.uploadCoverPhoto(_profile!.userId, file);

      final oldUrl = _profile!.profile.coverPhoto;
      if (oldUrl.isNotEmpty) await NetworkImage(oldUrl).evict();

      final freshUrl = _cacheBust(rawUrl);

      // Persist to Firestore.
      await _service.update(_profile!.id!, {'profile.cover_photo': freshUrl});

      if (!mounted) return;
      // Apply to local state so the header re-renders immediately.
      setState(() => _profile = _withCoverPhoto(_profile!, freshUrl));
      _showSnack('Cover photo updated ✓');
    } catch (e, st) {
      debugPrint('[ProfileScreen] _changeCover error: $e\n$st');
      _showSnack('Upload failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  // ── Mode switch ───────────────────────────────────────────────────────────

  Future<void> _switchMode() async {
    if (_profile?.id == null) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => _ModeSwitchDialog(
        currentMode: _profile!.currentMode,
        availableModes: _profile!.availableModes,
      ),
    );
    if (selected == null || selected == _profile!.currentMode) return;

    try {
      await _service.update(_profile!.id!, {'current_mode': selected});
      if (!mounted) return;
      setState(() => _profile = _withCurrentMode(_profile!, selected));
      _showSnack('Switched to ${_label(selected)} mode');
    } catch (e, st) {
      debugPrint('[ProfileScreen] _switchMode error: $e\n$st');
      _showSnack('Could not switch mode: ${e.toString()}', error: true);
    }
  }

  // ── Cache-buster ──────────────────────────────────────────────────────────

  static String _cacheBust(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return uri
        .replace(queryParameters: {...uri.queryParameters, '_cb': '$ts'})
        .toString();
  }

  // ── Model rebuild helpers ─────────────────────────────────────────────────

  static ProfileModel _withProfilePhoto(ProfileModel p, String url) {
    final o = p.profile;
    return _rebuildWith(
      p,
      ProfileInfo(
        fullName: o.fullName,
        profilePhoto: url,
        coverPhoto: o.coverPhoto,
        bio: o.bio,
        dateOfBirth: o.dateOfBirth,
        gender: o.gender,
        location: o.location,
        languages: o.languages,
        socialLinks: o.socialLinks,
      ),
    );
  }

  static ProfileModel _withCoverPhoto(ProfileModel p, String url) {
    final o = p.profile;
    return _rebuildWith(
      p,
      ProfileInfo(
        fullName: o.fullName,
        profilePhoto: o.profilePhoto,
        coverPhoto: url,
        bio: o.bio,
        dateOfBirth: o.dateOfBirth,
        gender: o.gender,
        location: o.location,
        languages: o.languages,
        socialLinks: o.socialLinks,
      ),
    );
  }

  static ProfileModel _withCurrentMode(ProfileModel p, String mode) =>
      ProfileModel(
        id: p.id,
        userId: p.userId,
        username: p.username,
        email: p.email,
        phone: p.phone,
        passwordHash: p.passwordHash,
        currentMode: mode,
        availableModes: p.availableModes,
        isVerified: p.isVerified,
        status: p.status,
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
        lastLogin: p.lastLogin,
        profile: p.profile,
        studentProfile: p.studentProfile,
        instructorProfile: p.instructorProfile,
        system: p.system,
      );

  static ProfileModel _rebuildWith(ProfileModel p, ProfileInfo info) =>
      ProfileModel(
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
        profile: info,
        studentProfile: p.studentProfile,
        instructorProfile: p.instructorProfile,
        system: p.system,
      );

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _initials(String name) {
    final parts = name.trim().split(' ')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  bool _hasSocial(SocialLinks s) =>
      s.linkedin.isNotEmpty || s.github.isNotEmpty || s.website.isNotEmpty;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildError()
            : _buildBody(),
      ),
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_rounded,
              size: 64,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Could not load profile', style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadOrCreateProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = _profile!;
    final info = p.profile;
    final isInstructor = p.currentMode == 'instructor';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          stretch: true,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () => AppNavigator(
                screen: const SettingsScreen(),
              ).navigate(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [
              StretchMode.zoomBackground,
              StretchMode.blurBackground,
            ],
            background: _buildHeader(cs, info),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        info.fullName.isNotEmpty ? info.fullName : p.username,
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ModeBadge(
                      mode: p.currentMode,
                      canSwitch: p.availableModes.length > 1,
                      onTap: p.availableModes.length > 1 ? _switchMode : null,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '@${p.username}',
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (p.isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.verified_rounded, size: 15, color: cs.primary),
                    ],
                  ],
                ),
                if (info.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(info.bio, style: tt.bodyMedium),
                ],
                if (info.location.city.isNotEmpty ||
                    info.location.country.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _IconRow(
                    icon: Icons.location_on_rounded,
                    label: [
                      info.location.city,
                      info.location.country,
                    ].where((s) => s.isNotEmpty).join(', '),
                  ),
                ],
                if (info.languages.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _IconRow(
                    icon: Icons.translate_rounded,
                    label: info.languages.join(', '),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                if (isInstructor && p.instructorProfile.headline.isNotEmpty)
                  _InfoCard(
                    icon: Icons.school_rounded,
                    title: 'Instructor',
                    subtitle: p.instructorProfile.headline,
                    trailing: p.instructorProfile.yearsOfExperience > 0
                        ? '${p.instructorProfile.yearsOfExperience} yrs'
                        : null,
                  ),
                if (isInstructor &&
                    p.instructorProfile.expertise.isNotEmpty) ...[
                  Text(
                    'Expertise',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.instructorProfile.expertise
                        .map(
                          (e) => Chip(
                            label: Text(e),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (!isInstructor && p.studentProfile.currentLevel.isNotEmpty)
                  _InfoCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Level',
                    subtitle: _label(p.studentProfile.currentLevel),
                  ),
                if (!isInstructor && p.studentProfile.interests.isNotEmpty) ...[
                  Text(
                    'Interests',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.studentProfile.interests
                        .map(
                          (i) => Chip(
                            label: Text(i),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_hasSocial(info.socialLinks)) ...[
                  _SocialRow(links: info.socialLinks),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => AppNavigator(
                      screen: const ProfileSettingsScreen(),
                    ).navigate(context),
                    child: const Text('Edit Profile'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Cover + floating avatar ───────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs, ProfileInfo info) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover — renders the stored coverPhoto URL; falls back to theme colour.
        Positioned.fill(
          child: info.coverPhoto.isNotEmpty
              ? Image.network(
                  info.coverPhoto,
                  fit: BoxFit.cover,
                  // ValueKey forces a widget rebuild when the URL string changes.
                  key: ValueKey(info.coverPhoto),
                )
              : Container(color: cs.secondaryContainer),
        ),

        if (_uploadingCover)
          Positioned.fill(
            child: Container(
              color: cs.scrim.withOpacity(.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),

        Positioned(
          right: 12,
          bottom: 72,
          child: _UploadChip(
            label: 'Edit Cover',
            loading: _uploadingCover,
            onTap: _changeCover,
          ),
        ),

        // Floating avatar
        Positioned(
          left: 20,
          bottom: -46,
          child: GestureDetector(
            onTap: _changeAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 46,
                    backgroundColor: cs.primaryContainer,
                    // ValueKey forces rebuild when the cache-busted URL changes.
                    key: ValueKey(info.profilePhoto),
                    backgroundImage: info.profilePhoto.isNotEmpty
                        ? NetworkImage(info.profilePhoto)
                        : null,
                    child: info.profilePhoto.isEmpty
                        ? Text(
                            _initials(
                              info.fullName.isNotEmpty ? info.fullName : 'U',
                            ),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                ),
                if (_uploadingAvatar)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black45,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: 13,
                    color: cs.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Private widgets
// =============================================================================

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
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose Photo',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            _SourceTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from library',
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            _SourceTile(
              icon: Icons.close_rounded,
              label: 'Cancel',
              muted: true,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.muted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ModeSwitchDialog extends StatefulWidget {
  const _ModeSwitchDialog({
    required this.currentMode,
    required this.availableModes,
  });
  final String currentMode;
  final List<String> availableModes;

  @override
  State<_ModeSwitchDialog> createState() => _ModeSwitchDialogState();
}

class _ModeSwitchDialogState extends State<_ModeSwitchDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMode;
  }

  String _label(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  IconData _icon(String mode) => switch (mode) {
    'instructor' => Icons.school_rounded,
    'admin' => Icons.admin_panel_settings_rounded,
    _ => Icons.person_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Switch Mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: widget.availableModes
            .map(
              (mode) => RadioListTile<String>(
                value: mode,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
                title: Text(_label(mode)),
                secondary: Icon(
                  _icon(mode),
                  color: _selected == mode ? cs.primary : cs.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Switch'),
        ),
      ],
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode, required this.canSwitch, this.onTap});
  final String mode;
  final bool canSwitch;
  final VoidCallback? onTap;

  Color _color(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    return switch (mode) {
      'instructor' => cs.tertiary,
      'admin' => cs.error,
      _ => cs.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final label = mode.isEmpty
        ? '?'
        : mode[0].toUpperCase() + mode.substring(1);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (canSwitch) ...[
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 15, color: cs.onSurfaceVariant),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: tt.bodyMedium),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: tt.labelMedium?.copyWith(color: cs.primary)),
          ],
        ],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.links});
  final SocialLinks links;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (links.linkedin.isNotEmpty)
          IconButton.filledTonal(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'LinkedIn',
            onPressed: () {},
          ),
        if (links.github.isNotEmpty)
          IconButton.filledTonal(
            icon: const Icon(Icons.code_rounded),
            tooltip: 'GitHub',
            onPressed: () {},
          ),
        if (links.website.isNotEmpty)
          IconButton.filledTonal(
            icon: const Icon(Icons.language_rounded),
            tooltip: 'Website',
            onPressed: () {},
          ),
      ],
    );
  }
}

class _UploadChip extends StatelessWidget {
  const _UploadChip({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.camera_alt_rounded,
                size: 13,
                color: Colors.white,
              ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
