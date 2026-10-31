import 'package:bloc_test/bloc_test.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/inicio/cubit/inicio_cubit.dart';
import 'package:financas/features/inicio/data/aporte_dispensado.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/aporte_dispensado_falso.dart';
import '../../apoio/planejamento_falso.dart';

void main() {
  late PlanejamentoRepositorioFalso planejamento;
  late AporteDispensadoFalso dispensado;
  final hoje = DateTime(2026, 11, 10);

  setUp(() {
    planejamento = PlanejamentoRepositorioFalso(
      resumo: resumoSalarioRecebido(),
    );
    dispensado = AporteDispensadoFalso();
  });

  InicioCubit criar() => InicioCubit(
    planejamento,
    dispensado,
    hoje: () => hoje.add(const Duration(hours: 9)),
  );

  blocTest<InicioCubit, InicioEstado>(
    'carrega o resumo com o dia, sem horário',
    build: criar,
    act: (cubit) => cubit.carregar(),
    expect: () => [
      const InicioEstado.carregando(),
      InicioEstado.carregado(resumo: resumoSalarioRecebido(), hoje: hoje),
    ],
  );

  blocTest<InicioCubit, InicioEstado>(
    'recarregar não volta a "carregando"',
    build: criar,
    act: (cubit) async {
      await cubit.carregar();
      planejamento.resumo = resumoComPrevisao();
      await cubit.carregar();
    },
    expect: () => [
      const InicioEstado.carregando(),
      InicioEstado.carregado(resumo: resumoSalarioRecebido(), hoje: hoje),
      InicioEstado.carregado(resumo: resumoComPrevisao(), hoje: hoje),
    ],
  );

  blocTest<InicioCubit, InicioEstado>(
    'erro da API vira a mensagem',
    build: () {
      planejamento.erro = const ErroApi('Sem conexão com o servidor.');
      return criar();
    },
    act: (cubit) => cubit.carregar(),
    expect: () => [
      const InicioEstado.carregando(),
      const InicioEstado.erro('Sem conexão com o servidor.'),
    ],
  );

  blocTest<InicioCubit, InicioEstado>(
    '"Agora não" guarda o salário e esconde a sugestão',
    build: criar,
    act: (cubit) async {
      await cubit.carregar();
      await cubit.dispensarAporte();
    },
    skip: 2,
    expect: () => [
      InicioEstado.carregado(
        resumo: resumoSalarioRecebido(),
        hoje: hoje,
        aporteDispensado: true,
      ),
    ],
    verify: (_) => expect(dispensado.chave, 'r1:2026-11-10'),
  );

  blocTest<InicioCubit, InicioEstado>(
    'salário já dispensado continua dispensado na carga seguinte',
    build: () {
      dispensado.chave = 'r1:2026-11-10';
      return criar();
    },
    act: (cubit) => cubit.carregar(),
    skip: 1,
    expect: () => [
      InicioEstado.carregado(
        resumo: resumoSalarioRecebido(),
        hoje: hoje,
        aporteDispensado: true,
      ),
    ],
  );

  blocTest<InicioCubit, InicioEstado>(
    'a dispensa de outro salário não vale para este',
    build: () {
      dispensado.chave = 'r1:2026-10-13';
      return criar();
    },
    act: (cubit) => cubit.carregar(),
    skip: 1,
    expect: () => [
      InicioEstado.carregado(resumo: resumoSalarioRecebido(), hoje: hoje),
    ],
  );

  blocTest<InicioCubit, InicioEstado>(
    'sem salário recebido não há o que dispensar',
    build: () {
      planejamento.resumo = resumoComPrevisao();
      return criar();
    },
    act: (cubit) async {
      await cubit.carregar();
      await cubit.dispensarAporte();
    },
    skip: 2,
    expect: () => <InicioEstado>[],
    verify: (_) => expect(dispensado.chave, isNull),
  );

  test('chaveDoAporte: renda e data esperada; nula sem salário', () {
    expect(chaveDoAporte(resumoSalarioRecebido()), 'r1:2026-11-10');
    expect(chaveDoAporte(resumoComPrevisao()), isNull);
    expect(chaveDoAporte(resumoSemSalario()), isNull);
  });
}
