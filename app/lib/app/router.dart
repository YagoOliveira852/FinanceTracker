import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/configuracoes/ui/mais_tela.dart';
import '../features/contas/cubit/nova_conta_cubit.dart';
import '../features/contas/data/contas_repositorio.dart';
import '../features/contas/ui/contas_tela.dart';
import '../features/contas/ui/nova_conta_tela.dart';
import '../features/faturas/data/faturas_repositorio.dart';
import '../features/inicio/ui/inicio_tela.dart';
import '../features/login/cubit/login_cubit.dart';
import '../features/login/cubit/sessao_cubit.dart';
import '../features/login/data/auth_repositorio.dart';
import '../features/login/ui/login_tela.dart';
import '../features/revisao/ui/revisao_tela.dart';
import '../features/transacoes/cubit/lancamento_cubit.dart';
import '../features/transacoes/cubit/transacoes_cubit.dart';
import '../features/transacoes/data/transacoes_repositorio.dart';
import '../features/transacoes/ui/lancamento_tela.dart';
import '../features/transacoes/ui/transacoes_tela.dart';

const rotaLogin = '/login';
const rotaInicio = '/inicio';

/// Rotas do app.
///
/// - `/login` fora das abas.
/// - Quatro abas (`StatefulShellRoute`): cada uma guarda a própria pilha, como
///   um Tab.Navigator com stacks no React Navigation.
/// - Nova conta e Lançamento abrem por cima das abas (navigator raiz), sem a
///   barra de navegação, como no design.
///
/// O `redirect` segue o [SessaoCubit]: sem sessão, tudo leva ao login; com
/// sessão, o login leva ao Início. Quando a sessão expira (refresh recusado),
/// o redirect roda de novo e o app volta ao login.
GoRouter criarRouter(SessaoCubit sessao) {
  final chaveRaiz = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: chaveRaiz,
    initialLocation: rotaInicio,
    refreshListenable: _OuvinteDeStream(sessao.stream),
    redirect: (context, state) {
      final conectada = sessao.state is SessaoConectada;
      final noLogin = state.matchedLocation == rotaLogin;
      if (!conectada && !noLogin) return rotaLogin;
      if (conectada && noLogin) return rotaInicio;
      return null;
    },
    routes: [
      GoRoute(
        path: rotaLogin,
        builder: (context, _) => BlocProvider(
          create: (context) => LoginCubit(
            context.read<AuthRepositorio>(),
            context.read<SessaoCubit>(),
          ),
          child: const LoginTela(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, _, abas) => _EstruturaAbas(abas),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: rotaInicio, builder: (_, _) => const InicioTela()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/revisao', builder: (_, _) => const RevisaoTela()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transacoes',
                builder: (context, _) => BlocProvider(
                  create: (context) => TransacoesCubit(
                    context.read<TransacoesRepositorio>(),
                    context.read<ContasRepositorio>(),
                  )..carregar(),
                  child: const TransacoesTela(),
                ),
                routes: [
                  GoRoute(
                    path: 'nova',
                    parentNavigatorKey: chaveRaiz,
                    builder: (context, state) => BlocProvider(
                      create: (context) => LancamentoCubit(
                        context.read<TransacoesRepositorio>(),
                        context.read<FaturasRepositorio>(),
                      ),
                      child: LancamentoTela(
                        contaInicial: state.extra as String?,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mais',
                builder: (_, _) => const MaisTela(),
                routes: [
                  GoRoute(
                    path: 'contas',
                    builder: (_, _) => const ContasTela(),
                    routes: [
                      GoRoute(
                        path: 'nova',
                        parentNavigatorKey: chaveRaiz,
                        builder: (context, _) => BlocProvider(
                          create: (context) =>
                              NovaContaCubit(context.read<ContasRepositorio>()),
                          child: const NovaContaTela(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Barra de navegação inferior com as quatro abas.
class _EstruturaAbas extends StatelessWidget {
  const _EstruturaAbas(this.abas);

  final StatefulNavigationShell abas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: abas,
      bottomNavigationBar: NavigationBar(
        selectedIndex: abas.currentIndex,
        // Tocar na aba atual volta para a raiz dela.
        onDestinationSelected: (indice) =>
            abas.goBranch(indice, initialLocation: indice == abas.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Revisão',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Transações',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'Mais',
          ),
        ],
      ),
    );
  }
}

/// Avisa o go_router a cada mudança da sessão, para ele refazer o redirect.
class _OuvinteDeStream extends ChangeNotifier {
  _OuvinteDeStream(Stream<Object?> stream) {
    _inscricao = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _inscricao;

  @override
  void dispose() {
    _inscricao.cancel();
    super.dispose();
  }
}
