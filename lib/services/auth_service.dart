import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in anonymously
  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }

  // Check if user is signed in, if not sign in anonymously
  Future<User?> ensureSignedIn() async {
    User? user = _auth.currentUser;
    
    if (user == null) {
      // No user signed in, sign in anonymously
      UserCredential? result = await signInAnonymously();
      user = result?.user;
    }
    
    return user;
  }

  // Get user ID (will ensure user is signed in first)
  Future<String?> getUserId() async {
    User? user = await ensureSignedIn();
    return user?.uid;
  }

  // Check if user is anonymous
  bool isAnonymous() {
    return _auth.currentUser?.isAnonymous ?? false;
  }
} 