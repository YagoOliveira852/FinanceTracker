import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../features/categorias/cubit/categorias_cubit.dart';
import '../features/configuracoes/cubit/tema_cubit.dart';
import '../features/contas/cubit/contas_cubit.dart';
import '../features/importacao/cubit/compartilhado_cubit.dart';
import '../features/importacao/data/importacao.dart';
import '../features/importacao/ui/importar_tela.dart';
import '../features/inicio/cubit/inicio_cubit.dart';
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
/// recarrega um cubit só, e todas as telas veem o saldo novo. O [InicioCubit]
/// porque o Início recarrega no login, ao voltar para a aba e no toque do
/// lembrete, e a aba guarda o resumo entre as idas e vindas. O
/// [CategoriasCubit] pelo mesmo motivo: Categorias e Lançamento. O
/// [RevisaoCubit] porque a barra de abas mostra o contador da Revisão. O
/// [CompartilhadoCubit] porque o extrato do Compartilhar pode chegar antes
/// do login e só abre a importação com a sessão conectada. O [TemaCubit]
/// porque o `MaterialApp` lê dele o tema escolhido em Mais.
///
/// Os lembretes de salário são reagendados a cada abertura com sessão e a
/// cada login, e cancelados no "Sair"; o toque num lembrete com o app aberto
/// volta ao Início.
class FinancasApp extends StatefulWidget {
  const FinancasApp(this.dependencias, {super.key});

  final Dependencias dependencias;

  @override
  State<FinancasApp> createState() => _FinancasAppState();
}

class _FinancasAppState extends State<FinancasApp> {
  late final GoRouter _router = criarRouter(widget.dependencias.sessao);
  late final InicioCubit _inicio = InicioCubit(
    widget.dependencias.planejamento,
    widget.dependencias.aporteDispensado,
  );
  late final StreamSubscription<void> _toques;

  @override
  void initState() {
    super.initState();
    final dependencias = widget.dependencias;
    if (dependencias.sessao.state is SessaoConectada) {
      dependencias.lembretes.reagendar();
      _inicio.carregar();
    }
    _toques = dependencias.notificador.toques.listen((_) {
      _inicio.carregar();
      _router.go(rotaInicio);
    });
  }

  @override
  void dispose() {
    _toques.cancel();
    _inicio.close();
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
        RepositoryProvider.value(value: dependencias.planejamento),
        RepositoryProvider.value(value: dependencias.importacoes),
        RepositoryProvider.value(value: dependencias.seletorArquivo),
        RepositoryProvider.value(value: dependencias.lembretes),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: dependencias.sessao),
          BlocProvider.value(value: dependencias.tema),
          BlocProvider.value(value: _inicio),
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
          BlocProvider(
            lazy: false,
            create: (_) => CompartilhadoCubit(dependencias.compartilhamento),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<SessaoCubit, SessaoEstado>(
              // Recarrega o Início, contas, categorias e a revisão a cada
              // login.
              listenWhen: (antes, depois) =>
                  antes is! SessaoConectada && depois is SessaoConectada,
              listener: (context, _) {
                _inicio.carregar();
                context.read<ContasCubit>().carregar();
                context.read<CategoriasCubit>().carregar();
                context.read<RevisaoCubit>().carregar();
                dependencias.lembretes.reagendar();
                _abrirCompartilhado(context);
              },
            ),
            BlocListener<SessaoCubit, SessaoEstado>(
              // Só o "Sair": com a sessão expirada, os lembretes ficam (o
              // toque leva ao login e, depois dele, ao Início).
              listenWhen: (antes, depois) =>
                  antes is SessaoConectada &&
                  depois is SessaoDesconectada &&
                  !depois.expirou,
              listener: (_, _) => dependencias.lembretes.cancelar(),
            ),
            BlocListener<CompartilhadoCubit, ArquivoEscolhido?>(
              listenWhen: (_, depois) => depois != null,
              listener: (context, _) => _abrirCompartilhado(context),
            ),
          ],
          child: BlocBuilder<TemaCubit, ThemeMode>(
            builder: (context, modo) => MaterialApp.router(
              title: 'Finanças',
              debugShowCheckedModeBanner: false,
              theme: temaClaro(),
              darkTheme: temaEscuro(),
              themeMode: modo,
              locale: const Locale('pt', 'BR'),
              supportedLocales: const [Locale('pt', 'BR')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              routerConfig: _router,
            ),
          ),
        ),
      ),
    );
  }

  /// Extrato recebido pelo Compartilhar: com a sessão conectada, abre a
  /// importação já preenchida; sem ela, espera o login.
  void _abrirCompartilhado(BuildContext context) {
    if (context.read<SessaoCubit>().state is! SessaoConectada) return;
    final arquivo = context.read<CompartilhadoCubit>().consumir();
    if (arquivo == null) return;
    // Depois do quadro: o redirect do login para o Início roda antes.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _router.push(rotaImportar, extra: arquivo),
    );
  }
}
