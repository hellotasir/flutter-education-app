import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_education_app/features/user/models/profile_model.dart';
import 'package:flutter_education_app/features/user/repositories/profile_repository.dart';
import 'package:flutter_education_app/others/services/database_service.dart';
import 'package:flutter_education_app/features/app/widgets/material_widget.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key, required this.profile});

  final ProfileModel profile;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _service = FirestoreService<ProfileModel>(ProfileRepository());
  final _formKey = GlobalKey<FormState>();

  late String _selectedMode;
  bool _saving = false;
  bool _dirty = false;

  final _fullNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _timezoneCtrl = TextEditingController();
  final _languagesCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _githubCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _headlineCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();
  final _interestsCtrl = TextEditingController();
  final _levelCtrl = TextEditingController();

  String _gender = 'Prefer not to say';

  static const _genderOptions = ['Male', 'Female'];
  static const _levelOptions = ['beginner', 'intermediate', 'advanced'];
  static const _modeOptions = ['student', 'instructor'];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.profile.currentMode;
    _populate(widget.profile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in _allControllers) {
        c.addListener(_markDirty);
      }
    });
  }

  @override
  void dispose() {
    for (final c in _allControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _allControllers => [
    _fullNameCtrl,
    _usernameCtrl,
    _bioCtrl,
    _phoneCtrl,
    _countryCtrl,
    _cityCtrl,
    _timezoneCtrl,
    _languagesCtrl,
    _linkedinCtrl,
    _githubCtrl,
    _websiteCtrl,
    _headlineCtrl,
    _yearsCtrl,
    _expertiseCtrl,
    _interestsCtrl,
    _levelCtrl,
  ];

  void _populate(ProfileModel p) {
    _fullNameCtrl.text = p.profile.fullName;
    _usernameCtrl.text = p.username;
    _bioCtrl.text = p.profile.bio;
    _phoneCtrl.text = p.phone;
    _countryCtrl.text = p.profile.location.country;
    _cityCtrl.text = p.profile.location.city;
    _timezoneCtrl.text = p.profile.location.timezone;
    _languagesCtrl.text = p.profile.languages.join(', ');
    _linkedinCtrl.text = p.profile.socialLinks.linkedin;
    _githubCtrl.text = p.profile.socialLinks.github;
    _websiteCtrl.text = p.profile.socialLinks.website;
    _headlineCtrl.text = p.instructorProfile.headline;
    _yearsCtrl.text = p.instructorProfile.yearsOfExperience == 0
        ? ''
        : p.instructorProfile.yearsOfExperience.toString();
    _expertiseCtrl.text = p.instructorProfile.expertise.join(', ');
    _interestsCtrl.text = p.studentProfile.interests.join(', ');
    _levelCtrl.text = p.studentProfile.currentLevel;
    _gender = _genderOptions.contains(p.profile.gender)
        ? p.profile.gender
        : 'Prefer not to say';
  }

  void _markDirty() {
    if (mounted && !_dirty) setState(() => _dirty = true);
  }

  List<String> _splitComma(String s) =>
      s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.profile.id == null) return;

    setState(() => _saving = true);
    try {
      final newMode = _selectedMode;
      final updatedModes = {...widget.profile.availableModes, newMode}.toList();

      final update = <String, dynamic>{
        'current_mode': newMode,
        'available_modes': updatedModes,
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'profile.full_name': _fullNameCtrl.text.trim(),
        'profile.bio': _bioCtrl.text.trim(),
        'profile.gender': _gender,
        'profile.languages': _splitComma(_languagesCtrl.text),
        'profile.location.country': _countryCtrl.text.trim(),
        'profile.location.city': _cityCtrl.text.trim(),
        'profile.location.timezone': _timezoneCtrl.text.trim(),
        'profile.social_links.linkedin': _linkedinCtrl.text.trim(),
        'profile.social_links.github': _githubCtrl.text.trim(),
        'profile.social_links.website': _websiteCtrl.text.trim(),
        'instructor_profile.headline': _headlineCtrl.text.trim(),
        'instructor_profile.years_of_experience':
            int.tryParse(_yearsCtrl.text.trim()) ?? 0,
        'instructor_profile.expertise': _splitComma(_expertiseCtrl.text),
        'student_profile.interests': _splitComma(_interestsCtrl.text),
        'student_profile.current_level': _levelCtrl.text.trim().isNotEmpty
            ? _levelCtrl.text.trim()
            : 'beginner',
        'updated_at': DateTime.now(),
      };

      await _service.update(widget.profile.id!, update);

      final p = widget.profile;
      final updated = ProfileModel(
        id: p.id,
        userId: p.userId,
        username: _usernameCtrl.text.trim(),
        email: p.email,
        phone: _phoneCtrl.text.trim(),
        passwordHash: p.passwordHash,
        currentMode: newMode,
        availableModes: updatedModes,
        isVerified: p.isVerified,
        status: p.status,
        createdAt: p.createdAt,
        updatedAt: DateTime.now(),
        lastLogin: p.lastLogin,
        profile: ProfileInfo(
          fullName: _fullNameCtrl.text.trim(),
          profilePhoto: p.profile.profilePhoto,
          coverPhoto: p.profile.coverPhoto,
          bio: _bioCtrl.text.trim(),
          dateOfBirth: p.profile.dateOfBirth,
          gender: _gender,
          location: Location(
            country: _countryCtrl.text.trim(),
            city: _cityCtrl.text.trim(),
            timezone: _timezoneCtrl.text.trim(),
          ),
          languages: _splitComma(_languagesCtrl.text),
          socialLinks: SocialLinks(
            linkedin: _linkedinCtrl.text.trim(),
            github: _githubCtrl.text.trim(),
            website: _websiteCtrl.text.trim(),
          ),
        ),
        studentProfile: StudentProfile(
          isActive: p.studentProfile.isActive,
          interests: _splitComma(_interestsCtrl.text),
          currentLevel: _levelCtrl.text.trim().isNotEmpty
              ? _levelCtrl.text.trim()
              : 'beginner',
        ),
        instructorProfile: InstructorProfile(
          isActive: newMode == 'instructor',
          headline: _headlineCtrl.text.trim(),
          expertise: _splitComma(_expertiseCtrl.text),
          yearsOfExperience: int.tryParse(_yearsCtrl.text.trim()) ?? 0,
        ),
        system: p.system,
      );

      if (!mounted) return;
      setState(() => _dirty = false);
      Navigator.pop(context, updated);
    } catch (e, st) {
      debugPrint('[ProfileSettingsScreen] save error: $e\n$st');
      _showSnack('Save failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () async {
                final ok = await _confirmDiscard();
                if (ok && context.mounted) Navigator.pop(context);
              },
            ),
            title: const Text('Edit Profile'),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: _dirty ? _save : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          shape: const StadiumBorder(),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 60),
              children: [
                const SizedBox(height: 20),
                _buildModeSection(),
                _SectionLabel(label: 'Personal Info'),
                _SlimField(
                  label: 'Full Name',
                  controller: _fullNameCtrl,
                  hint: 'Your display name',
                  required: true,
                ),
                _SlimField(
                  label: 'Username',
                  controller: _usernameCtrl,
                  hint: 'john_doe',
                  required: true,
                  prefixText: '@',
                ),
                _SlimField(
                  label: 'Bio',
                  controller: _bioCtrl,
                  hint: 'A short bio about yourself…',
                  maxLines: 3,
                ),
                _SlimField(
                  label: 'Phone',
                  controller: _phoneCtrl,
                  hint: '+1 234 567 890',
                  keyboard: TextInputType.phone,
                ),
                _GenderSelector(
                  value: _gender,
                  options: _genderOptions,
                  onChanged: (v) => setState(() {
                    _gender = v;
                    _dirty = true;
                  }),
                ),
                _SectionLabel(label: 'Location'),
                _SlimField(
                  label: 'Country',
                  controller: _countryCtrl,
                  hint: 'United States',
                ),
                _SlimField(
                  label: 'City',
                  controller: _cityCtrl,
                  hint: 'New York',
                ),
                _SlimField(
                  label: 'Timezone',
                  controller: _timezoneCtrl,
                  hint: 'America/New_York',
                ),
                _SlimField(
                  label: 'Languages',
                  controller: _languagesCtrl,
                  hint: 'English, Spanish…',
                  helperText: 'Comma-separated',
                ),
                _SectionLabel(label: 'Social Links'),
                _SlimField(
                  label: 'LinkedIn',
                  controller: _linkedinCtrl,
                  hint: 'linkedin.com/in/…',
                  keyboard: TextInputType.url,
                  prefixIcon: Icons.work_outline_rounded,
                ),
                _SlimField(
                  label: 'GitHub',
                  controller: _githubCtrl,
                  hint: 'github.com/…',
                  keyboard: TextInputType.url,
                  prefixIcon: Icons.code_rounded,
                ),
                _SlimField(
                  label: 'Website',
                  controller: _websiteCtrl,
                  hint: 'https://…',
                  keyboard: TextInputType.url,
                  prefixIcon: Icons.language_rounded,
                ),
                if (_selectedMode == 'instructor') ...[
                  _SectionLabel(label: 'Instructor Details'),
                  _SlimField(
                    label: 'Headline',
                    controller: _headlineCtrl,
                    hint: 'Senior Flutter Engineer',
                    required: true,
                  ),
                  _SlimField(
                    label: 'Years of Experience',
                    controller: _yearsCtrl,
                    hint: '5',
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  _SlimField(
                    label: 'Expertise',
                    controller: _expertiseCtrl,
                    hint: 'Flutter, Dart, Firebase…',
                    helperText: 'Comma-separated',
                    maxLines: 2,
                  ),
                ] else ...[
                  _SectionLabel(label: 'Student Details'),
                  _LevelSelector(
                    value: _levelOptions.contains(_levelCtrl.text)
                        ? _levelCtrl.text
                        : 'beginner',
                    options: _levelOptions,
                    onChanged: (v) => setState(() {
                      _levelCtrl.text = v;
                      _dirty = true;
                    }),
                  ),
                  _SlimField(
                    label: 'Interests',
                    controller: _interestsCtrl,
                    hint: 'Flutter, Design, AI…',
                    helperText: 'Comma-separated',
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSection() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'ACCOUNT TYPE',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SegmentedButton<String>(
            segments: _modeOptions.map((mode) {
              final icon = mode == 'instructor'
                  ? Icons.school_outlined
                  : Icons.person_outline_rounded;
              return ButtonSegment<String>(
                value: mode,
                label: Text(mode[0].toUpperCase() + mode.substring(1)),
                icon: Icon(icon, size: 16),
              );
            }).toList(),
            selected: {_selectedMode},
            onSelectionChanged: (selection) {
              final picked = selection.first;
              if (_selectedMode != picked) {
                setState(() {
                  _selectedMode = picked;
                  _dirty = true;
                });
              }
            },
            style: ButtonStyle(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          if (_selectedMode != widget.profile.currentMode)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Switching will update your active role on save.',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gender',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option;
              return ChoiceChip(
                label: Text(option),
                selected: selected,
                onSelected: (_) => onChanged(option),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: cs.outlineVariant),
              );
            }).toList(),
          ),
          Divider(color: cs.outlineVariant, height: 1, thickness: 1, indent: 0),
        ],
      ),
    );
  }
}

class _LevelSelector extends StatelessWidget {
  const _LevelSelector({
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

    final icons = {
      'beginner': Icons.star_outline_rounded,
      'intermediate': Icons.star_half_rounded,
      'advanced': Icons.star_rounded,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final selected = value == option;
              return ChoiceChip(
                avatar: Icon(
                  icons[option] ?? Icons.star_outline_rounded,
                  size: 14,
                  color: selected
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
                label: Text(option[0].toUpperCase() + option.substring(1)),
                selected: selected,
                onSelected: (_) => onChanged(option),
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                side: selected
                    ? BorderSide.none
                    : BorderSide(color: cs.outlineVariant),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant, height: 1, thickness: 1, indent: 0),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SlimField extends StatelessWidget {
  const _SlimField({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboard = TextInputType.text,
    this.required = false,
    this.prefixText,
    this.helperText,
    this.inputFormatters,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType keyboard;
  final bool required;
  final String? prefixText;
  final String? helperText;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        style: tt.bodyMedium,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
          helperText: helperText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 16, color: cs.onSurfaceVariant)
              : null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 36,
          ),
          hintStyle: tt.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant.withOpacity(0.4),
          ),
          labelStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          floatingLabelStyle: tt.labelSmall?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w600,
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.outlineVariant, width: 1),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          errorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.error, width: 1),
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: cs.error, width: 1.5),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.only(top: 12, bottom: 10),
        ),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}
