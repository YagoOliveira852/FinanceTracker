import '../../../core/api/erro_api.dart';
import '../../../core/notificacoes/notificador.dart';
import 'planejamento.dart';
import 'planejamento_repositorio.dart';

/// Lembrete local nos dias de salário: às 9h (fuso de negócio) da próxima
/// data efetiva de cada renda ativa, uma notificação por data. O toque abre o
/// app no Início, onde estão o aporte e o alerta.
///
/// Agenda só a próxima data de cada renda, a que a API já devolve: o app
/// reagenda a cada abertura com sessão e a cada carga do Planejamento.
class LembretesSalario {
  LembretesSalario(this._notificador, this._planejamento);

  /// Hora do lembrete: depois do sync da Pluggy das 7h.
  static const hora = 9;

  final Notificador _notificador;
  final PlanejamentoRepositorio _planejamento;

  /// Troca os lembretes agendados pelos de [rendas].
  Future<void> agendar(List<Renda> rendas) async {
    // Recusada, os lembretes ficam agendados e só não aparecem.
    if (rendas.any((renda) => renda.ativa)) await _notificador.pedirPermissao();
    final agora = _notificador.agora();
    final porHorario = <DateTime, List<String>>{};
    for (final renda in rendas) {
      final data = renda.proxima.data;
      final quando = DateTime(data.year, data.month, data.day, hora);
      // Depois das 9h do dia do salário, o do mês seguinte entra na próxima
      // abertura, quando a API já devolver a data seguinte.
      if (!renda.ativa || !quando.isAfter(agora)) continue;
      porHorario.putIfAbsent(quando, () => []).add(renda.descricao);
    }
    await _notificador.substituirAgendados([
      for (final MapEntry(key: quando, value: descricoes) in porHorario.entries)
        Lembrete(
          id: _id(quando),
          quando: quando,
          titulo: 'Dia de salário',
          // Sem valores: a notificação aparece na tela bloqueada.
          corpo:
              '${_juntar(descricoes)}: veja quanto aportar e o ritmo dos '
              'gastos.',
        ),
    ]);
  }

  /// Busca as rendas e agenda. Sem conexão, mantém os lembretes que já
  /// estavam: eles continuam valendo até a próxima abertura.
  Future<void> reagendar() async {
    final List<Renda> rendas;
    try {
      rendas = await _planejamento.listarRendas();
    } on ErroApi {
      return;
    }
    await agendar(rendas);
  }

  /// Ao sair: nenhum lembrete fica para a próxima sessão.
  Future<void> cancelar() => _notificador.cancelarTodos();

  /// A data em AAAAMMDD: estável entre reagendamentos.
  static int _id(DateTime data) =>
      data.year * 10000 + data.month * 100 + data.day;

  /// "A", "A e B", "A, B e C".
  static String _juntar(List<String> itens) => itens.length == 1
      ? itens.single
      : '${itens.sublist(0, itens.length - 1).join(', ')} e ${itens.last}';
}
