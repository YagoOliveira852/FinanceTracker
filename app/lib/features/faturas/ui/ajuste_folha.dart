import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../cubit/fatura_cubit.dart';
import '../data/fatura.dart';

/// Abre a folha "Ajustar para o valor real" sobre o detalhe da fatura.
Future<void> abrirAjuste(BuildContext context, DetalheFatura detalhe) {
  final cubit = context.read<FaturaCubit>();
  return showModalBottomSheet<void>(
    context: context,
    // No navegador raiz, a folha cobre a barra de abas, como no design.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: _FolhaAjuste(detalhe)),
  );
}

/// Valor real (preenchido com o informado) e o motivo; mostra quanto o
/// ajuste vai lançar antes de confirmar.
class _FolhaAjuste extends StatefulWidget {
  const _FolhaAjuste(this.detalhe);

  final DetalheFatura detalhe;

  @override
  State<_FolhaAjuste> createState() => _FolhaAjusteState();
}

class _FolhaAjusteState extends State<_FolhaAjuste> {
  late final _valor = TextEditingController(
    text: dinheiroParaCampo(
      widget.detalhe.resumo.valorInformado ??
          widget.detalhe.resumo.valorCalculado,
    ),
  );
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  /// "Vai lançar um ajuste de R$ 45,90 nesta fatura." conforme o valor
  /// digitado; nulo enquanto o valor não é válido.
  String? _previa() {
    final real = lerDinheiro(_valor.text);
    if (real == null || validarDinheiro(_valor.text) != null) return null;
    final diferenca = real - calculadoSemAjuste(widget.detalhe);
    if (diferenca == Decimal.zero) {
      return 'Sem diferença: a fatura fica sem ajuste.';
    }
    final valor = formatarDinheiro(diferenca.abs());
    return diferenca > Decimal.zero
        ? 'Vai lançar um ajuste de $valor nesta fatura.'
        : 'Vai lançar um crédito de $valor nesta fatura.';
  }

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final previa = _previa();
    return BlocConsumer<FaturaCubit, FaturaEstado>(
      // Fecha quando o envio terminou sem erro.
      listenWhen: (antes, depois) =>
          antes is FaturaCarregada &&
          antes.ajustando &&
          depois is FaturaCarregada &&
          !depois.ajustando &&
          depois.erroAjuste == null,
      listener: (context, _) => Navigator.of(context).pop(),
      builder: (context, estado) {
        final ajustando = estado is FaturaCarregada && estado.ajustando;
        final erro = estado is FaturaCarregada ? estado.erroAjuste : null;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            Espaco.x4,
            0,
            Espaco.x4,
            Espaco.x6 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ajustar para o valor real', style: textos.headlineSmall),
              const SizedBox(height: Espaco.x2),
              Text(
                'As compras lançadas somam '
                '${formatarDinheiro(calculadoSemAjuste(widget.detalhe))}. O '
                'ajuste lança a diferença nesta fatura e fica na lista de '
                'compras, com o motivo.',
                style: textos.bodyMedium?.copyWith(
                  color: context.esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaco.x6),
              CampoDinheiro(
                controller: _valor,
                rotulo: 'Valor real da fatura',
                habilitado: !ajustando,
                ajuda: 'Preenchido com o valor informado pelo banco.',
                erro: erro,
                aoMudar: (_) => setState(() {}),
              ),
              const SizedBox(height: Espaco.x6),
              TextField(
                controller: _motivo,
                enabled: !ajustando,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  hintText: 'Ex.: IOF que não veio no extrato',
                  counterText: '',
                ),
              ),
              if (previa != null) ...[
                const SizedBox(height: Espaco.x2),
                Text(previa, style: textos.bodyMedium),
              ],
              const SizedBox(height: Espaco.x4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: ajustando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: Espaco.x2),
                  FilledButton(
                    onPressed: ajustando
                        ? null
                        : () => context.read<FaturaCubit>().ajustar(
                            valorReal: _valor.text,
                            descricao: _motivo.text,
                          ),
                    child: RotuloEnviando(
                      enviando: ajustando,
                      rotulo: 'Ajustar',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
