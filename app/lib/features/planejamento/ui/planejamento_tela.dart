import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../cubit/planejamento_cubit.dart';
import '../data/planejamento.dart';
import 'textos.dart';

/// Rota da Nova renda; devolve `true` quando salvou.
const rotaNovaRenda = '/mais/planejamento/rendas/nova';

/// Rota do Editar renda; recebe a [Renda] em `extra` e devolve `true` quando
/// salvou (edição, desativação ou reativação).
String rotaEditarRenda(String id) => '/mais/planejamento/rendas/$id/editar';

/// Rota de Aporte e reserva; recebe a [LeituraConfiguracao] em `extra` e
/// devolve `true` quando salvou.
const rotaAjustesCalculo = '/mais/planejamento/ajustes';

/// Mais → Planejamento: rendas previstas e a configuração do cálculo. Até
/// existirem renda e configuração, mostra os dois passos para começar.
class PlanejamentoTela extends StatelessWidget {
  const PlanejamentoTela({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planejamento')),
      body: BlocBuilder<PlanejamentoCubit, PlanejamentoEstado>(
        builder: (context, estado) => switch (estado) {
          PlanejamentoCarregando() => const Carregando(),
          PlanejamentoErro(:final mensagem) => ErroComTentar(
            mensagem: mensagem,
            aoTentar: context.read<PlanejamentoCubit>().carregar,
          ),
          PlanejamentoCarregado(:final rendas, :final leitura) => _Conteudo(
            rendas: rendas,
            leitura: leitura,
          ),
        },
      ),
    );
  }
}

/// Abre um formulário e, se ele salvou, recarrega a tela.
Future<void> _abrir(BuildContext context, String rota, {Object? extra}) async {
  final cubit = context.read<PlanejamentoCubit>();
  final salvou = await context.push<bool>(rota, extra: extra);
  if (salvou == true) await cubit.carregar();
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.rendas, required this.leitura});

  final List<Renda> rendas;
  final LeituraConfiguracao leitura;

  @override
  Widget build(BuildContext context) {
    final configuracao = leitura.configuracao;
    final nomesDasContas = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) => {
        for (final conta in resumo.contas) conta.id: conta.nome,
      },
      _ => const <String, String>{},
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x2,
        Espaco.x4,
        Espaco.x6,
      ),
      children: [
        if (rendas.isEmpty || configuracao == null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Espaco.x1),
            child: Text(
              'Dois passos para o Início calcular o aporte do salário e o '
              'ritmo de gastos.',
              style: context.textos.bodyMedium?.copyWith(
                color: context.esquema.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: Espaco.x2),
          const TituloSecao('Para começar', pequeno: true),
          _Passos(
            rendaFeita: rendas.isNotEmpty,
            configuracaoFeita: configuracao != null,
            leitura: leitura,
          ),
          const SizedBox(height: Espaco.x4),
        ],
        const TituloSecao('Rendas previstas', pequeno: true),
        if (rendas.isEmpty)
          const _SemRendas()
        else
          GrupoLista(
            itens: [
              for (final renda in rendas)
                _ItemRenda(renda, nomeDaConta: nomesDasContas[renda.contaId]),
              const _AdicionarRenda(),
            ],
          ),
        if (configuracao != null) ...[
          const SizedBox(height: Espaco.x4),
          Row(
            children: [
              const Expanded(
                child: TituloSecao('Aporte e reserva', pequeno: true),
              ),
              TextButton.icon(
                onPressed: () =>
                    _abrir(context, rotaAjustesCalculo, extra: leitura),
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Editar'),
              ),
            ],
          ),
          _QuadroConfiguracao(configuracao, leitura),
        ],
      ],
    );
  }
}

/// "Para começar": cadastrar a renda e definir colchão e gastos. O passo
/// feito ganha um ✓ e perde o botão.
class _Passos extends StatelessWidget {
  const _Passos({
    required this.rendaFeita,
    required this.configuracaoFeita,
    required this.leitura,
  });

  final bool rendaFeita;
  final bool configuracaoFeita;
  final LeituraConfiguracao leitura;

  @override
  Widget build(BuildContext context) {
    return GrupoLista(
      itens: [
        _Passo(
          numero: 1,
          feito: rendaFeita,
          atual: !rendaFeita,
          titulo: 'Cadastre sua renda',
          texto:
              'Valor, dia em que cai e a conta. Dá para ter mais de uma, como '
              'salário e freela.',
          acao: FilledButton.icon(
            onPressed: () => _abrir(context, rotaNovaRenda),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar renda'),
          ),
        ),
        _Passo(
          numero: 2,
          feito: configuracaoFeita,
          atual: rendaFeita && !configuracaoFeita,
          titulo: 'Defina colchão e gastos',
          texto:
              'Colchão, gasto semanal estimado e meta da reserva. Sem eles, o '
              'aporte não é calculado.',
          acao: OutlinedButton(
            onPressed: () =>
                _abrir(context, rotaAjustesCalculo, extra: leitura),
            child: const Text('Definir'),
          ),
        ),
      ],
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo({
    required this.numero,
    required this.feito,
    required this.atual,
    required this.titulo,
    required this.texto,
    required this.acao,
  });

  final int numero;
  final bool feito;

  /// O próximo passo a fazer: número em destaque.
  final bool atual;
  final String titulo;
  final String texto;
  final Widget acao;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final destaque = feito || atual;
    return Padding(
      padding: const EdgeInsets.all(Espaco.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: destaque ? esquema.primary : esquema.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: feito
                ? Icon(Icons.check_rounded, size: 18, color: esquema.onPrimary)
                : Text(
                    '$numero',
                    style: textos.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: destaque
                          ? esquema.onPrimary
                          : esquema.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.titleMedium),
                const SizedBox(height: Espaco.x1),
                Text(
                  texto,
                  style: textos.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                if (!feito) ...[const SizedBox(height: Espaco.x3), acao],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemRendas extends StatelessWidget {
  const _SemRendas();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: esquema.outline),
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Column(
        children: [
          Icon(Icons.event_repeat_rounded, color: esquema.onSurfaceVariant),
          const SizedBox(height: Espaco.x2),
          Text(
            'Nenhuma renda cadastrada. Sem ela, o Início mostra só o saldo '
            'disponível.',
            textAlign: TextAlign.center,
            style: context.textos.bodyMedium?.copyWith(
              color: esquema.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Salário · R$ 4.200,00 / Dia 10 · Conta principal / Próxima: terça,
/// 10 nov"; inativa, em cinza, com o selo e sem a próxima data.
class _ItemRenda extends StatelessWidget {
  const _ItemRenda(this.renda, {required this.nomeDaConta});

  final Renda renda;
  final String? nomeDaConta;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final apagada = renda.ativa ? null : esquema.onSurfaceVariant;
    final meta = textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant);
    return InkWell(
      onTap: () => _abrir(context, rotaEditarRenda(renda.id), extra: renda),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.x4,
          Espaco.x3,
          Espaco.x2,
          Espaco.x3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          renda.descricao,
                          style: textos.bodyLarge?.copyWith(color: apagada),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Espaco.x3),
                      Text(
                        formatarDinheiro(renda.valor),
                        style: textos.bodyLarge?.copyWith(
                          color: apagada,
                          fontWeight: renda.ativa
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFeatures: algarismosTabulares,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: Espaco.x2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        ['Dia ${renda.diaPrevisto}', ?nomeDaConta].join(' · '),
                        style: meta,
                      ),
                      if (!renda.ativa) const _SeloInativa(),
                    ],
                  ),
                  if (renda.ativa) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.event_rounded,
                          size: 14,
                          color: esquema.primary,
                        ),
                        const SizedBox(width: Espaco.x1),
                        Expanded(
                          child: Text(
                            'Próxima: ${descreverProxima(renda.proxima, diaPrevisto: renda.diaPrevisto)}',
                            style: textos.bodySmall?.copyWith(
                              color: esquema.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: esquema.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _SeloInativa extends StatelessWidget {
  const _SeloInativa();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: esquema.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Inativa',
        style: context.textos.labelMedium?.copyWith(
          color: esquema.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AdicionarRenda extends StatelessWidget {
  const _AdicionarRenda();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return InkWell(
      onTap: () => _abrir(context, rotaNovaRenda),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espaco.x4),
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: esquema.primary),
              const SizedBox(width: Espaco.x3),
              Text(
                'Adicionar renda',
                style: context.textos.labelLarge?.copyWith(
                  color: esquema.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colchão, gasto semanal, meta da reserva e gasto mensal de referência.
class _QuadroConfiguracao extends StatelessWidget {
  const _QuadroConfiguracao(this.configuracao, this.leitura);

  final Configuracao configuracao;
  final LeituraConfiguracao leitura;

  @override
  Widget build(BuildContext context) {
    final semanal = configuracao.gastoSemanalEstimado;
    final fixo = configuracao.gastoMensalReferencia;
    final automatico = leitura.gastoMensalAutomatico;
    return GrupoLista(
      itens: [
        _Linha(
          titulo: 'Colchão',
          detalhe: 'Fica na conta depois do aporte',
          valor: formatarDinheiro(configuracao.colchao),
        ),
        _Linha(
          titulo: 'Gasto semanal estimado',
          detalhe: '${formatarDinheiro(gastoPorDia(semanal))} por dia',
          valor: formatarDinheiro(semanal),
        ),
        _Linha(
          titulo: 'Meta da reserva',
          detalhe: switch (leitura.mesesDeReserva) {
            final meses? => 'Hoje: ${formatarMeses(meses)}',
            null => null,
          },
          valor: formatarMeses(configuracao.metaReservaMeses),
        ),
        _Linha(
          titulo: 'Gasto mensal de referência',
          detalhe: fixo != null
              ? 'Valor fixo'
              : automatico == null
              ? 'Automático: ainda sem um mês fechado'
              : 'Automático: média de ${intervaloDeMeses(automatico.meses)}',
          valor: switch (fixo ?? automatico?.valor) {
            final valor? => formatarDinheiro(valor),
            null => '—',
          },
        ),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.titulo, required this.valor, this.detalhe});

  final String titulo;
  final String? detalhe;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x4,
        vertical: Espaco.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: textos.bodyMedium),
                if (detalhe != null)
                  Text(
                    detalhe!,
                    style: textos.bodySmall?.copyWith(
                      color: context.esquema.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Espaco.x3),
          Text(
            valor,
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
