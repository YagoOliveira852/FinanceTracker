import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/login/cubit/login_cubit.dart';
import 'package:financas/features/login/cubit/sessao_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/auth_falso.dart';

void main() {
  group('SessaoCubit', () {
    blocTest<SessaoCubit, SessaoEstado>(
      'com tokens guardados, entra direto',
      build: () => SessaoCubit(AuthRepositorioFalso(sessao: true)),
      act: (cubit) => cubit.iniciar(),
      expect: () => [const SessaoEstado.conectada()],
    );

    blocTest<SessaoCubit, SessaoEstado>(
      'sem tokens, vai para o login',
      build: () => SessaoCubit(AuthRepositorioFalso()),
      act: (cubit) => cubit.iniciar(),
      expect: () => [const SessaoEstado.desconectada()],
    );

    blocTest<SessaoCubit, SessaoEstado>(
      'refresh recusado: desconectada com sessão expirada',
      build: () => SessaoCubit(AuthRepositorioFalso(sessao: true)),
      act: (cubit) => cubit.expirou(),
      expect: () => [const SessaoEstado.desconectada(expirou: true)],
    );

    final auth = AuthRepositorioFalso(sessao: true);
    blocTest<SessaoCubit, SessaoEstado>(
      'sair apaga a sessão',
      build: () => SessaoCubit(auth),
      seed: () => const SessaoEstado.conectada(),
      act: (cubit) => cubit.sair(),
      expect: () => [const SessaoEstado.desconectada()],
      verify: (_) => expect(auth.sessao, isFalse),
    );
  });

  group('LoginCubit', () {
    late AuthRepositorioFalso auth;
    late SessaoCubit sessao;

    setUp(() {
      auth = AuthRepositorioFalso();
      sessao = SessaoCubit(auth);
    });

    blocTest<LoginCubit, LoginEstado>(
      'sucesso: enviando, depois conecta a sessão',
      build: () => LoginCubit(auth, sessao),
      act: (cubit) =>
          cubit.entrar(email: 'ana@exemplo.com', senha: 'exemplo-123'),
      expect: () => [const LoginEstado(enviando: true), const LoginEstado()],
      verify: (_) {
        expect(sessao.state, const SessaoEstado.conectada());
        expect(auth.entradas.single.email, 'ana@exemplo.com');
      },
    );

    blocTest<LoginCubit, LoginEstado>(
      'credenciais erradas mostram a mensagem da API',
      build: () {
        auth.erroAoEntrar = const ErroApi(
          'E-mail ou senha incorretos.',
          status: 401,
        );
        return LoginCubit(auth, sessao);
      },
      act: (cubit) => cubit.entrar(email: 'ana@exemplo.com', senha: 'errada'),
      expect: () => [
        const LoginEstado(enviando: true),
        const LoginEstado(erro: 'E-mail ou senha incorretos.'),
      ],
      verify: (_) => expect(sessao.state, const SessaoEstado.verificando()),
    );

    blocTest<LoginCubit, LoginEstado>(
      'sem rede',
      build: () {
        auth.erroAoEntrar = const ErroApi(ErroApi.semConexao);
        return LoginCubit(auth, sessao);
      },
      act: (cubit) => cubit.entrar(email: 'ana@exemplo.com', senha: 'x'),
      expect: () => [
        const LoginEstado(enviando: true),
        const LoginEstado(erro: 'Não foi possível falar com o servidor.'),
      ],
    );

    blocTest<LoginCubit, LoginEstado>(
      'campos vazios nem chamam a API',
      build: () => LoginCubit(auth, sessao),
      act: (cubit) => cubit.entrar(email: ' ', senha: ''),
      expect: () => [const LoginEstado(erro: 'Informe o e-mail e a senha.')],
      verify: (_) => expect(auth.entradas, isEmpty),
    );
  });
}
