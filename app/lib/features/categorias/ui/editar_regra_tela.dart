import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../cubit/categorias_cubit.dart';
import '../cubit/editar_regra_cubit.dart';
import '../data/regra.dart';
import 'textos.dart';

/// Nova regra ou Editar regra: padrão, categoria e conta; numa existente,
/// quantos rascunhos ela sugere agora, a origem e Excluir. Fecha devolvendo
/// o aviso para a lista ("Regra salva; …" ou "Regra excluída.").
class EditarRegraTela extends StatefulWidget {
  const EditarRegraTela({super.key});

  @override
  State<EditarRegraTela> createState() => _EditarRegraTelaState();
}

class _EditarRegraTelaState extends State<EditarRegraTela> {
  late final Regra? _existente = context.read<EditarRegraCubit>().existente;
  late final _padrao = TextEditingController(text: _existente?.padrao ?? '');
  late String? _categoriaId = _existente?.categoriaId;
  late String? _contaId = _existente?.contaId;

  @override
  void dispose() {
    _padrao.dispose();
    super.dispose();
  }

  Future<void> _excluir() async {
    final cubit = context.read<EditarRegraCubit>();
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir a regra de “${_existente!.padrao}”?'),
        content: const Text(
          'Os rascunhos deixam de receber a sugestão dela; as transações já '
          'classificadas não mudam.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.esquema.error,
              foregroundColor: context.esquema.onError,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmou == true) await cubit.excluir();
  }

  @override
  Widget build(BuildContext context) {
    final existente = _existente;
    // Opções: as ativas e, numa regra antiga, a categoria ou a conta que ela
    // já tem, mesmo desativada (senão o campo ficaria vazio).
    final categorias = switch (context.watch<CategoriasCubit>().state) {
      CategoriasCarregado(:final categorias) =>
        categorias
            .where((c) => c.ativa || c.id == existente?.categoriaId)
            .map((c) => (id: c.id, nome: c.nome))
            .toList(),
      _ => const <({String id, String nome})>[],
    };
    final contas = switch (context.watch<ContasCubit>().state) {
      ContasCarregado(:final resumo) => [
        for (final c in resumo.contas)
          if (c.ativa || c.id == existente?.contaId) (id: c.id, nome: c.nome),
      ],
      _ => [
        if (existente?.contaId case final id?)
          (id: id, nome: existente!.contaNome ?? ''),
      ],
    };

    return BlocConsumer<EditarRegraCubit, EditarRegraEstado>(
      listenWhen: (antes, depois) =>
          (antes.salva == null && depois.salva != null) ||
          (!antes.excluida && depois.excluida),
      listener: (context, estado) => context.pop(switch (estado.salva) {
        final salva? => textoRegraSalva(salva.rascunhos),
        null => 'Regra excluída.',
      }),
      builder: (context, estado) {
        final cubit = context.read<EditarRegraCubit>();
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
              title: Text(existente == null ? 'Nova regra' : 'Editar regra'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                TextField(
                  controller: _padrao,
                  onChanged: (_) => cubit.limparErro('padrao'),
                  enabled: livre,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: 'Padrão',
                    helperText:
                        'Procurado na descrição do banco, sem acentos, '
                        'números, datas e termos como “pix enviado”.',
                    helperMaxLines: 3,
                    errorText: estado.erros['padrao'],
                    errorMaxLines: 3,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                DropdownButtonFormField<String>(
                  key: ValueKey(('categoria', categorias.length)),
                  initialValue: categorias.any((c) => c.id == _categoriaId)
                      ? _categoriaId
                      : null,
                  isExpanded: true,
                  hint: const Text('Escolha a categoria'),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    errorText: estado.erros['categoria_id'],
                  ),
                  items: [
                    for (final c in categorias)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nome, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: livre
                      ? (id) {
                          setState(() => _categoriaId = id);
                          cubit.limparErro('categoria_id');
                        }
                      : null,
                ),
                const SizedBox(height: Espaco.x6),
                DropdownButtonFormField<String?>(
                  key: ValueKey(('conta', contas.length)),
                  initialValue: contas.any((c) => c.id == _contaId)
                      ? _contaId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Conta',
                    helperText:
                        'Restrinja quando a mesma descrição quer dizer coisas '
                        'diferentes em cada conta.',
                    helperMaxLines: 3,
                    errorText: estado.erros['conta_id'],
                  ),
                  items: [
                    const DropdownMenuItem(child: Text('Todas as contas')),
                    for (final c in contas)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(c.nome, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: livre
                      ? (id) {
                          setState(() => _contaId = id);
                          cubit.limparErro('conta_id');
                        }
                      : null,
                ),
                if (existente != null) ...[
                  if (_textoDosRascunhos(estado) case final texto?) ...[
                    const SizedBox(height: Espaco.x6),
                    Aviso(
                      icone: Icons.auto_awesome_rounded,
                      texto: Text(
                        texto,
                        style: context.textos.bodyMedium?.copyWith(
                          color: esquema.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      fundo: esquema.primaryContainer,
                      cor: esquema.onPrimaryContainer,
                    ),
                  ],
                  if (existente.origem == OrigemRegra.aprendida) ...[
                    const SizedBox(height: Espaco.x4),
                    Aviso(
                      icone: Icons.history_rounded,
                      corIcone: esquema.primary,
                      texto: Text(
                        'Aprendida na revisão em '
                        '${formatarDiaMes(existente.criadoEm)}, '
                        '${textoDoUsoDaRegra(existente.vezesAplicada).toLowerCase()}. '
                        'Salvar uma mudança a torna manual.',
                        style: context.textos.bodyMedium?.copyWith(
                          color: esquema.onSurfaceVariant,
                        ),
                      ),
                      fundo: esquema.surfaceContainer,
                      cor: esquema.onSurfaceVariant,
                    ),
                  ],
                ],
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: Row(
                children: [
                  if (existente != null) ...[
                    TextButton.icon(
                      onPressed: livre ? _excluir : null,
                      style: TextButton.styleFrom(
                        foregroundColor: esquema.error,
                      ),
                      icon: const Icon(Icons.delete_rounded),
                      label: const Text('Excluir'),
                    ),
                    const SizedBox(width: Espaco.x3),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: livre
                          ? () => cubit.salvar(
                              padrao: _padrao.text,
                              categoriaId: _categoriaId,
                              contaId: _contaId,
                            )
                          : null,
                      child: RotuloEnviando(
                        enviando: estado.enviando,
                        rotulo: 'Salvar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// "Casa com 1 rascunho agora: …"; enquanto carrega, nada; se falhou, a
  /// mensagem do erro.
  static String? _textoDosRascunhos(EditarRegraEstado estado) {
    if (estado.erroDetalhe case final erro?) {
      return 'Não deu para contar os rascunhos: $erro';
    }
    final detalhe = estado.detalhe;
    if (detalhe == null) return null;
    final exemplo = switch (detalhe.exemplo) {
      final e? => '${e.descricao}, ${formatarDiaMes(e.data)}',
      null => null,
    };
    return textoDosRascunhos(detalhe.rascunhos, exemplo: exemplo);
  }
}
