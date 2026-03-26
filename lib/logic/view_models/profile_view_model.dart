import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/repositories/profile_repository.dart';
import 'package:flutter_education_app/logic/services/firebase_firestore_service.dart';
import 'package:flutter_education_app/logic/services/supabase_storage_service.dart';

enum ProfileAvatarUploadState { idle, uploading, success, error }

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    FirestoreService<ProfileModel>? firestoreService,
    SupabaseStorageService? storageService,
  }) : _firestoreService =
           firestoreService ??
           FirestoreService<ProfileModel>(const ProfileRepository()),
       _storageService = storageService ?? SupabaseStorageService() {
    load();
  }

  final FirestoreService<ProfileModel> _firestoreService;
  final SupabaseStorageService _storageService;

  ProfileModel? _profile;
  ProfileModel? get profile => _profile;

  bool _loading = true;
  bool get loading => _loading;

  bool _savingDisplayName = false;
  bool get savingDisplayName => _savingDisplayName;

  UserRole _activeRole = UserRole.student;
  UserRole get activeRole => _activeRole;

  ProfileAvatarUploadState _avatarState = ProfileAvatarUploadState.idle;
  ProfileAvatarUploadState get avatarState => _avatarState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _avatarCacheBust = 0;

  String? get activeAvatarUrl {
    final raw = _activeRole == UserRole.student
        ? _profile?.studentAvatarUrl
        : _profile?.instructorAvatarUrl;
    if (raw == null || raw.isEmpty) return null;
    return '$raw?v=$_avatarCacheBust';
  }

  String get displayName => _profile?.displayName ?? '';

  bool get isUploadingAvatar =>
      _avatarState == ProfileAvatarUploadState.uploading;

  Future<void> load() async {
    _setLoading(true);
    try {
      final uid = _firestoreService.currentUserId;
      if (uid == null) return;

      final profile = await _firestoreService.getById(uid);
      _profile = profile;
      if (profile != null) _activeRole = profile.role;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadAvatar(File file) async {
    final uid = _firestoreService.currentUserId;
    if (uid == null || _profile == null) return;

    _setAvatarState(ProfileAvatarUploadState.uploading);
    try {
      // Uploads to avatars/$uid/student.jpg OR avatars/$uid/instructor.jpg
      final publicUrl = await _storageService.uploadAvatar(
        uid,
        _activeRole.name,
        file,
      );

      // Only update the active role's field — never touch the other role's URL
      final String firestoreField;
      final ProfileModel updated;

      if (_activeRole == UserRole.student) {
        firestoreField = 'studentAvatarUrl';
        updated = _profile!.copyWith(studentAvatarUrl: publicUrl);
      } else {
        firestoreField = 'instructorAvatarUrl';
        updated = _profile!.copyWith(instructorAvatarUrl: publicUrl);
      }

      // Partial update — never overwrite the whole document
      await _firestoreService.update(uid, {firestoreField: publicUrl});

      _profile = updated;
      _avatarCacheBust = DateTime.now().millisecondsSinceEpoch;
      _setAvatarState(ProfileAvatarUploadState.success);
    } catch (e) {
      _errorMessage = e.toString();
      _setAvatarState(ProfileAvatarUploadState.error);
    }
  }

  Future<bool> updateDisplayName(String newName) async {
    final uid = _firestoreService.currentUserId;
    if (uid == null || _profile == null) return false;

    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == displayName) return false;

    _savingDisplayName = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.update(uid, {
        'displayName': ProfileModel.encodeValue(trimmed),
      });
      _profile = _profile!.copyWith(displayName: trimmed);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _savingDisplayName = false;
      notifyListeners();
    }
  }

  void clearAvatarState() {
    if (_avatarState != ProfileAvatarUploadState.uploading) {
      _avatarState = ProfileAvatarUploadState.idle;
      _errorMessage = null;
    }
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setAvatarState(ProfileAvatarUploadState s) {
    _avatarState = s;
    notifyListeners();
  }
}
