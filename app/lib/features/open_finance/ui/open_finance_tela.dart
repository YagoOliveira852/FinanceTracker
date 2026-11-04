import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/estados.dart';
import '../cubit/open_finance_cubit.dart';
import '../data/open_finance.dart';
import 'textos.dart';

/// Rota da tela Open Finance (Mais → Open Finance).
const rotaOpenFinance = '/mais/open-finance';

/// Rota de Adicionar conexão; devolve `true` quando salvou.
const rotaAdicionarConexao = '/mais/open-finance/adicionar';

/// Rota da renovação; recebe a [Conexao] em `extra` e devolve `true` quando
/// salvou.
String rotaRenovarConexao(String id) => '/mais/open-finance/$id/renovar';

/// Mais → Open Finance: as conexões da Pluggy e o estado do sync. Design:
/// página "Open Finance" do canvas.
class OpenFinanceTela extends StatelessWidget {
  const OpenFinanceTela({super.key, this.agora});

  /// Para os testes; o padrão é o relógio do aparelho.
  final DateTime Function()? agora;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Open Finance')),
      body: BlocConsumer<OpenFinanceCubit, OpenFinanceEstado>(
        listenWhen: (_, depois) =>
            depois is OpenFinanceCarregado && depois.aviso != null,
        listener: (context, estado) {
          if (estado case OpenFinanceCarregado(:final aviso?)) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(aviso)));
            context.read<OpenFinanceCubit>().avisoMostrado();
          }
        },
        builder: (context, estado) => switch (estado) {
          OpenFinanceCarregando() => const Carregando(),
          OpenFinanceErro(:final mensagem) => ErroComTentar(
            mensagem: mensagem,
            aoTentar: context.read<OpenFinanceCubit>().carregar,
          ),
          OpenFinanceCarregado(:final lista, :final ocupada) => _Conteudo(
            lista: lista,
            ocupada: ocupada,
            agora: (agora ?? DateTime.now)(),
          ),
        },
      ),
    );
  }
}

/// Abre um formulário e recarrega a lista se ele salvou.
Future<void> _abrir(BuildContext context, String rota, {Object? extra}) async {
  final cubit = context.read<OpenFinanceCubit>();
  final salvou = await context.push<bool>(rota, extra: extra);
  if (salvou == true) await cubit.carregar();
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({
    required this.lista,
    required this.ocupada,
    required this.agora,
  });

  final ListaConexoes lista;
  final String? ocupada;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    return RefreshIndicator(
      onRefresh: context.read<OpenFinanceCubit>().carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espaco.x4,
          Espaco.x2,
          Espaco.x4,
          Espaco.x6,
        ),
        children: [
          Text(
            'A Pluggy atualiza os dados uma vez por dia. O app lê às 07:00 e, '
            'se falhar, tenta de novo às 13:00.',
            style: textos.bodyMedium?.copyWith(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: Espaco.x4),
          if (lista.conexoes.isNotEmpty) ...[
            Text(
              'Conexões',
              style: textos.labelMedium?.copyWith(
                color: esquema.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Espaco.x2),
          ],
          for (final conexao in lista.conexoes) ...[
            _CardConexao(conexao, ocupada: ocupada == conexao.id, agora: agora),
            const SizedBox(height: Espaco.x3),
          ],
          if (lista.conexoes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Espaco.x4),
              child: Text(
                'Nenhuma conexão ainda. Com o ID do item do Meu Pluggy, as '
                'transações do banco chegam sozinhas, como rascunho na Revisão.',
                style: textos.bodyMedium,
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _abrir(context, rotaAdicionarConexao),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar conexão'),
          ),
        ],
      ),
    );
  }
}

class _CardConexao extends StatelessWidget {
  const _CardConexao(
    this.conexao, {
    required this.ocupada,
    required this.agora,
  });

  final Conexao conexao;
  final bool ocupada;
  final DateTime agora;

  @override
  Widget build(BuildContext context) {
    final textos = context.textos;
    final esquema = context.esquema;
    final cubit = context.read<OpenFinanceCubit>();
    final expira = conexao.consentimentoExpiraEm;
    final buscarDepois = conexao.buscarAPartirDe;
    final linhas = <(String, String)>[
      (
        'Último sync',
        conexao.ultimoSyncEm == null
            ? 'ainda não'
            : quandoFoi(conexao.ultimoSyncEm!, agora),
      ),
      if (conexao.proximoSync case final proximo?)
        ('Próximo', quandoFoi(proximo, agora)),
      if (expira != null) ('Consentimento', 'até ${formatarDiaMesAno(expira)}'),
      (
        'Contas',
        conexao.contas.isEmpty
            ? 'nenhuma'
            : conexao.contas.map((c) => c.nome).join(', '),
      ),
    ];

    if (!conexao.ativa) {
      return Card(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Topo(conexao.instituicao, chip: const _Chip.desativada()),
              const SizedBox(height: Espaco.x2),
              Text(
                'Sem sync. '
                '${conexao.contas.isEmpty ? 'As contas' : conexao.contas.map((c) => c.nome).join(', ')} '
                'continua${conexao.contas.length > 1 ? 'm' : ''} no app, sem Open Finance.',
                style: textos.bodyMedium?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Espaco.x3),
              OutlinedButton.icon(
                onPressed: ocupada ? null : () => cubit.reativar(conexao.id),
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('Reativar'),
              ),
              const SizedBox(height: Espaco.x2),
              Text(
                'Reativar confere o item na Pluggy. Se o item mudou ou o '
                'consentimento venceu, use Renovar.',
                style: textos.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: () => _abrir(
                  context,
                  rotaRenovarConexao(conexao.id),
                  extra: conexao,
                ),
                child: const Text('Renovar'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Topo(
              conexao.instituicao,
              chip: _Chip.doProblema(conexao.problema),
            ),
            if (conexao.ultimoErro case final erro?
                when conexao.problema == ProblemaOpenFinance.erro) ...[
              const SizedBox(height: Espaco.x3),
              _Faixa.risco(context, Icons.error_outline_rounded, erro),
            ],
            if (expira != null &&
                conexao.problema == ProblemaOpenFinance.vencendo) ...[
              const SizedBox(height: Espaco.x3),
              _Faixa.atencao(
                context,
                Icons.event_busy_rounded,
                'O consentimento vence em ${diasAte(expira, agora)} dias, em '
                '${formatarDiaMesAno(expira)}.',
              ),
            ],
            const SizedBox(height: Espaco.x3),
            for (final (rotulo, valor) in linhas)
              Padding(
                padding: const EdgeInsets.only(bottom: Espaco.x1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: textos.bodyMedium?.copyWith(
                        color: esquema.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Espaco.x3),
                    Expanded(
                      child: Text(
                        valor,
                        textAlign: TextAlign.end,
                        style: textos.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: Espaco.x6),
            Wrap(
              spacing: Espaco.x2,
              runSpacing: Espaco.x2,
              children: [
                OutlinedButton.icon(
                  onPressed: ocupada || buscarDepois != null
                      ? null
                      : () => cubit.buscarAgora(conexao.id),
                  icon: ocupada
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Buscar agora'),
                ),
                if (conexao.problema
                    case ProblemaOpenFinance.vencido ||
                        ProblemaOpenFinance.vencendo)
                  TextButton(
                    onPressed: () => _abrir(
                      context,
                      rotaRenovarConexao(conexao.id),
                      extra: conexao,
                    ),
                    child: const Text('Renovar'),
                  ),
                TextButton(
                  onPressed: ocupada
                      ? null
                      : () => _confirmarDesativar(context, conexao),
                  child: const Text('Desativar'),
                ),
              ],
            ),
            if (buscarDepois != null) ...[
              const SizedBox(height: Espaco.x2),
              Text(
                'Dá para buscar de novo a partir de '
                '${quandoFoi(buscarDepois, agora)}. A Pluggy atualiza os '
                'dados uma vez por dia.',
                style: textos.bodySmall?.copyWith(
                  color: esquema.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmarDesativar(BuildContext context, Conexao conexao) async {
  final cubit = context.read<OpenFinanceCubit>();
  final contas = conexao.contas.map((c) => c.nome).join(' e ');
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text('Desativar ${conexao.instituicao}?'),
      content: Text(
        'O app para de ler essa conexão; o histórico fica. '
        '${contas.isEmpty ? '' : '$contas continua${conexao.contas.length > 1 ? 'm' : ''} '
                  'ativa${conexao.contas.length > 1 ? 's' : ''}, sem Open Finance: aceita'
                  '${conexao.contas.length > 1 ? 'm' : ''} extrato e lançamento manual. '}'
        'A conexão não é excluída: dá para reativar depois, na mesma tela.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(contexto).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Desativar'),
        ),
      ],
    ),
  );
  if (confirmou == true) await cubit.desativar(conexao.id);
}

class _Topo extends StatelessWidget {
  const _Topo(this.instituicao, {required this.chip});

  final String instituicao;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: esquema.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.account_balance_rounded,
            color: esquema.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: Espaco.x3),
        Expanded(child: Text(instituicao, style: context.textos.titleMedium)),
        chip,
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.rotulo, this.icone, this.tipo);

  const _Chip.desativada()
    : this('Desativada', Icons.block_rounded, _TipoChip.neutro);

  factory _Chip.doProblema(ProblemaOpenFinance? problema) => switch (problema) {
    null => const _Chip(
      'Em dia',
      Icons.check_circle_outline_rounded,
      _TipoChip.ok,
    ),
    ProblemaOpenFinance.vencido => const _Chip(
      'Vencido',
      Icons.event_busy_rounded,
      _TipoChip.risco,
    ),
    ProblemaOpenFinance.erro => const _Chip(
      'Com erro',
      Icons.warning_amber_rounded,
      _TipoChip.risco,
    ),
    ProblemaOpenFinance.semDados => const _Chip(
      'Sem dados novos',
      Icons.schedule_rounded,
      _TipoChip.atencao,
    ),
    ProblemaOpenFinance.vencendo => const _Chip(
      'Vencendo',
      Icons.hourglass_bottom_rounded,
      _TipoChip.atencao,
    ),
  };

  final String rotulo;
  final IconData icone;
  final _TipoChip tipo;

  @override
  Widget build(BuildContext context) {
    final cores = context.cores;
    final esquema = context.esquema;
    final (fundo, cor) = switch (tipo) {
      _TipoChip.ok => (cores.ritmoOkContainer, cores.ritmoOk),
      _TipoChip.atencao => (cores.ritmoAtencaoContainer, cores.ritmoAtencao),
      _TipoChip.risco => (cores.ritmoRiscoContainer, cores.ritmoRisco),
      _TipoChip.neutro => (
        esquema.surfaceContainerHigh,
        esquema.onSurfaceVariant,
      ),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 4),
          Text(rotulo, style: context.textos.labelMedium?.copyWith(color: cor)),
        ],
      ),
    );
  }
}

enum _TipoChip { ok, atencao, risco, neutro }

class _Faixa extends StatelessWidget {
  const _Faixa(this.icone, this.texto, this.fundo, this.cor);

  factory _Faixa.risco(BuildContext context, IconData icone, String texto) =>
      _Faixa(
        icone,
        texto,
        context.cores.ritmoRiscoContainer,
        context.cores.ritmoRisco,
      );

  factory _Faixa.atencao(BuildContext context, IconData icone, String texto) =>
      _Faixa(
        icone,
        texto,
        context.cores.ritmoAtencaoContainer,
        context.cores.ritmoAtencao,
      );

  final IconData icone;
  final String texto;
  final Color fundo;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espaco.x3,
        vertical: Espaco.x2,
      ),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(Raio.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(width: Espaco.x2),
          Expanded(
            child: Text(
              texto,
              style: context.textos.bodyMedium?.copyWith(
                color: cor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
