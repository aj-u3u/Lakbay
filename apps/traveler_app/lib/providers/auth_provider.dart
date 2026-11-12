import 'dart:async';

import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/profile_photo_storage.dart';
import '../services/session_storage.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SessionStorage _sessionStorage = SessionStorage();
  final ProfilePhotoStorage _profilePhotoStorage = ProfilePhotoStorage();

  UserProfile? _userProfile;
  String? _localProfilePhotoPath;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _apiService.onSessionChanged = _handleSessionChanged;
  }

  UserProfile? get userProfile => _userProfile;
  String? get localProfilePhotoPath => _localProfilePhotoPath;
  bool get isAuthenticated => _userProfile != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<String?> _readLocalProfilePhoto(String userId) async {
    try {
      return await _profilePhotoStorage.read(userId);
    } catch (_) {
      return null;
    }
  }

  void _handleSessionChanged(String? accessToken, String? refreshToken) {
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      unawaited(_sessionStorage.clear());
      return;
    }

    unawaited(
      _sessionStorage.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    );
  }

  Future<bool> restoreSavedSession() async {
    final savedTokens = await _sessionStorage.read();
    if (savedTokens == null) return false;

    final restored = await restoreSession(
      accessToken: savedTokens.accessToken,
      refreshToken: savedTokens.refreshToken,
    );

    if (!restored) {
      await _sessionStorage.clear();
      _apiService.setSessionTokens(accessToken: null, newRefreshToken: null);
    }

    return restored;
  }

  Future<bool> restoreSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _apiService.setSessionTokens(
        accessToken: accessToken,
        newRefreshToken: refreshToken,
      );
      final user = await _apiService.fetchCurrentUser();
      if (user != null) {
        _userProfile = user;
        _localProfilePhotoPath = await _readLocalProfilePhoto(user.uid);
        return true;
      }
      await _sessionStorage.clear();
      _apiService.setSessionTokens(accessToken: null, newRefreshToken: null);
      _errorMessage = _apiService.lastError ?? 'Session expired.';
      return false;
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _apiService.authenticateUser(email, password);
      if (user != null) {
        _userProfile = user;
        _localProfilePhotoPath = await _readLocalProfilePhoto(user.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = _apiService.lastError ?? 'Invalid email or password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _apiService.registerUser(name, email, password);
      if (success) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            _apiService.lastError ?? 'Registration failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void updateUserProfile(UserProfile updatedProfile) {
    _userProfile = updatedProfile;
    notifyListeners();
  }

  Future<bool> saveUserProfile(UserProfile updatedProfile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final saved = await _apiService.updateCurrentUser(updatedProfile);
      if (saved != null) {
        _userProfile = saved.copyWith(
          displayName: updatedProfile.displayName,
          avatarUrl: updatedProfile.avatarUrl,
          username: updatedProfile.username,
          phone: updatedProfile.phone,
          emergencyContact: updatedProfile.emergencyContact,
        );
        return true;
      }
      _errorMessage = _apiService.lastError ?? 'Failed to update profile.';
      return false;
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveLocalProfilePhoto(String sourcePath) async {
    final user = _userProfile;
    if (user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _localProfilePhotoPath = await _profilePhotoStorage.save(
        user.uid,
        sourcePath,
      );
      return true;
    } catch (_) {
      _errorMessage = 'Could not save the selected photo.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveAvatarUrl(String avatarUrl) async {
    final user = _userProfile;
    if (user == null) return false;
    final saved = await saveUserProfile(user.copyWith(avatarUrl: avatarUrl));
    if (!saved) return false;
    try {
      await _profilePhotoStorage.clear(user.uid);
      _localProfilePhotoPath = null;
      notifyListeners();
      return true;
    } catch (_) {
      _errorMessage = 'Avatar saved, but the local photo could not be removed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logoutSession();
    _userProfile = null;
    _localProfilePhotoPath = null;
    notifyListeners();
  }
}
