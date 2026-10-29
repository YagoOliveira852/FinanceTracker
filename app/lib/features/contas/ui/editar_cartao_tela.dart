import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../cubit/contas_cubit.dart';
import '../cubit/editar_cartao_cubit.dart';
import '../data/conta.dart';
import 'opcao_conta.dart';

/// Rota do Editar cartão; recebe a [Conta] do cartão em `extra` e devolve
/// `true` quando salvou (edição, desativação ou reativação).
String rotaEditarCartao(String contaId) =>
    '/mais/contas/cartao/$contaId/editar';

/// Os dados do cadastro do cartão, mais desativar e reativar.
class EditarCartaoTela extends StatefulWidget {
  const EditarCartaoTela({super.key, required this.conta});

  final Conta conta;

  @override
  State<EditarCartaoTela> createState() => _EditarCartaoTelaState();
}

class _EditarCartaoTelaState extends State<EditarCartaoTela> {
  late final Cartao _cartao = widget.conta.cartao!;
  late final _nome = TextEditingController(text: widget.conta.nome);
  late final _instituicao = TextEditingController(
    text: widget.conta.instituicao ?? '',
  );
  late final _diaFechamento = TextEditingController(
    text: '${_cartao.diaFechamento}',
  );
  late final _diaVencimento = TextEditingController(
    text: '${_cartao.diaVencimento}',
  );
  late final _limite = TextEditingController(
    text: switch (_cartao.limite) {
      final limite? => dinheiroParaCampo(limite),
      null => '',
    },
  );
  late var _contaPagamento = _cartao.contaPagamentoId;

  @override
  void dispose() {
    _nome.dispose();
    _instituicao.dispose();
    _diaFechamento.dispose();
    _diaVencimento.dispose();
    _limite.dispose();
    super.dispose();
  }

  void _salvar() {
    context.read<EditarCartaoCubit>().salvar(
      nome: _nome.text,
      instituicao: _instituicao.text,
      contaPagamentoId: _contaPagamento,
      diaFechamento: _diaFechamento.text,
      diaVencimento: _diaVencimento.text,
      limite: _limite.text,
    );
  }

  /// Com fatura de valor, confirma antes: ela continua lá para pagar.
  Future<void> _desativar() async {
    final cubit = context.read<EditarCartaoCubit>();
    final fatura = _cartao.faturaAtual;
    if (fatura.valor > Decimal.zero) {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmarDesativar(widget.conta),
      );
      if (confirmou != true) return;
    }
    await cubit.mudarAtivo(false);
  }

  @override
  Widget build(BuildContext context) {
    final correntes = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) =>
        resumo.contas
            .where((c) => c.ativa && c.tipo == TipoConta.corrente)
            .toList(),
      _ => const <Conta>[],
    };
    final competencia = _cartao.faturaAtual.competencia;
    final seguinte = DateTime(competencia.year, competencia.month + 1);

    return BlocConsumer<EditarCartaoCubit, EditarCartaoEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => Navigator.of(context).pop(true),
      builder: (context, estado) {
        final cubit = context.read<EditarCartaoCubit>();
        final livre = !estado.enviando;
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
              title: const Text('Editar cartão'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                TextField(
                  controller: _nome,
                  onChanged: (_) => cubit.limparErro('nome'),
                  enabled: livre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nome do cartão',
                    errorText: estado.erros['nome'],
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                TextField(
                  controller: _instituicao,
                  onChanged: (_) => cubit.limparErro('instituicao'),
                  enabled: livre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Instituição',
                    errorText: estado.erros['instituicao'],
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                CampoSelecao<String>(
                  rotulo: 'Conta de pagamento',
                  valor: _contaPagamento,
                  vazio: 'Escolha a conta corrente',
                  ajuda: 'Conta corrente de onde sai o pagamento da fatura.',
                  erro: estado.erros['conta_pagamento_id'],
                  opcoes: [for (final conta in correntes) opcaoDeConta(conta)],
                  aoMudar: livre
                      ? (id) {
                          setState(() => _contaPagamento = id);
                          cubit.limparErro('conta_pagamento_id');
                        }
                      : null,
                ),
                const SizedBox(height: Espaco.x6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CampoDiaDoMes(
                        controller: _diaFechamento,
                        rotulo: 'Dia de fechamento',
                        erro: estado.erros['dia_fechamento'],
                        habilitado: livre,
                        aoMudar: () => cubit.limparErro('dia_fechamento'),
                      ),
                    ),
                    const SizedBox(width: Espaco.x4),
                    Expanded(
                      child: CampoDiaDoMes(
                        controller: _diaVencimento,
                        rotulo: 'Dia de vencimento',
                        erro: estado.erros['dia_vencimento'],
                        habilitado: livre,
                        aoMudar: () => cubit.limparErro('dia_vencimento'),
                      ),
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
                    'Dias novos valem a partir da próxima fatura '
                    '(${nomeDoMes(seguinte)}); a de ${nomeDoMes(competencia)} '
                    'mantém as datas.',
                    style: context.textos.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                CampoDinheiro(
                  controller: _limite,
                  aoMudar: (_) => cubit.limparErro('limite'),
                  rotulo: 'Limite (opcional)',
                  habilitado: livre,
                  erro: estado.erros['limite'],
                ),
                const SizedBox(height: Espaco.x6),
                const Divider(height: 1),
                const SizedBox(height: Espaco.x4),
                if (widget.conta.ativa)
                  _SecaoAtivo(
                    titulo: 'Desativar cartão',
                    texto:
                        'O cartão sai do Lançamento e para de receber '
                        'compras. Faturas e histórico continuam; dá para '
                        'reativar depois.',
                    botao: OutlinedButton(
                      onPressed: livre ? _desativar : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.esquema.error,
                        side: BorderSide(color: context.esquema.error),
                      ),
                      child: const Text('Desativar cartão'),
                    ),
                  )
                else
                  _SecaoAtivo(
                    titulo: 'Cartão desativado',
                    texto:
                        'Ele não aparece no Lançamento. Reative para lançar '
                        'compras de novo.',
                    botao: FilledButton.tonal(
                      onPressed: livre ? () => cubit.mudarAtivo(true) : null,
                      child: const Text('Reativar cartão'),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre ? _salvar : null,
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

class _SecaoAtivo extends StatelessWidget {
  const _SecaoAtivo({
    required this.titulo,
    required this.texto,
    required this.botao,
  });

  final String titulo;
  final String texto;
  final Widget botao;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: context.textos.titleSmall),
        const SizedBox(height: Espaco.x2),
        Text(
          texto,
          style: context.textos.bodyMedium?.copyWith(
            color: context.esquema.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Espaco.x3),
        botao,
      ],
    );
  }
}

/// "Desativar o Cartão Exemplo?" com o valor da fatura atual. Devolve
/// `true` quando o usuário confirma.
class _ConfirmarDesativar extends StatelessWidget {
  const _ConfirmarDesativar(this.conta);

  final Conta conta;

  @override
  Widget build(BuildContext context) {
    final fatura = conta.cartao!.faturaAtual;
    final esquema = context.esquema;
    return AlertDialog(
      icon: Icon(Icons.credit_card_off_rounded, color: esquema.error),
      title: Text('Desativar o ${conta.nome}?'),
      content: Text(
        'A fatura de ${nomeDoMes(fatura.competencia)} está aberta com '
        '${formatarDinheiro(fatura.valor)}. Ela continua visível em Contas, '
        'mas o cartão não recebe compras novas até ser reativado.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: esquema.error,
            foregroundColor: esquema.onError,
          ),
          child: const Text('Desativar'),
        ),
      ],
    );
  }
}
