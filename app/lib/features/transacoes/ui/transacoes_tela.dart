import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../cubit/transacoes_cubit.dart';
import '../data/transacao.dart';
import 'item_transacao.dart';

/// Rota do Lançamento; recebe a conta do filtro em `extra` e devolve `true`
/// quando salvou.
const rotaLancamento = '/transacoes/nova';

class TransacoesTela extends StatelessWidget {
  const TransacoesTela({super.key});

  /// A conta da transação; na transferência ligada, "Origem → Destino" (o
  /// mesmo nos dois lados, com qualquer filtro).
  static String _subtitulo(TransacoesEstado estado, Transacao t) {
    String nome(String id) => estado.nomeDaConta(id) ?? '';
    // A fatura vem antes do cartão: se o nome for longo, o corte da linha
    // leva o nome e o mês continua à vista.
    if (t.tipo == TipoTransacao.pagamentoFatura) {
      if (t.fatura case final fatura?) {
        final mes = nomeDoMes(fatura.competencia);
        return 'Fatura de $mes · ${nome(fatura.cartaoId)}';
      }
    }
    return switch (t.transferencia) {
      final par? => '${nome(par.contaOrigemId)} → ${nome(par.contaDestinoId)}',
      null => nome(t.contaId),
    };
  }

  Future<void> _lancar(BuildContext context) async {
    final contas = context.read<ContasCubit>();
    final salvou = await context.push<bool>(
      rotaLancamento,
      extra: context.read<TransacoesCubit>().state.contaId,
    );
    // O lançamento muda o saldo das contas (Início e Contas); a lista desta
    // tela recarrega junto, pelo BlocListener abaixo.
    if (salvou == true) await contas.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<TransacoesCubit>().state;
    final cubit = context.read<TransacoesCubit>();

    // A aba fica viva: quando as contas mudam (conta nova, lançamento), a
    // lista e os chips de filtro recarregam.
    return BlocListener<ContasCubit, ContasEstado>(
      listenWhen: (antes, depois) =>
          depois is ContasCarregado && antes != depois,
      listener: (_, _) => cubit.carregar(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Transações')),
        floatingActionButton: estado.dias.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => _lancar(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Lançar'),
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SeletorDeMes(estado: estado, cubit: cubit),
            _FiltroDeContas(estado: estado, cubit: cubit),
            Expanded(
              child: switch (estado) {
                TransacoesEstado(carregando: true, dias: []) =>
                  const Carregando(),
                TransacoesEstado(:final erro?) => ErroComTentar(
                  mensagem: erro,
                  aoTentar: cubit.carregar,
                ),
                TransacoesEstado(dias: []) => _Vazio(
                  estado: estado,
                  aoLancar: () => _lancar(context),
                ),
                _ => RefreshIndicator(
                  onRefresh: cubit.carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      Espaco.x4,
                      0,
                      Espaco.x4,
                      96,
                    ),
                    children: [
                      for (final dia in estado.dias) ...[
                        TituloSecao(
                          formatarCabecalhoDia(dia.data, estado.hoje),
                          pequeno: true,
                        ),
                        GrupoLista(
                          itens: [
                            for (final t in dia.transacoes)
                              ItemTransacao(
                                transacao: t,
                                subtitulo: _subtitulo(estado, t),
                              ),
                          ],
                        ),
                        const SizedBox(height: Espaco.x2),
                      ],
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SeletorDeMes extends StatelessWidget {
  const _SeletorDeMes({required this.estado, required this.cubit});

  final TransacoesEstado estado;
  final TransacoesCubit cubit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Espaco.x1),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mês anterior',
            onPressed: cubit.mesAnterior,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              formatarMesAno(estado.mes),
              textAlign: TextAlign.center,
              style: context.textos.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Próximo mês',
            onPressed: estado.noMesAtual ? null : cubit.proximoMes,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _FiltroDeContas extends StatelessWidget {
  const _FiltroDeContas({required this.estado, required this.cubit});

  final TransacoesEstado estado;
  final TransacoesCubit cubit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x1,
        Espaco.x4,
        Espaco.x3,
      ),
      child: Row(
        spacing: Espaco.x2,
        children: [
          ChipOpcao(
            rotulo: 'Todas',
            selecionado: estado.contaId == null,
            aoTocar: () => cubit.filtrar(null),
          ),
          for (final conta in estado.contas.where((c) => c.ativa))
            ChipOpcao(
              rotulo: conta.nome,
              selecionado: estado.contaId == conta.id,
              aoTocar: () => cubit.filtrar(conta.id),
            ),
        ],
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.estado, required this.aoLancar});

  final TransacoesEstado estado;
  final VoidCallback aoLancar;

  @override
  Widget build(BuildContext context) {
    final conta = estado.contaId == null
        ? null
        : estado.nomeDaConta(estado.contaId!);
    return EstadoVazio(
      icone: Icons.receipt_long_rounded,
      titulo: 'Nenhuma transação em ${nomeDoMes(estado.mes)}',
      texto: conta == null
          ? 'Nenhum lançamento neste mês. Lance uma transação ou veja outro '
                'mês.'
          : '$conta não tem lançamentos neste mês. Troque o filtro ou lance '
                'uma transação.',
      acao: FilledButton.icon(
        onPressed: aoLancar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Lançar transação'),
      ),
    );
  }
}
