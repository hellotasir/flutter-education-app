import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/view_models/profile_settings_view_model.dart';
import 'package:provider/provider.dart';

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileSettingsViewModel(),
      child: const _ProfileSettingsView(),
    );
  }
}

class _ProfileSettingsView extends StatefulWidget {
  const _ProfileSettingsView();

  @override
  State<_ProfileSettingsView> createState() => _ProfileSettingsViewState();
}

class _ProfileSettingsViewState extends State<_ProfileSettingsView> {
  final _usernameCtrl = TextEditingController();

  late ProfileSettingsViewModel _vm;
  late VoidCallback _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _vm = context.read<ProfileSettingsViewModel>();

    _listener = _syncController;
    _vm.removeListener(_listener);
    _vm.addListener(_listener);
  }

  void _syncController() {
    if (!mounted) return;

    if (_vm.saved != null && _usernameCtrl.text.isEmpty) {
      _usernameCtrl.text = _vm.saved!.username;
    }

    if (_vm.saveState == ProfileSaveState.success) {
      _showSnack('Profile saved successfully');
      _vm.clearSaveState();
    } else if (_vm.saveState == ProfileSaveState.error) {
      _showSnack(_vm.errorMessage ?? 'Save failed', error: true);
      _vm.clearSaveState();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_listener);
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileSettingsViewModel>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: const Text('Profile Settings'),
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              children: [
                const _SectionLabel('Identity'),
                const SizedBox(height: 8),
                _UsernameField(
                  controller: _usernameCtrl,
                  error: vm.usernameError,
                  onChanged: vm.onUsernameChanged,
                  onEditingComplete: () =>
                      vm.onUsernameChanged(_usernameCtrl.text),
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Role'),
                const SizedBox(height: 8),
                _RolePicker(selected: vm.role, onChanged: vm.onRoleChanged),
                const SizedBox(height: 24),
                const _SectionLabel('Privacy'),
                const SizedBox(height: 8),
                _VisibilityToggle(
                  value: vm.visibility,
                  onChanged: vm.onVisibilityChanged,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: vm.isSaving ? null : () => vm.save(),
                  child: vm.isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Profile'),
                ),
                if (vm.saved != null) ...[
                  const SizedBox(height: 12),
                  _LastSaved(updatedAt: vm.saved!.updatedAt),
                ],
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onEditingComplete,
  });

  final TextEditingController controller;
  final String? error;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      decoration: const InputDecoration(
        prefixText: '@',
        hintText: 'your_username',
        border: OutlineInputBorder(),
      ).copyWith(errorText: error),
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.selected, required this.onChanged});

  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UserRole>(
      segments: const [
        ButtonSegment(
          value: UserRole.student,
          icon: Text('📚'),
          label: Text('Student'),
        ),
        ButtonSegment(
          value: UserRole.instructor,
          icon: Text('🎓'),
          label: Text('Instructor'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.value, required this.onChanged});

  final ProfileVisibility value;
  final ValueChanged<ProfileVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    final isPublic = value == ProfileVisibility.public;
    final theme = Theme.of(context);

    return SwitchListTile(
      value: isPublic,
      onChanged: (v) =>
          onChanged(v ? ProfileVisibility.public : ProfileVisibility.private),
      secondary: Icon(isPublic ? Icons.public_rounded : Icons.lock_rounded),
      title: Text(isPublic ? 'Public Profile' : 'Private Profile'),
      subtitle: Text(
        isPublic
            ? 'Anyone can view your profile'
            : 'Only you can see your profile',
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
    );
  }
}

class _LastSaved extends StatelessWidget {
  const _LastSaved({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(updatedAt);
    final String label;

    if (diff.inMinutes < 1) {
      label = 'Just saved';
    } else if (diff.inHours < 1) {
      label = 'Saved ${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      label = 'Saved ${diff.inHours}h ago';
    } else {
      label = 'Saved ${diff.inDays}d ago';
    }

    return Center(
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
