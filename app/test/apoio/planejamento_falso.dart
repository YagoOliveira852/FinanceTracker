import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:financas/features/planejamento/data/planejamento_repositorio.dart';

/// Salário de R$ 4.200,00 no dia 10 da Conta principal (`c1`); próxima em
/// terça, 10 nov.
Renda rendaExemplo({
  String id = 'r1',
  String descricao = 'Salário',
  String valor = '4200.00',
  int dia = 10,
  String contaId = 'c1',
  bool ativa = true,
  ProximaData? proxima,
}) => Renda(
  id: id,
  descricao: descricao,
  valor: Decimal.parse(valor),
  diaPrevisto: dia,
  contaId: contaId,
  ativa: ativa,
  proxima:
      proxima ??
      ProximaData(
        data: DateTime(2026, 11, dia),
        dataPrevista: DateTime(2026, 11, dia),
      ),
);

/// Freela no dia 15 (domingo e feriado): próxima em segunda, 16 nov.
Renda freelaExemplo() => rendaExemplo(
  id: 'r2',
  descricao: 'Freela mensal',
  valor: '600.00',
  dia: 15,
  proxima: ProximaData(
    data: DateTime(2026, 11, 16),
    dataPrevista: DateTime(2026, 11, 15),
    feriados: {DateTime(2026, 11, 15): 'Proclamação da República'},
  ),
);

/// Colchão R$ 500, gasto semanal R$ 280, meta de 6 meses, gasto mensal
/// automático (R$ 3.000,00, de jul a set), média real R$ 252 e 4,2 meses.
LeituraConfiguracao leituraExemplo({bool salva = true, String? mensalFixo}) =>
    LeituraConfiguracao(
      configuracao: salva
          ? Configuracao(
              colchao: Decimal.parse('500'),
              metaReservaMeses: Decimal.parse('6'),
              gastoSemanalEstimado: Decimal.parse('280'),
              gastoMensalReferencia: mensalFixo == null
                  ? null
                  : Decimal.parse(mensalFixo),
            )
          : null,
      gastoMensalAutomatico: GastoMensal(
        valor: Decimal.parse('3000'),
        meses: [DateTime(2026, 7), DateTime(2026, 8), DateTime(2026, 9)],
      ),
      mediaSemanalReal: Decimal.parse('252'),
      mesesDeReserva: Decimal.parse('4.2'),
    );

/// Prévia que o falso devolve para qualquer dia: o dia em novembro.
ProximaData previaRendaExemplo(int dia) => ProximaData(
  data: DateTime(2026, 11, dia),
  dataPrevista: DateTime(2026, 11, dia),
);

/// Repositório do planejamento em memória. [erro] faz a próxima chamada falhar.
class PlanejamentoRepositorioFalso implements PlanejamentoRepositorio {
  PlanejamentoRepositorioFalso({
    List<Renda>? rendas,
    LeituraConfiguracao? leitura,
  }) : rendas = rendas ?? [],
       leitura = leitura ?? const LeituraConfiguracao();

  final List<Renda> rendas;
  LeituraConfiguracao leitura;
  final criadas = <DadosRenda>[];
  final editadas = <({String id, DadosRenda dados})>[];
  final previas = <int>[];
  final configuracoesSalvas = <Configuracao>[];
  ErroApi? erro;

  @override
  Future<List<Renda>> listarRendas() async {
    if (erro case final e?) throw e;
    return List.of(rendas);
  }

  @override
  Future<Renda> criarRenda(DadosRenda dados) async {
    if (erro case final e?) throw e;
    criadas.add(dados);
    final renda = _renda('nova-${criadas.length}', dados);
    rendas.add(renda);
    return renda;
  }

  @override
  Future<Renda> editarRenda(String id, DadosRenda dados) async {
    if (erro case final e?) throw e;
    editadas.add((id: id, dados: dados));
    final renda = _renda(id, dados);
    rendas[rendas.indexWhere((r) => r.id == id)] = renda;
    return renda;
  }

  @override
  Future<ProximaData> previaRenda(int diaPrevisto) async {
    previas.add(diaPrevisto);
    if (erro case final e?) throw e;
    return previaRendaExemplo(diaPrevisto);
  }

  @override
  Future<LeituraConfiguracao> lerConfiguracao() async {
    if (erro case final e?) throw e;
    return leitura;
  }

  @override
  Future<LeituraConfiguracao> salvarConfiguracao(
    Configuracao configuracao,
  ) async {
    if (erro case final e?) throw e;
    configuracoesSalvas.add(configuracao);
    return leitura = leitura.copyWith(configuracao: configuracao);
  }

  static Renda _renda(String id, DadosRenda dados) => Renda(
    id: id,
    descricao: dados.descricao,
    valor: dados.valor,
    diaPrevisto: dados.diaPrevisto,
    contaId: dados.contaId,
    ativa: dados.ativa,
    proxima: previaRendaExemplo(dados.diaPrevisto.clamp(1, 30)),
  );
}
