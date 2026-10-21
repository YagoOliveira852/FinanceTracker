import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/aviso.dart';
import '../../../app/widgets/campos.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../core/formatacao/datas.dart';
import '../cubit/nova_conta_cubit.dart';
import '../data/conta.dart';

/// Cadastro de conta corrente ou carteira. Fecha devolvendo `true` quando a
/// conta foi criada.
class NovaContaTela extends StatefulWidget {
  const NovaContaTela({super.key});

  @override
  State<NovaContaTela> createState() => _NovaContaTelaState();
}

class _NovaContaTelaState extends State<NovaContaTela> {
  final _nome = TextEditingController();
  final _instituicao = TextEditingController();
  final _saldo = TextEditingController();
  var _data = somenteData(DateTime.now());

  @override
  void dispose() {
    _nome.dispose();
    _instituicao.dispose();
    _saldo.dispose();
    super.dispose();
  }

  void _salvar() {
    context.read<NovaContaCubit>().salvar(
      nome: _nome.text,
      instituicao: _instituicao.text,
      saldoInicial: _saldo.text,
      dataSaldoInicial: _data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NovaContaCubit, NovaContaEstado>(
      listenWhen: (antes, depois) =>
          antes.salva == null && depois.salva != null,
      listener: (context, _) => context.pop(true),
      builder: (context, estado) {
        final cubit = context.read<NovaContaCubit>();
        final livre = !estado.enviando;
        final corrente = estado.tipo == TipoConta.corrente;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Fechar',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => context.pop(false),
            ),
            title: const Text('Nova conta'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(Espaco.x4),
            children: [
              if (estado.erroGeral != null) ...[
                Aviso.erro(context, estado.erroGeral!),
                const SizedBox(height: Espaco.x6),
              ],
              Padding(
                padding: const EdgeInsets.only(
                  left: Espaco.x1,
                  bottom: Espaco.x2,
                ),
                child: Text('Tipo', style: context.textos.bodySmall),
              ),
              Wrap(
                spacing: Espaco.x2,
                children: [
                  ChipOpcao(
                    rotulo: 'Conta corrente',
                    selecionado: corrente,
                    aoTocar: livre
                        ? () => cubit.escolherTipo(TipoConta.corrente)
                        : null,
                  ),
                  ChipOpcao(
                    rotulo: 'Carteira (dinheiro)',
                    selecionado: !corrente,
                    aoTocar: livre
                        ? () => cubit.escolherTipo(TipoConta.carteira)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: Espaco.x6),
              TextField(
                controller: _nome,
                enabled: livre,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nome da conta',
                  hintText: corrente ? 'Ex.: Conta principal' : 'Ex.: Carteira',
                  errorText: estado.erros['nome'],
                  counterText: '',
                ),
              ),
              if (corrente) ...[
                const SizedBox(height: Espaco.x6),
                TextField(
                  controller: _instituicao,
                  enabled: livre,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Instituição',
                    hintText: 'Ex.: Banco Exemplo',
                    errorText: estado.erros['instituicao'],
                    counterText: '',
                  ),
                ),
              ],
              const SizedBox(height: Espaco.x6),
              CampoDinheiro(
                controller: _saldo,
                rotulo: 'Saldo inicial',
                aceitaNegativo: true,
                habilitado: livre,
                ajuda:
                    'O saldo exato do extrato no começo do dia abaixo. '
                    'Pode ser negativo.',
                erro: estado.erros['saldo_inicial'],
              ),
              const SizedBox(height: Espaco.x6),
              CampoData(
                rotulo: 'Saldo em',
                data: _data,
                habilitado: livre,
                aoMudar: (data) => setState(() => _data = data),
                // O backend soma as transações a partir desta data,
                // inclusive: o saldo informado é o do começo do dia.
                ajuda:
                    'Saldo no começo do dia: as transações a partir desta '
                    'data mudam o saldo.',
                erro: estado.erros['data_saldo_inicial'],
              ),
            ],
          ),
          bottomNavigationBar: RodapeFormulario(
            botao: FilledButton(
              onPressed: livre ? _salvar : null,
              child: RotuloEnviando(
                enviando: estado.enviando,
                rotulo: 'Salvar conta',
              ),
            ),
          ),
        );
      },
    );
  }
}
