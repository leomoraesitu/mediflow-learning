import 'package:firebase_auth/firebase_auth.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';

final class FirebaseAuthGateway implements AuthGateway {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthGateway({required this._firebaseAuth});

  @override
  Future<String?> currentUserToken() async {
    final user = _firebaseAuth.currentUser;
    try {
      return await user?.getIdToken();
    } on FirebaseAuthException catch (e) {
      throw AuthGatewayException(e.code);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthGatewayException(e.code);
    }
  }

  @override
  Future<String?> signInAnonymously() async {
    try {
      final userCredential = await _firebaseAuth.signInAnonymously();
      return await userCredential.user?.getIdToken();
    } on FirebaseAuthException catch (e) {
      throw AuthGatewayException(e.code);
    }
  }
}
