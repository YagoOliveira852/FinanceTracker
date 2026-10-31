import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/planejamento/data/planejamento.dart';
import 'package:financas/features/planejamento/data/planejamento_repositorio.dart';
import 'package:financas/features/planejamento/data/resumo.dart';

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
    Resumo? resumo,
  }) : rendas = rendas ?? [],
       leitura = leitura ?? const LeituraConfiguracao(),
       resumo = resumo ?? resumoSemSalario();

  final List<Renda> rendas;
  LeituraConfiguracao leitura;

  /// O que [lerResumo] devolve; troque para simular outra carga.
  Resumo resumo;
  var resumosLidos = 0;
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

  @override
  Future<Resumo> lerResumo() async {
    resumosLidos++;
    if (erro case final e?) throw e;
    return resumo;
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

/// Sem renda nem configuração: só o saldo (R\$ 3.180,10) e 2 rascunhos.
Resumo resumoSemSalario() =>
    Resumo(saldoDisponivel: Decimal.parse('3180.10'), rascunhos: 2);

/// Os estados do design "Início" (valores fictícios): saldo R\$ 3.180,10,
/// fatura do Cartão Exemplo de R\$ 1.032,15 vencendo em 10 nov, 21 dias até o
/// salário de terça, 10 nov, colchão R\$ 500,00, meta de 6 meses e gasto de
/// R\$ 3.000,00 por mês. [nivel] escolhe a sobra: no ritmo R\$ 1.307,95,
/// atenção R\$ 347,95 (pela média) ou risco − R\$ 252,05 (pela média).
Resumo resumoComPrevisao({
  NivelRitmo nivel = NivelRitmo.verde,
  int rascunhos = 2,
}) {
  final (gastos, sobra, pelaMedia) = switch (nivel) {
    NivelRitmo.verde => ('840.00', '1307.95', false),
    NivelRitmo.amarelo => ('1800.00', '347.95', true),
    NivelRitmo.vermelho => ('2400.00', '-252.05', true),
  };
  return Resumo(
    saldoDisponivel: Decimal.parse('3180.10'),
    rascunhos: rascunhos,
    previsao: Previsao(
      proximoSalario: DateTime(2026, 11, 10),
      diasAteSalario: 21,
      faturas: [
        FaturaReservada(
          cartaoId: 'k1',
          cartao: 'Cartão Exemplo',
          competencia: DateTime(2026, 11),
          vencimento: DateTime(2026, 11, 10),
          valor: Decimal.parse('1032.15'),
        ),
      ],
      gastosPrevistos: Decimal.parse(gastos),
      gastosPelaMedia: pelaMedia,
      sobra: Decimal.parse(sobra),
      nivel: nivel,
      colchao: Decimal.parse('500.00'),
    ),
    gastoMensal: GastoMensalReferencia(
      valor: Decimal.parse('3000.00'),
      automatico: true,
    ),
    metaReservaMeses: Decimal.parse('6.0'),
  );
}

/// Salário de R\$ 4.200,00 que caiu em 10 nov na Conta principal: aporte de
/// R\$ 2.319,80, próximo salário em 10 dez.
Resumo resumoSalarioRecebido({String aporte = '2319.80'}) => Resumo(
  saldoDisponivel: Decimal.parse('5430.10'),
  rascunhos: 2,
  previsao: Previsao(
    proximoSalario: DateTime(2026, 12, 10),
    diasAteSalario: 30,
    faturas: [
      FaturaReservada(
        cartaoId: 'k1',
        cartao: 'Cartão Exemplo',
        competencia: DateTime(2026, 12),
        vencimento: DateTime(2026, 12, 10),
        valor: Decimal.parse('1410.30'),
      ),
    ],
    gastosPrevistos: Decimal.parse('1200.00'),
    gastosPelaMedia: false,
    sobra: Decimal.parse('2819.80'),
    nivel: NivelRitmo.verde,
    colchao: Decimal.parse('500.00'),
    salarioRecebido: SalarioRecebido(
      rendaId: 'r1',
      descricao: 'Salário',
      contaId: 'c1',
      conta: 'Conta principal',
      dataEsperada: DateTime(2026, 11, 10),
      data: DateTime(2026, 11, 10),
      valor: Decimal.parse('4200.00'),
    ),
    aporte: Decimal.parse(aporte),
  ),
  gastoMensal: GastoMensalReferencia(
    valor: Decimal.parse('3000.00'),
    automatico: true,
  ),
  metaReservaMeses: Decimal.parse('6.0'),
);
