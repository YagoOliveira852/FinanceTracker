import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../cubit/transacoes_cubit.dart';
import '../data/transacao.dart';

/// Rota do Lançamento; recebe a conta do filtro em `extra` e devolve `true`
/// quando salvou.
const rotaLancamento = '/transacoes/nova';

class TransacoesTela extends StatelessWidget {
  const TransacoesTela({super.key});

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
                              _ItemTransacao(
                                transacao: t,
                                conta: estado.nomeDaConta(t.contaId) ?? '',
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
          for (final conta in estado.contas)
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

class _ItemTransacao extends StatelessWidget {
  const _ItemTransacao({required this.transacao, required this.conta});

  final Transacao transacao;
  final String conta;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final tipo = transacao.tipo;
    final rascunho = transacao.status == StatusTransacao.rascunho;

    // Receita e despesa ganham cor; transferência e pagamento de fatura não
    // são gasto nem renda, então ficam neutros e sem sinal.
    final (corValor, corIcone, fundoIcone) = switch (tipo) {
      _ when rascunho => (
        tipo == TipoTransacao.despesa ? cores.despesa : null,
        cores.rascunho,
        cores.rascunhoContainer,
      ),
      TipoTransacao.receita => (
        cores.receita,
        cores.receita,
        cores.receitaContainer,
      ),
      TipoTransacao.despesa => (
        cores.despesa,
        cores.despesa,
        cores.despesaContainer,
      ),
      _ => (null, null, null),
    };
    final semSinal = switch (tipo) {
      TipoTransacao.transferenciaEntrada ||
      TipoTransacao.transferenciaSaida ||
      TipoTransacao.pagamentoFatura => true,
      _ => false,
    };

    return ItemLista(
      icone: rascunho ? Icons.edit_note_rounded : _icone(tipo),
      corIcone: corIcone,
      fundoIcone: fundoIcone,
      titulo: transacao.descricao,
      subtitulo: Row(
        children: [
          if (rascunho) ...[const _SeloRascunho(), const SizedBox(width: 8)],
          Flexible(child: Text(conta, overflow: TextOverflow.ellipsis)),
        ],
      ),
      direita: Text(
        semSinal
            ? formatarDinheiro(transacao.valor)
            : formatarDinheiroComSinal(transacao.valor, entrada: tipo.entrada),
        style: context.textos.titleMedium?.copyWith(
          color: corValor,
          fontFeatures: algarismosTabulares,
        ),
      ),
    );
  }

  static IconData _icone(TipoTransacao tipo) => switch (tipo) {
    TipoTransacao.receita => Icons.payments_rounded,
    TipoTransacao.despesa => Icons.shopping_bag_rounded,
    TipoTransacao.transferenciaEntrada ||
    TipoTransacao.transferenciaSaida => Icons.sync_alt_rounded,
    TipoTransacao.pagamentoFatura => Icons.credit_card_rounded,
    TipoTransacao.aporte || TipoTransacao.resgate => Icons.savings_rounded,
    TipoTransacao.estorno => Icons.undo_rounded,
    TipoTransacao.ajusteEntrada ||
    TipoTransacao.ajusteSaida => Icons.tune_rounded,
  };
}

class _SeloRascunho extends StatelessWidget {
  const _SeloRascunho();

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: cores.rascunhoContainer,
        border: Border.all(color: cores.rascunho),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Rascunho',
        style: context.textos.labelMedium?.copyWith(color: cores.rascunho),
      ),
    );
  }
}
