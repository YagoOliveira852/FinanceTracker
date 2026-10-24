import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/datas.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../cubit/editar_fatura_cubit.dart';
import '../data/fatura.dart';
import 'textos.dart';

/// Datas de fechamento e vencimento e o valor que o banco informou. Fecha
/// devolvendo o [DetalheFatura] salvo.
class EditarFaturaTela extends StatefulWidget {
  const EditarFaturaTela({
    super.key,
    required this.contaId,
    required this.detalhe,
  });

  final String contaId;
  final DetalheFatura detalhe;

  @override
  State<EditarFaturaTela> createState() => _EditarFaturaTelaState();
}

class _EditarFaturaTelaState extends State<EditarFaturaTela> {
  late var _fechamento = widget.detalhe.resumo.dataFechamento;
  late var _vencimento = widget.detalhe.resumo.dataVencimento;
  late final _informado = TextEditingController(
    text: switch (widget.detalhe.resumo.valorInformado) {
      final valor? => dinheiroParaCampo(valor),
      null => '',
    },
  );

  /// O calendário vai até um ano depois do vencimento calculado: datas de
  /// fatura podem estar no futuro.
  late final _ultimaData = DateTime(
    widget.detalhe.vencimentoCalculado.year + 1,
    widget.detalhe.vencimentoCalculado.month,
    widget.detalhe.vencimentoCalculado.day,
  );

  @override
  void dispose() {
    _informado.dispose();
    super.dispose();
  }

  void _voltarAsCalculadas() {
    setState(() {
      _fechamento = widget.detalhe.fechamentoCalculado;
      _vencimento = widget.detalhe.vencimentoCalculado;
    });
    context.read<EditarFaturaCubit>()
      ..limparErro('data_fechamento')
      ..limparErro('data_vencimento');
  }

  /// Ajuda do campo de data: o porquê do ajuste, de onde veio a data ou que
  /// ela foi editada.
  String _ajuda({
    required DateTime data,
    required DateTime calculada,
    required AjusteData? ajuste,
    required String deOnde,
  }) {
    if (data != calculada) {
      return 'Editada. A calculada é ${formatarData(calculada)}.';
    }
    if (ajuste != null) return explicarAjuste(ajuste);
    return deOnde;
  }

  @override
  Widget build(BuildContext context) {
    final detalhe = widget.detalhe;
    final cartao = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.id == widget.contaId).firstOrNull,
      _ => null,
    };
    return BlocConsumer<EditarFaturaCubit, EditarFaturaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, estado) => context.pop(estado.salva),
      builder: (context, estado) {
        final cubit = context.read<EditarFaturaCubit>();
        final livre = !estado.enviando;
        final esquema = context.esquema;
        return PopScope(
          canPop: livre,
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: Espaco.x1,
              leading: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(),
              ),
              title: const Text('Editar fatura'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: Espaco.x1),
                  child: Text(
                    [
                      tituloDaFatura(detalhe.resumo.competencia),
                      ?cartao?.nome,
                    ].join(' · '),
                    style: context.textos.bodyMedium?.copyWith(
                      color: esquema.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                CampoData(
                  rotulo: 'Data de fechamento',
                  data: _fechamento,
                  ultimaData: _ultimaData,
                  habilitado: livre,
                  aoMudar: (data) {
                    setState(() => _fechamento = data);
                    cubit.limparErro('data_fechamento');
                  },
                  ajuda: _ajuda(
                    data: _fechamento,
                    calculada: detalhe.fechamentoCalculado,
                    ajuste: detalhe.ajusteFechamento,
                    deOnde: switch (cartao?.cartao?.diaFechamento) {
                      final dia? =>
                        'Calculada pelo dia de fechamento do cartão (dia $dia).',
                      null => 'Calculada pelo dia de fechamento do cartão.',
                    },
                  ),
                  erro: estado.erros['data_fechamento'],
                ),
                const SizedBox(height: Espaco.x6),
                CampoData(
                  rotulo: 'Data de vencimento',
                  data: _vencimento,
                  ultimaData: _ultimaData,
                  habilitado: livre,
                  aoMudar: (data) {
                    setState(() => _vencimento = data);
                    cubit.limparErro('data_vencimento');
                  },
                  ajuda: _ajuda(
                    data: _vencimento,
                    calculada: detalhe.vencimentoCalculado,
                    ajuste: detalhe.ajusteVencimento,
                    deOnde: switch (cartao?.cartao?.diaVencimento) {
                      final dia? =>
                        'Calculada pelo dia de vencimento do cartão (dia $dia).',
                      null => 'Calculada pelo dia de vencimento do cartão.',
                    },
                  ),
                  erro: estado.erros['data_vencimento'],
                ),
                const SizedBox(height: Espaco.x6),
                CampoDinheiro(
                  controller: _informado,
                  rotulo: 'Valor informado pelo banco',
                  habilitado: livre,
                  ajuda:
                      'O total que o banco mostra na fatura. Deixe vazio se '
                      'ainda não souber.',
                  erro: estado.erros['valor_informado'],
                  aoMudar: (_) => cubit.limparErro('valor_informado'),
                ),
                const SizedBox(height: Espaco.x4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: livre ? _voltarAsCalculadas : null,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Voltar às datas calculadas'),
                  ),
                ),
                const SizedBox(height: Espaco.x4),
                Container(
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
                      Icon(Icons.info_rounded, color: esquema.primary),
                      const SizedBox(width: Espaco.x3),
                      Expanded(
                        child: Text(
                          'Ao mudar o fechamento, as compras feitas a partir '
                          'da nova data vão para a fatura seguinte, e as '
                          'feitas antes dela ficam nesta.',
                          style: context.textos.bodyMedium?.copyWith(
                            color: esquema.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre
                    ? () => cubit.salvar(
                        dataFechamento: _fechamento,
                        dataVencimento: _vencimento,
                        valorInformado: _informado.text,
                      )
                    : null,
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
