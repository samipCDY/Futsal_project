import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_model.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/avatar_storage.dart';

/// The signed-in user's profile and preferences, loaded from the API.
/// Follows [AuthProvider]: reloads when someone logs in, clears on logout.
class ProfileProvider extends ChangeNotifier {
  String? _userId;
  ProfileModel? _profile;
  String? _error;

  ProfileModel? get profile => _profile;
  String? get error => _error;

  /// Follows the phone's light/dark setting until the user picks one (and
  /// on the login screens, before anyone is signed in).
  ThemeMode get themeMode => switch (_profile?.preferences.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Called by the ProxyProvider in main.dart during a build, so it must not
  /// notify synchronously — the async load notifies when it finishes.
  void setUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _profile = null;
    _error = null;
    if (userId != null) load();
  }

  Future<void> load() async {
    final userId = _userId;
    try {
      final profile = ProfileModel.fromJson(await ApiClient.get('/accounts/me/') as Map<String, dynamic>);
      if (userId != _userId) return; // someone else logged in meanwhile
      _profile = profile;
      _error = null;
    } on ApiException catch (e) {
      if (userId != _userId) return;
      _error = e.message;
    }
    notifyListeners();
  }

  /// Saves personal details, e.g. {'first_name': 'Samip', 'city': 'Kathmandu'}.
  /// Throws [ApiException] with a readable message.
  Future<void> updateDetails(Map<String, dynamic> details) async {
    final data = await ApiClient.patch('/accounts/me/', details);
    _profile = ProfileModel.fromJson(data as Map<String, dynamic>);
    notifyListeners();
  }

  bool _isSavingPhoto = false;
  bool get isSavingPhoto => _isSavingPhoto;

  /// Uploads [photo] as the new profile photo and removes the old one.
  /// Throws [ApiException] with a readable message.
  Future<void> changePhoto(XFile photo) => _savingPhoto(() async {
        final profile = _profile!;
        final url = await AvatarStorage.upload(profile.id, photo);
        try {
          await updateDetails({'avatar_url': url});
        } on ApiException {
          AvatarStorage.delete(url); // don't leave the unused upload behind
          rethrow;
        }
        if (profile.avatarUrl.isNotEmpty) AvatarStorage.delete(profile.avatarUrl);
      });

  Future<void> removePhoto() => _savingPhoto(() async {
        final oldUrl = _profile!.avatarUrl;
        await updateDetails({'avatar_url': ''});
        AvatarStorage.delete(oldUrl);
      });

  Future<void> _savingPhoto(Future<void> Function() action) async {
    if (_profile == null || _isSavingPhoto) return;
    _isSavingPhoto = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _isSavingPhoto = false;
      notifyListeners();
    }
  }

  /// Applies the change straight away so the switch/theme reacts instantly,
  /// then saves it; puts the old value back if saving fails.
  Future<void> updatePreferences(Preferences Function(Preferences current) change) async {
    final before = _profile;
    if (before == null) return;
    final updated = change(before.preferences);
    _profile = before.copyWith(preferences: updated);
    notifyListeners();
    try {
      await ApiClient.patch('/accounts/me/', {'preferences': updated.toJson()});
    } on ApiException {
      _profile = before;
      notifyListeners();
      rethrow;
    }
  }
}
