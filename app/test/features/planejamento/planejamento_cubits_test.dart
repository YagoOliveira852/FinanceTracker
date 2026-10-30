import 'package:bloc_test/bloc_test.dart';
import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/planejamento/cubit/ajustes_calculo_cubit.dart';
import 'package:financas/features/planejamento/cubit/editar_renda_cubit.dart';
import 'package:financas/features/planejamento/cubit/planejamento_cubit.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/planejamento_falso.dart';

void main() {
  late PlanejamentoRepositorioFalso repositorio;

  setUp(
    () => repositorio = PlanejamentoRepositorioFalso(
      rendas: [rendaExemplo()],
      leitura: leituraExemplo(),
    ),
  );

  group('PlanejamentoCubit', () {
    blocTest<PlanejamentoCubit, PlanejamentoEstado>(
      'carrega rendas e configuração juntas',
      build: () => PlanejamentoCubit(repositorio),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const PlanejamentoEstado.carregando(),
        PlanejamentoEstado.carregado(
          rendas: [rendaExemplo()],
          leitura: leituraExemplo(),
        ),
      ],
    );

    blocTest<PlanejamentoCubit, PlanejamentoEstado>(
      'erro da API vira a mensagem',
      build: () {
        repositorio.erro = const ErroApi('Sem conexão com o servidor.');
        return PlanejamentoCubit(repositorio);
      },
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const PlanejamentoEstado.carregando(),
        const PlanejamentoEstado.erro('Sem conexão com o servidor.'),
      ],
    );
  });

  group('EditarRendaCubit', () {
    Future<void> salvar(
      EditarRendaCubit cubit, {
      String descricao = 'Salário',
      String valor = '4.200,00',
      String dia = '10',
      String? conta = 'c1',
      bool ativa = true,
    }) => cubit.salvar(
      descricao: descricao,
      valor: valor,
      dia: dia,
      contaId: conta,
      ativa: ativa,
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'valida todos os campos de uma vez',
      build: () => EditarRendaCubit(repositorio),
      act: (cubit) =>
          salvar(cubit, descricao: '  ', valor: '0,00', dia: '32', conta: null),
      expect: () => [
        const EditarRendaEstado(
          erros: {
            'descricao': 'Dê um nome à renda, por exemplo: Salário.',
            'valor': 'O valor precisa ser maior que zero.',
            'dia_previsto': 'Use um dia de 1 a 31.',
            'conta_id':
                'Escolha a conta corrente ou a carteira onde a renda cai.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.criadas, isEmpty),
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'valor vazio também pede maior que zero; formato errado diz o formato',
      build: () => EditarRendaCubit(repositorio),
      act: (cubit) async {
        await salvar(cubit, valor: '');
        await salvar(cubit, valor: '12,345');
      },
      expect: () => [
        const EditarRendaEstado(
          erros: {'valor': 'O valor precisa ser maior que zero.'},
        ),
        const EditarRendaEstado(
          erros: {
            'valor': 'Use no máximo 2 casas decimais, por exemplo: 1.234,56.',
          },
        ),
      ],
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'nova renda: cria com os dados lidos',
      build: () => EditarRendaCubit(repositorio),
      act: (cubit) => salvar(cubit, descricao: ' Salário '),
      skip: 1,
      expect: () => [
        isA<EditarRendaEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) => expect(
        repositorio.criadas.single,
        DadosRenda(
          descricao: 'Salário',
          valor: Decimal.parse('4200'),
          diaPrevisto: 10,
          contaId: 'c1',
        ),
      ),
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'edição: manda o id e o ativo escolhido',
      build: () => EditarRendaCubit(repositorio, existente: rendaExemplo()),
      act: (cubit) => salvar(cubit, ativa: false),
      skip: 1,
      expect: () => [
        isA<EditarRendaEstado>().having((e) => e.salva?.ativa, 'ativa', false),
      ],
      verify: (_) {
        final editada = repositorio.editadas.single;
        expect(editada.id, 'r1');
        expect(editada.dados.ativa, isFalse);
      },
    );

    test('edição começa com a próxima data da renda', () {
      final cubit = EditarRendaCubit(repositorio, existente: freelaExemplo());

      expect(cubit.state.previa, freelaExemplo().proxima);
    });

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'erro do servidor num campo vai para o campo',
      build: () {
        repositorio.erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {
            'conta_id':
                'Escolha a conta corrente ou a carteira onde a renda cai.',
          },
        );
        return EditarRendaCubit(repositorio);
      },
      act: salvar,
      skip: 1,
      expect: () => [
        const EditarRendaEstado(
          erros: {
            'conta_id':
                'Escolha a conta corrente ou a carteira onde a renda cai.',
          },
        ),
      ],
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'erro sem campo vira erro geral',
      build: () {
        repositorio.erro = const ErroApi('Sem conexão com o servidor.');
        return EditarRendaCubit(repositorio);
      },
      act: salvar,
      skip: 1,
      expect: () => [
        const EditarRendaEstado(erroGeral: 'Sem conexão com o servidor.'),
      ],
    );

    blocTest<EditarRendaCubit, EditarRendaEstado>(
      'prévia da próxima data para o dia digitado; dia inválido a apaga',
      build: () => EditarRendaCubit(repositorio),
      act: (cubit) async {
        await cubit.atualizarPrevia('15');
        await cubit.atualizarPrevia('40');
      },
      expect: () => [
        EditarRendaEstado(previa: previaRendaExemplo(15)),
        const EditarRendaEstado(),
      ],
      verify: (_) => expect(repositorio.previas, [15]),
    );
  });

  group('AjustesCalculoCubit', () {
    Future<void> salvar(
      AjustesCalculoCubit cubit, {
      String colchao = '500,00',
      String semanal = '280,00',
      String meta = '6',
      String mensal = '',
    }) => cubit.salvar(
      colchao: colchao,
      gastoSemanal: semanal,
      meta: meta,
      gastoMensal: mensal,
    );

    test('começa no modo da configuração salva', () {
      expect(
        AjustesCalculoCubit(repositorio, leituraExemplo()).state.automatico,
        isTrue,
      );
      expect(
        AjustesCalculoCubit(
          repositorio,
          leituraExemplo(mensalFixo: '3200.00'),
        ).state.automatico,
        isFalse,
      );
    });

    blocTest<AjustesCalculoCubit, AjustesCalculoEstado>(
      'valida os campos; o gasto mensal só no valor fixo',
      build: () => AjustesCalculoCubit(repositorio, leituraExemplo()),
      act: (cubit) async {
        await salvar(cubit, colchao: '', semanal: '-1', meta: '0', mensal: 'x');
        cubit.escolherAutomatico(false);
        await salvar(cubit, meta: '4,55');
      },
      expect: () => [
        const AjustesCalculoEstado(
          automatico: true,
          erros: {
            'colchao': 'Informe um valor, por exemplo: 1.234,56.',
            'gasto_semanal_estimado': 'O valor não pode ser negativo.',
            'meta_reserva_meses': 'A meta precisa ser maior que zero.',
          },
        ),
        const AjustesCalculoEstado(
          automatico: false,
          erros: {
            'colchao': 'Informe um valor, por exemplo: 1.234,56.',
            'gasto_semanal_estimado': 'O valor não pode ser negativo.',
            'meta_reserva_meses': 'A meta precisa ser maior que zero.',
          },
        ),
        const AjustesCalculoEstado(
          automatico: false,
          erros: {
            'meta_reserva_meses':
                'Informe a meta em meses, com até uma casa: 6 ou 4,5.',
            'gasto_mensal_referencia': 'Informe um valor maior que zero.',
          },
        ),
      ],
      verify: (_) => expect(repositorio.configuracoesSalvas, isEmpty),
    );

    blocTest<AjustesCalculoCubit, AjustesCalculoEstado>(
      'automático manda o gasto mensal nulo',
      build: () => AjustesCalculoCubit(repositorio, leituraExemplo()),
      act: (cubit) => salvar(cubit, meta: '4,5', mensal: '3.200,00'),
      skip: 1,
      expect: () => [
        isA<AjustesCalculoEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) => expect(
        repositorio.configuracoesSalvas.single,
        Configuracao(
          colchao: Decimal.parse('500'),
          metaReservaMeses: Decimal.parse('4.5'),
          gastoSemanalEstimado: Decimal.parse('280'),
        ),
      ),
    );

    blocTest<AjustesCalculoCubit, AjustesCalculoEstado>(
      'valor fixo manda o gasto mensal digitado',
      build: () => AjustesCalculoCubit(repositorio, leituraExemplo()),
      act: (cubit) {
        cubit.escolherAutomatico(false);
        return salvar(cubit, mensal: '3.200,00');
      },
      skip: 2,
      expect: () => [
        isA<AjustesCalculoEstado>().having((e) => e.salva, 'salva', isNotNull),
      ],
      verify: (_) => expect(
        repositorio.configuracoesSalvas.single.gastoMensalReferencia,
        Decimal.parse('3200'),
      ),
    );
  });
}
