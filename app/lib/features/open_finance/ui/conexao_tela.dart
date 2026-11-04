import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../cubit/conexao_cubit.dart';
import '../data/open_finance.dart';
import 'textos.dart';

/// Adicionar conexão ([conexao] nula) ou Renovar a [conexao]: o ID do item e,
/// depois do "Continuar", o vínculo de cada conta. Fecha com `true` quando
/// salvou.
class ConexaoTela extends StatefulWidget {
  const ConexaoTela({super.key, this.conexao});

  final Conexao? conexao;

  @override
  State<ConexaoTela> createState() => _ConexaoTelaState();
}

class _ConexaoTelaState extends State<ConexaoTela> {
  final _item = TextEditingController();

  @override
  void dispose() {
    _item.dispose();
    super.dispose();
  }

  bool get _renovando => widget.conexao != null;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConexaoCubit, ConexaoEstado>(
      listenWhen: (antes, depois) => !antes.salvo && depois.salvo,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final vinculando = estado.vinculando && estado.previa != null;
        return PopScope(
          canPop: !vinculando,
          onPopInvokedWithResult: (saiu, _) {
            if (!saiu) context.read<ConexaoCubit>().voltar();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: vinculando ? 'Voltar' : 'Fechar',
                icon: Icon(
                  vinculando ? Icons.arrow_back_rounded : Icons.close_rounded,
                ),
                onPressed: vinculando
                    ? context.read<ConexaoCubit>().voltar
                    : () => context.pop(),
              ),
              title: Text(
                vinculando
                    ? 'Vincular contas'
                    : _renovando
                    ? 'Renovar conexão'
                    : 'Adicionar conexão',
              ),
            ),
            body: vinculando
                ? _Vinculos(estado: estado, renovando: _renovando)
                : _Item(
                    controller: _item,
                    estado: estado,
                    conexao: widget.conexao,
                  ),
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.controller,
    required this.estado,
    required this.conexao,
  });

  final TextEditingController controller;
  final ConexaoEstado estado;
  final Conexao? conexao;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    final cubit = context.read<ConexaoCubit>();
    final previa = estado.previa;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Espaco.x4),
            children: [
              Text(
                conexao == null
                    ? 'Cole o ID do item do Meu Pluggy. O app só lê os dados: '
                          'nada é movimentado no banco.'
                    : 'O consentimento vale 1 ano. Renove no Meu Pluggy e '
                          'cole aqui o ID do item: ele pode ter mudado. As '
                          'contas continuam as mesmas, com o histórico.',
                style: textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaco.x6),
              TextField(
                controller: controller,
                enabled: !estado.verificando,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: cubit.verificar,
                decoration: InputDecoration(
                  labelText: 'ID da conexão (itemId)',
                  helperText: ondeAcharOItem,
                  helperMaxLines: 3,
                  errorText: estado.erroItem,
                  errorMaxLines: 3,
                ),
              ),
              if (previa != null) ...[
                const SizedBox(height: Espaco.x4),
                Aviso(
                  icone: Icons.check_circle_rounded,
                  fundo: esquema.primaryContainer,
                  cor: esquema.onPrimaryContainer,
                  texto: Text(
                    '${previa.instituicao} encontrado\n'
                    '${_contas(previa.contas.length)}'
                    '${previa.consentimentoExpiraEm == null ? '' : ' · consentimento até ${formatarDiaMesAno(previa.consentimentoExpiraEm!)}'}',
                    style: textos.bodyMedium?.copyWith(
                      color: esquema.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _Rodape(
          child: previa == null
              ? FilledButton(
                  onPressed: estado.verificando
                      ? null
                      : () => cubit.verificar(controller.text),
                  child: Text(
                    estado.verificando ? 'Verificando…' : 'Verificar',
                  ),
                )
              : FilledButton(
                  onPressed: previa.contas.isEmpty ? null : cubit.continuar,
                  child: const Text('Continuar'),
                ),
        ),
      ],
    );
  }
}

String _contas(int n) =>
    n == 1 ? '1 conta compartilhada' : '$n contas compartilhadas';

class _Vinculos extends StatelessWidget {
  const _Vinculos({required this.estado, required this.renovando});

  final ConexaoEstado estado;
  final bool renovando;

  @override
  Widget build(BuildContext context) {
    final previa = estado.previa!;
    final textos = context.textos;
    final esquema = context.esquema;
    final contasDoApp = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) => [
        for (final conta in resumo.contas)
          if (conta.ativa) conta,
      ],
      _ => const <Conta>[],
    };
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Espaco.x4),
            children: [
              Text(
                renovando
                    ? 'Confirme as contas do item renovado: o histórico continua '
                          'nelas.'
                    : '${previa.instituicao} compartilhou '
                          '${previa.contas.length == 1 ? '1 conta' : '${previa.contas.length} contas'}. '
                          'Cada uma vira uma conta nova ou passa a alimentar uma '
                          'que você já tem.',
                style: textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaco.x4),
              for (final conta in previa.contas) ...[
                _ContaPluggy(
                  conta: conta,
                  escolha: estado.escolhas[conta.pluggyAccountId],
                  opcoes: [
                    for (final c in contasDoApp)
                      if (c.tipo == conta.tipo) c,
                  ],
                ),
                const SizedBox(height: Espaco.x3),
              ],
              if (estado.erro case final erro?) Aviso.erro(context, erro),
            ],
          ),
        ),
        _Rodape(
          child: FilledButton(
            onPressed: estado.salvando
                ? null
                : context.read<ConexaoCubit>().salvar,
            child: Text(
              estado.salvando
                  ? 'Salvando…'
                  : renovando
                  ? 'Renovar conexão'
                  : 'Salvar vínculos',
            ),
          ),
        ),
      ],
    );
  }
}

class _ContaPluggy extends StatelessWidget {
  const _ContaPluggy({
    required this.conta,
    required this.escolha,
    required this.opcoes,
  });

  final ContaDaPrevia conta;
  final Escolha? escolha;
  final List<Conta> opcoes;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    final cubit = context.read<ConexaoCubit>();
    final vinculada = switch (escolha) {
      EscolhaVincular(:final contaId) => contaId,
      _ => null,
    };
    final criando = escolha is EscolhaCriar;
    final tipo = conta.tipo == TipoConta.cartaoCredito
        ? 'Cartão de crédito'
        : 'Conta corrente';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conta.nome, style: textos.titleMedium),
            Text(
              '$tipo${conta.numeroFinal == null ? '' : ' · final ${conta.numeroFinal}'}',
              style: textos.bodySmall?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaco.x2),
            RadioGroup<bool>(
              groupValue: escolha == null ? null : criando,
              onChanged: (criar) {
                if (criar == true) {
                  cubit.escolher(conta.pluggyAccountId, const Escolha.criar());
                } else if (opcoes.isNotEmpty) {
                  cubit.escolher(
                    conta.pluggyAccountId,
                    Escolha.vincular(vinculada ?? opcoes.first.id),
                  );
                }
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    enabled: conta.podeCriar,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Criar nova conta'),
                    subtitle: Text(
                      conta.podeCriar
                          ? conta.nome
                          : 'A Pluggy não informa o fechamento deste cartão.',
                    ),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    enabled: opcoes.isNotEmpty,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vincular a uma existente'),
                    subtitle: const Text(
                      'Para não duplicar uma conta que você já usa com extrato.',
                    ),
                  ),
                ],
              ),
            ),
            if (!criando && opcoes.isNotEmpty) ...[
              const SizedBox(height: Espaco.x2),
              DropdownButtonFormField<String>(
                initialValue: vinculada,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Conta do app'),
                items: [
                  for (final opcao in opcoes)
                    DropdownMenuItem(value: opcao.id, child: Text(opcao.nome)),
                ],
                onChanged: (id) {
                  if (id != null) {
                    cubit.escolher(conta.pluggyAccountId, Escolha.vincular(id));
                  }
                },
              ),
            ],
            if (conta.sugestao case final sugestao?
                when conta.numeroFinal != null) ...[
              const SizedBox(height: Espaco.x2),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: esquema.primary,
                  ),
                  const SizedBox(width: Espaco.x1),
                  Expanded(
                    child: Text(
                      'Sugestão: ${sugestao.nome} (mesmo final ${conta.numeroFinal})',
                      style: textos.bodySmall?.copyWith(color: esquema.primary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          Espaco.x4,
          Espaco.x4,
          Espaco.x4,
          Espaco.x6,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.esquema.outlineVariant),
          ),
        ),
        child: child,
      ),
    );
  }
}
