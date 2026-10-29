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
import '../../contas/ui/opcao_conta.dart';
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
  void initState() {
    super.initState();
    // Voltando a este tipo depois de trocar de chip, o cubit já tem a fatura
    // (o listener não dispara de novo): valor e data voltam ao padrão dela.
    if (context.read<PagamentoCubit>().state.fatura case final fatura?) {
      _preencher(fatura);
    }
  }

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
    _data = dataPadraoDoPagamento(fatura, DateTime.now());
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
          setState(() => _preencher(fatura));
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
            CampoSelecao<String>(
              rotulo: 'Cartão',
              valor: cartao?.id,
              vazio: semCartao ? 'Nenhum cartão ativo' : 'Selecione',
              opcoes: [for (final c in cartoes) opcaoDeConta(c)],
              aoMudar: livre && widget.inicial == null ? _escolherCartao : null,
            ),
            const SizedBox(height: Espaco.x6),
            CampoSelecao<DateTime>(
              rotulo: 'Fatura',
              valor: fatura?.competencia,
              ajuda: estado.carregando
                  ? 'Carregando as faturas…'
                  : fatura == null
                  ? null
                  : 'Valor da fatura: ${formatarDinheiro(fatura.valor)}.',
              opcoes: [
                for (final f in estado.faturas)
                  OpcaoSelecao(valor: f.competencia, rotulo: _opcaoDeFatura(f)),
              ],
              aoMudar: livre ? cubit.escolherFatura : null,
            ),
            const SizedBox(height: Espaco.x6),
            CampoSelecao<String>(
              rotulo: 'Pagar com',
              valor: conta,
              vazio: 'Selecione uma conta',
              erro: estado.erros['conta_id'],
              ajuda: 'Conta de pagamento do cartão; dá para trocar.',
              opcoes: [for (final c in pagadoras) opcaoDeConta(c)],
              aoMudar: livre
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
                  onPressed: () async {
                    final contas = context.read<ContasCubit>();
                    final criou = await context.push<bool>(
                      rotaNovaConta,
                      extra: TipoConta.cartaoCredito,
                    );
                    // O cartão novo entra no formulário (que escolhe o
                    // primeiro cartão quando as contas recarregam).
                    if (criou == true) await contas.carregar();
                  },
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
