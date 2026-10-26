import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../cubit/transferencia_cubit.dart';
import 'lancamento_tela.dart';

/// Transferência entre contas próprias: De, Para, valor, data e descrição
/// opcional. Só correntes e carteiras ativas (pagar cartão é pagamento de
/// fatura); Para não oferece a conta de De. Fecha devolvendo `true`.
class FormularioTransferencia extends StatefulWidget {
  const FormularioTransferencia({super.key, this.contaInicial});

  /// Conta do filtro em Transações: vira a origem, se puder.
  final String? contaInicial;

  @override
  State<FormularioTransferencia> createState() =>
      _FormularioTransferenciaState();
}

class _FormularioTransferenciaState extends State<FormularioTransferencia> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();
  String? _origemEscolhida;
  String? _destino;
  var _data = somenteData(DateTime.now());

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  /// Só conta da lista vale: a do filtro pode ser cartão ou estar desativada.
  String? _origem(List<Conta> contas) {
    final id = _origemEscolhida ?? widget.contaInicial;
    return contas.any((c) => c.id == id) ? id : null;
  }

  void _inverter(List<Conta> contas) {
    final origem = _origem(contas);
    setState(() {
      _origemEscolhida = _destino;
      _destino = origem;
    });
  }

  @override
  Widget build(BuildContext context) {
    final estadoContas = context.watch<ContasCubit>().state;
    final contas = switch (estadoContas) {
      ContasCarregado(:final resumo) =>
        resumo.contas
            .where((c) => c.ativa && c.tipo != TipoConta.cartaoCredito)
            .toList(),
      _ => const <Conta>[],
    };
    final origem = _origem(contas);
    final destinos = contas.where((c) => c.id != origem).toList();
    final destino = destinos.any((c) => c.id == _destino) ? _destino : null;

    return BlocConsumer<TransferenciaCubit, TransferenciaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<TransferenciaCubit>();
        final livre = !estado.enviando;
        return EsqueletoLancamento(
          livre: livre,
          erroGeral: estado.erroGeral,
          campos: [
            _CampoConta(
              // initialValue só é lido na criação: a chave recria o campo
              // quando as contas carregam ou a escolha é invertida.
              key: ValueKey(('origem', estadoContas.runtimeType, origem)),
              rotulo: 'De',
              valor: origem,
              contas: contas,
              erro: estado.erros['origem'],
              aoMudar: livre
                  ? (id) {
                      setState(() => _origemEscolhida = id);
                      cubit.limparErro('origem');
                    }
                  : null,
            ),
            Center(
              child: IconButton.outlined(
                tooltip: 'Inverter origem e destino',
                icon: Icon(
                  Icons.swap_vert_rounded,
                  color: context.esquema.primary,
                ),
                onPressed: livre ? () => _inverter(contas) : null,
              ),
            ),
            _CampoConta(
              key: ValueKey(('destino', estadoContas.runtimeType, destino)),
              rotulo: 'Para',
              valor: destino,
              contas: destinos,
              erro: estado.erros['destino'],
              aoMudar: livre
                  ? (id) {
                      setState(() => _destino = id);
                      cubit.limparErro('destino');
                    }
                  : null,
            ),
            const SizedBox(height: Espaco.x6),
            CampoDinheiro(
              controller: _valor,
              rotulo: 'Valor',
              habilitado: livre,
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
            TextField(
              controller: _descricao,
              onChanged: (_) => cubit.limparErro('descricao'),
              enabled: livre,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição (opcional)',
                hintText: 'Transferência',
                errorText: estado.erros['descricao'],
                counterText: '',
              ),
            ),
            const SizedBox(height: Espaco.x6),
            const _AvisoTransferencia(),
          ],
          botao: FilledButton(
            onPressed: livre
                ? () => cubit.salvar(
                    origemId: origem,
                    destinoId: destino,
                    valor: _valor.text,
                    data: _data,
                    descricao: _descricao.text,
                  )
                : null,
            child: RotuloEnviando(enviando: estado.enviando, rotulo: 'Salvar'),
          ),
        );
      },
    );
  }
}

class _CampoConta extends StatelessWidget {
  const _CampoConta({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.contas,
    required this.erro,
    required this.aoMudar,
  });

  final String rotulo;
  final String? valor;
  final List<Conta> contas;
  final String? erro;
  final ValueChanged<String?>? aoMudar;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      hint: const Text('Selecione uma conta'),
      decoration: InputDecoration(labelText: rotulo, errorText: erro),
      items: [
        for (final conta in contas)
          DropdownMenuItem(
            value: conta.id,
            child: Text(
              conta.instituicao == null
                  ? conta.nome
                  : '${conta.nome} · ${conta.instituicao}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: aoMudar,
    );
  }
}

class _AvisoTransferencia extends StatelessWidget {
  const _AvisoTransferencia();

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
          Icon(Icons.sync_alt_rounded, color: esquema.primary),
          const SizedBox(width: Espaco.x3),
          Expanded(
            child: Text(
              'Entre contas próprias: não conta como gasto nem como renda. '
              'Para pagar cartão, use Pagamento de fatura.',
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
