import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/dinheiro.dart';
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
    final contas = switch (estado) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.aceitaLancamento).toList(),
      _ => const <Conta>[],
    };
    final vazio = estado is ContasCarregado && contas.isEmpty;

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
              const GrupoLista(
                itens: [
                  ItemLista(
                    icone: Icons.credit_card_rounded,
                    titulo: 'Cartões e faturas',
                    subtitulo: Text('Fechamento, vencimento e fatura atual'),
                    direita: SeloEmBreve(),
                    habilitado: false,
                  ),
                ],
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
