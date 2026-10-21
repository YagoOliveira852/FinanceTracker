import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../cubit/login_cubit.dart';
import '../cubit/sessao_cubit.dart';

/// Login com e-mail e senha. Mostra "Sessão expirada" quando o app chegou
/// aqui porque o refresh foi recusado.
class LoginTela extends StatefulWidget {
  const LoginTela({super.key});

  @override
  State<LoginTela> createState() => _LoginTelaState();
}

class _LoginTelaState extends State<LoginTela> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  var _senhaVisivel = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _entrar() {
    context.read<LoginCubit>().entrar(email: _email.text, senha: _senha.text);
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<LoginCubit>().state;
    final expirou = context.select(
      (SessaoCubit c) => switch (c.state) {
        SessaoDesconectada(:final expirou) => expirou,
        _ => false,
      },
    );
    final esquema = context.esquema;
    final textos = context.textos;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, restricoes) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.x6,
              Espaco.x6,
              Espaco.x6,
              Espaco.x8,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: restricoes.maxHeight - Espaco.x6 - Espaco.x8,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: Espaco.x10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Finanças pessoais',
                        style: textos.titleLarge?.copyWith(
                          color: esquema.primary,
                        ),
                      ),
                      const SizedBox(height: Espaco.x2),
                      Text(
                        'Acesse suas finanças',
                        style: textos.headlineMedium,
                      ),
                      const SizedBox(height: Espaco.x2),
                      Text(
                        'Entre com o e-mail e a senha do seu usuário.',
                        style: textos.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Espaco.x10),
                      TextField(
                        controller: _email,
                        enabled: !estado.enviando,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'E-mail',
                          errorText: estado.erro == null ? null : '',
                          errorStyle: const TextStyle(height: 0),
                        ),
                      ),
                      const SizedBox(height: Espaco.x6),
                      TextField(
                        controller: _senha,
                        enabled: !estado.enviando,
                        obscureText: !_senhaVisivel,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          errorText: estado.erro == null ? null : '',
                          errorStyle: const TextStyle(height: 0),
                          suffixIcon: IconButton(
                            tooltip: _senhaVisivel
                                ? 'Esconder senha'
                                : 'Mostrar senha',
                            onPressed: estado.enviando
                                ? null
                                : () => setState(
                                    () => _senhaVisivel = !_senhaVisivel,
                                  ),
                            icon: Icon(
                              _senhaVisivel
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                      ),
                      if (estado.erro != null) ...[
                        const SizedBox(height: Espaco.x6),
                        Aviso.erro(context, estado.erro!),
                      ] else if (expirou) ...[
                        const SizedBox(height: Espaco.x6),
                        _AvisoSessaoExpirada(),
                      ],
                      const SizedBox(height: Espaco.x6),
                      FilledButton(
                        onPressed: estado.enviando ? null : _entrar,
                        // Enviando, o botão fica desabilitado mas na cor
                        // primária, com o indicador de progresso.
                        style: estado.enviando
                            ? FilledButton.styleFrom(
                                disabledBackgroundColor: esquema.primary,
                                disabledForegroundColor: esquema.onPrimary,
                              )
                            : null,
                        child: estado.enviando
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: esquema.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: Espaco.x2),
                                  const Text('Entrando'),
                                ],
                              )
                            : const Text('Entrar'),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: Espaco.x10),
                    child: Text(
                      'Sem cadastro: o acesso é criado no servidor.',
                      textAlign: TextAlign.center,
                      style: textos.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvisoSessaoExpirada extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Aviso(
      icone: Icons.lock_clock_rounded,
      corIcone: context.esquema.onSurfaceVariant,
      cor: context.esquema.onSurface,
      fundo: context.esquema.surfaceContainerHigh,
      texto: Text.rich(
        TextSpan(
          style: textos.bodyMedium,
          children: const [
            TextSpan(
              text: 'Sessão expirada.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' Faça login de novo para continuar.'),
          ],
        ),
      ),
    );
  }
}
