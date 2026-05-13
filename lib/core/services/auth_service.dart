import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _db = FirestoreService();

  Stream<User?> get userStream => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      // Keep the userEmails lookup in sync for existing accounts that
      // pre-date the collection. updateUserProfile is idempotent.
      await _db.updateUserProfile(cred.user!.uid, {
        'email': email.trim().toLowerCase(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  Future<String?> signUp(String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user!.updateDisplayName(name);
      await _db.createUserProfile(cred.user!.uid, {
        'name': name,
        'email': email,
        'totalPoints': 0,
        'dailyPoints': 0,
        'currentStreak': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  Future<void> signOut() async => _auth.signOut();

  /// Sends a password-reset email. Returns an error string or null on success.
  Future<String?> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) return 'Please enter your email address first.';
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'invalid-credential': return 'Invalid email or password.';
      default: return 'Something went wrong. Please try again.';
    }
  }
}
