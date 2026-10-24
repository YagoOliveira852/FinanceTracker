import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/faturas/data/fatura.dart';
import 'package:financas/features/faturas/data/faturas_repositorio.dart';

/// Repositório de faturas em memória, com a regra do exemplo (fecha dia 3,
/// vence dia 10): compra até 4 de outubro cai em outubro; depois, em novembro.
class FaturasRepositorioFalso implements FaturasRepositorio {
  final consultasParaCompra = <({String contaId, DateTime data})>[];
  ErroApi? erro;

  @override
  Future<DatasFatura> paraCompra(String contaId, DateTime data) async {
    consultasParaCompra.add((contaId: contaId, data: data));
    if (erro case final e?) throw e;
    final outubro = data.isBefore(DateTime(2026, 10, 5));
    return outubro
        ? DatasFatura(
            competencia: DateTime(2026, 10),
            dataFechamento: DateTime(2026, 10, 5),
            dataVencimento: DateTime(2026, 10, 13),
          )
        : DatasFatura(
            competencia: DateTime(2026, 11),
            dataFechamento: DateTime(2026, 11, 3),
            dataVencimento: DateTime(2026, 11, 10),
          );
  }
}
