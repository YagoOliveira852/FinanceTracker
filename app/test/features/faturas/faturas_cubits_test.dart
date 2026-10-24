import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/faturas/cubit/fatura_cubit.dart';
import 'package:financas/features/faturas/cubit/faturas_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/faturas_falso.dart';

void main() {
  late FaturasRepositorioFalso repositorio;

  setUp(() => repositorio = FaturasRepositorioFalso());

  group('FaturasCubit', () {
    blocTest<FaturasCubit, FaturasEstado>(
      'carrega a lista do cartão',
      build: () => FaturasCubit(repositorio, 'k1'),
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const FaturasEstado.carregando(),
        FaturasEstado.carregado(listaExemplo),
      ],
    );

    blocTest<FaturasCubit, FaturasEstado>(
      'erro da API vira estado de erro',
      build: () {
        repositorio.erro = const ErroApi(ErroApi.semConexao);
        return FaturasCubit(repositorio, 'k1');
      },
      act: (cubit) => cubit.carregar(),
      expect: () => [
        const FaturasEstado.carregando(),
        const FaturasEstado.erro('Não foi possível falar com o servidor.'),
      ],
    );
  });

  group('FaturaCubit', () {
    blocTest<FaturaCubit, FaturaEstado>(
      'carrega a competência pedida',
      build: () => FaturaCubit(repositorio, 'k1'),
      act: (cubit) => cubit.carregar(DateTime(2026, 10)),
      expect: () => [
        const FaturaEstado.carregando(),
        FaturaEstado.carregada(detalheExemplo(outubroExemplo)),
      ],
    );
  });
}
