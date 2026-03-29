import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/repositories/profile_repository.dart';
import 'package:flutter_education_app/logic/services/database_service.dart';
import 'package:flutter_education_app/logic/services/storage_service.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';

// =============================================================================
// ProfileSettingsScreen
//
// Auth:     Supabase  → AuthRepository.currentUser
// Database: Firestore → FirestoreService<ProfileModel>
// Storage:  Supabase  → SupabaseStorageService
//
// Pops `true` on successful save so the caller can refresh.
// =============================================================================

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  // ── Dependencies ───────────────────────────────────────────────────────────

  final _authRepo = AuthRepository();
  final _service = FirestoreService<ProfileModel>(ProfileRepository());
  final _storage = SupabaseStorageService();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  // ── State ──────────────────────────────────────────────────────────────────

  ProfileModel? _profile;
  bool _loading = true;
  String? _loadError;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _dirty = false;

  // ── Controllers ────────────────────────────────────────────────────────────

  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();

  String _gender = 'Prefer not to say';

  static const _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl,
      _usernameCtrl,
      _bioCtrl,
      _phoneCtrl,
      _countryCtrl,
      _cityCtrl,
      _timezoneCtrl,
      _linkedinCtrl,
      _githubCtrl,
      _websiteCtrl,
      _headlineCtrl,
      _yearsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final uid = _authRepo.currentUser?.id;
    if (uid == null) {
      setState(() {
        _loading = false;
        _loadError = 'Not logged in. Please sign in and try again.';
      });
      return;
    }

    try {
      final results = await _service.getAll(
        query: (col) => col.where('user_id', isEqualTo: uid).limit(1),
      );

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _loading = false;
          _loadError = 'Profile not found for this account.';
        });
        return;
      }

      _populateControllers(results.first);
      setState(() {
        _profile = results.first;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[ProfileSettingsScreen] _loadProfile error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  void _populateControllers(ProfileModel p) {
    _fullNameCtrl.text = p.profile.fullName;
    _usernameCtrl.text = p.username;
    _bioCtrl.text = p.profile.bio;
    _phoneCtrl.text = p.phone;
    _countryCtrl.text = p.profile.location.country;
    _cityCtrl.text = p.profile.location.city;
    _timezoneCtrl.text = p.profile.location.timezone;
    _linkedinCtrl.text = p.profile.socialLinks.linkedin;
    _githubCtrl.text = p.profile.socialLinks.github;
    _websiteCtrl.text = p.profile.socialLinks.website;
    _headlineCtrl.text = p.instructorProfile.headline;
    _yearsCtrl.text = p.instructorProfile.yearsOfExperience == 0
        ? ''
        : p.instructorProfile.yearsOfExperience.toString();
    _gender = _genderOptions.contains(p.profile.gender)
        ? p.profile.gender
        : 'Prefer not to say';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [
        _fullNameCtrl,
        _usernameCtrl,
        _bioCtrl,
        _phoneCtrl,
        _countryCtrl,
        _cityCtrl,
        _timezoneCtrl,
        _linkedinCtrl,
        _githubCtrl,
        _websiteCtrl,
        _headlineCtrl,
        _yearsCtrl,
      ]) {
        c.addListener(_markDirty);
      }
    });
  }

  void _markDirty() {
    if (mounted && !_dirty) setState(() => _dirty = true);
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    if (_profile?.id == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
    );
    if (source == null) return;

    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 512,
    );
    if (xfile == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final url = await _storage.uploadAvatar(
        _profile!.userId,
        _profile!.currentMode,
        File(xfile.path),
      );

      await _service.update(_profile!.id!, {'profile.profile_photo': url});

      if (!mounted) return;
      setState(() {
        _profile = _withProfilePhoto(_profile!, url);
        _dirty = true;
      });
      _showSnack('Photo updated ✓');
    } catch (e, st) {
      debugPrint('[ProfileSettingsScreen] _pickAvatar error: $e\n$st');
      _showSnack('Upload failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_profile?.id == null) return;

    setState(() => _saving = true);
    try {
      final update = <String, dynamic>{
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'profile.full_name': _fullNameCtrl.text.trim(),
        'profile.bio': _bioCtrl.text.trim(),
        'profile.gender': _gender,
        'profile.location.country': _countryCtrl.text.trim(),
        'profile.location.city': _cityCtrl.text.trim(),
        'profile.location.timezone': _timezoneCtrl.text.trim(),
        'profile.social_links.linkedin': _linkedinCtrl.text.trim(),
        'profile.social_links.github': _githubCtrl.text.trim(),
        'profile.social_links.website': _websiteCtrl.text.trim(),
        'updated_at': DateTime.now(),
      };

      if (_profile!.currentMode == 'instructor') {
        update['instructor_profile.headline'] = _headlineCtrl.text.trim();
        update['instructor_profile.years_of_experience'] =
            int.tryParse(_yearsCtrl.text.trim()) ?? 0;
      }

      await _service.update(_profile!.id!, update);

      if (!mounted) return;
      setState(() => _dirty = false);
      _showSnack('Changes saved ✓');
      Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('[ProfileSettingsScreen] _save error: $e\n$st');
      _showSnack('Save failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Discard guard ─────────────────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. They will be lost if you leave now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

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

  String _initials(String name) {
    final parts = name.trim().split(' ')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static ProfileModel _withProfilePhoto(ProfileModel p, String url) {
    final old = p.profile;
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
        fullName: old.fullName,
        profilePhoto: url,
        bio: old.bio,
        dateOfBirth: old.dateOfBirth,
        gender: old.gender,
        location: old.location,
        languages: old.languages,
        socialLinks: old.socialLinks,
        coverPhoto: old.coverPhoto,
      ),
      studentProfile: p.studentProfile,
      instructorProfile: p.instructorProfile,
      system: p.system,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: MaterialWidget(
        child: Scaffold(
          appBar: _buildAppBar(),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildError()
              : _buildForm(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.chevron_left_rounded),
        onPressed: () async {
          final ok = await _confirmDiscard();
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
      title: const Text('Edit Profile'),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _saving
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : FilledButton(
                  onPressed: _dirty ? _save : null,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  ),
                  child: const Text('Save'),
                ),
        ),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text('Could not load profile', style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              _loadError!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    final isInstructor = _profile!.currentMode == 'instructor';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildAvatarHero(),
          _SettingsGroup(
            label: 'Personal Info',
            icon: Icons.person_outline_rounded,
            children: [
              _SettingsField(
                label: 'Full Name',
                controller: _fullNameCtrl,
                hint: 'Your display name',
                required: true,
              ),
              _SettingsField(
                label: 'Username',
                controller: _usernameCtrl,
                hint: 'e.g. john_doe',
                required: true,
                prefixText: '@',
              ),
              _SettingsField(
                label: 'Bio',
                controller: _bioCtrl,
                hint: 'A short bio about yourself…',
                maxLines: 3,
              ),
              _SettingsField(
                label: 'Phone',
                controller: _phoneCtrl,
                hint: '+1 234 567 890',
                keyboard: TextInputType.phone,
                icon: Icons.phone_outlined,
              ),
              _GenderTile(
                value: _gender,
                options: _genderOptions,
                onChanged: (v) => setState(() {
                  _gender = v;
                  _dirty = true;
                }),
              ),
            ],
          ),
          _SettingsGroup(
            label: 'Location',
            icon: Icons.location_on_outlined,
            children: [
              _SettingsField(
                label: 'Country',
                controller: _countryCtrl,
                hint: 'e.g. United States',
                icon: Icons.flag_outlined,
              ),
              _SettingsField(
                label: 'City',
                controller: _cityCtrl,
                hint: 'e.g. New York',
                icon: Icons.apartment_outlined,
              ),
              _SettingsField(
                label: 'Timezone',
                controller: _timezoneCtrl,
                hint: 'e.g. America/New_York',
                icon: Icons.schedule_outlined,
              ),
            ],
          ),
          _SettingsGroup(
            label: 'Social Links',
            icon: Icons.link_rounded,
            children: [
              _SettingsField(
                label: 'LinkedIn',
                controller: _linkedinCtrl,
                hint: 'linkedin.com/in/…',
                keyboard: TextInputType.url,
                icon: Icons.work_outline_rounded,
              ),
              _SettingsField(
                label: 'GitHub',
                controller: _githubCtrl,
                hint: 'github.com/…',
                keyboard: TextInputType.url,
                icon: Icons.code_rounded,
              ),
              _SettingsField(
                label: 'Website',
                controller: _websiteCtrl,
                hint: 'https://…',
                keyboard: TextInputType.url,
                icon: Icons.language_rounded,
              ),
            ],
          ),
          if (isInstructor)
            _SettingsGroup(
              label: 'Instructor Details',
              icon: Icons.school_outlined,
              children: [
                _SettingsField(
                  label: 'Headline',
                  controller: _headlineCtrl,
                  hint: 'e.g. Senior Flutter Engineer',
                  required: true,
                  icon: Icons.badge_outlined,
                ),
                _SettingsField(
                  label: 'Years of Experience',
                  controller: _yearsCtrl,
                  hint: 'e.g. 5',
                  keyboard: TextInputType.number,
                  icon: Icons.workspace_premium_outlined,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ── Avatar hero ───────────────────────────────────────────────────────────

  Widget _buildAvatarHero() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final info = _profile!.profile;
    final name = info.fullName.isNotEmpty ? info.fullName : _profile!.username;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: _uploadingAvatar ? null : _pickAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.outlineVariant, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: info.profilePhoto.isNotEmpty
                        ? NetworkImage(info.profilePhoto)
                        : null,
                    child: _uploadingAvatar
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimaryContainer,
                          )
                        : info.profilePhoto.isEmpty
                        ? Text(
                            _initials(name),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : null,
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

          const SizedBox(width: 20),

          // Name + tap hint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${_profile!.username}',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _uploadingAvatar ? null : _pickAvatar,
                  child: Text(
                    'Change photo',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
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

// =============================================================================
// _ImageSourceSheet
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
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Update Photo',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
              title: Text(
                'Cancel',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              onTap: () => Navigator.pop(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _SettingsGroup  — labelled card section
// =============================================================================

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.label,
    required this.icon,
    required this.children,
  });

  final String label;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(icon, size: 15, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // Card containing fields
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              children: List.generate(children.length * 2 - 1, (i) {
                if (i.isEven) return children[i ~/ 2];
                return Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SettingsField  — a single form row inside a group card
// =============================================================================

class _SettingsField extends StatelessWidget {
  const _SettingsField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    this.required = false,
    this.icon,
    this.prefixText,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType keyboard;
  final bool required;
  final IconData? icon;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          // Leading icon or spacer
          SizedBox(
            width: 36,
            child: icon != null
                ? Padding(
                    padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
                    child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
                  )
                : null,
          ),

          // Text field
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboard,
              inputFormatters: inputFormatters,
              style: tt.bodyMedium,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                hintStyle: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(.5),
                ),
                prefixText: prefixText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                labelStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                floatingLabelStyle: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              validator: required
                  ? (v) => (v == null || v.trim().isEmpty)
                        ? '$label is required'
                        : null
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _GenderTile  — dropdown row, styled to match _SettingsField
// =============================================================================

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                labelStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                floatingLabelStyle: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: Icon(
                Icons.unfold_more_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              style: tt.bodyMedium?.copyWith(color: cs.onSurface),
              dropdownColor: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              items: options
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}
