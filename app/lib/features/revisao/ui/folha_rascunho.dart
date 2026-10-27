import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../core/formatacao/datas.dart';
import '../../categorias/cubit/categorias_cubit.dart';
import '../../categorias/data/categoria.dart';
import '../cubit/folha_rascunho_cubit.dart';
import '../cubit/revisao_cubit.dart';
import '../data/revisao.dart';
import '../data/revisao_repositorio.dart';
import 'item_rascunho.dart';
import 'textos.dart';

/// Abre a folha do rascunho sobre a lista. Ao confirmar ou ignorar, a folha
/// fecha e a lista recarrega com o aviso.
Future<void> abrirFolhaRascunho(BuildContext context, Rascunho rascunho) {
  final repositorio = context.read<RevisaoRepositorio>();
  final revisao = context.read<RevisaoCubit>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => FolhaRascunhoCubit(repositorio, rascunho),
      child: _FolhaRascunho(aoConcluir: revisao.concluiu),
    ),
  );
}

class _FolhaRascunho extends StatefulWidget {
  const _FolhaRascunho({required this.aoConcluir});

  final ValueChanged<String> aoConcluir;

  @override
  State<_FolhaRascunho> createState() => _FolhaRascunhoState();
}

class _FolhaRascunhoState extends State<_FolhaRascunho> {
  late final _descricao = TextEditingController(
    text: context.read<FolhaRascunhoCubit>().state.descricao,
  );

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FolhaRascunhoCubit>();
    final rascunho = cubit.rascunho;
    final item = rascunho.item;
    final textos = context.textos;
    final esquema = context.esquema;
    final categorias = switch (context.watch<CategoriasCubit>().state) {
      CategoriasCarregado(:final categorias) => categorias,
      _ => const <Categoria>[],
    };

    return BlocConsumer<FolhaRascunhoCubit, FolhaRascunhoEstado>(
      listenWhen: (antes, depois) =>
          antes.concluido == null && depois.concluido != null,
      listener: (context, estado) {
        Navigator.of(context).pop();
        widget.aoConcluir(estado.concluido!);
      },
      builder: (context, estado) {
        final tipos = FolhaRascunhoCubit.tiposPara(item);
        final opcoes = [
          for (final c in categorias)
            if (c.opcaoPara(estado.tipo)) c,
        ];
        final escolhida = categorias
            .where((c) => c.id == estado.categoriaId)
            .firstOrNull;
        final efeito = textoDoEfeito(
          rascunho,
          cubit.efeito,
          escolhida?.nome ?? '',
        );
        final dataTexto = [
          formatarDataLonga(item.data),
          if (item.faturaCompetencia case final c?)
            'entra na fatura de ${nomeDoMes(c)}',
        ].join(' · ');

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Espaco.x6,
              0,
              Espaco.x6,
              Espaco.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinhaDeOrigem(item),
                const SizedBox(height: Espaco.x1),
                Text(item.descricao, style: textos.headlineSmall),
                ValorNaRevisao(item, estilo: textos.headlineMedium),
                Text(
                  dataTexto,
                  style: textos.bodyMedium?.copyWith(
                    color: esquema.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Espaco.x4),
                _ComoVeio(item.descricaoOriginal),
                const SizedBox(height: Espaco.x4),
                TextField(
                  controller: _descricao,
                  enabled: !estado.enviando,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  onChanged: cubit.mudarDescricao,
                ),
                if (tipos.length > 1) ...[
                  const SizedBox(height: Espaco.x2),
                  Text('Tipo', style: textos.labelLarge),
                  const SizedBox(height: Espaco.x2),
                  Wrap(
                    spacing: Espaco.x2,
                    children: [
                      for (final tipo in tipos)
                        ChipOpcao(
                          rotulo: rotuloDoTipo(tipo),
                          selecionado: estado.tipo == tipo,
                          aoTocar: estado.enviando
                              ? null
                              : () => cubit.escolherTipo(tipo),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: Espaco.x2),
                Text('Categoria', style: textos.labelLarge),
                const SizedBox(height: Espaco.x2),
                Wrap(
                  spacing: Espaco.x2,
                  runSpacing: Espaco.x2,
                  children: [
                    for (final categoria in opcoes)
                      ChipOpcao(
                        rotulo: categoria.nome,
                        selecionado: estado.categoriaId == categoria.id,
                        aoTocar: estado.enviando
                            ? null
                            : () => cubit.escolherCategoria(categoria.id),
                      ),
                  ],
                ),
                if (efeito != null) ...[
                  const SizedBox(height: Espaco.x4),
                  Aviso(
                    icone: cubit.efeito == EfeitoRegra.manualMantida
                        ? Icons.lock_outline_rounded
                        : Icons.auto_awesome_rounded,
                    texto: Text(
                      efeito,
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onPrimaryContainer,
                      ),
                    ),
                    fundo: esquema.primaryContainer,
                    cor: esquema.onPrimaryContainer,
                  ),
                ],
                if (estado.erro case final erro?) ...[
                  const SizedBox(height: Espaco.x4),
                  Aviso.erro(context, erro),
                ],
                const SizedBox(height: Espaco.x6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: estado.enviando ? null : cubit.ignorar,
                        child: const Text('Ignorar'),
                      ),
                    ),
                    const SizedBox(width: Espaco.x3),
                    Expanded(
                      child: FilledButton(
                        onPressed: cubit.podeConfirmar ? cubit.confirmar : null,
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Como veio do banco": a descrição original, que nunca muda.
class _ComoVeio extends StatelessWidget {
  const _ComoVeio(this.descricaoOriginal);

  final String descricaoOriginal;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x3,
        vertical: Espaco.x2,
      ),
      decoration: BoxDecoration(
        color: esquema.surfaceContainer,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como veio do banco',
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
          Text(
            descricaoOriginal,
            style: textos.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: algarismosTabulares,
            ),
          ),
        ],
      ),
    );
  }
}
