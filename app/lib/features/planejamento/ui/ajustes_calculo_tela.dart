import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../cubit/ajustes_calculo_cubit.dart';
import '../data/planejamento.dart';
import 'textos.dart';

/// Aporte e reserva: colchão, gasto semanal estimado, meta da reserva e
/// gasto mensal de referência (automático ou valor fixo). Fecha com `true`
/// quando salvou.
class AjustesCalculoTela extends StatefulWidget {
  const AjustesCalculoTela({super.key, required this.leitura});

  /// A configuração atual (nula na primeira vez) e o que o histórico dá.
  final LeituraConfiguracao leitura;

  @override
  State<AjustesCalculoTela> createState() => _AjustesCalculoTelaState();
}

class _AjustesCalculoTelaState extends State<AjustesCalculoTela> {
  late final Configuracao? _atual = widget.leitura.configuracao;
  late final _colchao = TextEditingController(text: _campo(_atual?.colchao));
  late final _semanal = TextEditingController(
    text: _campo(_atual?.gastoSemanalEstimado),
  );
  late final _meta = TextEditingController(
    text: switch (_atual?.metaReservaMeses) {
      final meta? =>
        meta
            .toStringAsFixed(1)
            .replaceFirst(RegExp(r'\.0$'), '')
            .replaceAll('.', ','),
      null => '',
    },
  );
  late final _mensal = TextEditingController(
    text: _campo(_atual?.gastoMensalReferencia),
  );

  static String _campo(Decimal? valor) =>
      valor == null ? '' : dinheiroParaCampo(valor);

  @override
  void dispose() {
    _colchao.dispose();
    _semanal.dispose();
    _meta.dispose();
    _mensal.dispose();
    super.dispose();
  }

  void _salvar() {
    context.read<AjustesCalculoCubit>().salvar(
      colchao: _colchao.text,
      gastoSemanal: _semanal.text,
      meta: _meta.text,
      gastoMensal: _mensal.text,
    );
  }

  /// "R$ 40,00 por dia. É o mínimo usado nos gastos previstos: (...) a
  /// média real (hoje R$ 252,00 por semana)."
  String _ajudaSemanal() {
    final semanal = lerDinheiro(_semanal.text);
    final porDia = semanal == null || semanal < Decimal.zero
        ? ''
        : '${formatarDinheiro(gastoPorDia(semanal))} por dia. ';
    final media = switch (widget.leitura.mediaSemanalReal) {
      final media? => ' (hoje ${formatarDinheiro(media)} por semana)',
      null => '',
    };
    return '$porDiaÉ o mínimo usado nos gastos previstos: com 4 semanas de '
        'histórico, vale o maior entre ele e a média real$media.';
  }

  @override
  Widget build(BuildContext context) {
    final leitura = widget.leitura;
    return BlocConsumer<AjustesCalculoCubit, AjustesCalculoEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => Navigator.of(context).pop(true),
      builder: (context, estado) {
        final cubit = context.read<AjustesCalculoCubit>();
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
              title: const Text('Aporte e reserva'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                CampoDinheiro(
                  controller: _colchao,
                  aoMudar: (_) => cubit.limparErro('colchao'),
                  rotulo: 'Colchão',
                  ajuda:
                      'Fica na conta depois do aporte, para imprevistos até o '
                      'próximo salário. Abaixo dele, o alerta fica amarelo.',
                  habilitado: livre,
                  erro: estado.erros['colchao'],
                ),
                const SizedBox(height: Espaco.x6),
                CampoDinheiro(
                  controller: _semanal,
                  aoMudar: (_) {
                    cubit.limparErro('gasto_semanal_estimado');
                    setState(() {});
                  },
                  rotulo: 'Gasto semanal estimado',
                  ajuda: _ajudaSemanal(),
                  habilitado: livre,
                  erro: estado.erros['gasto_semanal_estimado'],
                ),
                const SizedBox(height: Espaco.x6),
                TextField(
                  controller: _meta,
                  onChanged: (_) => cubit.limparErro('meta_reserva_meses'),
                  enabled: livre,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Meta da reserva',
                    hintText: 'Ex.: 6',
                    suffixText: 'meses',
                    helperText: [
                      'Em meses de gasto.',
                      if (leitura.mesesDeReserva case final meses?)
                        'Hoje a reserva cobre ${formatarMeses(meses)}.',
                    ].join(' '),
                    errorText: estado.erros['meta_reserva_meses'],
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                _GastoMensal(
                  automatico: estado.automatico,
                  calculado: leitura.gastoMensalAutomatico,
                  controller: _mensal,
                  erro: estado.erros['gasto_mensal_referencia'],
                  habilitado: livre,
                  aoEscolher: cubit.escolherAutomatico,
                  aoMudar: () => cubit.limparErro('gasto_mensal_referencia'),
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

/// "Automático" (a média calculada) ou "Valor fixo" (campo de valor).
class _GastoMensal extends StatelessWidget {
  const _GastoMensal({
    required this.automatico,
    required this.calculado,
    required this.controller,
    required this.erro,
    required this.habilitado,
    required this.aoEscolher,
    required this.aoMudar,
  });

  final bool automatico;
  final GastoMensal? calculado;
  final TextEditingController controller;
  final String? erro;
  final bool habilitado;
  final ValueChanged<bool> aoEscolher;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final variante = textos.bodySmall?.copyWith(
      color: esquema.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: Espaco.x1, bottom: Espaco.x2),
          child: Text('Gasto mensal de referência', style: variante),
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Automático')),
            ButtonSegment(value: false, label: Text('Valor fixo')),
          ],
          selected: {automatico},
          onSelectionChanged: habilitado
              ? (escolha) => aoEscolher(escolha.single)
              : null,
        ),
        const SizedBox(height: Espaco.x2),
        if (automatico)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Espaco.x4,
              vertical: Espaco.x3,
            ),
            decoration: BoxDecoration(
              color: esquema.surfaceContainer,
              borderRadius: BorderRadius.circular(Raio.md),
            ),
            child: switch (calculado) {
              final gasto? => Row(
                children: [
                  Expanded(
                    child: Text(
                      'Média de ${listaDeMeses(gasto.meses)}',
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    formatarDinheiro(gasto.valor),
                    style: textos.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: algarismosTabulares,
                    ),
                  ),
                ],
              ),
              null => Text(
                'Ainda não há um mês fechado inteiro no histórico.',
                style: textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            },
          )
        else
          CampoDinheiro(
            controller: controller,
            aoMudar: (_) => aoMudar(),
            rotulo: 'Gasto mensal fixo',
            habilitado: habilitado,
            erro: erro,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x1,
            Espaco.x4,
            0,
          ),
          child: Text(
            'Divide a reserva para dar os meses. Automático usa a média dos 3 '
            'últimos meses fechados.',
            style: variante,
          ),
        ),
      ],
    );
  }
}
