import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/view_models/profile_view_model.dart';
import 'package:flutter_education_app/ui/screens/user/settings_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  late ProfileViewModel _vm;
  late VoidCallback _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm = context.read<ProfileViewModel>();
    _listener = _onVmChanged;
    _vm.removeListener(_listener);
    _vm.addListener(_listener);
  }

  void _onVmChanged() {
    if (!mounted) return;

    if (_vm.avatarState == ProfileAvatarUploadState.success) {
      _showSnack('Profile picture updated');
      _vm.clearAvatarState();
    } else if (_vm.avatarState == ProfileAvatarUploadState.error) {
      _showSnack(_vm.errorMessage ?? 'Upload failed', error: true);
      _vm.clearAvatarState();
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_listener);
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

  Future<void> _showEditDisplayNameDialog() async {
    final vm = context.read<ProfileViewModel>();
    final controller = TextEditingController(text: vm.displayName);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit display name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Enter your name',
              counterText: '',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await vm.updateDisplayName(controller.text);
    if (!mounted) return;

    _showSnack(
      success ? 'Display name updated' : (vm.errorMessage ?? 'Update failed'),
      error: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProfileViewModel>();

    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          actions: [
            IconButton(
              onPressed: () => AppNavigator(
                screen: const SettingsScreen(),
              ).navigate(context),
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
        body: vm.loading
            ? const Center(child: CircularProgressIndicator())
            : _ProfileBody(
                vm: vm,
                onEditDisplayName: _showEditDisplayNameDialog,
              ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.vm, required this.onEditDisplayName});

  final ProfileViewModel vm;
  final VoidCallback onEditDisplayName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        _RoleDisplay(role: vm.activeRole),
        const SizedBox(height: 32),
        Center(
          child: _AvatarSection(
            avatarUrl: vm.activeAvatarUrl, // single source of truth
            isUploading: vm.isUploadingAvatar,
            role: vm.activeRole,
            onPickImage: (file) => vm.uploadAvatar(file),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: vm.savingDisplayName
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        vm.displayName.isEmpty ? '—' : vm.displayName,
                        style: theme.textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: vm.savingDisplayName ? null : onEditDisplayName,
                icon: const Icon(Icons.edit_rounded),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit display name',
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (vm.profile?.username.isNotEmpty == true)
          Center(
            child: Text(
              '@${vm.profile!.username}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        const SizedBox(height: 32),
        if (vm.profile != null)
          Center(child: _VisibilityBadge(visibility: vm.profile!.visibility)),
      ],
    );
  }
}

class _RoleDisplay extends StatelessWidget {
  const _RoleDisplay({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isStudent = role == UserRole.student;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isStudent ? '📚' : '🎓', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            isStudent ? 'Student' : 'Instructor',
            style: theme.textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarUrl,
    required this.isUploading,
    required this.role,
    required this.onPickImage,
  });

  final String? avatarUrl;
  final bool isUploading;
  final UserRole role;
  final ValueChanged<File> onPickImage;

  Future<void> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    onPickImage(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleEmoji = role == UserRole.student ? '📚' : '🎓';

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
          ),
          child: isUploading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint("Image load error: $error");
                            return _AvatarPlaceholder(emoji: roleEmoji);
                          },
                        )
                      : _AvatarPlaceholder(emoji: roleEmoji),
                ),
        ),
        GestureDetector(
          onTap: isUploading ? null : () => _pickImage(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
              border: Border.all(color: theme.colorScheme.surface, width: 2),
            ),
            child: Icon(
              Icons.camera_alt_rounded,
              size: 16,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(emoji, style: const TextStyle(fontSize: 40)));
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final ProfileVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility == ProfileVisibility.public;
    return Chip(
      avatar: Icon(
        isPublic ? Icons.public_rounded : Icons.lock_rounded,
        size: 16,
      ),
      label: Text(isPublic ? 'Public' : 'Private'),
    );
  }
}
