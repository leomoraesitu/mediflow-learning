import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/config/auth_gateway.dart';
import 'package:mediflow_mobile/config/auth_user.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/register_page.dart';
import 'package:mediflow_mobile/features/auth/presentation/sign_in_page.dart';

/// Decide a primeira tela a partir de quem está autenticado.
///
/// Recebe `authenticatedHome` pronto: o portão não conhece a tela de
/// benefícios nem os parâmetros dela, e por isso pode ser testado com um
/// `Placeholder`.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.authGateway, required this.authenticatedHome});

  final AuthGateway authGateway;
  final Widget authenticatedHome;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// O fluxo é assinado uma vez, e não a cada `build`.
  ///
  /// `StreamBuilder` compara o fluxo antigo com o novo por `!=` e reassina
  /// quando eles diferem. `FirebaseAuthGateway.authStateChanges()` devolve um
  /// `.map()` novo a cada chamada, que não se compara igual ao anterior —
  /// então chamá-lo dentro do `build` reassinaria a cada reconstrução, e o
  /// portão voltaria ao estado de espera. Com o `FakeAuthGateway` isso não
  /// acontece, porque o `stream` de um controlador broadcast se compara
  /// igual: é uma diferença que os testes não conseguem revelar.
  late final Stream<AuthUser?> _authState = widget.authGateway.authStateChanges();

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // A rota precisa do próprio provedor: o `BlocProvider` da tela de
        // entrada é descendente do `Navigator`, não ancestral, e por isso não
        // alcança o que for empurrado por cima.
        builder: (_) => BlocProvider(
          create: (_) => AuthCubit(authGateway: widget.authGateway),
          child: const RegisterPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _authState,
      // Evita o quadro de espera quando já existe sessão: é para isto que o
      // `currentUser` síncrono existe no contrato.
      initialData: widget.authGateway.currentUser,
      builder: (context, snapshot) {
        // `connectionState`, e não `hasData`: `hasData` é `data != null`, então
        // "ainda não sei" e "ninguém autenticado" seriam indistinguíveis, e a
        // tela de entrada piscaria em toda abertura para quem já entrou.
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == null) {
          return BlocProvider(
            create: (_) => AuthCubit(authGateway: widget.authGateway),
            child: SignInPage(onRegisterRequested: _openRegister),
          );
        }

        return widget.authenticatedHome;
      },
    );
  }
}
