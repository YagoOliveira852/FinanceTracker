import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../cubit/categorias_cubit.dart';
import '../data/categoria.dart';
import 'textos.dart';

/// Rota da tela Nova categoria; devolve `true` quando criou.
const rotaNovaCategoria = '/mais/categorias/nova';

/// Rota do Editar categoria; recebe a [Categoria] em `extra` e devolve
/// `true` quando salvou.
String rotaEditarCategoria(String id) => '/mais/categorias/$id/editar';

/// Mais → Categorias e regras: duas abas, Categorias (por grupo) e Regras.
class CategoriasRegrasTela extends StatefulWidget {
  const CategoriasRegrasTela({super.key});

  @override
  State<CategoriasRegrasTela> createState() => _CategoriasRegrasTelaState();
}

class _CategoriasRegrasTelaState extends State<CategoriasRegrasTela>
    with SingleTickerProviderStateMixin {
  // O botão flutuante muda com a aba ("Nova categoria" / "Nova regra").
  late final _abas = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _abrirCategoria(BuildContext context, [Categoria? c]) async {
    final salvou = await context.push<bool>(
      c == null ? rotaNovaCategoria : rotaEditarCategoria(c.id),
      extra: c,
    );
    if (salvou == true && context.mounted) {
      await context.read<CategoriasCubit>().carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final carregado =
        context.watch<CategoriasCubit>().state is CategoriasCarregado;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: Espaco.x1,
        title: const Text('Categorias e regras'),
        bottom: TabBar(
          controller: _abas,
          tabs: const [
            Tab(text: 'Categorias'),
            Tab(text: 'Regras'),
          ],
        ),
      ),
      floatingActionButton: _abas.index == 0 && carregado
          ? FloatingActionButton.extended(
              onPressed: () => _abrirCategoria(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova categoria'),
            )
          : null,
      body: TabBarView(
        controller: _abas,
        children: [
          _AbaCategorias(aoTocar: (c) => _abrirCategoria(context, c)),
          const EstadoVazio(
            icone: Icons.rule_rounded,
            titulo: 'Regras em breve',
            texto:
                'As regras sugerem a categoria dos rascunhos; a revisão '
                'sempre confirma.',
          ),
        ],
      ),
    );
  }
}

/// Categorias por grupo, com quantas regras cada uma tem.
class _AbaCategorias extends StatelessWidget {
  const _AbaCategorias({required this.aoTocar});

  final ValueChanged<Categoria> aoTocar;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CategoriasCubit>();
    return switch (context.watch<CategoriasCubit>().state) {
      CategoriasCarregando() => const Carregando(),
      CategoriasErro(:final mensagem) => ErroComTentar(
        mensagem: mensagem,
        aoTentar: cubit.carregar,
      ),
      CategoriasCarregado(:final categorias) => RefreshIndicator(
        onRefresh: cubit.carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x2,
            Espaco.x4,
            96,
          ),
          children: [
            for (final grupo in GrupoCategoria.values)
              if (categorias.where((c) => c.grupo == grupo).toList()
                  case final doGrupo when doGrupo.isNotEmpty) ...[
                TituloSecao(grupo.rotulo, pequeno: true),
                GrupoLista(
                  itens: [
                    for (final categoria in doGrupo)
                      _LinhaCategoria(
                        categoria,
                        aoTocar: () => aoTocar(categoria),
                      ),
                  ],
                ),
                const SizedBox(height: Espaco.x2),
              ],
          ],
        ),
      ),
    };
  }
}

/// "Mercado · 4 regras ›"; desativada, em cinza e com "Desativada".
class _LinhaCategoria extends StatelessWidget {
  const _LinhaCategoria(this.categoria, {required this.aoTocar});

  final Categoria categoria;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return InkWell(
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x2,
            Espaco.x2,
            Espaco.x2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  categoria.nome,
                  style: textos.bodyLarge?.copyWith(
                    color: categoria.ativa ? null : esquema.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Espaco.x3),
              Text(
                categoria.ativa
                    ? textoDasRegras(categoria.qtdRegras)
                    : 'Desativada',
                style: textos.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: esquema.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
