import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../../contas/ui/contas_tela.dart';
import '../../transacoes/ui/lancamento_tela.dart';
import '../cubit/pagamento_cubit.dart';
import '../data/fatura.dart';
import '../data/pagamento.dart';

/// O formulário de pagamento aberto pela tela de uma fatura: o cartão e a
/// fatura já vêm escolhidos (mesmo cartão desativado).
class PagamentoInicial {
  const PagamentoInicial({required this.cartaoId, required this.competencia});

  final String cartaoId;
  final DateTime competencia;
}

/// Pagamento de fatura: cartão, fatura, conta que paga, valor e data. Não é
/// gasto (as compras já contaram no cartão). Valor e data acompanham a
/// fatura escolhida: o que falta pagar e a menor entre o vencimento e hoje.
/// Fecha devolvendo `true`.
class FormularioPagamento extends StatefulWidget {
  const FormularioPagamento({super.key, this.inicial});

  final PagamentoInicial? inicial;

  @override
  State<FormularioPagamento> createState() => _FormularioPagamentoState();
}

class _FormularioPagamentoState extends State<FormularioPagamento> {
  final _valor = TextEditingController();
  String? _contaEscolhida;
  var _data = somenteData(DateTime.now());

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  /// Cartões que o campo oferece: os ativos e, aberto por uma fatura, o
  /// cartão dela.
  List<Conta> _cartoes(List<Conta> contas) => contas
      .where(
        (c) =>
            c.tipo == TipoConta.cartaoCredito &&
            (c.ativa || c.id == widget.inicial?.cartaoId),
      )
      .toList();

  void _escolherCartao(String cartaoId) {
    setState(() => _contaEscolhida = null);
    context.read<PagamentoCubit>().escolherCartao(
      cartaoId,
      competencia: cartaoId == widget.inicial?.cartaoId
          ? widget.inicial?.competencia
          : null,
    );
  }

  /// A fatura escolhida mudou: valor e data voltam ao padrão dela.
  void _preencher(ResumoFatura fatura) {
    final aPagar = fatura.aPagar;
    _valor.text = aPagar > Decimal.zero ? dinheiroParaCampo(aPagar) : '';
    setState(() => _data = dataPadraoDoPagamento(fatura, DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final estadoContas = context.watch<ContasCubit>().state;
    final todas = switch (estadoContas) {
      ContasCarregado(:final resumo) => resumo.contas,
      _ => const <Conta>[],
    };
    final cartoes = _cartoes(todas);
    final pagadoras = todas
        .where((c) => c.ativa && c.tipo != TipoConta.cartaoCredito)
        .toList();
    final semCartao = estadoContas is ContasCarregado && cartoes.isEmpty;

    final pagamento = context.watch<PagamentoCubit>().state;
    // Com as contas carregadas, escolhe o cartão uma vez: o da fatura de
    // onde veio, senão o primeiro.
    if (pagamento.cartaoId == null && cartoes.isNotEmpty) {
      final id = widget.inicial?.cartaoId ?? cartoes.first.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.read<PagamentoCubit>().state.cartaoId == null) {
          _escolherCartao(id);
        }
      });
    }
    final cartao = cartoes.where((c) => c.id == pagamento.cartaoId).firstOrNull;
    final padrao = cartao?.cartao?.contaPagamentoId;
    final conta = [
      _contaEscolhida,
      padrao,
    ].firstWhere((id) => pagadoras.any((c) => c.id == id), orElse: () => null);

    return BlocConsumer<PagamentoCubit, PagamentoEstado>(
      listenWhen: (antes, depois) =>
          (antes.salvo == null && depois.salvo != null) ||
          (depois.fatura != null && antes.fatura != depois.fatura),
      listener: (context, estado) {
        if (estado.salvo != null) {
          context.pop(true);
        } else if (estado.fatura case final fatura?) {
          _preencher(fatura);
        }
      },
      builder: (context, estado) {
        final cubit = context.read<PagamentoCubit>();
        final livre = !estado.enviando && !semCartao;
        final fatura = estado.fatura;
        return EsqueletoLancamento(
          livre: !estado.enviando,
          erroGeral: estado.erroGeral,
          campos: [
            if (semCartao) ...[
              const _SemCartao(),
              const SizedBox(height: Espaco.x6),
            ],
            DropdownButtonFormField<String>(
              key: ValueKey(('cartao', estadoContas.runtimeType, cartao?.id)),
              initialValue: cartao?.id,
              isExpanded: true,
              hint: Text(semCartao ? 'Nenhum cartão ativo' : 'Selecione'),
              decoration: const InputDecoration(labelText: 'Cartão'),
              items: [
                for (final c in cartoes)
                  DropdownMenuItem(value: c.id, child: Text(_nomeDaConta(c))),
              ],
              onChanged: livre && widget.inicial == null
                  ? (id) => id == null ? null : _escolherCartao(id)
                  : null,
            ),
            const SizedBox(height: Espaco.x6),
            DropdownButtonFormField<DateTime>(
              key: ValueKey(('fatura', estado.cartaoId, estado.faturas.length)),
              initialValue: fatura?.competencia,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Fatura',
                helperText: estado.carregando
                    ? 'Carregando as faturas…'
                    : fatura == null
                    ? null
                    : 'Valor da fatura: ${formatarDinheiro(fatura.valor)}.',
              ),
              items: [
                for (final f in estado.faturas)
                  DropdownMenuItem(
                    value: f.competencia,
                    child: Text(_opcaoDeFatura(f)),
                  ),
              ],
              onChanged: livre
                  ? (competencia) {
                      if (competencia != null) {
                        cubit.escolherFatura(competencia);
                      }
                    }
                  : null,
            ),
            const SizedBox(height: Espaco.x6),
            DropdownButtonFormField<String>(
              key: ValueKey(('conta', estadoContas.runtimeType, conta)),
              initialValue: conta,
              isExpanded: true,
              hint: const Text('Selecione uma conta'),
              decoration: InputDecoration(
                labelText: 'Pagar com',
                errorText: estado.erros['conta_id'],
                helperText: 'Conta de pagamento do cartão; dá para trocar.',
              ),
              items: [
                for (final c in pagadoras)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      _nomeDaConta(c),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: livre
                  ? (id) {
                      setState(() => _contaEscolhida = id);
                      cubit.limparErro('conta_id');
                    }
                  : null,
            ),
            const SizedBox(height: Espaco.x6),
            CampoDinheiro(
              controller: _valor,
              rotulo: 'Valor',
              habilitado: livre,
              ajuda:
                  'Preenchido com o valor da fatura. Pagando menos, ela '
                  'continua fechada.',
              erro: estado.erros['valor'],
              aoMudar: (_) => cubit.limparErro('valor'),
            ),
            const SizedBox(height: Espaco.x6),
            CampoData(
              rotulo: 'Data',
              data: _data,
              habilitado: livre,
              aoMudar: (data) {
                setState(() => _data = data);
                cubit.limparErro('data');
              },
              erro: estado.erros['data'],
            ),
            const SizedBox(height: Espaco.x6),
            const _AvisoPagamento(),
          ],
          botao: FilledButton(
            onPressed: livre && fatura != null
                ? () => cubit.salvar(
                    contaId: conta,
                    valor: _valor.text,
                    data: _data,
                  )
                : null,
            child: RotuloEnviando(
              enviando: estado.enviando,
              rotulo: 'Salvar pagamento',
            ),
          ),
        );
      },
    );
  }

  static String _nomeDaConta(Conta c) =>
      c.instituicao == null ? c.nome : '${c.nome} · ${c.instituicao}';

  /// "Outubro · fechada · vence ter, 13 out".
  static String _opcaoDeFatura(ResumoFatura f) {
    final mes = nomeDoMes(f.competencia);
    final status = switch (f.status) {
      StatusFatura.aberta => 'aberta',
      StatusFatura.fechada => 'fechada',
      StatusFatura.paga => 'paga',
    };
    return '${mes[0].toUpperCase()}${mes.substring(1)} · $status · '
        'vence ${formatarDiaCurto(f.dataVencimento)}';
  }
}

/// Sem cartão ativo: o aviso e o atalho para cadastrar um.
class _SemCartao extends StatelessWidget {
  const _SemCartao();

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
          Icon(Icons.credit_card_off_rounded, color: cores.ritmoAtencao),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum cartão ativo',
                  style: textos.titleSmall?.copyWith(color: cores.ritmoAtencao),
                ),
                Text(
                  'Para registrar um pagamento de fatura, cadastre o cartão '
                  'primeiro.',
                  style: textos.bodyMedium?.copyWith(color: cores.ritmoAtencao),
                ),
                const SizedBox(height: Espaco.x3),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cores.ritmoAtencao,
                    side: BorderSide(color: cores.ritmoAtencao),
                  ),
                  onPressed: () => context.push(
                    rotaNovaConta,
                    extra: TipoConta.cartaoCredito,
                  ),
                  child: const Text('Cadastrar cartão'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisoPagamento extends StatelessWidget {
  const _AvisoPagamento();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
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
            child: Text(
              'Não conta como gasto: as compras já entraram no cartão.',
              style: context.textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
