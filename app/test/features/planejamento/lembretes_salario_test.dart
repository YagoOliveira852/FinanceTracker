import 'package:financas/core/api/erro_api.dart';
import 'package:financas/core/notificacoes/notificador.dart';
import 'package:financas/features/planejamento/data/lembretes_salario.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/notificador_falso.dart';
import '../../apoio/planejamento_falso.dart';

void main() {
  late NotificadorFalso notificador;
  late PlanejamentoRepositorioFalso repositorio;
  late LembretesSalario lembretes;

  void montar({DateTime? agora}) {
    notificador = NotificadorFalso(agora: agora);
    repositorio = PlanejamentoRepositorioFalso();
    lembretes = LembretesSalario(notificador, repositorio);
  }

  setUp(montar);

  group('agendar', () {
    test('renda ativa: lembrete às 9h da data efetiva', () async {
      await lembretes.agendar([rendaExemplo()]);

      expect(notificador.agendados, [
        Lembrete(
          id: 20261110,
          quando: DateTime(2026, 11, 10, 9),
          titulo: 'Dia de salário',
          corpo: 'Salário: veja quanto aportar e o ritmo dos gastos.',
        ),
      ]);
    });

    test('renda inativa não tem lembrete', () async {
      await lembretes.agendar([rendaExemplo(ativa: false), freelaExemplo()]);

      expect(notificador.agendados.map((l) => l.quando), [
        DateTime(2026, 11, 16, 9),
      ]);
    });

    test('rendas na mesma data viram um lembrete só', () async {
      await lembretes.agendar([
        rendaExemplo(id: 'a', descricao: 'Salário'),
        rendaExemplo(id: 'b', descricao: 'Vale-alimentação'),
        rendaExemplo(id: 'c', descricao: 'Bônus'),
        freelaExemplo(),
      ]);

      expect(notificador.agendados.map((l) => (l.id, l.corpo)), [
        (
          20261110,
          'Salário, Vale-alimentação e Bônus: veja quanto aportar e o ritmo '
              'dos gastos.',
        ),
        (20261116, 'Freela mensal: veja quanto aportar e o ritmo dos gastos.'),
      ]);
    });

    test('no dia do salário, agenda só antes das 9h', () async {
      montar(agora: DateTime(2026, 11, 10, 8, 59));
      await lembretes.agendar([rendaExemplo()]);
      expect(notificador.agendados, hasLength(1));

      montar(agora: DateTime(2026, 11, 10, 9));
      await lembretes.agendar([rendaExemplo(), freelaExemplo()]);
      expect(notificador.agendados.map((l) => l.id), [20261116]);
    });

    test('pede a permissão só com renda ativa', () async {
      await lembretes.agendar([rendaExemplo(ativa: false)]);
      expect(notificador.pedidosDePermissao, 0);
      expect(notificador.agendados, isEmpty);

      await lembretes.agendar([rendaExemplo()]);
      expect(notificador.pedidosDePermissao, 1);
    });

    test('permissão recusada: agenda mesmo assim', () async {
      notificador = NotificadorFalso(permite: false);
      lembretes = LembretesSalario(notificador, repositorio);

      await lembretes.agendar([rendaExemplo()]);

      expect(notificador.agendados, hasLength(1));
    });
  });

  group('reagendar', () {
    test('busca as rendas na API', () async {
      repositorio.rendas.add(freelaExemplo());

      await lembretes.reagendar();

      expect(notificador.agendados.map((l) => l.id), [20261116]);
    });

    test('erro da API mantém os lembretes que já estavam', () async {
      await lembretes.agendar([rendaExemplo()]);
      repositorio.erro = const ErroApi('Sem conexão com o servidor.');

      await lembretes.reagendar();

      expect(notificador.agendados.map((l) => l.id), [20261110]);
    });
  });

  test('cancelar tira todos os lembretes', () async {
    await lembretes.agendar([rendaExemplo()]);

    await lembretes.cancelar();

    expect(notificador.cancelamentos, 1);
    expect(notificador.agendados, isEmpty);
  });
}
