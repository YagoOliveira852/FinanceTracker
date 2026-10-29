import '../../../app/widgets/campos.dart';
import '../data/conta.dart';

/// A conta como opção de um [CampoSelecao]: na folha, a instituição vai no
/// detalhe; no campo, "Conta principal · Banco Exemplo".
OpcaoSelecao<String> opcaoDeConta(Conta conta) => OpcaoSelecao(
  valor: conta.id,
  rotulo: conta.nome,
  detalhe: conta.instituicao,
  resumo: conta.instituicao == null
      ? null
      : '${conta.nome} · ${conta.instituicao}',
);
