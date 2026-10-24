import 'package:decimal/decimal.dart';
import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/faturas/data/faturas_repositorio.dart';

import 'transacoes_falso.dart';

/// Faturas do cartão do exemplo (fecha dia 3, vence dia 10), com hoje em
/// 20/10/2026: outubro fechada (com diferença), novembro aberta, dezembro
/// com parcela.
final outubroExemplo = ResumoFatura(
  competencia: DateTime(2026, 10),
  dataFechamento: DateTime(2026, 10, 5),
  dataVencimento: DateTime(2026, 10, 13),
  status: StatusFatura.fechada,
  valor: Decimal.parse('1032.15'),
  valorCalculado: Decimal.parse('986.25'),
  valorInformado: Decimal.parse('1032.15'),
);

final novembroExemplo = ResumoFatura(
  competencia: DateTime(2026, 11),
  dataFechamento: DateTime(2026, 11, 3),
  dataVencimento: DateTime(2026, 11, 10),
  status: StatusFatura.aberta,
  valor: Decimal.parse('544.80'),
  valorCalculado: Decimal.parse('544.80'),
);

final dezembroExemplo = ResumoFatura(
  competencia: DateTime(2026, 12),
  dataFechamento: DateTime(2026, 12, 3),
  dataVencimento: DateTime(2026, 12, 10),
  status: StatusFatura.aberta,
  valor: Decimal.parse('249.90'),
  valorCalculado: Decimal.parse('249.90'),
);

final listaExemplo = ListaFaturas(
  atual: novembroExemplo,
  proximas: [dezembroExemplo],
  anteriores: [outubroExemplo],
);

DetalheFatura detalheExemplo(ResumoFatura resumo) {
  final outubro = resumo.competencia == DateTime(2026, 10);
  return DetalheFatura(
    resumo: resumo,
    fechamentoCalculado: resumo.dataFechamento,
    vencimentoCalculado: resumo.dataVencimento,
    ajusteFechamento: outubro
        ? AjusteData(dataPrevista: DateTime(2026, 10, 3), feriados: const {})
        : null,
    ajusteVencimento: outubro
        ? AjusteData(
            dataPrevista: DateTime(2026, 10, 10),
            feriados: {DateTime(2026, 10, 12): 'Nossa Senhora Aparecida'},
          )
        : null,
    transacoes: [
      transacaoExemplo(
        id: 'compra-${resumo.competencia.month}',
        contaId: 'k1',
        valor: '150.00',
        data: resumo.dataFechamento.subtract(const Duration(days: 3)),
        descricao: 'Posto Fictício',
      ),
    ],
  );
}

/// Repositório de faturas em memória. [erro] faz a próxima chamada falhar.
class FaturasRepositorioFalso implements FaturasRepositorio {
  final consultasParaCompra = <({String contaId, DateTime data})>[];
  final edicoes =
      <
        ({
          DateTime competencia,
          DateTime dataFechamento,
          DateTime dataVencimento,
          Decimal? valorInformado,
        })
      >[];
  final ajustes = <({Decimal valorReal, String? descricao})>[];
  final obtidas = <DateTime>[];
  ErroApi? erro;

  @override
  Future<ListaFaturas> listar(String contaId) async {
    if (erro case final e?) throw e;
    return listaExemplo;
  }

  @override
  Future<DetalheFatura> obter(String contaId, DateTime competencia) async {
    obtidas.add(competencia);
    if (erro case final e?) throw e;
    return detalheExemplo(
      listaExemplo.emOrdem.firstWhere((f) => f.competencia == competencia),
    );
  }

  @override
  Future<DetalheFatura> editar(
    String contaId,
    DateTime competencia, {
    required DateTime dataFechamento,
    required DateTime dataVencimento,
    Decimal? valorInformado,
  }) async {
    if (erro case final e?) throw e;
    edicoes.add((
      competencia: competencia,
      dataFechamento: dataFechamento,
      dataVencimento: dataVencimento,
      valorInformado: valorInformado,
    ));
    final atual = await obter(contaId, competencia);
    return atual.copyWith(
      resumo: atual.resumo.copyWith(
        dataFechamento: dataFechamento,
        dataVencimento: dataVencimento,
        valorInformado: valorInformado,
      ),
    );
  }

  @override
  Future<DetalheFatura> ajustar(
    String contaId,
    DateTime competencia, {
    required Decimal valorReal,
    String? descricao,
  }) async {
    if (erro case final e?) throw e;
    ajustes.add((valorReal: valorReal, descricao: descricao));
    final atual = await obter(contaId, competencia);
    return atual.copyWith(
      resumo: atual.resumo.copyWith(
        valor: valorReal,
        valorCalculado: valorReal,
        valorInformado: valorReal,
      ),
    );
  }

  @override
  Future<DatasFatura> paraCompra(String contaId, DateTime data) async {
    consultasParaCompra.add((contaId: contaId, data: data));
    if (erro case final e?) throw e;
    final outubro = data.isBefore(DateTime(2026, 10, 5));
    final resumo = outubro ? outubroExemplo : novembroExemplo;
    return DatasFatura(
      competencia: resumo.competencia,
      dataFechamento: resumo.dataFechamento,
      dataVencimento: resumo.dataVencimento,
    );
  }
}
