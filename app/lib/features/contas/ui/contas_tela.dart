import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../faturas/ui/faturas_tela.dart';
import '../cubit/contas_cubit.dart';
import '../data/conta.dart';

/// Rota da tela Nova conta; devolve `true` quando a conta foi criada.
const rotaNovaConta = '/mais/contas/nova';

class ContasTela extends StatelessWidget {
  const ContasTela({super.key});

  Future<void> _adicionar(BuildContext context) async {
    final criou = await context.push<bool>(rotaNovaConta);
    if (criou == true && context.mounted) {
      await context.read<ContasCubit>().carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<ContasCubit>().state;
    final todas = switch (estado) {
      ContasCarregado(:final resumo) => resumo.contas,
      _ => const <Conta>[],
    };
    final contas = todas.where((c) => c.recebeReceita).toList();
    // Cartão desativado continua aqui (as faturas dele seguem visíveis);
    // conta corrente ou carteira desativada não aparece.
    final cartoes = todas
        .where((c) => c.tipo == TipoConta.cartaoCredito)
        .toList();
    final vazio =
        estado is ContasCarregado && contas.isEmpty && cartoes.isEmpty;

    return Scaffold(
      appBar: AppBar(titleSpacing: Espaco.x1, title: const Text('Contas')),
      floatingActionButton: estado is ContasCarregado && !vazio
          ? FloatingActionButton.extended(
              onPressed: () => _adicionar(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar conta'),
            )
          : null,
      body: switch (estado) {
        ContasCarregando() => const Carregando(),
        ContasErro(:final mensagem) => ErroComTentar(
          mensagem: mensagem,
          aoTentar: context.read<ContasCubit>().carregar,
        ),
        ContasCarregado() when vazio => EstadoVazio(
          icone: Icons.account_balance_wallet_rounded,
          titulo: 'Nenhuma conta cadastrada',
          texto:
              'Adicione uma conta corrente ou a carteira para ver seus '
              'saldos aqui.',
          acao: FilledButton.icon(
            onPressed: () => _adicionar(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar conta'),
          ),
        ),
        ContasCarregado(:final resumo) => RefreshIndicator(
          onRefresh: context.read<ContasCubit>().carregar,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.x4,
              Espaco.x2,
              Espaco.x4,
              96,
            ),
            children: [
              _CardTotal(resumo),
              const SizedBox(height: Espaco.x6),
              const TituloSecao('Contas e carteira'),
              GrupoLista(itens: [for (final c in contas) _ItemConta(c)]),
              const SizedBox(height: Espaco.x6),
              const TituloSecao('Cartões de crédito'),
              GrupoLista(
                itens: cartoes.isEmpty
                    ? const [
                        ItemLista(
                          icone: Icons.credit_card_rounded,
                          titulo: 'Nenhum cartão cadastrado',
                          subtitulo: Text(
                            'Em Adicionar conta, escolha Cartão de crédito.',
                          ),
                          habilitado: false,
                        ),
                      ]
                    : [for (final c in cartoes) _ItemCartao(c)],
              ),
            ],
          ),
        ),
      },
    );
  }
}

class _CardTotal extends StatelessWidget {
  const _CardTotal(this.resumo);

  final ResumoContas resumo;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total disponível', style: textos.bodySmall),
            const SizedBox(height: Espaco.x1),
            Text(
              formatarDinheiro(resumo.totalDisponivel),
              style: textos.displaySmall?.copyWith(
                fontFeatures: algarismosTabulares,
              ),
            ),
            const SizedBox(height: Espaco.x1),
            Text(
              'Contas correntes e carteira. A fatura do cartão não entra '
              'no total.',
              style: textos.bodyMedium?.copyWith(
                color: context.esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemConta extends StatelessWidget {
  const _ItemConta(this.conta);

  final Conta conta;

  @override
  Widget build(BuildContext context) {
    final carteira = conta.tipo == TipoConta.carteira;
    final negativo = conta.saldoAtual < Decimal.zero;
    final textos = context.textos;
    final corValor = negativo ? context.esquema.error : null;

    return ItemLista(
      icone: carteira ? Icons.wallet_rounded : Icons.account_balance_rounded,
      titulo: conta.nome,
      subtitulo: Text(
        carteira
            ? 'Dinheiro em espécie'
            : '${conta.instituicao} · Conta corrente',
      ),
      direita: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            negativo ? 'Saldo negativo' : 'Saldo',
            style: textos.bodySmall?.copyWith(
              color: corValor,
              fontWeight: negativo ? FontWeight.w600 : null,
            ),
          ),
          Text(
            formatarDinheiro(conta.saldoAtual),
            style: textos.titleMedium?.copyWith(
              color: corValor,
              fontFeatures: algarismosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão com o fechamento e o vencimento da fatura atual e o valor dela.
class _ItemCartao extends StatelessWidget {
  const _ItemCartao(this.conta);

  final Conta conta;

  @override
  Widget build(BuildContext context) {
    final fatura = conta.cartao!.faturaAtual;
    final textos = context.textos;
    final esquema = context.esquema;
    if (!conta.ativa) {
      return ItemLista(
        icone: Icons.credit_card_off_rounded,
        corIcone: esquema.onSurfaceVariant,
        fundoIcone: esquema.surfaceContainerHigh,
        titulo: conta.nome,
        aoTocar: () => context.push(rotaFaturas(conta.id)),
        subtitulo: Wrap(
          spacing: Espaco.x2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: esquema.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Desativado',
                style: textos.labelMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ),
            if (conta.instituicao case final instituicao?) Text(instituicao),
          ],
        ),
      );
    }
    return ItemLista(
      icone: Icons.credit_card_rounded,
      titulo: conta.nome,
      aoTocar: () => context.push(rotaFaturas(conta.id)),
      subtitulo: Text(
        'Fecha ${formatarDiaMes(fatura.dataFechamento)} · '
        'vence ${formatarDiaMes(fatura.dataVencimento)}',
      ),
      direita: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Fatura atual', style: textos.bodySmall),
          Text(
            formatarDinheiro(fatura.valor),
            style: textos.titleMedium?.copyWith(
              fontFeatures: algarismosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
