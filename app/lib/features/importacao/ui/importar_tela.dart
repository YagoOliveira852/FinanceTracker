import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/lista.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../../revisao/cubit/revisao_cubit.dart';
import '../cubit/importar_cubit.dart';
import '../data/importacao.dart';
import 'textos.dart';

/// Rota da tela "Importar extrato" (por cima das abas).
const rotaImportar = '/importar';

/// Rota do resumo de uma importação.
String rotaResumoImportacao(String id) => '$rotaImportar/$id';

/// Argumentos da rota do resumo: a importação já carregada e se ela acabou
/// de ser feita (título, X e textos mudam).
typedef ArgsResumo = ({Importacao importacao, bool recemImportada});

/// "Importar extrato": arquivo, conta de destino e o histórico.
///
/// Aberta por Mais e pela Revisão (voltar), ou pelo Compartilhar de outro app
/// ([compartilhado]: o X volta ao Início).
class ImportarTela extends StatelessWidget {
  const ImportarTela({super.key, this.compartilhado = false});

  final bool compartilhado;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ImportarCubit, ImportarEstado>(
      listenWhen: (antes, depois) =>
          antes.importada == null && depois.importada != null,
      listener: (context, estado) {
        context.read<ImportarCubit>().resumoAberto();
        context.read<RevisaoCubit>().carregar();
        _abrirResumo(context, estado.importada!, recemImportada: true);
      },
      builder: (context, estado) {
        final cubit = context.read<ImportarCubit>();
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                leading: compartilhado
                    ? IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => context.go('/inicio'),
                      )
                    : null,
                title: const Text('Importar extrato'),
              ),
              body: RefreshIndicator(
                onRefresh: cubit.carregar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x4,
                    Espaco.x2,
                    Espaco.x4,
                    Espaco.x6,
                  ),
                  children: [
                    ..._avisos(context, estado),
                    TituloSecao('Arquivo', pequeno: true),
                    _CampoArquivo(estado: estado),
                    if (estado.linhasRepetidas.isNotEmpty) ...[
                      const SizedBox(height: Espaco.x2),
                      _LinhasRepetidas(estado.linhasRepetidas),
                    ],
                    if (estado.arquivo == null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Espaco.x4,
                          Espaco.x2,
                          Espaco.x4,
                          0,
                        ),
                        child: Text(
                          'Também dá para mandar o arquivo pelo Compartilhar '
                          'do app do banco ou do e-mail.',
                          style: context.textos.bodySmall?.copyWith(
                            color: context.esquema.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: Espaco.x6),
                    _CampoConta(estado: estado),
                    const SizedBox(height: Espaco.x6),
                    TituloSecao('Importações anteriores', pequeno: true),
                    _Historico(estado: estado),
                  ],
                ),
              ),
              bottomNavigationBar: RodapeFormulario(
                botao: FilledButton.icon(
                  onPressed: estado.podeImportar ? cubit.importar : null,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Importar'),
                ),
              ),
            ),
            if (estado.enviando) _Processando(arquivo: estado.arquivo),
          ],
        );
      },
    );
  }

  List<Widget> _avisos(BuildContext context, ImportarEstado estado) {
    final aviso = switch (estado) {
      ImportarEstado(:final jaImportada?) => _AvisoJaImportada(jaImportada),
      ImportarEstado(linhasRepetidas: [_, ...]) => Aviso.erro(
        context,
        avisoFitidRepetido(estado.linhasRepetidas.length),
      ),
      ImportarEstado(:final erros) when erros['arquivo'] != null =>
        _AvisoFormato(erros['arquivo']!),
      ImportarEstado(:final erroGeral?) => Aviso.erro(context, erroGeral),
      _ => null,
    };
    if (aviso == null) return const [];
    return [aviso, const SizedBox(height: Espaco.x4)];
  }
}

void _abrirResumo(
  BuildContext context,
  Importacao importacao, {
  required bool recemImportada,
}) {
  final cubit = context.read<ImportarCubit>();
  context
      .push<bool>(
        rotaResumoImportacao(importacao.id),
        extra: (importacao: importacao, recemImportada: recemImportada),
      )
      // Ao voltar: desfeita ou com confirmadas novas, o histórico muda.
      .then((_) => cubit.carregar());
}

class _CampoArquivo extends StatelessWidget {
  const _CampoArquivo({required this.estado});

  final ImportarEstado estado;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    final cubit = context.read<ImportarCubit>();
    final arquivo = estado.arquivo;
    final comErro =
        estado.erros['arquivo'] != null || estado.linhasRepetidas.isNotEmpty;

    if (arquivo == null) {
      return InkWell(
        onTap: estado.enviando ? null : cubit.escolherArquivo,
        borderRadius: BorderRadius.circular(Raio.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 136),
          padding: const EdgeInsets.symmetric(
            horizontal: Espaco.x6,
            vertical: Espaco.x5,
          ),
          decoration: BoxDecoration(
            color: esquema.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Raio.lg),
            border: Border.all(
              color: comErro ? esquema.error : esquema.outline,
              width: comErro ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded, size: 32, color: esquema.primary),
              const SizedBox(height: Espaco.x1),
              Text(
                'Escolher arquivo',
                style: textos.titleMedium?.copyWith(color: esquema.primary),
              ),
              const SizedBox(height: Espaco.x1),
              Text(
                'OFX do extrato ou da fatura, ou CSV do Mercado Pago',
                style: textos.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: esquema.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Raio.lg),
        border: Border.all(
          color: comErro ? esquema.error : esquema.outlineVariant,
          width: comErro ? 2 : 1,
        ),
      ),
      child: ItemLista(
        icone: Icons.description_rounded,
        titulo: arquivo.nome,
        subtitulo: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: descricaoDoArquivo(arquivo)),
              if (arquivo.compartilhado) ...[
                const TextSpan(text: ' · '),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(Icons.share_rounded, size: 14),
                ),
                const TextSpan(text: ' Recebido pelo Compartilhar'),
              ],
            ],
          ),
        ),
        direita: TextButton(
          onPressed: estado.enviando ? null : cubit.escolherArquivo,
          child: const Text('Trocar'),
        ),
      ),
    );
  }
}

class _CampoConta extends StatelessWidget {
  const _CampoConta({required this.estado});

  final ImportarEstado estado;

  @override
  Widget build(BuildContext context) {
    final estadoContas = context.watch<ContasCubit>().state;
    final contas = switch (estadoContas) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.ativa).toList(),
      _ => const <Conta>[],
    };
    final selecionada = contas.any((c) => c.id == estado.contaId)
        ? estado.contaId
        : null;
    final ajuda = switch (estadoContas) {
      ContasCarregando() => 'Carregando as contas…',
      ContasErro(:final mensagem) => mensagem,
      ContasCarregado() => ajudaDaConta(
        arquivo: estado.arquivo,
        contaSugerida: estado.contaSugerida,
      ),
    };

    return DropdownButtonFormField<String>(
      // initialValue só é lido na criação: a chave recria o campo quando as
      // contas carregam ou o app sugere outra conta.
      key: ValueKey((estadoContas.runtimeType, selecionada)),
      initialValue: selecionada,
      isExpanded: true,
      hint: const Text('Selecione uma conta'),
      decoration: InputDecoration(
        labelText: 'Conta de destino',
        errorText: estado.erros['conta_id'],
        helperText: ajuda,
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
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
      onChanged: estado.enviando
          ? null
          : (id) {
              if (id != null) context.read<ImportarCubit>().escolherConta(id);
            },
    );
  }
}

class _Historico extends StatelessWidget {
  const _Historico({required this.estado});

  final ImportarEstado estado;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final historico = estado.historico;
    if (historico == null) {
      return Padding(
        padding: const EdgeInsets.all(Espaco.x4),
        child: estado.erroHistorico == null
            ? const Center(child: CircularProgressIndicator())
            : Text(
                estado.erroHistorico!,
                style: context.textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
      );
    }
    if (historico.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(Espaco.x4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Raio.lg),
          border: Border.all(color: esquema.outlineVariant),
        ),
        child: Text(
          'Nenhum extrato importado ainda. Cada importação aparece aqui e pode '
          'ser desfeita enquanto nada dela foi confirmado.',
          style: context.textos.bodyMedium?.copyWith(
            color: esquema.onSurfaceVariant,
          ),
        ),
      );
    }
    return GrupoLista(
      itens: [
        for (final importacao in historico)
          ItemLista(
            icone: importacao.contaTipo == TipoConta.cartaoCredito
                ? Icons.credit_card_rounded
                : Icons.account_balance_rounded,
            titulo: importacao.nomeArquivo ?? 'Extrato',
            subtitulo: Text(subtituloDoHistorico(importacao)),
            direita: Text(
              plural(importacao.qtdNovas, 'nova', 'novas'),
              style: context.textos.labelLarge?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            aoTocar: () =>
                _abrirResumo(context, importacao, recemImportada: false),
          ),
      ],
    );
  }
}

class _AvisoJaImportada extends StatelessWidget {
  const _AvisoJaImportada(this.anterior);

  final Importacao anterior;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Aviso(
      icone: Icons.info_rounded,
      fundo: esquema.secondaryContainer,
      cor: esquema.onSecondaryContainer,
      texto: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            avisoJaImportada(anterior),
            style: context.textos.bodyMedium?.copyWith(
              color: esquema.onSecondaryContainer,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () =>
                _abrirResumo(context, anterior, recemImportada: false),
            child: const Text('Ver importação'),
          ),
        ],
      ),
    );
  }
}

class _AvisoFormato extends StatelessWidget {
  const _AvisoFormato(this.mensagem);

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    return Aviso(
      icone: Icons.error_rounded,
      fundo: cores.ritmoRiscoContainer,
      cor: cores.ritmoRisco,
      texto: Text(
        '$mensagem O app lê o OFX do extrato da conta ou da fatura do '
        'cartão e o CSV do extrato do Mercado Pago (baixado pelo site); PDF '
        'e outras planilhas não são lidos.',
        style: context.textos.bodyMedium?.copyWith(
          color: cores.ritmoRisco,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LinhasRepetidas extends StatelessWidget {
  const _LinhasRepetidas(this.linhas);

  final List<LinhaRepetida> linhas;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final textos = context.textos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GrupoLista(
          itens: [
            for (final linha in linhas)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Espaco.x4,
                  vertical: Espaco.x3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            linha.descricao,
                            style: textos.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(valorDaLinha(linha), style: textos.titleSmall),
                      ],
                    ),
                    Text(
                      '${formatarDiaMes(linha.data)} · '
                      'id ${fitidCurto(linha.fitid)}',
                      style: textos.bodySmall?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Espaco.x4,
            Espaco.x2,
            Espaco.x4,
            0,
          ),
          child: Text(
            'Baixe o extrato de novo no banco. Se o erro continuar, o leitor '
            'do arquivo precisa tratar esse caso.',
            style: textos.bodySmall?.copyWith(color: esquema.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Diálogo de progresso sem cancelar: a importação é uma chamada só.
class _Processando extends StatelessWidget {
  const _Processando({required this.arquivo});

  final ArquivoEscolhido? arquivo;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.x6),
            child: Material(
              color: esquema.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(Raio.xl),
              child: Padding(
                padding: const EdgeInsets.all(Espaco.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: Espaco.x4),
                    Text(
                      'Importando ${arquivo?.nome ?? 'o extrato'}',
                      style: context.textos.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Espaco.x4),
                    Text(
                      'Lendo o arquivo e conferindo o que já está no app. '
                      'Leva alguns segundos.',
                      style: context.textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
