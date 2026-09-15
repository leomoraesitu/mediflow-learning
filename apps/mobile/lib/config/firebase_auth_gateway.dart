import 'package:firebase_auth/firebase_auth.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/auth_user.dart';

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

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(uid: user.uid, email: user.email, isAnonymous: user.isAnonymous);
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_toAuthUser);
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return _requireUser(userCredential);
    } on FirebaseAuthException catch (e) {
      throw AuthGatewayException(e.code);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({required String email, required String password}) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      return _requireUser(userCredential);
    } on FirebaseAuthException catch (e) {
      throw AuthGatewayException(e.code);
    }
  }

  /// O `user` do `UserCredential` é anulável, e o contrato promete um
  /// `AuthUser`. Um `!` aqui lançaria `TypeError` — que é `Error`, não
  /// `Exception`, e por isso escaparia do `catch` da tela de login,
  /// deixando-a presa no estado "entrando" sem mensagem nenhuma.
  AuthUser _requireUser(UserCredential credential) {
    final user = _toAuthUser(credential.user);

    if (user == null) {
      throw const AuthGatewayException('missing-user');
    }

    return user;
  }
}
