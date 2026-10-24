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
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../../faturas/data/fatura.dart';
import '../cubit/lancamento_cubit.dart';
import '../data/transacao.dart';
import 'textos.dart';

/// Opções do campo Parcelas: 1 é à vista.
const _maximoDeParcelas = 24;

/// Lançamento manual de despesa ou receita; despesa num cartão é uma compra,
/// à vista ou parcelada, e mostra em que fatura entra. Transferência,
/// pagamento de fatura e categoria aparecem desabilitados ("em breve"). Fecha
/// devolvendo `true` quando salvou.
class LancamentoTela extends StatefulWidget {
  const LancamentoTela({super.key, this.contaInicial});

  /// Conta já escolhida (o filtro ativo em Transações).
  final String? contaInicial;

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

  void _salvar(List<Conta> contas) {
    final conta = _contaSelecionada(contas);
    context.read<LancamentoCubit>().salvar(
      contaId: conta?.id,
      valor: _valor.text,
      data: _data,
      descricao: _descricao.text,
      parcelas: _parcelasDa(conta),
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

        // Enquanto salva, o voltar do Android fica bloqueado: fechar no meio
        // perderia o aviso de que o registro foi criado.
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
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                Padding(
                  padding: const EdgeInsets.only(
                    left: Espaco.x1,
                    bottom: Espaco.x2,
                  ),
                  child: Text('Tipo', style: context.textos.bodySmall),
                ),
                Wrap(
                  spacing: Espaco.x2,
                  runSpacing: Espaco.x2,
                  children: [
                    ChipOpcao(
                      rotulo: 'Despesa',
                      selecionado: estado.tipo == TipoTransacao.despesa,
                      aoTocar: livre
                          ? () => cubit.escolherTipo(TipoTransacao.despesa)
                          : null,
                    ),
                    ChipOpcao(
                      rotulo: 'Receita',
                      selecionado: estado.tipo == TipoTransacao.receita,
                      aoTocar: livre
                          ? () => cubit.escolherTipo(TipoTransacao.receita)
                          : null,
                    ),
                    const ChipOpcao(
                      rotulo: 'Transferência',
                      selecionado: false,
                      aoTocar: null,
                    ),
                    const ChipOpcao(
                      rotulo: 'Pagamento de fatura',
                      selecionado: false,
                      aoTocar: null,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x4,
                    Espaco.x1,
                    Espaco.x4,
                    0,
                  ),
                  child: Text(
                    'Transferência e pagamento de fatura: em breve.',
                    style: context.textos.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                DropdownButtonFormField<String>(
                  // initialValue só é lido na criação: a chave recria o campo
                  // quando as contas carregam ou o tipo muda a lista.
                  key: ValueKey((estadoContas.runtimeType, tipo)),
                  initialValue: contaSelecionada?.id,
                  isExpanded: true,
                  hint: const Text('Selecione uma conta'),
                  decoration: InputDecoration(
                    labelText: 'Conta',
                    errorText: estado.erros['conta_id'],
                    helperText: ajudaConta,
                  ),
                  items: [
                    for (final conta in contas)
                      DropdownMenuItem(
                        value: conta.id,
                        child: Text(
                          conta.instituicao == null
                              ? conta.nome
                              : '${conta.nome} · ${conta.instituicao}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: livre
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
                        child: DropdownButtonFormField<int>(
                          initialValue: _parcelas,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Parcelas',
                            errorText: estado.erros['parcelas'],
                          ),
                          items: [
                            for (var n = 1; n <= _maximoDeParcelas; n++)
                              DropdownMenuItem(
                                value: n,
                                child: Text(n == 1 ? 'À vista' : '${n}x'),
                              ),
                          ],
                          onChanged: livre
                              ? (n) {
                                  setState(() => _parcelas = n ?? 1);
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
                const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Categoria (opcional)',
                    hintText: 'Sem categoria',
                    helperText: 'Categorias: em breve.',
                    suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre ? () => _salvar(contas) : null,
                child: RotuloEnviando(
                  enviando: estado.enviando,
                  rotulo: 'Salvar',
                ),
              ),
            ),
          ),
        );
      },
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
