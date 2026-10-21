import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../core/formatacao/datas.dart';
import '../../contas/cubit/contas_cubit.dart';
import '../../contas/data/conta.dart';
import '../cubit/lancamento_cubit.dart';
import '../data/transacao.dart';

/// Lançamento manual de despesa ou receita. Transferência, pagamento de
/// fatura e categoria aparecem desabilitados ("em breve"). Fecha devolvendo
/// `true` quando salvou.
class LancamentoTela extends StatefulWidget {
  const LancamentoTela({super.key, this.contaInicial});

  /// Conta já escolhida (o filtro ativo em Transações).
  final String? contaInicial;

  @override
  State<LancamentoTela> createState() => _LancamentoTelaState();
}

class _LancamentoTelaState extends State<LancamentoTela> {
  final _valor = TextEditingController();
  final _descricao = TextEditingController();

  /// Conta escolhida no campo; antes da escolha vale a `contaInicial`.
  String? _contaEscolhida;
  var _data = somenteData(DateTime.now());

  @override
  void dispose() {
    _valor.dispose();
    _descricao.dispose();
    super.dispose();
  }

  /// Só conta da lista vale: a do filtro pode ser um cartão, que ainda não
  /// recebe lançamento, ou as contas podem não ter carregado.
  String? _contaSelecionada(List<Conta> contas) {
    final id = _contaEscolhida ?? widget.contaInicial;
    return contas.any((c) => c.id == id) ? id : null;
  }

  void _salvar(List<Conta> contas) {
    context.read<LancamentoCubit>().salvar(
      contaId: _contaSelecionada(contas),
      valor: _valor.text,
      data: _data,
      descricao: _descricao.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final estadoContas = context.watch<ContasCubit>().state;
    final contas = switch (estadoContas) {
      ContasCarregado(:final resumo) =>
        resumo.contas.where((c) => c.aceitaLancamento).toList(),
      _ => const <Conta>[],
    };
    final ajudaConta = switch (estadoContas) {
      ContasCarregando() => 'Carregando as contas…',
      ContasErro(:final mensagem) => mensagem,
      ContasCarregado() when contas.isEmpty =>
        'Cadastre uma conta em Mais → Contas.',
      ContasCarregado() => null,
    };
    final contaSelecionada = _contaSelecionada(contas);

    return BlocConsumer<LancamentoCubit, LancamentoEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<LancamentoCubit>();
        final livre = !estado.enviando;

        // Enquanto salva, o voltar do Android fica bloqueado: fechar no meio
        // perderia o aviso de que o registro foi criado.
        return PopScope(
          canPop: livre,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => context.pop(false),
              ),
              title: const Text('Nova transação'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(Espaco.x4),
              children: [
                if (estado.erroGeral != null) ...[
                  Aviso.erro(context, estado.erroGeral!),
                  const SizedBox(height: Espaco.x6),
                ],
                DropdownButtonFormField<String>(
                  // initialValue só é lido na criação: a chave recria o campo
                  // quando as contas terminam de carregar.
                  key: ValueKey(estadoContas.runtimeType),
                  initialValue: contaSelecionada,
                  isExpanded: true,
                  hint: const Text('Selecione uma conta'),
                  decoration: InputDecoration(
                    labelText: 'Conta',
                    errorText: estado.erros['conta_id'],
                    helperText: ajudaConta,
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
                  onChanged: livre
                      ? (id) => setState(() => _contaEscolhida = id)
                      : null,
                ),
                const SizedBox(height: Espaco.x6),
                Padding(
                  padding: const EdgeInsets.only(
                    left: Espaco.x1,
                    bottom: Espaco.x2,
                  ),
                  child: Text('Tipo', style: context.textos.bodySmall),
                ),
                Wrap(
                  spacing: Espaco.x2,
                  runSpacing: Espaco.x2,
                  children: [
                    ChipOpcao(
                      rotulo: 'Despesa',
                      selecionado: estado.tipo == TipoTransacao.despesa,
                      aoTocar: livre
                          ? () => cubit.escolherTipo(TipoTransacao.despesa)
                          : null,
                    ),
                    ChipOpcao(
                      rotulo: 'Receita',
                      selecionado: estado.tipo == TipoTransacao.receita,
                      aoTocar: livre
                          ? () => cubit.escolherTipo(TipoTransacao.receita)
                          : null,
                    ),
                    const ChipOpcao(
                      rotulo: 'Transferência',
                      selecionado: false,
                      aoTocar: null,
                    ),
                    const ChipOpcao(
                      rotulo: 'Pagamento de fatura',
                      selecionado: false,
                      aoTocar: null,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Espaco.x4,
                    Espaco.x1,
                    Espaco.x4,
                    0,
                  ),
                  child: Text(
                    'Transferência e pagamento de fatura: em breve.',
                    style: context.textos.bodySmall?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                CampoDinheiro(
                  controller: _valor,
                  rotulo: 'Valor',
                  habilitado: livre,
                  ajuda: 'Sempre positivo; o tipo define se entra ou sai.',
                  erro: estado.erros['valor'],
                ),
                const SizedBox(height: Espaco.x6),
                CampoData(
                  rotulo: 'Data',
                  data: _data,
                  habilitado: livre,
                  aoMudar: (data) => setState(() => _data = data),
                  erro: estado.erros['data'],
                ),
                const SizedBox(height: Espaco.x6),
                TextField(
                  controller: _descricao,
                  enabled: livre,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    errorText: estado.erros['descricao'],
                    counterText: '',
                  ),
                ),
                const SizedBox(height: Espaco.x6),
                const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Categoria (opcional)',
                    hintText: 'Sem categoria',
                    helperText: 'Categorias: em breve.',
                    suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: RodapeFormulario(
              botao: FilledButton(
                onPressed: livre ? () => _salvar(contas) : null,
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
