import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../../contas/ui/editar_cartao_tela.dart';
import '../cubit/faturas_cubit.dart';
import '../data/fatura.dart';
import 'chip_status.dart';

/// Rota da lista de faturas de um cartão.
String rotaFaturas(String contaId) => '/mais/contas/cartao/$contaId';

/// Rota do detalhe de uma fatura; recebe em `extra` a ordem das faturas da
/// lista (para as setas).
String rotaFatura(String contaId, DateTime competencia) =>
    '${rotaFaturas(contaId)}/fatura/${competenciaParaApi(competencia)}';

/// Faturas do cartão: próximas, a atual e as anteriores.
class FaturasTela extends StatelessWidget {
  const FaturasTela({super.key, required this.contaId});

  final String contaId;

  Future<void> _abrir(
    BuildContext context,
    ResumoFatura fatura,
    ListaFaturas lista,
  ) async {
    await context.push(
      rotaFatura(contaId, fatura.competencia),
      extra: lista.emOrdem.map((f) => f.competencia).toList(),
    );
    // Editar ou ajustar no detalhe muda datas e valores daqui.
    if (context.mounted) await context.read<FaturasCubit>().carregar();
  }

  /// Depois de editar, recarrega as contas (nome, dias, ativo) e as faturas
  /// (dias novos mudam as datas das próximas).
  Future<void> _editarCartao(BuildContext context, Conta conta) async {
    final salvou = await context.push<bool>(
      rotaEditarCartao(contaId),
      extra: conta,
    );
    if (salvou == true && context.mounted) {
      await Future.wait([
        context.read<ContasCubit>().carregar(),
        context.read<FaturasCubit>().carregar(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conta = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.id == contaId).firstOrNull,
      _ => null,
    };
    final estado = context.watch<FaturasCubit>().state;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Espaco.x1,
        title: Text(conta?.nome ?? 'Cartão'),
        actions: [
          if (conta?.cartao != null)
            IconButton(
              tooltip: 'Editar cartão',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _editarCartao(context, conta!),
            ),
        ],
      ),
      body: switch (estado) {
        FaturasCarregando() => const Carregando(),
        FaturasErro(:final mensagem) => ErroComTentar(
          mensagem: mensagem,
          aoTentar: context.read<FaturasCubit>().carregar,
        ),
        FaturasCarregado(:final lista) => RefreshIndicator(
          onRefresh: context.read<FaturasCubit>().carregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.x4,
              0,
              Espaco.x4,
              Espaco.x6,
            ),
            children: [
              if (conta?.cartao case final cartao?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x1,
                    0,
                    Espaco.x1,
                    Espaco.x2,
                  ),
                  child: Text(
                    _resumoDoCartao(conta!, cartao),
                    style: context.textos.bodyMedium?.copyWith(
                      color: context.esquema.onSurfaceVariant,
                    ),
                  ),
                ),
              if (lista.proximas.isNotEmpty) ...[
                const TituloSecao('Próximas', pequeno: true),
                GrupoLista(
                  itens: [
                    for (final f in lista.proximas.reversed)
                      _ItemFatura(
                        fatura: f,
                        icone: Icons.event_rounded,
                        comStatus: false,
                        aoTocar: () => _abrir(context, f, lista),
                      ),
                  ],
                ),
                const SizedBox(height: Espaco.x4),
              ],
              const TituloSecao('Atual', pequeno: true),
              GrupoLista(
                itens: [
                  _ItemFatura(
                    fatura: lista.atual,
                    icone: Icons.credit_card_rounded,
                    aoTocar: () => _abrir(context, lista.atual, lista),
                  ),
                ],
              ),
              if (lista.anteriores.isNotEmpty) ...[
                const SizedBox(height: Espaco.x4),
                const TituloSecao('Anteriores', pequeno: true),
                GrupoLista(
                  itens: [
                    for (final f in lista.anteriores)
                      _ItemFatura(
                        fatura: f,
                        icone: Icons.lock_rounded,
                        aoTocar: () => _abrir(context, f, lista),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      },
    );
  }

  /// "Banco Exemplo · fecha dia 3 · vence dia 10 · limite R$ 3.000,00".
  static String _resumoDoCartao(Conta conta, Cartao cartao) => [
    ?conta.instituicao,
    'fecha dia ${cartao.diaFechamento}',
    'vence dia ${cartao.diaVencimento}',
    if (cartao.limite case final limite?) 'limite ${formatarDinheiro(limite)}',
  ].join(' · ');
}

class _ItemFatura extends StatelessWidget {
  const _ItemFatura({
    required this.fatura,
    required this.icone,
    required this.aoTocar,
    this.comStatus = true,
  });

  final ResumoFatura fatura;
  final IconData icone;
  final VoidCallback aoTocar;
  final bool comStatus;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return ItemLista(
      icone: icone,
      titulo: formatarMesAno(fatura.competencia),
      // Wrap: com fonte grande, a data desce para a linha de baixo.
      subtitulo: Wrap(
        spacing: Espaco.x2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (comStatus) ChipStatus(fatura.status),
          Text('vence ${formatarDiaCurto(fatura.dataVencimento)}'),
        ],
      ),
      aoTocar: aoTocar,
      direita: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatarDinheiro(fatura.valor),
            style: context.textos.titleMedium?.copyWith(
              fontFeatures: algarismosTabulares,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: esquema.onSurfaceVariant),
        ],
      ),
    );
  }
}
