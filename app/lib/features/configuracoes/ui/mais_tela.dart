import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/tema.dart';
import '../../../app/widgets/chip_opcao.dart';
import '../../../app/widgets/lista.dart';
import '../../importacao/ui/importar_tela.dart';
import '../../login/cubit/sessao_cubit.dart';
import '../cubit/tema_cubit.dart';
import 'aparencia_folha.dart';

/// Rota da tela Contas, dentro da aba Mais.
const rotaContas = '/mais/contas';

/// Rota de Categorias e regras, dentro da aba Mais.
const rotaCategorias = '/mais/categorias';

/// Rota do Planejamento (rendas e configuração), dentro da aba Mais.
const rotaPlanejamento = '/mais/planejamento';

/// Aba Mais: Contas, Importar extrato, Planejamento, Categorias e regras,
/// Aparência e os
/// itens que ainda não têm tela ("em breve").
class MaisTela extends StatelessWidget {
  const MaisTela({super.key});

  @override
  Widget build(BuildContext context) {
    final esquema = context.esquema;
    final seta = Icon(
      Icons.chevron_right_rounded,
      color: esquema.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Espaco.x4, 0, Espaco.x4, Espaco.x6),
        children: [
          const TituloSecao('Dinheiro', pequeno: true),
          GrupoLista(
            itens: [
              ItemLista(
                icone: Icons.account_balance_rounded,
                titulo: 'Contas',
                subtitulo: const Text('Contas correntes e carteira'),
                direita: seta,
                aoTocar: () => context.go(rotaContas),
              ),
              const _EmBreve(
                icone: Icons.credit_card_rounded,
                titulo: 'Faturas',
                subtitulo: 'Cartões, fechamento e vencimento',
              ),
              const _EmBreve(
                icone: Icons.savings_rounded,
                titulo: 'Investimentos',
                subtitulo: 'Reserva e rendimento',
              ),
            ],
          ),
          const SizedBox(height: Espaco.x4),
          const TituloSecao('Dados', pequeno: true),
          GrupoLista(
            itens: [
              ItemLista(
                icone: Icons.upload_file_rounded,
                titulo: 'Importar extrato',
                subtitulo: const Text('Arquivo OFX ou CSV'),
                direita: seta,
                aoTocar: () => context.push(rotaImportar),
              ),
              const _EmBreve(
                icone: Icons.sync_rounded,
                titulo: 'Open Finance',
                subtitulo: 'Conexões do Meu Pluggy',
              ),
            ],
          ),
          const SizedBox(height: Espaco.x4),
          const TituloSecao('Ajustes', pequeno: true),
          GrupoLista(
            itens: [
              ItemLista(
                icone: Icons.tune_rounded,
                titulo: 'Planejamento',
                subtitulo: const Text('Salário, colchão e meta da reserva'),
                direita: seta,
                aoTocar: () => context.go(rotaPlanejamento),
              ),
              ItemLista(
                icone: Icons.category_rounded,
                titulo: 'Categorias e regras',
                subtitulo: const Text('Como os rascunhos são classificados'),
                direita: seta,
                aoTocar: () => context.go(rotaCategorias),
              ),
              ItemLista(
                icone: Icons.contrast_rounded,
                titulo: 'Aparência',
                subtitulo: Text(
                  'Tema: ${nomeDoTema(context.watch<TemaCubit>().state)}',
                ),
                direita: seta,
                aoTocar: () => abrirAparencia(context),
              ),
              const _EmBreve(
                icone: Icons.fingerprint_rounded,
                titulo: 'Segurança',
                subtitulo: 'Desbloqueio por biometria',
              ),
            ],
          ),
          const SizedBox(height: Espaco.x4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: context.read<SessaoCubit>().sair,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Item de Mais que ainda não tem tela: visível, com selo, sem ação.
class _EmBreve extends StatelessWidget {
  const _EmBreve({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;

  @override
  Widget build(BuildContext context) {
    return ItemLista(
      icone: icone,
      titulo: titulo,
      subtitulo: Text(subtitulo),
      direita: const SeloEmBreve(),
      habilitado: false,
    );
  }
}
