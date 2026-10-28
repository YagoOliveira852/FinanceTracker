import '../core/api/cliente_api.dart';
import '../core/api/interceptor_auth.dart';
import '../core/auth/armazenamento_tokens.dart';
import '../features/categorias/data/categorias_repositorio.dart';
import '../features/contas/data/contas_repositorio.dart';
import '../features/faturas/data/faturas_repositorio.dart';
import '../features/importacao/data/arquivos.dart';
import '../features/importacao/data/importacoes_repositorio.dart';
import '../features/login/cubit/sessao_cubit.dart';
import '../features/login/data/auth_repositorio.dart';
import '../features/revisao/data/revisao_repositorio.dart';
import '../features/transacoes/data/transacoes_repositorio.dart';

/// Monta os objetos de longa duração do app: repositórios e a sessão.
///
/// É o equivalente ao `create_app()` de um projeto Flask: tudo é criado num
/// lugar só e entregue às telas pelos providers em `app.dart`. Nos testes, o
/// construtor recebe repositórios falsos.
class Dependencias {
  Dependencias({
    required this.auth,
    required this.contas,
    required this.transacoes,
    required this.faturas,
    required this.categorias,
    required this.revisao,
    required this.importacoes,
    required this.seletorArquivo,
    required this.compartilhamento,
  }) : sessao = SessaoCubit(auth);

  /// Dependências reais, falando com a API em [baseUrl].
  factory Dependencias.api({String baseUrl = urlApi}) {
    final armazenamento = ArmazenamentoTokensSeguro();
    // O interceptor avisa a sessão, que só existe depois do construtor.
    late final Dependencias dependencias;
    final cliente = criarClienteApi(
      dio: criarDio(baseUrl: baseUrl),
      interceptors: [
        InterceptorAuth(
          armazenamento: armazenamento,
          dioSemAuth: criarDio(baseUrl: baseUrl),
          aoExpirarSessao: () => dependencias.sessao.expirou(),
        ),
      ],
    );
    return dependencias = Dependencias(
      auth: AuthRepositorioApi(cliente, armazenamento),
      contas: ContasRepositorioApi(cliente),
      transacoes: TransacoesRepositorioApi(cliente),
      faturas: FaturasRepositorioApi(cliente),
      categorias: CategoriasRepositorioApi(cliente),
      revisao: RevisaoRepositorioApi(cliente),
      importacoes: ImportacoesRepositorioApi(cliente),
      seletorArquivo: SeletorArquivoSistema(),
      compartilhamento: FonteCompartilhamentoSistema(),
    );
  }

  final AuthRepositorio auth;
  final ContasRepositorio contas;
  final TransacoesRepositorio transacoes;
  final FaturasRepositorio faturas;
  final CategoriasRepositorio categorias;
  final RevisaoRepositorio revisao;
  final ImportacoesRepositorio importacoes;
  final SeletorArquivo seletorArquivo;

  /// Extratos recebidos pelo Compartilhar de outro app.
  final FonteCompartilhamento compartilhamento;
  final SessaoCubit sessao;
}
