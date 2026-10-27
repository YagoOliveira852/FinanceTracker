import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/revisao/cubit/decisao_cubit.dart';
import 'package:financas/features/revisao/cubit/folha_rascunho_cubit.dart';
import 'package:financas/features/revisao/cubit/pagamento_revisao_cubit.dart';
import 'package:financas/features/revisao/cubit/revisao_cubit.dart';
import 'package:financas/features/revisao/data/revisao.dart';
import 'package:financas/features/transacoes/data/transacao.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/revisao_falso.dart';

final _hoje = DateTime(2026, 10, 26, 9, 30);

RevisaoCubit _cubit(RevisaoRepositorioFalso repositorio) =>
    RevisaoCubit(repositorio, hoje: () => _hoje);

void main() {
  group('RevisaoCubit', () {
    blocTest<RevisaoCubit, RevisaoEstado>(
      'carrega a revisão',
      build: () => _cubit(RevisaoRepositorioFalso()),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        RevisaoEstado(hoje: DateTime(2026, 10, 26), carregando: true),
        isA<RevisaoEstado>()
            .having((e) => e.carregando, 'carregando', isFalse)
            .having((e) => e.total, 'total', 3)
            .having((e) => e.revisao?.qtdSugeridos, 'sugeridos', 2),
      ],
    );

    blocTest<RevisaoCubit, RevisaoEstado>(
      'erro ao carregar vira mensagem',
      build: () => _cubit(
        RevisaoRepositorioFalso()..erro = const ErroApi(ErroApi.semConexao),
      ),
      act: (cubit) => cubit.carregar(),
      skip: 1,
      expect: () => [
        RevisaoEstado(hoje: DateTime(2026, 10, 26), erro: ErroApi.semConexao),
      ],
    );

    test('agrupa os rascunhos por dia, do mais recente', () async {
      final cubit = _cubit(RevisaoRepositorioFalso());
      addTearDown(cubit.close);

      await cubit.carregar();

      final dias = cubit.state.dias;
      expect(dias.map((d) => d.data), [
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 24),
      ]);
      expect(dias.first.rascunhos.map((r) => r.item.id), ['i1', 'i2']);
    });

    test('✓ confirma com a sugestão, avisa e recarrega', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = _cubit(repositorio);
      addTearDown(cubit.close);
      await cubit.carregar();

      await cubit.confirmarComSugestao(rascunhoSugerido());

      final confirmado = repositorio.confirmados.single;
      expect(confirmado.id, 'i1');
      expect(confirmado.categoriaId, 'cat-alimentacao');
      expect(confirmado.tipo, isNull);
      expect(
        cubit.state.aviso,
        'Padaria Pão Quente confirmada como Alimentação.',
      );
      expect(cubit.state.total, 2);
      expect(repositorio.cargas, 2);
    });

    test('sem sugestão o ✓ não faz nada', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = _cubit(repositorio);
      addTearDown(cubit.close);

      await cubit.confirmarComSugestao(rascunhoSemSugestao());

      expect(repositorio.confirmados, isEmpty);
    });

    test('lote manda os sugeridos e avisa quantos', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = _cubit(repositorio);
      addTearDown(cubit.close);
      await cubit.carregar();

      await cubit.confirmarLote();

      expect(repositorio.lotes.single, ['i1', 'i2']);
      expect(cubit.state.aviso, '2 rascunhos confirmados.');
      expect(cubit.state.total, 1);
      expect(cubit.state.enviando, isFalse);
    });

    test('lista velha (409) avisa e recarrega', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = _cubit(repositorio);
      addTearDown(cubit.close);
      await cubit.carregar();
      repositorio.erro = const ErroApi(
        'Esta transação já foi revisada.',
        status: 409,
      );

      await cubit.confirmarComSugestao(rascunhoSugerido());

      expect(cubit.state.aviso, 'Esta transação já foi revisada.');
      expect(repositorio.cargas, 2);
    });
  });

  group('FolhaRascunhoCubit', () {
    test('começa na sugestão e no tipo do rascunho', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoSugerido(),
      );
      addTearDown(cubit.close);

      expect(cubit.state.tipo, TipoTransacao.despesa);
      expect(cubit.state.categoriaId, 'cat-alimentacao');
      expect(cubit.state.descricao, 'Padaria Pão Quente');
      expect(cubit.efeito, EfeitoRegra.reforcada);
      expect(cubit.podeConfirmar, isTrue);
    });

    test('trocar a categoria troca o efeito', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoDeManual(),
      );
      addTearDown(cubit.close);

      cubit.escolherCategoria('cat-alimentacao');

      expect(cubit.efeito, EfeitoRegra.manualMantida);
    });

    test('sem sugestão não confirma até escolher', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoSemSugestao(),
      );
      addTearDown(cubit.close);

      expect(cubit.podeConfirmar, isFalse);
      expect(cubit.efeito, isNull);

      cubit.escolherCategoria('cat-mercado');

      expect(cubit.podeConfirmar, isTrue);
      expect(cubit.efeito, EfeitoRegra.criada);
    });

    test('tipos: transferência só fora do cartão', () {
      expect(FolhaRascunhoCubit.tiposPara(itemExemplo()), [
        TipoTransacao.despesa,
        TipoTransacao.transferenciaSaida,
      ]);
      expect(
        FolhaRascunhoCubit.tiposPara(
          itemExemplo(
            tipo: TipoTransacao.receita,
            contaTipo: TipoConta.carteira,
          ),
        ),
        [
          TipoTransacao.receita,
          TipoTransacao.estorno,
          TipoTransacao.transferenciaEntrada,
        ],
      );
      expect(
        FolhaRascunhoCubit.tiposPara(
          itemExemplo(contaTipo: TipoConta.cartaoCredito),
        ),
        [TipoTransacao.despesa],
      );
    });

    test('entrada troca entre receita e estorno, sem efeito', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoSugerido().copyWith(
          item: itemExemplo(tipo: TipoTransacao.receita),
        ),
      );
      addTearDown(cubit.close);

      cubit.escolherTipo(TipoTransacao.estorno);

      expect(cubit.state.categoriaId, isNull);
      cubit.escolherCategoria('cat-mercado');
      expect(cubit.efeito, isNull);
    });

    test('pagamento das fontes abre como despesa', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoSemSugestao().copyWith(item: pagamentoExemplo()),
      );
      addTearDown(cubit.close);

      expect(cubit.state.tipo, TipoTransacao.despesa);
    });

    test('como transferência, pede a outra conta e não a categoria', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = FolhaRascunhoCubit(repositorio, rascunhoSugerido());
      addTearDown(cubit.close);

      cubit.escolherTipo(TipoTransacao.transferenciaSaida);
      expect(cubit.podeConfirmar, isFalse);
      expect(cubit.efeito, isNull);

      cubit.escolherOutraConta('carteira');
      expect(cubit.podeConfirmar, isTrue);
      await cubit.confirmar();

      expect(repositorio.decisoes, [
        'transferir i1 carteira Padaria Pão Quente',
      ]);
      expect(
        cubit.state.concluido,
        'Padaria Pão Quente ligada como transferência.',
      );
    });

    test('rascunho que já veio como transferência abre assim', () {
      final cubit = FolhaRascunhoCubit(
        RevisaoRepositorioFalso(),
        rascunhoSemSugestao().copyWith(
          item: itemExemplo(tipo: TipoTransacao.transferenciaSaida),
        ),
      );
      addTearDown(cubit.close);

      expect(cubit.state.tipo, TipoTransacao.transferenciaSaida);
    });

    blocTest<FolhaRascunhoCubit, FolhaRascunhoEstado>(
      'confirmar manda a descrição editada e conclui',
      build: () =>
          FolhaRascunhoCubit(RevisaoRepositorioFalso(), rascunhoSugerido()),
      act: (cubit) async {
        cubit.mudarDescricao('  Padaria  ');
        await cubit.confirmar();
      },
      skip: 2,
      expect: () => [
        isA<FolhaRascunhoEstado>()
            .having((e) => e.concluido, 'concluido', 'Padaria confirmada.')
            .having((e) => e.enviando, 'enviando', isFalse),
      ],
    );

    test('erro de campo aparece na folha', () async {
      final repositorio = RevisaoRepositorioFalso()
        ..erro = const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'categoria_id': 'Esta categoria está desativada.'},
        );
      final cubit = FolhaRascunhoCubit(repositorio, rascunhoSugerido());
      addTearDown(cubit.close);

      await cubit.confirmar();

      expect(cubit.state.erro, 'Esta categoria está desativada.');
      expect(cubit.state.concluido, isNull);
    });

    test('ignorar conclui com aviso', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = FolhaRascunhoCubit(repositorio, rascunhoSemSugestao());
      addTearDown(cubit.close);

      await cubit.ignorar();

      expect(repositorio.ignorados, ['i3']);
      expect(cubit.state.concluido, 'Posto Fictício ignorada.');
    });
  });

  group('DecisaoCubit', () {
    blocTest<DecisaoCubit, DecisaoEstado>(
      'conclui com o aviso',
      build: DecisaoCubit.new,
      act: (cubit) => cubit.executar(() async {}, aviso: 'Par ligado.'),
      expect: () => [
        const DecisaoEstado(enviando: true),
        const DecisaoEstado(concluido: 'Par ligado.'),
      ],
    );

    blocTest<DecisaoCubit, DecisaoEstado>(
      'erro fica na folha',
      build: DecisaoCubit.new,
      act: (cubit) => cubit.executar(
        () async => throw const ErroApi(
          'Dados inválidos.',
          status: 422,
          campos: {'entrada_id': 'O par precisa ter o mesmo valor.'},
        ),
        aviso: 'Par ligado.',
      ),
      expect: () => [
        const DecisaoEstado(enviando: true),
        const DecisaoEstado(erro: 'O par precisa ter o mesmo valor.'),
      ],
    );
  });

  group('PagamentoRevisaoCubit', () {
    test('carrega as candidatas e começa na sugerida', () async {
      final cubit = PagamentoRevisaoCubit(
        RevisaoRepositorioFalso(),
        pagamentoExemplo(),
      );
      addTearDown(cubit.close);

      await cubit.carregar();

      expect(cubit.state.carregando, isFalse);
      expect(cubit.state.candidatas, hasLength(2));
      expect(cubit.state.escolhida?.competencia, DateTime(2026, 10));
    });

    test('sem sugerida, espera a escolha', () async {
      final repositorio = RevisaoRepositorioFalso()
        ..candidatas = [
          for (final f in candidatasExemplo()) f.copyWith(sugerida: false),
        ];
      final cubit = PagamentoRevisaoCubit(repositorio, pagamentoExemplo());
      addTearDown(cubit.close);

      await cubit.carregar();
      await cubit.confirmar();

      expect(cubit.state.escolhida, isNull);
      expect(repositorio.decisoes, isEmpty);
    });

    test('confirma na escolhida', () async {
      final repositorio = RevisaoRepositorioFalso();
      final cubit = PagamentoRevisaoCubit(repositorio, pagamentoExemplo());
      addTearDown(cubit.close);
      await cubit.carregar();

      cubit.escolher(cubit.state.candidatas.last);
      await cubit.confirmar();

      expect(repositorio.decisoes, ['pagar f1 k1 11']);
      expect(
        cubit.state.concluido,
        'Pagamento ligado à fatura de Cartão Exemplo.',
      );
    });

    test('erro ao carregar', () async {
      final cubit = PagamentoRevisaoCubit(
        RevisaoRepositorioFalso()..erro = const ErroApi(ErroApi.semConexao),
        pagamentoExemplo(),
      );
      addTearDown(cubit.close);

      await cubit.carregar();

      expect(cubit.state.erro, ErroApi.semConexao);
    });
  });
}
