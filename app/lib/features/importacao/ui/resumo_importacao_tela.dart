import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/estados.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../revisao/cubit/revisao_cubit.dart';
import '../cubit/importacao_cubit.dart';
import '../data/importacao.dart';
import 'textos.dart';

/// Resumo de uma importação: logo depois de importar ([recemImportada]) ou
/// aberto pelo histórico. Daqui se vai à Revisão ou se desfaz a importação.
class ResumoImportacaoTela extends StatelessWidget {
  const ResumoImportacaoTela({super.key, this.recemImportada = false});

  final bool recemImportada;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ImportacaoCubit, ImportacaoEstado>(
      listenWhen: (antes, depois) =>
          (!antes.desfeita && depois.desfeita) ||
          (depois.erroDesfazer != null &&
              antes.erroDesfazer != depois.erroDesfazer),
      listener: (context, estado) {
        final mensageiro = ScaffoldMessenger.of(context);
        if (estado.desfeita) {
          context.read<RevisaoCubit>().carregar();
          mensageiro.showSnackBar(
            const SnackBar(content: Text('Importação desfeita.')),
          );
          context.pop(true);
        } else {
          mensageiro.showSnackBar(
            SnackBar(content: Text(estado.erroDesfazer!)),
          );
        }
      },
      builder: (context, estado) {
        final importacao = estado.importacao;
        return Scaffold(
          appBar: AppBar(
            leading: recemImportada
                ? IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => context.pop(),
                  )
                : null,
            title: Text(
              recemImportada || importacao == null
                  ? 'Extrato importado'
                  : tituloDaImportacao(importacao),
            ),
          ),
          body: switch (estado) {
            ImportacaoEstado(importacao: null, :final erro?) => ErroComTentar(
              mensagem: erro,
              aoTentar: context.read<ImportacaoCubit>().carregar,
            ),
            ImportacaoEstado(importacao: null) => const Carregando(),
            _ => _Corpo(
              importacao: importacao!,
              recemImportada: recemImportada,
            ),
          },
          bottomNavigationBar: importacao == null
              ? null
              : _Rodape(importacao: importacao, desfazendo: estado.desfazendo),
        );
      },
    );
  }
}

class _Corpo extends StatelessWidget {
  const _Corpo({required this.importacao, required this.recemImportada});

  final Importacao importacao;
  final bool recemImportada;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final cores = context.cores;
    final textos = context.textos;
    final periodo =
        importacao.periodoInicio == null || importacao.periodoFim == null
        ? null
        : formatarPeriodo(importacao.periodoInicio!, importacao.periodoFim!);
    final origem = [?importacao.nomeArquivo, ?importacao.contaNome].join(' · ');
    final fatura = importacao.fatura;
    final saldo = importacao.saldoExtrato;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x2,
        Espaco.x4,
        Espaco.x4,
      ),
      children: [
        Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cores.ritmoOkContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                fatura == null
                    ? Icons.task_alt_rounded
                    : Icons.credit_card_rounded,
                size: 32,
                color: cores.ritmoOk,
              ),
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              recemImportada
                  ? '${plural(importacao.qtdRascunhos, 'rascunho', 'rascunhos')} '
                        'na Revisão'
                  : importacao.nomeArquivo ?? 'Extrato',
              style: textos.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              [
                if (recemImportada) origem else ?importacao.contaNome,
                ?periodo,
              ].join('\n'),
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: Espaco.x5),
        _Caixa(
          itens: [
            _Linha(
              icone: Icons.add_circle_rounded,
              fundo: esquema.primaryContainer,
              cor: esquema.onPrimaryContainer,
              titulo: 'Novas',
              subtitulo: subtituloDasNovas(importacao),
              valor: '${importacao.qtdNovas}',
            ),
            if (importacao.qtdPossiveisDuplicatas > 0)
              _Linha(
                icone: Icons.content_copy_rounded,
                fundo: cores.ritmoAtencaoContainer,
                cor: cores.ritmoAtencao,
                titulo: 'Possíveis duplicatas',
                subtitulo:
                    'Iguais a lançamentos que já estavam no app; você escolhe '
                    'qual fica',
                valor: '${importacao.qtdPossiveisDuplicatas}',
              ),
            if (importacao.qtdJaImportadas > 0)
              _Linha(
                icone: Icons.done_all_rounded,
                fundo: esquema.surfaceContainerHigh,
                cor: esquema.onSurfaceVariant,
                titulo: 'Já importadas',
                subtitulo:
                    'Mesmo identificador de uma importação anterior; ficaram '
                    'de fora',
                valor: '${importacao.qtdJaImportadas}',
              ),
            if (importacao.qtdParcelas > 0)
              _Linha(
                icone: Icons.splitscreen_rounded,
                fundo: esquema.secondaryContainer,
                cor: esquema.onSecondaryContainer,
                titulo: 'Parcelas',
                subtitulo:
                    'Data da compra estimada pela parcela (3/10 = 2 meses '
                    'antes)',
                valor: '${importacao.qtdParcelas}',
              ),
          ],
        ),
        if (saldo != null) ...[
          const SizedBox(height: Espaco.x4),
          _Caixa(
            itens: [
              _Linha(
                icone: Icons.account_balance_wallet_rounded,
                fundo: esquema.secondaryContainer,
                cor: esquema.onSecondaryContainer,
                titulo: 'Saldo no extrato',
                subtitulo:
                    'Em ${formatarDiaMes(saldo.data)}; guardado para conferir '
                    'com o saldo do app',
                valor: formatarDinheiro(saldo.valor),
                dinheiro: true,
              ),
            ],
          ),
        ],
        if (fatura != null) ...[
          const SizedBox(height: Espaco.x4),
          _Caixa(
            itens: [
              _Linha(
                icone: Icons.receipt_long_rounded,
                fundo: esquema.secondaryContainer,
                cor: esquema.onSecondaryContainer,
                titulo: 'Fatura de ${nomeDoMes(fatura.competencia)}',
                subtitulo:
                    'Valor do banco e fechamento em '
                    '${formatarDiaMes(fatura.dataFechamento)} gravados na '
                    'fatura',
                valor: fatura.valorInformado == null
                    ? ''
                    : formatarDinheiro(fatura.valorInformado!),
                dinheiro: true,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({required this.itens});

  final List<Widget> itens;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Raio.lg),
        border: Border.all(color: esquema.outlineVariant),
      ),
      child: Column(
        children: [
          for (final (indice, item) in itens.indexed) ...[
            if (indice > 0) Divider(height: 1, color: esquema.outlineVariant),
            item,
          ],
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({
    required this.icone,
    required this.fundo,
    required this.cor,
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    this.dinheiro = false,
  });

  final IconData icone;
  final Color fundo;
  final Color cor;
  final String titulo;
  final String subtitulo;
  final String valor;
  final bool dinheiro;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: fundo, shape: BoxShape.circle),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: Espaco.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleSmall),
                Text(
                  subtitulo,
                  style: textos.bodySmall?.copyWith(
                    color: context.esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.x4),
          Text(valor, style: dinheiro ? textos.titleMedium : textos.titleLarge),
        ],
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.importacao, required this.desfazendo});

  final Importacao importacao;
  final bool desfazendo;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: esquema.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x4,
            Espaco.x4,
            Espaco.x6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!importacao.podeDesfazer) ...[
                Aviso(
                  icone: Icons.lock_rounded,
                  fundo: esquema.surfaceContainerHigh,
                  cor: esquema.onSurfaceVariant,
                  texto: Text(
                    avisoSemDesfazer(importacao),
                    style: context.textos.bodyMedium,
                  ),
                ),
                const SizedBox(height: Espaco.x3),
              ],
              FilledButton.icon(
                onPressed: () => context.go('/revisao'),
                icon: const Icon(Icons.fact_check_rounded),
                label: Text(rotuloIrParaRevisao(importacao)),
              ),
              if (importacao.podeDesfazer) ...[
                const SizedBox(height: Espaco.x2),
                TextButton.icon(
                  onPressed: desfazendo ? null : () => _confirmar(context),
                  icon: const Icon(Icons.undo_rounded),
                  label: const Text('Desfazer importação'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmar(BuildContext context) async {
    final cubit = context.read<ImportacaoCubit>();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.undo_rounded),
        title: const Text('Desfazer a importação?'),
        content: Text(textoDoDesfazer(importacao)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desfazer'),
          ),
        ],
      ),
    );
    if (confirmado ?? false) await cubit.desfazer();
  }
}
