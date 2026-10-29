import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../categorias/cubit/categorias_cubit.dart';
import '../../categorias/data/categoria.dart';
import '../../categorias/ui/opcao_categoria.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../../contas/ui/opcao_conta.dart';
import '../../faturas/data/fatura.dart';
import '../../faturas/ui/formulario_pagamento.dart';
import '../cubit/lancamento_cubit.dart';
import '../data/transacao.dart';
import 'formulario_transferencia.dart';
import 'textos.dart';

/// Opções do campo Parcelas: 1 é à vista.
const _maximoDeParcelas = 24;

/// Lançamento manual: despesa ou receita (despesa num cartão é uma compra, à
/// vista ou parcelada, e mostra em que fatura entra), transferência entre
/// contas próprias e pagamento de fatura, cada um com o seu formulário.
/// Categoria é opcional e só oferece as ativas do grupo do tipo. Fecha
/// devolvendo `true` quando salvou.
class LancamentoTela extends StatefulWidget {
  const LancamentoTela({super.key, this.contaInicial, this.pagamentoInicial});

  /// Conta já escolhida (o filtro ativo em Transações).
  final String? contaInicial;

  /// Aberto pela tela de uma fatura: começa em Pagamento de fatura, com o
  /// cartão e a fatura dela.
  final PagamentoInicial? pagamentoInicial;

  @override
  State<LancamentoTela> createState() => _LancamentoTelaState();
}

class _LancamentoTelaState extends State<LancamentoTela> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  /// Conta escolhida no campo; antes da escolha vale a `contaInicial`.
  String? _contaEscolhida;
  var _data = somenteData(DateTime.now());

  /// Escolha do campo Parcelas; só vale com cartão (ver [_parcelasDa]).
  var _parcelas = 1;

  /// Escolha do campo Categoria; só vale se está entre as opções do tipo.
  String? _categoriaEscolhida;

  @override
  void initState() {
    super.initState();
    if (widget.pagamentoInicial != null) {
      context.read<LancamentoCubit>().escolherTipo(
        TipoTransacao.pagamentoFatura,
      );
    }
  }

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  /// Só conta da lista vale: a do filtro pode estar desativada, não receber
  /// o tipo escolhido (receita em cartão) ou as contas podem não ter
  /// carregado.
  Conta? _contaSelecionada(List<Conta> contas) {
    final id = _contaEscolhida ?? widget.contaInicial;
    return contas.where((c) => c.id == id).firstOrNull;
  }

  /// Parcelas que valem para a conta: fora do cartão, sempre à vista.
  int _parcelasDa(Conta? conta) =>
      conta?.tipo == TipoConta.cartaoCredito ? _parcelas : 1;

  /// A categoria escolhida, se ela é uma das [opcoes] (trocar de despesa
  /// para receita descarta a escolha).
  String? _categoriaSelecionada(List<Categoria> opcoes) =>
      opcoes.any((c) => c.id == _categoriaEscolhida)
      ? _categoriaEscolhida
      : null;

  void _salvar(List<Conta> contas, List<Categoria> categorias) {
    final conta = _contaSelecionada(contas);
    context.read<LancamentoCubit>().salvar(
      contaId: conta?.id,
      valor: _valor.text,
      data: _data,
      descricao: _descricao.text,
      parcelas: _parcelasDa(conta),
      categoriaId: _categoriaSelecionada(categorias),
    );
  }

  /// "3x de R$ 333,33; …" quando o valor digitado dá pelo menos um centavo
  /// por parcela; senão, nada.
  String? _textoDaDivisao(int parcelas) {
    if (parcelas < 2) return null;
    if (validarDinheiro(_valor.text, exigePositivo: true) != null) return null;
    final total = lerDinheiro(_valor.text)!;
    if (total * Decimal.fromInt(100) < Decimal.fromInt(parcelas)) return null;
    return textoDaDivisao(total, parcelas);
  }

  @override
  Widget build(BuildContext context) {
    final tipo = context.select((LancamentoCubit c) => c.state.tipo);
    if (tipo == TipoTransacao.transferenciaSaida) {
      return FormularioTransferencia(contaInicial: widget.contaInicial);
    }
    if (tipo == TipoTransacao.pagamentoFatura) {
      return FormularioPagamento(inicial: widget.pagamentoInicial);
    }
    final estadoContas = context.watch<ContasCubit>().state;
    final contas = switch (estadoContas) {
      ContasCarregado(:final resumo) =>
        resumo.contas
            .where(
              (c) => tipo == TipoTransacao.receita
                  ? c.recebeReceita
                  : c.recebeDespesa,
            )
            .toList(),
      _ => const <Conta>[],
    };
    final ajudaConta = switch (estadoContas) {
      ContasCarregando() => 'Carregando as contas…',
      ContasErro(:final mensagem) => mensagem,
      ContasCarregado() when contas.isEmpty =>
        'Cadastre uma conta em Mais → Contas.',
      ContasCarregado() => null,
    };
    final estadoCategorias = context.watch<CategoriasCubit>().state;
    final categorias = switch (estadoCategorias) {
      CategoriasCarregado(:final categorias) =>
        categorias.where((c) => c.opcaoPara(tipo)).toList(),
      _ => const <Categoria>[],
    };
    final ajudaCategoria = switch (estadoCategorias) {
      CategoriasCarregando() => 'Carregando as categorias…',
      CategoriasErro(:final mensagem) => mensagem,
      CategoriasCarregado() => null,
    };
    final contaSelecionada = _contaSelecionada(contas);
    final noCartao = contaSelecionada?.tipo == TipoConta.cartaoCredito;
    final parcelas = _parcelasDa(contaSelecionada);
    // A consulta repete a cada quadro, mas o cubit só chama a API quando a
    // conta ou a data mudam (inclusive quando as contas terminam de carregar).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LancamentoCubit>().consultarFatura(
          contaSelecionada,
          _data,
        );
      }
    });

    return BlocConsumer<LancamentoCubit, LancamentoEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<LancamentoCubit>();
        final livre = !estado.enviando;

        return EsqueletoLancamento(
          livre: livre,
          erroGeral: estado.erroGeral,
          campos: [
            CampoSelecao<String>(
              rotulo: 'Conta',
              valor: contaSelecionada?.id,
              vazio: 'Selecione uma conta',
              erro: estado.erros['conta_id'],
              ajuda: ajudaConta,
              opcoes: [for (final conta in contas) opcaoDeConta(conta)],
              aoMudar: livre
                  ? (id) {
                      setState(() {
                        _contaEscolhida = id;
                        // Parcelas são só do cartão: outra conta volta a
                        // à vista.
                        final conta = contas
                            .where((c) => c.id == id)
                            .firstOrNull;
                        if (conta?.tipo != TipoConta.cartaoCredito) {
                          _parcelas = 1;
                        }
                      });
                      cubit.limparErro('conta_id');
                    }
                  : null,
            ),
            const SizedBox(height: Espaco.x6),
            CampoDinheiro(
              controller: _valor,
              aoMudar: (_) {
                // O texto da divisão acompanha a digitação.
                setState(() {});
                cubit.limparErro('valor');
              },
              rotulo: noCartao ? 'Valor total' : 'Valor',
              habilitado: livre,
              ajuda: 'Sempre positivo; o tipo define se entra ou sai.',
              erro: estado.erros['valor'],
            ),
            const SizedBox(height: Espaco.x6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CampoData(
                    rotulo: noCartao ? 'Data da compra' : 'Data',
                    data: _data,
                    habilitado: livre,
                    aoMudar: (data) {
                      setState(() => _data = data);
                      cubit.limparErro('data');
                    },
                    erro: estado.erros['data'],
                  ),
                ),
                if (noCartao) ...[
                  const SizedBox(width: Espaco.x4),
                  SizedBox(
                    width: 128,
                    child: CampoSelecao<int>(
                      rotulo: 'Parcelas',
                      valor: _parcelas,
                      erro: estado.erros['parcelas'],
                      opcoes: [
                        for (var n = 1; n <= _maximoDeParcelas; n++)
                          OpcaoSelecao(
                            valor: n,
                            rotulo: n == 1 ? 'À vista' : '${n}x',
                          ),
                      ],
                      aoMudar: livre
                          ? (n) {
                              setState(() => _parcelas = n);
                              cubit.limparErro('parcelas');
                            }
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            if (noCartao) ...[
              if (_textoDaDivisao(parcelas) case final divisao?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x4,
                    Espaco.x1,
                    Espaco.x4,
                    0,
                  ),
                  child: Text(
                    divisao,
                    style: context.textos.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              if (estado.faturaDaCompra case final fatura?) ...[
                const SizedBox(height: Espaco.x6),
                _FaturaDaCompra(fatura, parcelas: parcelas),
              ],
            ],
            const SizedBox(height: Espaco.x6),
            TextField(
              controller: _descricao,
              onChanged: (_) => cubit.limparErro('descricao'),
              enabled: livre,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição',
                errorText: estado.erros['descricao'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Espaco.x6),
            CampoSelecao<String?>(
              rotulo: 'Categoria (opcional)',
              valor: _categoriaSelecionada(categorias),
              erro: estado.erros['categoria_id'],
              ajuda: ajudaCategoria,
              opcoes: [
                const OpcaoSelecao(valor: null, rotulo: 'Sem categoria'),
                for (final categoria in categorias) opcaoDeCategoria(categoria),
              ],
              aoMudar: livre
                  ? (id) {
                      setState(() => _categoriaEscolhida = id);
                      cubit.limparErro('categoria_id');
                    }
                  : null,
            ),
          ],
          botao: FilledButton(
            onPressed: livre ? () => _salvar(contas, categorias) : null,
            child: RotuloEnviando(enviando: estado.enviando, rotulo: 'Salvar'),
          ),
        );
      },
    );
  }
}

/// Moldura comum dos formulários do Lançamento: fechar, título, os chips de
/// tipo, os [campos] e o [botao] no rodapé. Enquanto não está [livre]
/// (salvando), o voltar do Android fica bloqueado (fechar no meio perderia o
/// aviso de que o registro foi criado) e os chips ficam desabilitados.
class EsqueletoLancamento extends StatelessWidget {
  const EsqueletoLancamento({
    super.key,
    required this.livre,
    this.erroGeral,
    required this.campos,
    required this.botao,
  });

  final bool livre;
  final String? erroGeral;
  final List<Widget> campos;
  final Widget botao;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: livre,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: Espaco.x1,
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.pop(false),
          ),
          title: const Text('Nova transação'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(Espaco.x4),
          children: [
            if (erroGeral != null) ...[
              Aviso.erro(context, erroGeral!),
              const SizedBox(height: Espaco.x6),
            ],
            _ChipsDeTipo(livre: livre),
            const SizedBox(height: Espaco.x6),
            ...campos,
          ],
        ),
        bottomNavigationBar: RodapeFormulario(botao: botao),
      ),
    );
  }
}

/// Tipo do lançamento; o escolhido fica no [LancamentoCubit] e decide o
/// formulário.
class _ChipsDeTipo extends StatelessWidget {
  const _ChipsDeTipo({required this.livre});

  final bool livre;

  @override
  Widget build(BuildContext context) {
    final tipo = context.select((LancamentoCubit c) => c.state.tipo);
    final cubit = context.read<LancamentoCubit>();
    ChipOpcao chip(String rotulo, TipoTransacao valor) => ChipOpcao(
      rotulo: rotulo,
      selecionado: tipo == valor,
      aoTocar: livre ? () => cubit.escolherTipo(valor) : null,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Espaco.x1, bottom: Espaco.x2),
          child: Text('Tipo', style: context.textos.bodySmall),
        ),
        Wrap(
          spacing: Espaco.x2,
          runSpacing: Espaco.x2,
          children: [
            chip('Despesa', TipoTransacao.despesa),
            chip('Receita', TipoTransacao.receita),
            chip('Transferência', TipoTransacao.transferenciaSaida),
            chip('Pagamento de fatura', TipoTransacao.pagamentoFatura),
          ],
        ),
      ],
    );
  }
}

/// "Entra na fatura de novembro · Fecha ter, 3 nov · vence ter, 10 nov";
/// parcelada, acrescenta em que fatura cai a última parcela.
class _FaturaDaCompra extends StatelessWidget {
  const _FaturaDaCompra(this.fatura, {required this.parcelas});

  final DatasFatura fatura;
  final int parcelas;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final datas =
        'Fecha ${formatarDiaCurto(fatura.dataFechamento)} · '
        'vence ${formatarDiaCurto(fatura.dataVencimento)}';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      decoration: BoxDecoration(
        color: esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.credit_card_rounded, color: esquema.primary),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entra na fatura de ${nomeDoMes(fatura.competencia)}',
                  style: textos.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  parcelas > 1
                      ? '$datas. '
                            '${textoDaUltimaParcela(fatura.competencia, parcelas)}'
                      : datas,
                  style: textos.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
