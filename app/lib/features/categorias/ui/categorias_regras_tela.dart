import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../../../app/widgets/lista.dart';
import '../cubit/categorias_cubit.dart';
import '../cubit/regras_cubit.dart';
import '../data/categoria.dart';
import '../data/regra.dart';
import 'textos.dart';

/// Rota da tela Nova categoria; devolve `true` quando criou.
const rotaNovaCategoria = '/mais/categorias/nova';

/// Rota do Editar categoria; recebe a [Categoria] em `extra` e devolve
/// `true` quando salvou.
String rotaEditarCategoria(String id) => '/mais/categorias/$id/editar';

/// Rota da tela Nova regra; devolve o aviso para a lista quando salvou.
const rotaNovaRegra = '/mais/categorias/regras/nova';

/// Rota do Editar regra; recebe a [Regra] em `extra` e devolve o aviso para
/// a lista quando salvou ou excluiu.
String rotaEditarRegra(String id) => '/mais/categorias/regras/$id/editar';

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

  /// Depois de salvar ou excluir, mostra o aviso e recarrega as regras e as
  /// categorias (a contagem de regras muda).
  Future<void> _abrirRegra(BuildContext context, [Regra? r]) async {
    final aviso = await context.push<String>(
      r == null ? rotaNovaRegra : rotaEditarRegra(r.id),
      extra: r,
    );
    if (aviso == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    await Future.wait([
      context.read<RegrasCubit>().carregar(),
      context.read<CategoriasCubit>().carregar(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final carregado = _abas.index == 0
        ? context.watch<CategoriasCubit>().state is CategoriasCarregado
        : context.watch<RegrasCubit>().state is RegrasCarregado;
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
      floatingActionButton: !carregado
          ? null
          : _abas.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _abrirCategoria(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova categoria'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _abrirRegra(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nova regra'),
            ),
      body: TabBarView(
        controller: _abas,
        children: [
          _AbaCategorias(aoTocar: (c) => _abrirCategoria(context, c)),
          _AbaRegras(aoTocar: (r) => _abrirRegra(context, r)),
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

/// Regras manuais e aprendidas, com a explicação da ordem.
class _AbaRegras extends StatelessWidget {
  const _AbaRegras({required this.aoTocar});

  final ValueChanged<Regra> aoTocar;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RegrasCubit>();
    return switch (context.watch<RegrasCubit>().state) {
      RegrasCarregando() => const Carregando(),
      RegrasErro(:final mensagem) => ErroComTentar(
        mensagem: mensagem,
        aoTentar: cubit.carregar,
      ),
      RegrasCarregado(:final regras) when regras.isEmpty => const EstadoVazio(
        icone: Icons.rule_rounded,
        titulo: 'Nenhuma regra ainda',
        texto:
            'Elas nascem quando você confirma a categoria de um rascunho na '
            'revisão. Também dá para criar uma aqui.',
      ),
      RegrasCarregado(:final regras) => RefreshIndicator(
        onRefresh: cubit.carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x4,
            Espaco.x4,
            96,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espaco.x1),
              child: Text(
                'Regras sugerem a categoria dos rascunhos; a revisão sempre '
                'confirma. Vale a regra cujo padrão aparece na descrição; '
                'empate: manual, depois a de uma conta só, depois o padrão '
                'mais longo.',
                style: context.textos.bodyMedium?.copyWith(
                  color: context.esquema.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: Espaco.x2),
            for (final (titulo, origem) in [
              ('Manuais', OrigemRegra.manual),
              ('Aprendidas na revisão', OrigemRegra.aprendida),
            ])
              if (regras.where((r) => r.origem == origem).toList()
                  case final daOrigem when daOrigem.isNotEmpty) ...[
                TituloSecao(titulo, pequeno: true),
                GrupoLista(
                  itens: [
                    for (final regra in daOrigem)
                      _LinhaRegra(regra, aoTocar: () => aoTocar(regra)),
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

/// "“posto”", a categoria e "Só Cartão Exemplo" (manual) ou
/// "Usada N vezes" (aprendida).
class _LinhaRegra extends StatelessWidget {
  const _LinhaRegra(this.regra, {required this.aoTocar});

  final Regra regra;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final detalhe = switch (regra.origem) {
      OrigemRegra.manual => switch (regra.contaNome) {
        final conta? => 'Só $conta',
        null => 'Todas as contas',
      },
      OrigemRegra.aprendida => textoDoUsoDaRegra(regra.vezesAplicada),
    };
    return InkWell(
      onTap: aoTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x3,
            Espaco.x2,
            Espaco.x3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '“${regra.padrao}”',
                      style: textos.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: esquema.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            regra.categoriaNome,
                            style: textos.labelMedium?.copyWith(
                              color: esquema.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: Espaco.x2),
                        Flexible(
                          child: Text(
                            detalhe,
                            style: textos.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
