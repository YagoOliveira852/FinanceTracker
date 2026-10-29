import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formatacao/datas.dart';
import '../tema.dart';

/// Campo de valor em reais: prefixo `R$`, teclado numérico, algarismos
/// tabulares. O texto é lido com `lerDinheiro` (nunca `double`).
class CampoDinheiro extends StatelessWidget {
  const CampoDinheiro({
    super.key,
    required this.controller,
    required this.rotulo,
    this.ajuda,
    this.erro,
    this.aceitaNegativo = false,
    this.habilitado = true,
    this.aoMudar,
  });

  final TextEditingController controller;
  final ValueChanged<String>? aoMudar;
  final String rotulo;
  final String? ajuda;
  final String? erro;
  final bool aceitaNegativo;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: habilitado,
      onChanged: aoMudar,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: aceitaNegativo,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(aceitaNegativo ? r'[0-9.,\-−]' : r'[0-9.,]'),
        ),
      ],
      style: context.textos.bodyLarge?.copyWith(
        fontFeatures: algarismosTabulares,
      ),
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: '0,00',
        prefixText: 'R\$ ',
        helperText: ajuda,
        errorText: erro,
        suffixIcon: erro == null ? null : const Icon(Icons.error_rounded),
      ),
    );
  }
}

/// Campo de data só leitura: tocar abre o calendário em pt-BR.
class CampoData extends StatelessWidget {
  const CampoData({
    super.key,
    required this.rotulo,
    required this.data,
    required this.aoMudar,
    this.ajuda,
    this.erro,
    this.habilitado = true,
    this.ultimaData,
  });

  final String rotulo;
  final DateTime data;

  /// Última data que o calendário oferece; sem ela, hoje.
  final DateTime? ultimaData;
  final ValueChanged<DateTime> aoMudar;
  final String? ajuda;
  final String? erro;
  final bool habilitado;

  Future<void> _escolher(BuildContext context) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: data,
      firstDate: DateTime(2000),
      // Por padrão sem datas futuras: o saldo inicial não pode ser futuro, e
      // lançamento agendado não existe nesta versão. Datas de fatura podem.
      lastDate: ultimaData ?? somenteData(DateTime.now()),
      helpText: rotulo,
    );
    if (escolhida != null) aoMudar(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    final aoTocar = habilitado ? () => _escolher(context) : null;
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(Raio.md),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          errorText: erro,
          enabled: habilitado,
          suffixIcon: IconButton(
            tooltip: 'Escolher data',
            onPressed: aoTocar,
            icon: const Icon(Icons.calendar_today_rounded),
          ),
        ),
        child: Text(formatarData(data), style: context.textos.bodyLarge),
      ),
    );
  }
}

/// Uma opção de [CampoSelecao]. Na folha, [rotulo] e, embaixo, o [detalhe]
/// (instituição da conta, grupo da categoria); no campo, o [resumo] ou, sem
/// ele, o [rotulo].
class OpcaoSelecao<T> {
  const OpcaoSelecao({
    required this.valor,
    required this.rotulo,
    this.detalhe,
    this.resumo,
  });

  final T valor;
  final String rotulo;
  final String? detalhe;
  final String? resumo;
}

/// Campo de escolha: tocar abre uma folha de baixo com as [opcoes] e um
/// check na escolhida. Controlado: mostra a opção de [valor], e escolher
/// chama [aoMudar] (nulo desabilita o campo).
class CampoSelecao<T> extends StatelessWidget {
  const CampoSelecao({
    super.key,
    required this.rotulo,
    required this.opcoes,
    required this.valor,
    required this.aoMudar,
    this.vazio,
    this.ajuda,
    this.erro,
  });

  final String rotulo;
  final List<OpcaoSelecao<T>> opcoes;
  final T? valor;
  final ValueChanged<T>? aoMudar;

  /// Texto do campo quando nenhuma opção está escolhida.
  final String? vazio;
  final String? ajuda;
  final String? erro;

  OpcaoSelecao<T>? get _escolhida =>
      opcoes.where((opcao) => opcao.valor == valor).firstOrNull;

  Future<void> _escolher(BuildContext context) async {
    final escolhida = await showModalBottomSheet<OpcaoSelecao<T>>(
      context: context,
      // No navegador raiz, a folha cobre a barra de abas, como as outras.
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _FolhaSelecao(titulo: rotulo, opcoes: opcoes, escolhida: _escolhida),
    );
    if (escolhida != null) aoMudar?.call(escolhida.valor);
  }

  @override
  Widget build(BuildContext context) {
    final habilitado = aoMudar != null;
    final escolhida = _escolhida;
    final textos = context.textos;
    return InkWell(
      onTap: habilitado ? () => _escolher(context) : null,
      borderRadius: BorderRadius.circular(Raio.md),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          helperMaxLines: 3,
          errorText: erro,
          errorMaxLines: 3,
          enabled: habilitado,
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        child: Text(
          escolhida?.resumo ?? escolhida?.rotulo ?? vazio ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: escolhida == null
              ? textos.bodyLarge?.copyWith(
                  color: context.esquema.onSurfaceVariant,
                )
              : textos.bodyLarge,
        ),
      ),
    );
  }
}

class _FolhaSelecao<T> extends StatelessWidget {
  const _FolhaSelecao({
    required this.titulo,
    required this.opcoes,
    required this.escolhida,
  });

  final String titulo;
  final List<OpcaoSelecao<T>> opcoes;
  final OpcaoSelecao<T>? escolhida;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return ConstrainedBox(
      // Lista longa (categorias, parcelas) rola dentro da folha.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Espaco.x6,
                0,
                Espaco.x6,
                Espaco.x2,
              ),
              child: Text(titulo, style: context.textos.titleLarge),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: Espaco.x4),
                children: [
                  for (final opcao in opcoes)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Espaco.x6,
                      ),
                      selected: identical(opcao, escolhida),
                      selectedColor: esquema.primary,
                      title: Text(opcao.rotulo),
                      subtitle: opcao.detalhe == null
                          ? null
                          : Text(opcao.detalhe!),
                      trailing: identical(opcao, escolhida)
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.of(context).pop(opcao),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior dos formulários com o botão principal.
class RodapeFormulario extends StatelessWidget {
  const RodapeFormulario({super.key, required this.botao});

  final Widget botao;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.esquema.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x4,
            Espaco.x4,
            Espaco.x6,
          ),
          child: SizedBox(width: double.infinity, child: botao),
        ),
      ),
    );
  }
}

/// Conteúdo do botão de enviar: rótulo ou indicador de progresso.
class RotuloEnviando extends StatelessWidget {
  const RotuloEnviando({
    super.key,
    required this.enviando,
    required this.rotulo,
  });

  final bool enviando;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    if (!enviando) return Text(rotulo);
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2.5),
    );
  }
}

/// Dia do mês (1 a 31) do cartão: fechamento ou vencimento.
class CampoDiaDoMes extends StatelessWidget {
  const CampoDiaDoMes({
    super.key,
    required this.controller,
    required this.rotulo,
    required this.erro,
    required this.habilitado,
    required this.aoMudar,
  });

  final TextEditingController controller;
  final String rotulo;
  final String? erro;
  final bool habilitado;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: habilitado,
      onChanged: (_) => aoMudar(),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: '1 a 31',
        errorText: erro,
        errorMaxLines: 2,
      ),
    );
  }
}
