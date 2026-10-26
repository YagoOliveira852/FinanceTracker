import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../cubit/editar_categoria_cubit.dart';
import '../data/categoria.dart';
import 'textos.dart';

/// Nova categoria ou Editar categoria: nome, grupo e, numa existente, quanto
/// ela é usada e desativar/reativar. Fecha devolvendo `true` quando salvou.
class EditarCategoriaTela extends StatefulWidget {
  const EditarCategoriaTela({super.key});

  @override
  State<EditarCategoriaTela> createState() => _EditarCategoriaTelaState();
}

class _EditarCategoriaTelaState extends State<EditarCategoriaTela> {
  late final Categoria? _existente = context
      .read<EditarCategoriaCubit>()
      .existente;
  late final _nome = TextEditingController(text: _existente?.nome ?? '');
  late GrupoCategoria? _grupo = _existente?.grupo;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existente = _existente;
    return BlocConsumer<EditarCategoriaCubit, EditarCategoriaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<EditarCategoriaCubit>();
        final livre = !estado.enviando;
        final esquema = context.esquema;
        final textos = context.textos;
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
              title: Text(
                existente == null ? 'Nova categoria' : 'Editar categoria',
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                TextField(
                  controller: _nome,
                  onChanged: (_) => cubit.limparErro('nome'),
                  enabled: livre,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    errorText: estado.erros['nome'],
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                Padding(
                  padding: const EdgeInsets.only(
                    left: Espaco.x1,
                    bottom: Espaco.x2,
                  ),
                  child: Text('Grupo', style: textos.bodySmall),
                ),
                Wrap(
                  spacing: Espaco.x2,
                  runSpacing: Espaco.x2,
                  children: [
                    for (final grupo in GrupoCategoria.values)
                      ChipOpcao(
                        rotulo: grupo.rotulo,
                        selecionado: _grupo == grupo,
                        aoTocar: livre
                            ? () {
                                setState(() => _grupo = grupo);
                                cubit.limparErro('grupo');
                              }
                            : null,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x1,
                    Espaco.x2,
                    Espaco.x1,
                    0,
                  ),
                  child: Text(
                    estado.erros['grupo'] ??
                        'Essencial e variável são gasto; renda e investimento '
                            'não entram no gasto do mês.',
                    style: textos.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: estado.erros.containsKey('grupo')
                          ? esquema.error
                          : null,
                    ),
                  ),
                ),
                if (existente != null) ...[
                  const SizedBox(height: Espaco.x6),
                  Aviso(
                    icone: Icons.info_outline_rounded,
                    corIcone: esquema.primary,
                    texto: Text(
                      textoDoUso(
                        regras: existente.qtdRegras,
                        transacoes: existente.qtdTransacoes,
                      ),
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                    fundo: esquema.surfaceContainer,
                    cor: esquema.onSurfaceVariant,
                  ),
                  const SizedBox(height: Espaco.x6),
                  if (existente.ativa) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: livre ? () => cubit.mudarAtivo(false) : null,
                        icon: const Icon(Icons.visibility_off_rounded),
                        label: const Text('Desativar categoria'),
                      ),
                    ),
                    const _Ajuda(
                      'Sai das opções da revisão e das regras novas; as '
                      'transações antigas continuam com ela.',
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: livre ? () => cubit.mudarAtivo(true) : null,
                        icon: const Icon(Icons.visibility_rounded),
                        label: const Text('Reativar categoria'),
                      ),
                    ),
                    const _Ajuda(
                      'Desativada: não aparece nas opções e as regras dela '
                      'não sugerem.',
                    ),
                  ],
                ],
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre
                    ? () => cubit.salvar(nome: _nome.text, grupo: _grupo)
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

class _Ajuda extends StatelessWidget {
  const _Ajuda(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espaco.x1, Espaco.x1, Espaco.x1, 0),
      child: Text(
        texto,
        style: context.textos.bodySmall?.copyWith(fontWeight: FontWeight.w400),
      ),
    );
  }
}
