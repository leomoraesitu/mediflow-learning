import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mediflow_mobile/design_system/app_spacing.dart';
import 'package:mediflow_mobile/design_system/widgets/mediflow_content_card.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_cubit.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_validators.dart';
import 'package:mediflow_mobile/features/auth/presentation/auth_view_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
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

    await context.read<AuthCubit>().register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    // `mounted` do `State`, e não `context.mounted`: dentro de um `State` o
    // `context` é o `State.context`, e é essa a guarda que
    // `use_build_context_synchronously` reconhece como relacionada.
    if (!mounted) return;

    // O Cubit não emite no sucesso, então "deu certo" se lê pela ausência de
    // falha. Sem este `pop`, a rota de cadastro continuaria cobrindo a tela
    // que o portão já trocou por baixo dela.
    if (context.read<AuthCubit>().state.feedback is! AuthFailure) {
      Navigator.of(context).pop();
    }
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
                Icon(Icons.person_add_outlined, size: 48, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Criar conta',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
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
                          : const Text('Criar conta'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
