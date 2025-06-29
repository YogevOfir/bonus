import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get isAnonymous => _user?.isAnonymous ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() async {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });

    // Ensure user is signed in (will sign in anonymously if not)
    await _authService.ensureSignedIn();
  }

  Future<String?> getUserId() async {
    return await _authService.getUserId();
  }

  // This method is not exposed since we don't want sign out functionality
  // The user will always be signed in anonymously
} 