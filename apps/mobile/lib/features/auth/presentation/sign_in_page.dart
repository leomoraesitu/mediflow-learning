import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_validators.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_view_state.dart';

/// A tela de entrada.
///
/// Não recebe controllers nem chave de formulário: eles são estado desta tela
/// e precisam ser descartados com ela. E não constrói o `AuthCubit` — quem o
/// provê é o portão, com `BlocProvider(create:)`, que também o fecha.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key, required this.onRegisterRequested});

  final VoidCallback onRegisterRequested;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    // Nada usa `context` depois deste `await`: em caso de sucesso a tela sai
    // da árvore pelo portão, e em caso de falha o Cubit emite o estado novo.
    await context.read<AuthCubit>().signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('MediFlow')),
      body: SafeArea(
        child: MediFlowContentCard(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text('Entrar', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'alguem@exemplo.com',
                  ),
                  // Sem estes três o teclado do Android capitaliza a primeira
                  // letra e a entrada falha por um motivo invisível na tela.
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: validatePassword,
                ),
                const SizedBox(height: AppSpacing.md),
                // Dois seletores separados: a mensagem e o botão mudam em
                // momentos diferentes, e cada um assina só o que consome.
                BlocSelector<AuthCubit, AuthViewState, AuthFeedback>(
                  selector: (state) => state.feedback,
                  builder: (context, feedback) {
                    return switch (feedback) {
                      NoAuthFeedback() => const SizedBox.shrink(),
                      AuthFailure(:final message) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    };
                  },
                ),
                BlocSelector<AuthCubit, AuthViewState, bool>(
                  selector: (state) => state.isBusy,
                  builder: (context, isBusy) {
                    return ElevatedButton(
                      onPressed: isBusy ? null : _submit,
                      // O indicador substitui o texto dentro do botão, e não o
                      // botão: trocar o widget inteiro encolheria o alvo de
                      // toque abaixo do mínimo que o teste de acessibilidade
                      // verifica.
                      child: isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Entrar'),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: widget.onRegisterRequested, child: const Text('Criar conta')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
