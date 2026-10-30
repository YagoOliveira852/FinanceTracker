import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/dinheiro.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/cubit/validacao_cartao.dart';
import '../../contas/data/conta.dart';
import '../../contas/ui/opcao_conta.dart';
import '../cubit/editar_renda_cubit.dart';
import '../data/planejamento.dart';
import 'textos.dart';

/// Nova renda ([existente] nulo) e Editar renda, que também desativa e
/// reativa. Fecha com `true` quando salvou.
class EditarRendaTela extends StatefulWidget {
  const EditarRendaTela({super.key, this.existente});

  final Renda? existente;

  @override
  State<EditarRendaTela> createState() => _EditarRendaTelaState();
}

class _EditarRendaTelaState extends State<EditarRendaTela> {
  late final _descricao = TextEditingController(
    text: widget.existente?.descricao ?? '',
  );
  late final _valor = TextEditingController(
    text: switch (widget.existente) {
      final renda? => dinheiroParaCampo(renda.valor),
      null => '',
    },
  );
  late final _dia = TextEditingController(
    text: switch (widget.existente) {
      final renda? => '${renda.diaPrevisto}',
      null => '',
    },
  );
  late String? _conta = widget.existente?.contaId;
  late bool _ativa = widget.existente?.ativa ?? true;

  @override
  void dispose() {
    _descricao.dispose();
    _valor.dispose();
    _dia.dispose();
    super.dispose();
  }

  void _salvar() {
    context.read<EditarRendaCubit>().salvar(
      descricao: _descricao.text,
      valor: _valor.text,
      dia: _dia.text,
      contaId: _conta,
      ativa: _ativa,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nova = widget.existente == null;
    // Corrente e carteira ativas; a conta atual fica na lista mesmo se foi
    // desativada, para a renda inativa continuar editável.
    final contas = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) =>
        resumo.contas
            .where(
              (c) =>
                  c.tipo != TipoConta.cartaoCredito &&
                  (c.ativa || c.id == widget.existente?.contaId),
            )
            .toList(),
      _ => const <Conta>[],
    };

    return BlocConsumer<EditarRendaCubit, EditarRendaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => Navigator.of(context).pop(true),
      builder: (context, estado) {
        final cubit = context.read<EditarRendaCubit>();
        final livre = !estado.enviando;
        final previa = estado.previa;
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
              title: Text(nova ? 'Nova renda' : 'Editar renda'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                TextField(
                  controller: _descricao,
                  onChanged: (_) => cubit.limparErro('descricao'),
                  enabled: livre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Ex.: Salário',
                    errorText: estado.erros['descricao'],
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                CampoDinheiro(
                  controller: _valor,
                  aoMudar: (_) => cubit.limparErro('valor'),
                  rotulo: 'Valor',
                  ajuda:
                      'O valor líquido que cai na conta. O app reconhece o '
                      'crédito quando chega um valor próximo deste.',
                  habilitado: livre,
                  erro: estado.erros['valor'],
                ),
                const SizedBox(height: Espaco.x6),
                CampoDiaDoMes(
                  controller: _dia,
                  rotulo: 'Dia previsto',
                  ajuda:
                      'Fim de semana ou feriado passa para o próximo dia '
                      'útil. Dia 29 a 31 em mês mais curto vira o último dia '
                      'do mês.',
                  erro: estado.erros['dia_previsto'],
                  habilitado: livre,
                  aoMudar: () {
                    cubit.limparErro('dia_previsto');
                    cubit.atualizarPrevia(_dia.text);
                  },
                ),
                if (previa != null) ...[
                  const SizedBox(height: Espaco.x2),
                  _ProximaData(
                    previa,
                    diaPrevisto:
                        lerDiaDoMes(_dia.text) ?? previa.dataPrevista.day,
                  ),
                ],
                const SizedBox(height: Espaco.x6),
                CampoSelecao<String>(
                  rotulo: 'Conta onde cai',
                  valor: _conta,
                  vazio: 'Escolha a conta',
                  ajuda:
                      'A conta onde o crédito aparece primeiro. Se você '
                      'transfere para outra, é a de origem.',
                  erro: estado.erros['conta_id'],
                  opcoes: [for (final conta in contas) opcaoDeConta(conta)],
                  aoMudar: livre
                      ? (id) {
                          setState(() => _conta = id);
                          cubit.limparErro('conta_id');
                        }
                      : null,
                ),
                if (!nova) ...[
                  const SizedBox(height: Espaco.x6),
                  const Divider(height: 1),
                  const SizedBox(height: Espaco.x2),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _ativa,
                    onChanged: livre
                        ? (ativa) => setState(() => _ativa = ativa)
                        : null,
                    title: const Text('Renda ativa'),
                    subtitle: const Text(
                      'Desativada, não entra no aporte, no alerta nem no '
                      'lembrete. Dá para reativar depois.',
                    ),
                  ),
                ],
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre ? _salvar : null,
                child: RotuloEnviando(
                  enviando: estado.enviando,
                  rotulo: nova ? 'Salvar renda' : 'Salvar',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "Próxima data: segunda, 16 nov (dia 15 é domingo e feriado)".
class _ProximaData extends StatelessWidget {
  const _ProximaData(this.previa, {required this.diaPrevisto});

  final ProximaData previa;
  final int diaPrevisto;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Espaco.x3,
          vertical: Espaco.x2,
        ),
        decoration: BoxDecoration(
          color: esquema.primaryContainer,
          borderRadius: BorderRadius.circular(Raio.md),
        ),
        child: Row(
          children: [
            Icon(
              Icons.event_rounded,
              size: 20,
              color: esquema.onPrimaryContainer,
            ),
            const SizedBox(width: Espaco.x2),
            Expanded(
              child: Text(
                'Próxima data: '
                '${descreverProxima(previa, diaPrevisto: diaPrevisto)}',
                style: context.textos.bodyMedium?.copyWith(
                  color: esquema.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
