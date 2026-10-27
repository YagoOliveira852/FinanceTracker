import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../features/categorias/cubit/categorias_cubit.dart';
import '../features/contas/cubit/contas_cubit.dart';
import '../features/login/cubit/sessao_cubit.dart';
import '../features/revisao/cubit/revisao_cubit.dart';
import 'injecao.dart';
import 'router.dart';
import 'tema.dart';

/// Raiz do app: entrega repositórios e cubits às telas e liga tema, idioma
/// e rotas.
///
/// O [ContasCubit] fica aqui em cima porque Início, Contas e Lançamento
/// mostram as mesmas contas: criar uma conta ou lançar uma transação
/// recarrega um cubit só, e todas as telas veem o saldo novo. O
/// [CategoriasCubit] pelo mesmo motivo: Categorias e Lançamento. O
/// [RevisaoCubit] porque a barra de abas mostra o contador da Revisão.
class FinancasApp extends StatefulWidget {
  const FinancasApp(this.dependencias, {super.key});

  final Dependencias dependencias;

  @override
  State<FinancasApp> createState() => _FinancasAppState();
}

class _FinancasAppState extends State<FinancasApp> {
  late final GoRouter _router = criarRouter(widget.dependencias.sessao);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencias = widget.dependencias;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: dependencias.auth),
        RepositoryProvider.value(value: dependencias.contas),
        RepositoryProvider.value(value: dependencias.transacoes),
        RepositoryProvider.value(value: dependencias.faturas),
        RepositoryProvider.value(value: dependencias.categorias),
        RepositoryProvider.value(value: dependencias.revisao),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: dependencias.sessao),
          BlocProvider(
            // Criado já na abertura: o listener abaixo só recarrega nas
            // trocas para "conectada", sem uma segunda carga na criação.
            lazy: false,
            create: (_) {
              final contas = ContasCubit(dependencias.contas);
              if (dependencias.sessao.state is SessaoConectada) {
                contas.carregar();
              }
              return contas;
            },
          ),
          BlocProvider(
            lazy: false,
            create: (_) {
              final categorias = CategoriasCubit(dependencias.categorias);
              if (dependencias.sessao.state is SessaoConectada) {
                categorias.carregar();
              }
              return categorias;
            },
          ),
          BlocProvider(
            lazy: false,
            create: (_) {
              final revisao = RevisaoCubit(dependencias.revisao);
              if (dependencias.sessao.state is SessaoConectada) {
                revisao.carregar();
              }
              return revisao;
            },
          ),
        ],
        child: BlocListener<SessaoCubit, SessaoEstado>(
          // Recarrega contas, categorias e a revisão a cada login.
          listenWhen: (antes, depois) =>
              antes is! SessaoConectada && depois is SessaoConectada,
          listener: (context, _) {
            context.read<ContasCubit>().carregar();
            context.read<CategoriasCubit>().carregar();
            context.read<RevisaoCubit>().carregar();
          },
          child: MaterialApp.router(
            title: 'Finanças',
            debugShowCheckedModeBanner: false,
            theme: temaClaro(),
            darkTheme: temaEscuro(),
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
