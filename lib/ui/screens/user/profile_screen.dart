// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_education_app/ui/screens/user/settings_screen.dart';
import 'package:flutter_education_app/ui/widgets/app/material_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_education_app/logic/repositories/auth_repository.dart';
import 'package:flutter_education_app/logic/routers/app_navigator.dart';
import 'package:flutter_education_app/ui/screens/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final _supabase = Supabase.instance.client;

  User? _user;
  bool _isLoading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  File? _pickedImage;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _authRepository.currentUser;
      _fullNameController = TextEditingController(
        text: user?.userMetadata?['full_name'] as String? ?? '',
      );
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load user data: $e')));
      }
    }
  }

  String get _displayName =>
      _user?.userMetadata?['full_name'] as String? ??
      _user?.userMetadata?['name'] as String? ??
      _user?.email?.split('@').first ??
      'User';

  String? get _avatarUrl => _user?.userMetadata?['avatar_url'] as String?;

  Future<void> _pickPhoto() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(ctx),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: choice,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadPhoto() async {
    if (_pickedImage == null) return null;
    setState(() => _isUploadingPhoto = true);
    try {
      final userId = _authRepository.currentUser?.id;
      if (userId == null) throw Exception('No user logged in');
      final fileExt = _pickedImage!.path.split('.').last.toLowerCase();
      final fileName = '$userId/avatar.$fileExt';
      final bytes = await _pickedImage!.readAsBytes();
      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: true,
            ),
          );
      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(fileName);
      return '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save(StateSetter setSheetState) async {
    if (!_formKey.currentState!.validate()) return;
    setSheetState(() => _isSaving = true);
    setState(() => _isSaving = true);
    try {
      final user = _authRepository.currentUser;
      final fullName = _fullNameController.text.trim();
      final nameChanged =
          fullName != (user?.userMetadata?['full_name'] as String? ?? '');
      final photoChanged = _pickedImage != null;

      String? newAvatarUrl;
      if (photoChanged) newAvatarUrl = await _uploadPhoto();

      final Map<String, dynamic> updatedData = {};
      if (nameChanged) updatedData['full_name'] = fullName;
      if (newAvatarUrl != null) updatedData['avatar_url'] = newAvatarUrl;

      if (updatedData.isNotEmpty) {
        await _authRepository.updateUser(data: updatedData);
      }

      await _loadUserData();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setSheetState(() => _isSaving = false);
        setState(() => _isSaving = false);
      }
    }
  }

  void _showEditSheet() {
    _pickedImage = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final user = _authRepository.currentUser;
          ImageProvider? imageProvider;
          if (_pickedImage != null) {
            imageProvider = FileImage(_pickedImage!);
          } else if (_avatarUrl != null) {
            imageProvider = NetworkImage(_avatarUrl!);
          }
          final displayName = _fullNameController.text.isNotEmpty
              ? _fullNameController.text
              : user?.email?.split('@').first ?? 'User';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (_, controller) => Column(
                children: [
                  _sheetHandle(ctx),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Theme.of(ctx).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Edit Profile',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                await _pickPhoto();
                                setSheetState(() {});
                              },
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.surfaceVariant,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 44,
                                      backgroundImage: imageProvider,
                                      child: imageProvider == null
                                          ? Text(
                                              displayName.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(ctx).colorScheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          ctx,
                                        ).colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingPhoto
                                        ? SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Theme.of(
                                                ctx,
                                              ).colorScheme.onPrimary,
                                            ),
                                          )
                                        : Icon(
                                            Icons.camera_alt_rounded,
                                            size: 14,
                                            color: Theme.of(
                                              ctx,
                                            ).colorScheme.onPrimary,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              _pickedImage != null
                                  ? 'Photo selected ✓'
                                  : 'Tap to change photo',
                              style: Theme.of(ctx).textTheme.labelMedium
                                  ?.copyWith(
                                    color: _pickedImage != null
                                        ? Colors.green.shade600
                                        : Theme.of(ctx).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildField(
                            controller: _fullNameController,
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.badge_outlined,
                            validator: (v) => v != null && v.trim().isEmpty
                                ? 'Name cannot be empty'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: (_isSaving || _isUploadingPhoto)
                                  ? null
                                  : () => _save(setSheetState),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: (_isSaving || _isUploadingPhoto)
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetHandle(BuildContext ctx) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: Theme.of(ctx).colorScheme.outline.withOpacity(0.3),
      borderRadius: BorderRadius.circular(2),
    ),
  );

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error, width: 1.8),
        ),
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.6),
          fontWeight: FontWeight.w500,
        ),
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface.withOpacity(0.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialWidget(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () =>
                AppNavigator(screen: HomeScreen()).navigate(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Profile'),
          actions: [
            IconButton(
              onPressed: () => SettingsScreen.open(context),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _user == null
            ? const Center(child: Text('No user logged in.'))
            : RefreshIndicator(
                onRefresh: _loadUserData,
                child: ListView(
                  children: [_buildProfileCard(), const SizedBox(height: 32)],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surfaceVariant,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? Text(
                      _displayName.isNotEmpty
                          ? _displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          if (_user?.email != null) ...[
            const SizedBox(height: 4),
            Text(
              _user!.email!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _showEditSheet,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
