import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../transacoes/ui/item_transacao.dart';
import '../cubit/fatura_cubit.dart';
import '../data/fatura.dart';
import 'ajuste_folha.dart';
import 'chip_status.dart';
import 'faturas_tela.dart';
import 'quadro_pagamento.dart';
import 'textos.dart';

/// Rota do Editar fatura; recebe o [DetalheFatura] em `extra` e devolve o
/// detalhe salvo.
String rotaEditarFatura(String contaId, DateTime competencia) =>
    '${rotaFatura(contaId, competencia)}/editar';

/// Rota do pagamento da fatura (o Lançamento já em Pagamento de fatura);
/// devolve `true` quando salvou.
String rotaPagarFatura(String contaId, DateTime competencia) =>
    '${rotaFatura(contaId, competencia)}/pagar';

/// Detalhe de uma fatura: valor, pagamentos, datas (com o porquê do ajuste
/// para dia útil) e as compras. As setas andam pelas faturas da lista; a
/// fechada a pagar tem "Registrar pagamento".
class FaturaTela extends StatefulWidget {
  const FaturaTela({
    super.key,
    required this.contaId,
    required this.competencia,
    this.ordem = const [],
  });

  final String contaId;
  final DateTime competencia;

  /// Competências da lista de faturas, da mais futura à mais antiga.
  final List<DateTime> ordem;

  @override
  State<FaturaTela> createState() => _FaturaTelaState();
}

class _FaturaTelaState extends State<FaturaTela> {
  late var _competencia = widget.competencia;

  @override
  void initState() {
    super.initState();
    context.read<FaturaCubit>().carregar(_competencia);
  }

  void _ir(DateTime competencia) {
    setState(() => _competencia = competencia);
    context.read<FaturaCubit>().carregar(competencia);
  }

  Future<void> _editar(DetalheFatura detalhe) async {
    final salva = await context.push<DetalheFatura>(
      rotaEditarFatura(widget.contaId, _competencia),
      extra: detalhe,
    );
    if (salva != null && mounted) context.read<FaturaCubit>().atualizar(salva);
  }

  Future<void> _pagar() async {
    final contas = context.read<ContasCubit>();
    final pagou = await context.push<bool>(
      rotaPagarFatura(widget.contaId, _competencia),
    );
    if (pagou != true || !mounted) return;
    // O pagamento muda o saldo da conta que pagou e o status da fatura.
    await context.read<FaturaCubit>().carregar(_competencia);
    await contas.carregar();
  }

  @override
  Widget build(BuildContext context) {
    final nome = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.id == widget.contaId).firstOrNull?.nome,
      _ => null,
    };
    final estado = context.watch<FaturaCubit>().state;
    final indice = widget.ordem.indexOf(_competencia);
    // A lista vai da mais futura à mais antiga: "anterior" é o próximo item.
    final anterior = indice >= 0 && indice + 1 < widget.ordem.length
        ? widget.ordem[indice + 1]
        : null;
    final proxima = indice > 0 ? widget.ordem[indice - 1] : null;

    return Scaffold(
      floatingActionButton: switch (estado) {
        FaturaCarregada(:final detalhe)
            when detalhe.resumo.status == StatusFatura.fechada =>
          FloatingActionButton.extended(
            onPressed: _pagar,
            icon: const Icon(Icons.payments_rounded),
            label: const Text('Registrar pagamento'),
          ),
        _ => null,
      },
      appBar: AppBar(
        titleSpacing: Espaco.x1,
        title: Text(nome ?? 'Cartão'),
        actions: [
          if (estado case FaturaCarregada(:final detalhe))
            IconButton(
              tooltip: 'Editar fatura',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _editar(detalhe),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                _Seta(
                  tooltip: 'Fatura anterior',
                  icone: Icons.chevron_left_rounded,
                  destino: anterior,
                  aoIr: _ir,
                ),
                Expanded(
                  child: Text(
                    tituloDaFatura(_competencia),
                    textAlign: TextAlign.center,
                    style: context.textos.titleMedium,
                  ),
                ),
                _Seta(
                  tooltip: 'Próxima fatura',
                  icone: Icons.chevron_right_rounded,
                  destino: proxima,
                  aoIr: _ir,
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (estado) {
              FaturaCarregando() => const Carregando(),
              FaturaErro(:final mensagem) => ErroComTentar(
                mensagem: mensagem,
                aoTentar: () =>
                    context.read<FaturaCubit>().carregar(_competencia),
              ),
              FaturaCarregada(:final detalhe) => _Detalhe(detalhe),
            },
          ),
        ],
      ),
    );
  }
}

class _Seta extends StatelessWidget {
  const _Seta({
    required this.tooltip,
    required this.icone,
    required this.destino,
    required this.aoIr,
  });

  final String tooltip;
  final IconData icone;
  final DateTime? destino;
  final ValueChanged<DateTime> aoIr;

  @override
  Widget build(BuildContext context) {
    final destino = this.destino;
    if (destino == null) return const SizedBox(width: 48);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icone),
      onPressed: () => aoIr(destino),
    );
  }
}

class _Detalhe extends StatelessWidget {
  const _Detalhe(this.detalhe);

  final DetalheFatura detalhe;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Embaixo, espaço para o botão "Registrar pagamento" não cobrir a
      // última compra.
      padding: const EdgeInsets.fromLTRB(Espaco.x4, Espaco.x2, Espaco.x4, 96),
      children: [
        _CardResumo(detalhe),
        const SizedBox(height: Espaco.x4),
        TituloSecao('Compras · ${detalhe.transacoes.length}'),
        if (detalhe.transacoes.isEmpty)
          const GrupoLista(
            itens: [
              ItemLista(
                icone: Icons.receipt_long_rounded,
                titulo: 'Nenhuma compra nesta fatura',
                habilitado: false,
              ),
            ],
          )
        else
          GrupoLista(
            itens: [
              for (final t in detalhe.transacoes)
                ItemTransacao(transacao: t, subtitulo: formatarDiaMes(t.data)),
            ],
          ),
      ],
    );
  }
}

class _CardResumo extends StatelessWidget {
  const _CardResumo(this.detalhe);

  final DetalheFatura detalhe;

  @override
  Widget build(BuildContext context) {
    final resumo = detalhe.resumo;
    final aberta = resumo.status == StatusFatura.aberta;
    final paga = resumo.status == StatusFatura.paga;
    // Fechada com parte paga: o número grande é o que falta.
    final parcial = !aberta && !paga && resumo.valorPago > Decimal.zero;
    final textos = context.textos;
    final variante = context.esquema.onSurfaceVariant;
    final informado = resumo.valorInformado;
    final diferenca = resumo.diferenca;
    final rotuloPagamento = switch (resumo.status) {
      StatusFatura.paga => 'Paga em',
      StatusFatura.aberta => 'Pagamento adiantado em',
      StatusFatura.fechada => 'Pagamento em',
    };
    final nomes = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) => {
        for (final c in resumo.contas)
          c.id: c.instituicao == null ? c.nome : '${c.nome} · ${c.instituicao}',
      },
      _ => const <String, String>{},
    };
    final explicacoes = [
      ?_explicacao(
        'Fechamento',
        resumo.dataFechamento,
        detalhe.fechamentoCalculado,
        detalhe.ajusteFechamento,
      ),
      ?_explicacao(
        'Vencimento',
        resumo.dataVencimento,
        detalhe.vencimentoCalculado,
        detalhe.ajusteVencimento,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChipStatus(resumo.status, grande: true),
            const SizedBox(height: Espaco.x2),
            Text(
              aberta
                  ? 'Total até agora'
                  : parcial
                  ? 'Falta pagar'
                  : 'Valor da fatura',
              style: textos.bodySmall,
            ),
            Text(
              formatarDinheiro(parcial ? resumo.aPagar : resumo.valor),
              style: textos.displaySmall?.copyWith(
                fontFeatures: algarismosTabulares,
              ),
            ),
            if (parcial)
              Text(
                'De ${formatarDinheiro(resumo.valor)} da fatura. Pagando o '
                'restante, ela fica paga.',
                style: textos.bodyMedium?.copyWith(color: variante),
              )
            else if (paga && informado != null && diferenca == null)
              const _ConfereComBanco()
            else if (informado == null)
              Text(
                'Soma das compras lançadas. O banco ainda não informou o '
                'valor desta fatura.',
                style: textos.bodyMedium?.copyWith(color: variante),
              )
            else ...[
              const SizedBox(height: Espaco.x1),
              _Linha('Informado pelo banco', informado),
              _Linha('Calculado (compras lançadas)', resumo.valorCalculado),
            ],
            if (diferenca != null) ...[
              const SizedBox(height: Espaco.x2),
              _AvisoDiferenca(detalhe, diferenca),
            ],
            if (aberta && resumo.valorPago > Decimal.zero) ...[
              const SizedBox(height: Espaco.x1),
              Text(
                'Falta pagar ${formatarDinheiro(resumo.aPagar)} até agora. '
                'Compras novas ainda entram nesta fatura.',
                style: textos.bodyMedium?.copyWith(color: variante),
              ),
            ],
            for (final pagamento in detalhe.pagamentos) ...[
              const SizedBox(height: Espaco.x2),
              QuadroPagamento(
                pagamento,
                rotulo: rotuloPagamento,
                nomeDaConta: nomes[pagamento.contaId] ?? '',
              ),
            ],
            const SizedBox(height: Espaco.x3),
            const Divider(height: 1),
            const SizedBox(height: Espaco.x3),
            Row(
              children: [
                Expanded(
                  child: _Data(
                    aberta ? 'Fecha' : 'Fechou',
                    resumo.dataFechamento,
                  ),
                ),
                Expanded(
                  child: _Data(
                    paga ? 'Venceu' : 'Vence',
                    resumo.dataVencimento,
                  ),
                ),
              ],
            ),
            for (final texto in explicacoes) ...[
              const SizedBox(height: Espaco.x1),
              Text(texto, style: textos.bodySmall?.copyWith(color: variante)),
            ],
          ],
        ),
      ),
    );
  }

  /// "Vencimento: dia 10 caiu num sábado…", só quando a data em uso é a
  /// calculada (uma data editada à mão não tem esse porquê).
  static String? _explicacao(
    String rotulo,
    DateTime efetiva,
    DateTime calculada,
    AjusteData? ajuste,
  ) {
    if (ajuste == null || efetiva != calculada) return null;
    final texto = explicarAjuste(ajuste);
    return '$rotulo: ${texto[0].toLowerCase()}${texto.substring(1)}';
  }
}

/// Fatura paga cujo calculado bate com o informado pelo banco.
class _ConfereComBanco extends StatelessWidget {
  const _ConfereComBanco();

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Row(
      children: [
        Icon(Icons.check_rounded, size: 18, color: context.cores.ritmoOk),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Confere com o valor informado pelo banco.',
            style: textos.bodyMedium?.copyWith(
              color: context.esquema.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha(this.rotulo, this.valor);

  final String rotulo;
  final Decimal valor;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rotulo,
              style: textos.bodyMedium?.copyWith(
                color: context.esquema.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            formatarDinheiro(valor),
            style: textos.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: algarismosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}

class _Data extends StatelessWidget {
  const _Data(this.rotulo, this.data);

  final String rotulo;
  final DateTime data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: context.textos.bodySmall),
        Text(formatarDiaCurto(data), style: context.textos.titleMedium),
      ],
    );
  }
}

/// "Faltam R$ 45,90 em lançamentos." com o botão de ajuste.
class _AvisoDiferenca extends StatelessWidget {
  const _AvisoDiferenca(this.detalhe, this.diferenca);

  final DetalheFatura detalhe;
  final Decimal diferenca;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Espaco.x3,
        Espaco.x2,
        Espaco.x3,
        Espaco.x1,
      ),
      decoration: BoxDecoration(
        color: cores.ritmoAtencaoContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_rounded, size: 20, color: cores.ritmoAtencao),
              const SizedBox(width: Espaco.x2),
              Expanded(
                child: Text(
                  descreverDiferenca(diferenca),
                  style: context.textos.bodyMedium?.copyWith(
                    color: cores.ritmoAtencao,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: () => abrirAjuste(context, detalhe),
            style: TextButton.styleFrom(foregroundColor: cores.ritmoAtencao),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Ajustar para o valor real'),
          ),
        ],
      ),
    );
  }
}
