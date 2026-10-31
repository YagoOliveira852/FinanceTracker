import '../core/api/cliente_api.dart';
import '../core/api/interceptor_auth.dart';
import '../core/auth/armazenamento_tokens.dart';
import '../core/notificacoes/notificador.dart';
import '../core/notificacoes/notificador_local.dart';
import '../features/categorias/data/categorias_repositorio.dart';
import '../features/configuracoes/cubit/tema_cubit.dart';
import '../features/configuracoes/data/preferencia_tema.dart';
import '../features/contas/data/contas_repositorio.dart';
import '../features/faturas/data/faturas_repositorio.dart';
import '../features/importacao/data/arquivos.dart';
import '../features/importacao/data/importacoes_repositorio.dart';
import '../features/inicio/data/aporte_dispensado.dart';
import '../features/login/cubit/sessao_cubit.dart';
import '../features/login/data/auth_repositorio.dart';
import '../features/planejamento/data/lembretes_salario.dart';
import '../features/planejamento/data/planejamento_repositorio.dart';
import '../features/revisao/data/revisao_repositorio.dart';
import '../features/transacoes/data/transacoes_repositorio.dart';

/// Monta os objetos de longa duração do app: repositórios, a sessão e os
/// lembretes.
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
    required this.planejamento,
    required this.importacoes,
    required this.seletorArquivo,
    required this.compartilhamento,
    required PreferenciaTema preferenciaTema,
    required this.aporteDispensado,
    required this.notificador,
  }) : sessao = SessaoCubit(auth),
       tema = TemaCubit(preferenciaTema),
       lembretes = LembretesSalario(notificador, planejamento);

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
      planejamento: PlanejamentoRepositorioApi(cliente),
      importacoes: ImportacoesRepositorioApi(cliente),
      seletorArquivo: SeletorArquivoSistema(),
      compartilhamento: FonteCompartilhamentoSistema(),
      preferenciaTema: PreferenciaTemaLocal(),
      aporteDispensado: AporteDispensadoLocal(),
      notificador: NotificadorLocal(),
    );
  }

  final AuthRepositorio auth;
  final ContasRepositorio contas;
  final TransacoesRepositorio transacoes;
  final FaturasRepositorio faturas;
  final CategoriasRepositorio categorias;
  final RevisaoRepositorio revisao;
  final PlanejamentoRepositorio planejamento;
  final ImportacoesRepositorio importacoes;
  final SeletorArquivo seletorArquivo;

  /// Extratos recebidos pelo Compartilhar de outro app.
  final FonteCompartilhamento compartilhamento;

  /// O último salário cujo aporte sugerido foi dispensado ("Agora não").
  final AporteDispensado aporteDispensado;

  /// Notificações locais; [iniciar](Notificador.iniciar) antes do app.
  final Notificador notificador;
  final SessaoCubit sessao;
  final TemaCubit tema;

  /// Lembretes nos dias de salário: reagendados a cada login e abertura com
  /// sessão e a cada carga do Planejamento; cancelados ao sair.
  final LembretesSalario lembretes;
}
