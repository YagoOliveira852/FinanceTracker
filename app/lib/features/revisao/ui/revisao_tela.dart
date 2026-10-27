import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../transacoes/data/transacao.dart';
import '../cubit/revisao_cubit.dart';
import '../data/revisao.dart';
import 'folha_rascunho.dart';
import 'folhas_decisao.dart';
import 'item_rascunho.dart';
import 'textos.dart';

/// Aba Revisão: as decisões no topo ("Precisam de você") e os rascunhos
/// comuns por dia, com a categoria sugerida pelas regras.
class RevisaoTela extends StatelessWidget {
  const RevisaoTela({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<RevisaoCubit>().state;
    final cubit = context.read<RevisaoCubit>();
    final revisao = estado.revisao;

    // Toda ação termina com um aviso; confirmar muda o saldo das contas.
    return BlocListener<RevisaoCubit, RevisaoEstado>(
      listenWhen: (antes, depois) =>
          depois.aviso != null && antes.aviso != depois.aviso,
      listener: (context, estado) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(estado.aviso!)));
        context.read<ContasCubit>().carregar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revisão'),
              if (estado.total > 0)
                Text(
                  textoDoTotal(estado.total),
                  style: context.textos.bodySmall?.copyWith(
                    color: context.esquema.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        body: switch (estado) {
          RevisaoEstado(revisao: null, :final erro?) => ErroComTentar(
            mensagem: erro,
            aoTentar: cubit.carregar,
          ),
          RevisaoEstado(revisao: null) => const Carregando(),
          RevisaoEstado(total: 0) => const _Vazio(),
          _ => RefreshIndicator(
            onRefresh: cubit.carregar,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Espaco.x4,
                0,
                Espaco.x4,
                Espaco.x6,
              ),
              children: [
                if (revisao!.qtdSugeridos > 0)
                  _FaixaDoLote(
                    quantidade: revisao.qtdSugeridos,
                    aoConfirmar: estado.enviando ? null : cubit.confirmarLote,
                  ),
                if (revisao.qtdDecisoes > 0) ...[
                  TituloSecao(
                    'Precisam de você · ${revisao.qtdDecisoes}',
                    pequeno: true,
                  ),
                  GrupoLista(itens: _decisoes(context, revisao)),
                ],
                for (final dia in estado.dias) ...[
                  TituloSecao(
                    formatarCabecalhoDia(dia.data, estado.hoje),
                    pequeno: true,
                  ),
                  GrupoLista(
                    itens: [
                      for (final rascunho in dia.rascunhos)
                        ItemRascunho(
                          rascunho: rascunho,
                          aoConfirmar: estado.enviando
                              ? null
                              : () => cubit.confirmarComSugestao(rascunho),
                          aoAbrir: () => abrirFolhaRascunho(context, rascunho),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        },
      ),
    );
  }

  /// As linhas de decisão: sem botões, o toque abre a folha da decisão.
  static List<Widget> _decisoes(BuildContext context, Revisao revisao) {
    final cores = context.cores;
    final esquema = context.esquema;
    return [
      for (final par in revisao.pares)
        ItemLista(
          icone: Icons.sync_alt_rounded,
          corIcone: esquema.onPrimaryContainer,
          fundoIcone: esquema.primaryContainer,
          titulo: 'Par de transferência?',
          aoTocar: () => abrirFolhaPar(context, par),
          subtitulo: Text(
            '${par.saida.contaNome} → ${par.entrada.contaNome}',
            overflow: TextOverflow.ellipsis,
          ),
          // Sem sinal: ligado, o par não é gasto nem renda.
          direita: ValorNaRevisao(
            par.saida.copyWith(tipo: TipoTransacao.transferenciaSaida),
          ),
        ),
      for (final pagamento in revisao.pagamentos)
        ItemLista(
          icone: Icons.credit_card_rounded,
          titulo: 'Pagamento de fatura?',
          aoTocar: () => abrirFolhaPagamento(context, pagamento),
          subtitulo: Text(
            '${pagamento.contaNome} · escolha a fatura',
            overflow: TextOverflow.ellipsis,
          ),
          direita: ValorNaRevisao(pagamento),
        ),
      for (final duplicata in revisao.duplicatas)
        ItemLista(
          icone: Icons.content_copy_rounded,
          corIcone: cores.ritmoAtencao,
          fundoIcone: cores.ritmoAtencaoContainer,
          titulo: 'Possível duplicata',
          aoTocar: () => abrirFolhaDuplicata(context, duplicata),
          subtitulo: Text(
            '${duplicata.outra.descricao} · ${duplicata.outra.fonte.rotulo} '
            'e ${duplicata.rascunho.fonte.rotulo}',
            overflow: TextOverflow.ellipsis,
          ),
          direita: ValorNaRevisao(duplicata.rascunho),
        ),
      for (final sumida in revisao.sumidas)
        ItemLista(
          icone: Icons.cloud_off_rounded,
          corIcone: cores.ritmoRisco,
          fundoIcone: cores.ritmoRiscoContainer,
          titulo: 'Sumiu do Open Finance',
          aoTocar: () => abrirFolhaSumida(context, sumida),
          subtitulo: Text(
            '${sumida.descricao} · confirmada',
            overflow: TextOverflow.ellipsis,
          ),
          direita: ValorNaRevisao(sumida),
        ),
    ];
  }
}

/// "7 rascunhos com categoria sugerida" e "Confirmar 7".
class _FaixaDoLote extends StatelessWidget {
  const _FaixaDoLote({required this.quantidade, required this.aoConfirmar});

  final int quantidade;
  final VoidCallback? aoConfirmar;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      margin: const EdgeInsets.only(top: Espaco.x2),
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x2,
        Espaco.x2,
        Espaco.x2,
      ),
      decoration: BoxDecoration(
        color: esquema.primaryContainer,
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: esquema.onPrimaryContainer),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Text(
              textoDoLote(quantidade),
              style: context.textos.labelLarge?.copyWith(
                color: esquema.onPrimaryContainer,
              ),
            ),
          ),
          FilledButton(
            onPressed: aoConfirmar,
            child: Text('Confirmar $quantidade'),
          ),
        ],
      ),
    );
  }
}

/// "Nada para revisar". Importar extrato chega com a importação (em breve).
class _Vazio extends StatelessWidget {
  const _Vazio();

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: Icons.task_alt_rounded,
      titulo: 'Nada para revisar',
      texto: 'Tudo o que chegou está confirmado.',
      acao: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Espaco.x2,
        runSpacing: Espaco.x2,
        children: [
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Importar extrato'),
          ),
          const SeloEmBreve(),
        ],
      ),
    );
  }
}
