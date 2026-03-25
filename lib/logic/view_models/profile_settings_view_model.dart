import 'package:flutter/foundation.dart';
import 'package:flutter_education_app/logic/models/profile_model.dart';
import 'package:flutter_education_app/logic/repositories/profile_repository.dart';
import 'package:flutter_education_app/logic/services/firebase_firestore_service.dart';

enum ProfileSaveState { idle, saving, success, error }

class ProfileSettingsViewModel extends ChangeNotifier {
  ProfileSettingsViewModel({FirestoreService<ProfileModel>? service})
    : _service =
          service ?? FirestoreService<ProfileModel>(const ProfileRepository()) {
    load();
  }

  final FirestoreService<ProfileModel> _service;

  ProfileModel? _saved;
  ProfileModel? get saved => _saved;

  bool _loading = true;
  bool get loading => _loading;

  ProfileSaveState _saveState = ProfileSaveState.idle;
  ProfileSaveState get saveState => _saveState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _usernameError;
  String? get usernameError => _usernameError;

  String _username = '';
  UserRole _role = UserRole.student;
  ProfileVisibility _visibility = ProfileVisibility.public;

  UserRole get role => _role;
  ProfileVisibility get visibility => _visibility;

  bool get isSaving => _saveState == ProfileSaveState.saving;

  Future<void> load() async {
    _setLoading(true);
    try {
      final uid = _service.currentUserId;
      if (uid == null) return;

      final profile = await _service.getById(uid);
      _saved = profile;

      if (profile != null) {
        _username = profile.username;
        _role = profile.role;
        _visibility = profile.visibility;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void onUsernameChanged(String value) {
    _username = value;
    if (_usernameError != null) {
      _usernameError = null;
      notifyListeners();
    }
  }

  void onRoleChanged(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void onVisibilityChanged(ProfileVisibility visibility) {
    _visibility = visibility;
    notifyListeners();
  }

  Future<bool> save() async {
    await _validateUsername(_username);
    if (_usernameError != null) return false;

    final uid = _service.currentUserId;
    final email = _service.currentUser?.email;
    if (uid == null || email == null) {
      _errorMessage = 'No authenticated user found';
      notifyListeners();
      return false;
    }

    _setSaveState(ProfileSaveState.saving);
    try {
      final model = ProfileModel(
        userId: uid,
        email: email,
        username: _username.trim(),
        role: _role,
        visibility: _visibility,
        updatedAt: DateTime.now(),
      );
      await _service.set(uid, model);
      _saved = model;
      _setSaveState(ProfileSaveState.success);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setSaveState(ProfileSaveState.error);
      return false;
    }
  }

  void clearSaveState() {
    if (_saveState != ProfileSaveState.saving) {
      _saveState = ProfileSaveState.idle;
      _errorMessage = null;
    }
  }

  Future<void> _validateUsername(String value) async {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      _usernameError = 'Username is required';
      notifyListeners();
      return;
    }
    if (trimmed.length < 3) {
      _usernameError = 'At least 3 characters';
      notifyListeners();
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(trimmed)) {
      _usernameError = 'Letters, numbers, _ and . only';
      notifyListeners();
      return;
    }

    final taken = await _isUsernameTaken(trimmed);
    _usernameError = taken ? 'Username already taken' : null;
    notifyListeners();
  }

  Future<bool> _isUsernameTaken(String username) async {
    final encoded = ProfileModel.encodeValue(username.toLowerCase());
    final docs = await _service.getAll(
      query: (col) => col.where('usernameLower', isEqualTo: encoded).limit(2),
    );
    return docs.any((p) => p.userId != _service.currentUserId);
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setSaveState(ProfileSaveState state) {
    _saveState = state;
    notifyListeners();
  }
}
