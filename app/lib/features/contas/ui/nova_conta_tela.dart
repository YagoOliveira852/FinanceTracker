import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../core/formatacao/datas.dart';
import '../../faturas/data/fatura.dart';
import '../cubit/contas_cubit.dart';
import '../cubit/nova_conta_cubit.dart';
import '../data/conta.dart';

/// Cadastro de conta corrente, carteira ou cartão de crédito. Fecha
/// devolvendo `true` quando a conta foi criada.
class NovaContaTela extends StatefulWidget {
  const NovaContaTela({super.key});

  @override
  State<NovaContaTela> createState() => _NovaContaTelaState();
}

class _NovaContaTelaState extends State<NovaContaTela> {
  final _nome = TextEditingController();
  final _instituicao = TextEditingController();
  final _saldo = TextEditingController();
  final _diaFechamento = TextEditingController();
  final _diaVencimento = TextEditingController();
  final _limite = TextEditingController();
  var _data = somenteData(DateTime.now());

  /// Conta de pagamento escolhida; antes da escolha vale a primeira corrente.
  String? _contaPagamentoEscolhida;

  @override
  void dispose() {
    _nome.dispose();
    _instituicao.dispose();
    _saldo.dispose();
    _diaFechamento.dispose();
    _diaVencimento.dispose();
    _limite.dispose();
    super.dispose();
  }

  String? _contaPagamento(List<Conta> correntes) {
    final id = _contaPagamentoEscolhida;
    if (correntes.any((c) => c.id == id)) return id;
    return correntes.isEmpty ? null : correntes.first.id;
  }

  void _salvar(NovaContaEstado estado, List<Conta> correntes) {
    final cubit = context.read<NovaContaCubit>();
    if (estado.tipo == TipoConta.cartaoCredito) {
      cubit.salvarCartao(
        nome: _nome.text,
        instituicao: _instituicao.text,
        contaPagamentoId: _contaPagamento(correntes),
        diaFechamento: _diaFechamento.text,
        diaVencimento: _diaVencimento.text,
        limite: _limite.text,
      );
    } else {
      cubit.salvar(
        nome: _nome.text,
        instituicao: _instituicao.text,
        saldoInicial: _saldo.text,
        dataSaldoInicial: _data,
      );
    }
  }

  void _mudouDia(String campo) {
    final cubit = context.read<NovaContaCubit>()..limparErro(campo);
    cubit.atualizarPrevia(_diaFechamento.text, _diaVencimento.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NovaContaCubit, NovaContaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<NovaContaCubit>();
        final livre = !estado.enviando;
        final cartao = estado.tipo == TipoConta.cartaoCredito;
        final corrente = estado.tipo == TipoConta.corrente;
        // Só o cartão precisa das contas (a conta que paga a fatura).
        final correntes = cartao
            ? switch (context.watch<ContasCubit>().state) {
                ContasCarregado(:final resumo) =>
                  resumo.contas
                      .where((c) => c.ativa && c.tipo == TipoConta.corrente)
                      .toList(),
                _ => const <Conta>[],
              }
            : const <Conta>[];
        final semContaPagamento = cartao && correntes.isEmpty;

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
              title: const Text('Nova conta'),
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
                    for (final (tipo, rotulo) in const [
                      (TipoConta.corrente, 'Conta corrente'),
                      (TipoConta.carteira, 'Carteira (dinheiro)'),
                      (TipoConta.cartaoCredito, 'Cartão de crédito'),
                    ])
                      ChipOpcao(
                        rotulo: rotulo,
                        selecionado: estado.tipo == tipo,
                        aoTocar: livre ? () => cubit.escolherTipo(tipo) : null,
                      ),
                  ],
                ),
                if (semContaPagamento) ...[
                  const SizedBox(height: Espaco.x6),
                  _SemContaPagamento(
                    aoCadastrar: () => cubit.escolherTipo(TipoConta.corrente),
                  ),
                ],
                const SizedBox(height: Espaco.x6),
                TextField(
                  controller: _nome,
                  onChanged: (_) => cubit.limparErro('nome'),
                  enabled: livre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: cartao ? 'Nome do cartão' : 'Nome da conta',
                    hintText: switch (estado.tipo) {
                      TipoConta.corrente => 'Ex.: Conta principal',
                      TipoConta.carteira => 'Ex.: Carteira',
                      TipoConta.cartaoCredito => 'Ex.: Cartão principal',
                    },
                    errorText: estado.erros['nome'],
                    counterText: '',
                  ),
                ),
                if (corrente || cartao) ...[
                  const SizedBox(height: Espaco.x6),
                  TextField(
                    controller: _instituicao,
                    onChanged: (_) => cubit.limparErro('instituicao'),
                    enabled: livre,
                    maxLength: 100,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Instituição',
                      hintText: 'Ex.: Banco Exemplo',
                      errorText: estado.erros['instituicao'],
                      counterText: '',
                    ),
                  ),
                ],
                if (cartao)
                  ..._camposCartao(estado, cubit, correntes, livre)
                else ...[
                  const SizedBox(height: Espaco.x6),
                  CampoDinheiro(
                    controller: _saldo,
                    aoMudar: (_) => cubit.limparErro('saldo_inicial'),
                    rotulo: 'Saldo inicial',
                    aceitaNegativo: true,
                    habilitado: livre,
                    ajuda:
                        'O saldo exato do extrato no começo do dia abaixo. '
                        'Pode ser negativo.',
                    erro: estado.erros['saldo_inicial'],
                  ),
                  const SizedBox(height: Espaco.x6),
                  CampoData(
                    rotulo: 'Saldo em',
                    data: _data,
                    habilitado: livre,
                    aoMudar: (data) {
                      setState(() => _data = data);
                      cubit.limparErro('data_saldo_inicial');
                    },
                    // O backend soma as transações a partir desta data,
                    // inclusive: o saldo informado é o do começo do dia.
                    ajuda:
                        'Saldo no começo do dia: as transações a partir desta '
                        'data mudam o saldo.',
                    erro: estado.erros['data_saldo_inicial'],
                  ),
                ],
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre && !semContaPagamento
                    ? () => _salvar(estado, correntes)
                    : null,
                child: RotuloEnviando(
                  enviando: estado.enviando,
                  rotulo: cartao ? 'Salvar cartão' : 'Salvar conta',
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _camposCartao(
    NovaContaEstado estado,
    NovaContaCubit cubit,
    List<Conta> correntes,
    bool livre,
  ) {
    final contaPagamento = _contaPagamento(correntes);
    return [
      const SizedBox(height: Espaco.x6),
      DropdownButtonFormField<String>(
        // initialValue só é lido na criação: a chave recria o campo quando
        // as contas terminam de carregar.
        key: ValueKey(correntes.length),
        initialValue: contaPagamento,
        isExpanded: true,
        hint: const Text('Nenhuma conta corrente'),
        decoration: InputDecoration(
          labelText: 'Conta de pagamento',
          helperText: 'Conta corrente de onde sai o pagamento da fatura.',
          errorText: estado.erros['conta_pagamento_id'],
        ),
        items: [
          for (final conta in correntes)
            DropdownMenuItem(
              value: conta.id,
              child: Text(
                '${conta.nome} · ${conta.instituicao}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: livre && correntes.isNotEmpty
            ? (id) {
                setState(() => _contaPagamentoEscolhida = id);
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
              aoMudar: () => _mudouDia('dia_fechamento'),
            ),
          ),
          const SizedBox(width: Espaco.x4),
          Expanded(
            child: CampoDiaDoMes(
              controller: _diaVencimento,
              rotulo: 'Dia de vencimento',
              erro: estado.erros['dia_vencimento'],
              habilitado: livre,
              aoMudar: () => _mudouDia('dia_vencimento'),
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(Espaco.x4, Espaco.x1, Espaco.x4, 0),
        child: Text(
          'Fechamento e vencimento em fim de semana ou feriado passam para o '
          'próximo dia útil.',
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
      if (estado.previa case final previa?) ...[
        const SizedBox(height: Espaco.x6),
        _PreviaFatura(previa),
      ],
    ];
  }
}

/// "Próxima fatura: novembro · Fecha ter, 3 nov · vence ter, 10 nov".
class _PreviaFatura extends StatelessWidget {
  const _PreviaFatura(this.previa);

  final DatasFatura previa;

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
        color: esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_rounded, color: esquema.primary),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próxima fatura: ${nomeDoMes(previa.competencia)}',
                  style: textos.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Fecha ${formatarDiaCurto(previa.dataFechamento)} · '
                  'vence ${formatarDiaCurto(previa.dataVencimento)}',
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

/// Todo cartão precisa de uma conta corrente que pague a fatura.
class _SemContaPagamento extends StatelessWidget {
  const _SemContaPagamento({required this.aoCadastrar});

  final VoidCallback aoCadastrar;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final textos = context.textos;
    return Container(
      padding: const EdgeInsets.all(Espaco.x4),
      decoration: BoxDecoration(
        color: cores.ritmoAtencaoContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.account_balance_rounded, color: cores.ritmoAtencao),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Falta a conta que paga a fatura',
                  style: textos.titleSmall?.copyWith(
                    color: cores.ritmoAtencao,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Todo cartão precisa de uma conta corrente para o '
                  'pagamento. Cadastre a conta primeiro e depois volte ao '
                  'cartão.',
                  style: textos.bodyMedium?.copyWith(color: cores.ritmoAtencao),
                ),
                const SizedBox(height: Espaco.x3),
                OutlinedButton(
                  onPressed: aoCadastrar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cores.ritmoAtencao,
                    side: BorderSide(color: cores.ritmoAtencao),
                  ),
                  child: const Text('Cadastrar conta corrente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
