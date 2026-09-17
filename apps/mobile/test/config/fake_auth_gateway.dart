import 'dart:async';

import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/auth_user.dart';

/// Fake escrito à mão, no padrão do projeto: cada operação tem um valor
/// configurável, um erro configurável e um contador.
///
/// Quem usa `authStateChanges` precisa chamar [dispose] no `addTearDown`.
final class FakeAuthGateway implements AuthGateway {
  String? currentUserTokenValue;
  AuthGatewayException? currentUserTokenError;

  String? signInToken;
  AuthGatewayException? signInError;

  AuthGatewayException? signOutError;

  /// Quem está autenticado. Público porque é arranjo de teste: a política de
  /// recuperação de identidade ramifica em `isAnonymous`, e sem poder montar
  /// os dois casos aqui não há como cobrir os dois ramos.
  AuthUser? currentUserValue;

  /// O usuário que `signInAnonymously` passa a reportar como atual. O
  /// Firebase real define o usuário ao entrar; um fake que não faça o mesmo
  /// deixa passar teste verde sobre comportamento que não existiria.
  AuthUser anonymousUser = const AuthUser(uid: 'anon-uid', isAnonymous: true);

  AuthUser emailUser = const AuthUser(
    uid: 'account-uid',
    email: 'alguem@exemplo.test',
    isAnonymous: false,
  );

  AuthGatewayException? signInWithEmailError;
  AuthGatewayException? registerWithEmailError;

  /// Segura as operações de e-mail até o teste soltar.
  ///
  /// Sem isto, o fake resolve no mesmo microtask e não há instante em que a
  /// tentativa esteja *em curso* — um teste de "enquanto carrega" acabaria
  /// observando o estado posterior e passando pelo motivo errado.
  Completer<void>? pendingEmailOperation;

  void holdEmailOperations() => pendingEmailOperation = Completer<void>();

  void releaseEmailOperations() {
    pendingEmailOperation?.complete();
    pendingEmailOperation = null;
  }

  int signOutCalls = 0;
  int signInCalls = 0;
  int signInWithEmailCalls = 0;
  int registerWithEmailCalls = 0;

  // `broadcast` porque os testes nem sempre assinam, e um controlador comum
  // com evento pendente e sem ouvinte não completa o `close()`.
  final _authState = StreamController<AuthUser?>.broadcast();

  Future<void> dispose() => _authState.close();

  void _setCurrentUser(AuthUser? user) {
    currentUserValue = user;
    _authState.add(user);
  }

  @override
  AuthUser? get currentUser => currentUserValue;

  @override
  Stream<AuthUser?> authStateChanges() => _authState.stream;

  @override
  Future<String?> currentUserToken() async {
    if (currentUserTokenError != null) {
      throw currentUserTokenError!;
    }
    return currentUserTokenValue;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutError != null) {
      throw signOutError!;
    }
    _setCurrentUser(null);
  }

  @override
  Future<String?> signInAnonymously() async {
    signInCalls++;
    if (signInError != null) {
      throw signInError!;
    }
    _setCurrentUser(anonymousUser);
    return signInToken;
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    signInWithEmailCalls++;
    await pendingEmailOperation?.future;
    if (signInWithEmailError != null) {
      throw signInWithEmailError!;
    }
    final user = AuthUser(uid: emailUser.uid, email: email, isAnonymous: false);
    _setCurrentUser(user);
    return user;
  }

  @override
  Future<AuthUser> registerWithEmail({required String email, required String password}) async {
    registerWithEmailCalls++;
    await pendingEmailOperation?.future;
    if (registerWithEmailError != null) {
      throw registerWithEmailError!;
    }
    final user = AuthUser(uid: emailUser.uid, email: email, isAnonymous: false);
    _setCurrentUser(user);
    return user;
  }
}
