import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../planejamento/data/resumo.dart';
import '../../planejamento/ui/textos.dart';
import '../../revisao/cubit/revisao_cubit.dart';
import '../cubit/inicio_cubit.dart';
import 'textos.dart';

/// Rota do Planejamento, aberta pelo "Cadastrar salário".
const _rotaPlanejamento = '/mais/planejamento';

/// Início: a sobra até o próximo salário com o alerta de ritmo, o aporte
/// quando o salário chega, os rascunhos que o cálculo considera e a reserva.
/// Sem renda ativa ou sem configuração, convida a cadastrar o salário e
/// mostra só o saldo disponível. Design: página "Início" do canvas.
class InicioTela extends StatelessWidget {
  const InicioTela({super.key});

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<InicioCubit>().state;
    final hoje = switch (estado) {
      InicioCarregado(:final hoje) => hoje,
      _ => somenteData(DateTime.now()),
    };

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatarDataLonga(hoje), style: context.textos.bodySmall),
            const Text('Início'),
          ],
        ),
      ),
      body: switch (estado) {
        InicioCarregando() => const Carregando(),
        InicioErro(:final mensagem) => ErroComTentar(
          mensagem: mensagem,
          aoTentar: context.read<InicioCubit>().carregar,
        ),
        InicioCarregado() => RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<InicioCubit>().carregar(),
            context.read<ContasCubit>().carregar(),
          ]),
          child: _Conteudo(estado),
        ),
      },
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo(this.estado);

  final InicioCarregado estado;

  @override
  Widget build(BuildContext context) {
    final resumo = estado.resumo;
    final previsao = resumo.previsao;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x2,
        Espaco.x4,
        Espaco.x4,
      ),
      children: [
        if (previsao == null) ...[
          const _CadastrarSalario(),
          const SizedBox(height: Espaco.x4),
          const _SaldoDisponivel(),
        ] else ...[
          if (_sugereAporte(previsao) && !estado.aporteDispensado)
            _CardAporte(
              previsao,
              saldo: resumo.saldoDisponivel,
              hoje: estado.hoje,
            )
          else
            _CardSobra(
              previsao,
              saldo: resumo.saldoDisponivel,
              hoje: estado.hoje,
            ),
          if (resumo.rascunhos > 0) ...[
            const SizedBox(height: Espaco.x4),
            _AvisoRascunhos(resumo.rascunhos),
          ],
          const SizedBox(height: Espaco.x4),
          _CardReserva(resumo),
        ],
      ],
    );
  }
}

/// O aporte só é sugerido quando o salário chegou e sobra acima do colchão;
/// com aporte zero, o alerta assume.
bool _sugereAporte(Previsao previsao) =>
    previsao.salarioRecebido != null &&
    (previsao.aporte ?? Decimal.zero) > Decimal.zero;

/// Estado "sem salário cadastrado": o que o cálculo precisa e o atalho para
/// Mais → Planejamento.
class _CadastrarSalario extends StatelessWidget {
  const _CadastrarSalario();

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    Widget item(IconData icone, String texto) => Padding(
      padding: const EdgeInsets.only(top: Espaco.x2),
      child: Row(
        children: [
          Icon(icone, color: esquema.onSurfaceVariant),
          const SizedBox(width: Espaco.x2),
          Expanded(child: Text(texto, style: textos.bodyMedium)),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Espaco.x5,
          Espaco.x8,
          Espaco.x5,
          Espaco.x5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: esquema.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_repeat_rounded,
                color: esquema.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: Espaco.x3),
            Text('Cadastre seu salário', style: textos.titleLarge),
            const SizedBox(height: Espaco.x3),
            Text(
              'Com o valor e o dia em que você recebe, o app calcula quanto dá '
              'para aportar e avisa se o ritmo de gastos ameaça a reserva.',
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaco.x1),
            item(
              Icons.payments_outlined,
              'Salário: valor, dia e conta onde cai',
            ),
            item(
              Icons.savings_outlined,
              'Colchão: quanto fica na conta após o aporte',
            ),
            item(Icons.flag_outlined, 'Meta da reserva, em meses de gasto'),
            const SizedBox(height: Espaco.x5),
            FilledButton(
              onPressed: () => context.go(_rotaPlanejamento),
              child: const Text('Cadastrar salário'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saldo oficial (só confirmadas), o mesmo da aba Contas: sem salário
/// cadastrado, nada é calculado com os rascunhos.
class _SaldoDisponivel extends StatelessWidget {
  const _SaldoDisponivel();

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    final estado = context.watch<ContasCubit>().state;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo disponível', style: textos.bodySmall),
            const SizedBox(height: Espaco.x1),
            switch (estado) {
              ContasCarregando() => const Padding(
                padding: EdgeInsets.symmetric(vertical: Espaco.x2),
                child: LinearProgressIndicator(),
              ),
              ContasErro(:final mensagem) => Text(
                mensagem,
                style: textos.bodyMedium?.copyWith(color: esquema.error),
              ),
              ContasCarregado(:final resumo) => Text(
                formatarDinheiro(resumo.totalDisponivel),
                style: textos.headlineMedium?.copyWith(
                  fontFeatures: algarismosTabulares,
                ),
              ),
            },
            const SizedBox(height: Espaco.x1),
            Text(
              'Contas correntes e carteira.',
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sobra prevista até o salário" com o chip do alerta de ritmo e a conta:
/// saldo − faturas − gastos previstos.
class _CardSobra extends StatelessWidget {
  const _CardSobra(this.previsao, {required this.saldo, required this.hoje});

  final Previsao previsao;
  final Decimal saldo;
  final DateTime hoje;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final risco = previsao.nivel == NivelRitmo.vermelho;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sobra prevista até o salário',
                    style: textos.titleMedium,
                  ),
                ),
                const SizedBox(width: Espaco.x2),
                _ChipRitmo(previsao.nivel),
              ],
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              formatarDinheiro(previsao.sobra),
              style: textos.displaySmall?.copyWith(
                fontFeatures: algarismosTabulares,
                color: risco ? context.cores.ritmoRisco : null,
              ),
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              fraseDaSobra(previsao, hoje),
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            _Conta(
              cor: esquema.onSurfaceVariant,
              divisor: esquema.outlineVariant,
              linhas: [
                ('Saldo disponível', formatarDinheiro(saldo)),
                ..._linhasDaPrevisao(previsao, hoje),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Faturas e gastos previstos, com o sinal de saída.
List<(String, String)> _linhasDaPrevisao(Previsao previsao, DateTime hoje) => [
  for (final fatura in previsao.faturas)
    (linhaDaFatura(fatura, hoje), _saida(fatura.valor)),
  (linhaDosGastos(previsao), _saida(previsao.gastosPrevistos)),
];

String _saida(Decimal valor) => formatarDinheiroComSinal(valor, entrada: false);

/// "Salário recebido: você pode aportar", no tom primário. "Registrar
/// aporte" fica desabilitado, com o aviso de "em breve", até os investimentos
/// (S8); "Agora não" dispensa a sugestão até o salário seguinte.
class _CardAporte extends StatelessWidget {
  const _CardAporte(this.previsao, {required this.saldo, required this.hoje});

  final Previsao previsao;
  final Decimal saldo;
  final DateTime hoje;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final cor = esquema.onPrimaryContainer;
    return Card(
      color: esquema.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payments_outlined, color: cor),
                const SizedBox(width: Espaco.x2),
                Expanded(
                  child: Text(
                    'Salário recebido: você pode aportar',
                    style: textos.titleMedium?.copyWith(color: cor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              formatarDinheiro(previsao.aporte!),
              style: textos.displaySmall?.copyWith(
                color: cor,
                fontFeatures: algarismosTabulares,
              ),
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              fraseDoAporte(previsao, hoje),
              style: textos.bodyMedium?.copyWith(color: cor),
            ),
            _Conta(
              cor: cor,
              divisor: cor.withValues(alpha: 0.2),
              linhas: [
                ('Saldo disponível', formatarDinheiro(saldo)),
                ..._linhasDaPrevisao(previsao, hoje),
                ('Colchão na conta', _saida(previsao.colchao)),
              ],
            ),
            const SizedBox(height: Espaco.x4),
            // Wrap: com fonte grande, "Agora não" desce para a linha de baixo.
            Wrap(
              spacing: Espaco.x2,
              runSpacing: Espaco.x2,
              children: [
                const FilledButton(
                  onPressed: null,
                  child: Text('Registrar aporte'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: cor),
                  onPressed: context.read<InicioCubit>().dispensarAporte,
                  child: const Text('Agora não'),
                ),
              ],
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              'Registrar o aporte chega em breve, com os investimentos.',
              style: textos.bodySmall?.copyWith(color: cor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A conta do card: rótulo à esquerda, valor à direita, abaixo de um divisor.
class _Conta extends StatelessWidget {
  const _Conta({
    required this.linhas,
    required this.cor,
    required this.divisor,
  });

  final List<(String, String)> linhas;

  /// Cor dos rótulos.
  final Color cor;
  final Color divisor;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    return Container(
      margin: const EdgeInsets.only(top: Espaco.x2),
      padding: const EdgeInsets.only(top: Espaco.x3),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: divisor)),
      ),
      child: Column(
        children: [
          for (final (indice, (rotulo, valor)) in linhas.indexed)
            Padding(
              padding: EdgeInsets.only(top: indice == 0 ? 0 : Espaco.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rotulo,
                      style: textos.bodyMedium?.copyWith(color: cor),
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
            ),
        ],
      ),
    );
  }
}

/// "No ritmo", "Atenção" ou "Risco".
class _ChipRitmo extends StatelessWidget {
  const _ChipRitmo(this.nivel);

  final NivelRitmo nivel;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final (rotulo, icone, fundo, cor) = switch (nivel) {
      NivelRitmo.verde => (
        'No ritmo',
        Icons.check_circle_outline_rounded,
        cores.ritmoOkContainer,
        cores.ritmoOk,
      ),
      NivelRitmo.amarelo => (
        'Atenção',
        Icons.error_outline_rounded,
        cores.ritmoAtencaoContainer,
        cores.ritmoAtencao,
      ),
      NivelRitmo.vermelho => (
        'Risco',
        Icons.warning_amber_rounded,
        cores.ritmoRiscoContainer,
        cores.ritmoRisco,
      ),
    };
    return Container(
      height: 32,
      padding: const EdgeInsets.fromLTRB(Espaco.x2, 0, Espaco.x3, 0),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(Raio.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 6),
          Text(rotulo, style: context.textos.labelLarge?.copyWith(color: cor)),
        ],
      ),
    );
  }
}

/// "Considera N rascunhos não revisados", com o atalho para a Revisão.
class _AvisoRascunhos extends StatelessWidget {
  const _AvisoRascunhos(this.quantidade);

  final int quantidade;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(
        Espaco.x4,
        Espaco.x1,
        Espaco.x1,
        Espaco.x1,
      ),
      decoration: BoxDecoration(
        color: cores.rascunhoContainer,
        border: Border.all(color: cores.rascunho),
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, color: cores.rascunho),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Text(
              fraseDosRascunhos(quantidade),
              style: context.textos.bodyMedium?.copyWith(
                color: cores.rascunho,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: cores.rascunho),
            onPressed: () {
              context.read<RevisaoCubit>().carregar();
              context.go('/revisao');
            },
            child: const Text('Revisar'),
          ),
        ],
      ),
    );
  }
}

/// Reserva de emergência até os investimentos (S8): a meta e o gasto de
/// referência, com o selo "Em breve" no lugar dos meses.
class _CardReserva extends StatelessWidget {
  const _CardReserva(this.resumo);

  final Resumo resumo;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final meta = resumo.metaReservaMeses;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reserva de emergência',
                    style: textos.titleMedium,
                  ),
                ),
                if (meta != null)
                  Text(
                    'meta ${formatarMeses(meta)}',
                    style: textos.bodySmall?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Espaco.x2),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: Espaco.x2),
              decoration: BoxDecoration(
                color: esquema.secondaryContainer,
                borderRadius: BorderRadius.circular(Raio.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Em breve',
                    style: textos.labelMedium?.copyWith(
                      color: esquema.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Espaco.x2),
            Text(
              fraseDaReserva(resumo.gastoMensal),
              style: textos.bodyMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
