import '../../../app/widgets/campos.dart';
import '../data/categoria.dart';

/// A categoria como opção de um [CampoSelecao]: o grupo vai no detalhe.
OpcaoSelecao<String> opcaoDeCategoria(Categoria categoria) => OpcaoSelecao(
  valor: categoria.id,
  rotulo: categoria.nome,
  detalhe: categoria.grupo.rotulo,
);
