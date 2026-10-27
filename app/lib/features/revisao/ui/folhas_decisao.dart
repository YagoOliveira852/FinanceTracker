import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../faturas/data/fatura.dart';
import '../../transacoes/data/transacao.dart';
import '../cubit/decisao_cubit.dart';
import '../cubit/pagamento_revisao_cubit.dart';
import '../cubit/revisao_cubit.dart';
import '../data/revisao.dart';
import '../data/revisao_repositorio.dart';
import 'folha_rascunho.dart';
import 'item_rascunho.dart';

/// "Par de transferência?": Ligar ou Não é par.
Future<void> abrirFolhaPar(BuildContext context, ParSugerido par) =>
    _abrirDecisao(context, (repositorio) => _FolhaPar(par, repositorio));

/// "Possível duplicata": escolhe qual fica.
Future<void> abrirFolhaDuplicata(BuildContext context, Duplicata duplicata) =>
    _abrirDecisao(
      context,
      (repositorio) => _FolhaDuplicata(duplicata, repositorio),
    );

/// "Sumiu do Open Finance": Manter ou Remover.
Future<void> abrirFolhaSumida(BuildContext context, ItemRevisao sumida) =>
    _abrirDecisao(context, (repositorio) => _FolhaSumida(sumida, repositorio));

/// "Pagamento de fatura?": escolhe a fatura; "É outra coisa" abre a folha
/// comum do rascunho, como despesa.
Future<void> abrirFolhaPagamento(BuildContext context, ItemRevisao pagamento) {
  final repositorio = context.read<RevisaoRepositorio>();
  final revisao = context.read<RevisaoCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (folha) => BlocProvider(
      create: (_) => PagamentoRevisaoCubit(repositorio, pagamento)..carregar(),
      child: _FolhaPagamento(
        aoConcluir: revisao.concluiu,
        aoOutraCoisa: () {
          Navigator.of(folha).pop();
          abrirFolhaRascunho(
            context,
            Rascunho(
              item: pagamento,
              padrao: '',
              efeitoConfirmando: EfeitoRegra.nenhuma,
              efeitoCorrigindo: EfeitoRegra.nenhuma,
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _abrirDecisao(
  BuildContext context,
  Widget Function(RevisaoRepositorio repositorio) folha,
) {
  final repositorio = context.read<RevisaoRepositorio>();
  final revisao = context.read<RevisaoCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => DecisaoCubit(),
      child: BlocListener<DecisaoCubit, DecisaoEstado>(
        listenWhen: (antes, depois) =>
            antes.concluido == null && depois.concluido != null,
        listener: (context, estado) {
          Navigator.of(context).pop();
          revisao.concluiu(estado.concluido!);
        },
        child: folha(repositorio),
      ),
    ),
  );
}

class _FolhaPar extends StatefulWidget {
  const _FolhaPar(this.par, this.repositorio);

  final ParSugerido par;
  final RevisaoRepositorio repositorio;

  @override
  State<_FolhaPar> createState() => _FolhaParState();
}

class _FolhaParState extends State<_FolhaPar> {
  final _descricao = TextEditingController();

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final par = widget.par;
    final estado = context.watch<DecisaoCubit>().state;
    final cubit = context.read<DecisaoCubit>();
    final dias = switch (par.dias) {
      0 => 'no mesmo dia',
      1 => '1 dia de diferença',
      final n => '$n dias de diferença',
    };
    return _CorpoDecisao(
      icone: Icons.sync_alt_rounded,
      kicker: 'Sugestão de par',
      titulo: 'É uma transferência entre suas contas?',
      texto: 'Mesmo valor, sentidos opostos, contas diferentes, $dias.',
      erro: estado.erro,
      conteudo: [
        _CartaoTransacao(par.saida, titulo: 'Saiu da ${par.saida.contaNome}'),
        const Icon(Icons.arrow_downward_rounded),
        _CartaoTransacao(
          par.entrada,
          titulo: 'Entrou na ${par.entrada.contaNome}',
        ),
        TextField(
          controller: _descricao,
          enabled: !estado.enviando,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
        ),
        _Nota(
          icone: Icons.link_rounded,
          texto:
              'Ligadas, as duas são confirmadas e não contam como gasto nem '
              'como renda. “Não é par” devolve as duas para a lista e a '
              'sugestão não volta.',
        ),
      ],
      secundario: OutlinedButton(
        onPressed: estado.enviando
            ? null
            : () => cubit.executar(
                () =>
                    widget.repositorio.recusarPar(par.saida.id, par.entrada.id),
                aviso: 'Sugestão de par descartada.',
              ),
        child: const Text('Não é par'),
      ),
      principal: FilledButton(
        onPressed: estado.enviando
            ? null
            : () => cubit.executar(
                () => widget.repositorio.ligarPar(
                  par.saida.id,
                  par.entrada.id,
                  descricao: _descricao.text.trim().isEmpty
                      ? null
                      : _descricao.text.trim(),
                ),
                aviso: 'Transferência ligada.',
              ),
        child: const Text('Ligar'),
      ),
    );
  }
}

class _FolhaDuplicata extends StatefulWidget {
  const _FolhaDuplicata(this.duplicata, this.repositorio);

  final Duplicata duplicata;
  final RevisaoRepositorio repositorio;

  @override
  State<_FolhaDuplicata> createState() => _FolhaDuplicataState();
}

class _FolhaDuplicataState extends State<_FolhaDuplicata> {
  /// Começa na que já estava.
  var _manter = ManterDuplicata.outra;

  @override
  Widget build(BuildContext context) {
    final duplicata = widget.duplicata;
    final estado = context.watch<DecisaoCubit>().state;
    final cubit = context.read<DecisaoCubit>();
    void decidir(ManterDuplicata manter, String aviso) => cubit.executar(
      () => widget.repositorio.resolverDuplicata(duplicata.rascunho.id, manter),
      aviso: aviso,
    );
    return _CorpoDecisao(
      icone: Icons.content_copy_rounded,
      kicker: 'Possível duplicata',
      titulo: 'Chegou a mesma compra duas vezes?',
      texto:
          'Mesma conta, data e valor, por fontes diferentes. Escolha a '
          'que fica.',
      erro: estado.erro,
      conteudo: [
        Text('Ficar com', style: context.textos.labelLarge),
        RadioGroup<ManterDuplicata>(
          groupValue: _manter,
          onChanged: (valor) {
            if (valor != null && !estado.enviando) {
              setState(() => _manter = valor);
            }
          },
          child: Column(
            children: [
              _OpcaoDuplicata(
                valor: ManterDuplicata.outra,
                item: duplicata.outra,
                selecionada: _manter == ManterDuplicata.outra,
              ),
              const SizedBox(height: Espaco.x2),
              _OpcaoDuplicata(
                valor: ManterDuplicata.rascunho,
                item: duplicata.rascunho,
                selecionada: _manter == ManterDuplicata.rascunho,
              ),
            ],
          ),
        ),
        const _Nota(
          icone: Icons.info_outline_rounded,
          texto:
              'A outra fica ignorada e não volta numa nova importação. '
              'Ficando com o rascunho, ele já entra confirmado com a categoria '
              'e a descrição da outra.',
        ),
      ],
      secundario: OutlinedButton(
        onPressed: estado.enviando
            ? null
            : () => decidir(ManterDuplicata.asDuas, 'As duas ficam.'),
        child: const Text('Manter as duas'),
      ),
      principal: FilledButton(
        onPressed: estado.enviando
            ? null
            : () => decidir(_manter, 'Duplicata resolvida.'),
        child: const Text('Ficar com esta'),
      ),
    );
  }
}

class _OpcaoDuplicata extends StatelessWidget {
  const _OpcaoDuplicata({
    required this.valor,
    required this.item,
    required this.selecionada,
  });

  final ManterDuplicata valor;
  final ItemRevisao item;
  final bool selecionada;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: selecionada ? esquema.primary : esquema.outlineVariant,
          width: selecionada ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: RadioListTile<ManterDuplicata>(
        value: valor,
        contentPadding: const EdgeInsets.only(right: Espaco.x3),
        title: Row(
          children: [
            Expanded(
              child: Text(item.descricao, overflow: TextOverflow.ellipsis),
            ),
            ValorNaRevisao(item),
          ],
        ),
        subtitle: Text(
          '${_meta(item)}\n${item.descricaoOriginal}',
          style: context.textos.bodySmall,
        ),
      ),
    );
  }
}

class _FolhaSumida extends StatelessWidget {
  const _FolhaSumida(this.sumida, this.repositorio);

  final ItemRevisao sumida;
  final RevisaoRepositorio repositorio;

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<DecisaoCubit>().state;
    final cubit = context.read<DecisaoCubit>();
    return _CorpoDecisao(
      icone: Icons.cloud_off_rounded,
      kicker: 'Sumiu do Open Finance',
      titulo: 'Esta transação não veio mais do banco',
      texto:
          'O banco pode ter cancelado a compra, ou o Open Finance a recriou '
          'com outro código. Se houver um rascunho igual na lista, remova '
          'esta e confirme o novo.',
      erro: estado.erro,
      conteudo: [
        _CartaoTransacao(sumida),
        const _Nota(
          icone: Icons.info_outline_rounded,
          texto:
              'Remover deixa a transação ignorada: sai do saldo e dos gastos, '
              'mas fica no histórico.',
        ),
      ],
      secundario: OutlinedButton(
        onPressed: estado.enviando
            ? null
            : () => cubit.executar(
                () => repositorio.manter(sumida.id),
                aviso: '${sumida.descricao} mantida.',
              ),
        child: const Text('Manter'),
      ),
      principal: FilledButton(
        onPressed: estado.enviando
            ? null
            : () => cubit.executar(
                () => repositorio.remover(sumida.id),
                aviso: '${sumida.descricao} removida.',
              ),
        child: const Text('Remover'),
      ),
    );
  }
}

class _FolhaPagamento extends StatelessWidget {
  const _FolhaPagamento({required this.aoConcluir, required this.aoOutraCoisa});

  final ValueChanged<String> aoConcluir;
  final VoidCallback aoOutraCoisa;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PagamentoRevisaoCubit>();
    final pagamento = cubit.pagamento;
    return BlocConsumer<PagamentoRevisaoCubit, PagamentoRevisaoEstado>(
      listenWhen: (antes, depois) =>
          antes.concluido == null && depois.concluido != null,
      listener: (context, estado) {
        Navigator.of(context).pop();
        aoConcluir(estado.concluido!);
      },
      builder: (context, estado) {
        final escolhida = estado.escolhida;
        return _CorpoDecisao(
          icone: iconeDaFonte(pagamento.fonte),
          kicker: '${pagamento.fonte.rotulo} · ${pagamento.contaNome}',
          titulo: 'Pagamento de fatura?',
          texto:
              '${formatarDinheiro(pagamento.valor)} em '
              '${formatarDataLonga(pagamento.data)}. Escolha a fatura paga.',
          erro: estado.erro,
          conteudo: [
            ComoVeio(pagamento.descricaoOriginal),
            if (estado.carregando)
              const Center(child: CircularProgressIndicator())
            else if (estado.candidatas.isEmpty)
              const _Nota(
                icone: Icons.info_outline_rounded,
                texto: 'Nenhum cartão ativo: é outra coisa?',
              )
            else ...[
              RadioGroup<FaturaCandidata>(
                groupValue: escolhida,
                onChanged: (fatura) {
                  if (fatura != null && !estado.enviando) {
                    cubit.escolher(fatura);
                  }
                },
                child: Column(
                  children: [
                    for (final fatura in estado.candidatas)
                      RadioListTile<FaturaCandidata>(
                        value: fatura,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${fatura.cartaoNome} · '
                          '${nomeDoMes(fatura.competencia)}',
                        ),
                        subtitle: Text(
                          '${_rotuloStatus(fatura.status)} · vence '
                          '${formatarDiaMes(fatura.dataVencimento)}',
                        ),
                      ),
                  ],
                ),
              ),
              if (escolhida == null)
                const _Nota(
                  icone: Icons.info_outline_rounded,
                  texto:
                      'Sem sugestão: escolha a fatura que este pagamento '
                      'quitou.',
                )
              else
                _QuadroFatura(escolhida),
            ],
            const _Nota(
              icone: Icons.credit_card_rounded,
              texto: 'Não conta como gasto: as compras já entraram no cartão.',
            ),
          ],
          secundario: OutlinedButton(
            onPressed: estado.enviando ? null : aoOutraCoisa,
            child: const Text('É outra coisa'),
          ),
          principal: FilledButton(
            onPressed: escolhida == null || estado.enviando
                ? null
                : cubit.confirmar,
            child: const Text('Confirmar pagamento'),
          ),
        );
      },
    );
  }

  static String _rotuloStatus(StatusFatura status) => switch (status) {
    StatusFatura.aberta => 'aberta',
    StatusFatura.fechada => 'fechada',
    StatusFatura.paga => 'paga',
  };
}

/// Valor da fatura, já pago e como ela fica com este pagamento.
class _QuadroFatura extends StatelessWidget {
  const _QuadroFatura(this.fatura);

  final FaturaCandidata fatura;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final cores = context.cores;
    Widget linha(String rotulo, Widget valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: textos.bodyMedium)),
          valor,
        ],
      ),
    );
    return Column(
      children: [
        linha('Valor da fatura', Text(formatarDinheiro(fatura.valor))),
        linha('Já pago', Text(formatarDinheiro(fatura.valorPago))),
        linha(
          'Com este pagamento',
          Text(
            fatura.ficaPaga ? 'Paga' : 'Fica em aberto',
            style: textos.labelLarge?.copyWith(
              color: fatura.ficaPaga ? cores.ritmoOk : cores.ritmoAtencao,
            ),
          ),
        ),
      ],
    );
  }
}

/// Esqueleto das folhas de decisão: o que é, a pergunta, o conteúdo e os
/// dois botões.
class _CorpoDecisao extends StatelessWidget {
  const _CorpoDecisao({
    required this.icone,
    required this.kicker,
    required this.titulo,
    required this.texto,
    required this.conteudo,
    required this.secundario,
    required this.principal,
    this.erro,
  });

  final IconData icone;
  final String kicker;
  final String titulo;
  final String texto;
  final List<Widget> conteudo;
  final Widget secundario;
  final Widget principal;
  final String? erro;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Espaco.x6,
        0,
        Espaco.x6,
        Espaco.x6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: esquema.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  kicker,
                  style: textos.labelMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaco.x1),
          Text(titulo, style: textos.headlineSmall),
          const SizedBox(height: Espaco.x1),
          Text(
            texto,
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          for (final widget in conteudo) ...[
            const SizedBox(height: Espaco.x4),
            widget,
          ],
          if (erro != null) ...[
            const SizedBox(height: Espaco.x4),
            Aviso.erro(context, erro!),
          ],
          const SizedBox(height: Espaco.x6),
          Row(
            children: [
              Expanded(child: secundario),
              const SizedBox(width: Espaco.x3),
              Expanded(child: principal),
            ],
          ),
        ],
      ),
    );
  }
}

/// Uma transação dentro de uma folha de decisão.
class _CartaoTransacao extends StatelessWidget {
  const _CartaoTransacao(this.item, {this.titulo});

  final ItemRevisao item;

  /// "Saiu da Conta principal"; sem título, a descrição.
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      decoration: BoxDecoration(
        color: esquema.surface,
        border: Border.all(color: esquema.outlineVariant),
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo ?? item.descricao,
                  style: textos.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ValorNaRevisao(item),
            ],
          ),
          Text(
            [_meta(item), item.descricaoOriginal].join(' · '),
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  const _Nota({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Aviso(
      icone: icone,
      texto: Text(
        texto,
        style: context.textos.bodyMedium?.copyWith(
          color: esquema.onSurfaceVariant,
        ),
      ),
      fundo: esquema.surfaceContainerHigh,
      cor: esquema.onSurfaceVariant,
    );
  }
}

/// "qua, 22 out · Extrato OFX · confirmada · Mercado".
String _meta(ItemRevisao item) => [
  formatarDiaCurto(item.data),
  item.fonte.rotulo,
  if (item.status == StatusTransacao.confirmada) 'confirmada' else 'rascunho',
  ?item.categoria?.nome,
].join(' · ');
