import 'package:financas/core/api/erro_api.dart';
import 'package:financas/features/contas/data/conta.dart';
import 'package:financas/features/open_finance/data/open_finance.dart';
import 'package:financas/features/open_finance/data/open_finance_repositorio.dart';

/// Banco Exemplo em dia: sincronizou hoje às 07:02 (10:02 UTC), alimenta a
/// Conta principal (`c1`). Valores fictícios.
Conexao conexaoExemplo({
  String id = 'x1',
  String instituicao = 'Banco Exemplo',
  bool ativa = true,
  ProblemaOpenFinance? problema,
  String? ultimoErro,
  DateTime? buscarAPartirDe,
  DateTime? consentimentoExpiraEm,
}) => Conexao(
  id: id,
  itemId: '8f3c2a91-5d4e-4b7a-9c1f-2e6d0a7b4c35',
  instituicao: instituicao,
  ativa: ativa,
  consentimentoExpiraEm: consentimentoExpiraEm ?? DateTime.utc(2027, 8, 15, 12),
  ultimoSyncEm: DateTime.utc(2026, 11, 4, 10, 2),
  ultimaTentativaEm: DateTime.utc(2026, 11, 4, 10, 2),
  ultimoErro: ultimoErro,
  proximoSync: ativa ? DateTime.utc(2026, 11, 5, 10) : null,
  buscarAPartirDe: buscarAPartirDe,
  problema: problema,
  contas: const [
    ContaDoApp(id: 'c1', nome: 'Conta principal', tipo: TipoConta.corrente),
  ],
);

/// Prévia do Banco Exemplo: conta corrente final 3456 (sugere a Conta
/// principal) e cartão final 5678 (sem sugestão).
PreviaConexao previaExemplo({bool cartaoPodeCriar = true}) => PreviaConexao(
  itemId: '8f3c2a91-5d4e-4b7a-9c1f-2e6d0a7b4c35',
  instituicao: 'Banco Exemplo',
  consentimentoExpiraEm: DateTime.utc(2027, 8, 15, 12),
  contas: [
    const ContaDaPrevia(
      pluggyAccountId: 'conta-1',
      tipo: TipoConta.corrente,
      nome: 'Conta corrente',
      numeroFinal: '3456',
      sugestao: ContaDoApp(
        id: 'c1',
        nome: 'Conta principal',
        tipo: TipoConta.corrente,
      ),
      podeCriar: true,
    ),
    ContaDaPrevia(
      pluggyAccountId: 'cartao-1',
      tipo: TipoConta.cartaoCredito,
      nome: 'Cartão Exemplo',
      numeroFinal: '5678',
      podeCriar: cartaoPodeCriar,
    ),
  ],
);

/// Repositório do Open Finance em memória. [erro] faz a próxima chamada falhar.
class OpenFinanceRepositorioFalso implements OpenFinanceRepositorio {
  OpenFinanceRepositorioFalso({ListaConexoes? lista, PreviaConexao? previa})
    : lista = lista ?? const ListaConexoes(),
      previaDevolvida = previa ?? previaExemplo();

  ListaConexoes lista;
  PreviaConexao previaDevolvida;
  ErroApi? erro;
  ResultadoBusca resultadoBusca = const ResultadoBusca(
    ok: true,
    novas: 3,
    atualizadas: 0,
  );
  final previas = <({String itemId, String? conexaoId})>[];
  final criadas = <({String itemId, List<Vinculo> vinculos})>[];
  final renovadas =
      <({String conexaoId, String itemId, List<Vinculo> vinculos})>[];
  final alteracoes = <({String conexaoId, bool ativa})>[];
  final buscas = <String>[];

  @override
  Future<ListaConexoes> listar() async {
    if (erro case final e?) throw e;
    return lista;
  }

  @override
  Future<PreviaConexao> previa(String itemId, {String? conexaoId}) async {
    previas.add((itemId: itemId, conexaoId: conexaoId));
    if (erro case final e?) throw e;
    return previaDevolvida;
  }

  @override
  Future<Conexao> criar(String itemId, List<Vinculo> vinculos) async {
    if (erro case final e?) throw e;
    criadas.add((itemId: itemId, vinculos: vinculos));
    return conexaoExemplo();
  }

  @override
  Future<Conexao> renovar(
    String conexaoId,
    String itemId,
    List<Vinculo> vinculos,
  ) async {
    if (erro case final e?) throw e;
    renovadas.add((conexaoId: conexaoId, itemId: itemId, vinculos: vinculos));
    return conexaoExemplo(id: conexaoId);
  }

  @override
  Future<Conexao> alterarAtiva(String conexaoId, {required bool ativa}) async {
    if (erro case final e?) throw e;
    alteracoes.add((conexaoId: conexaoId, ativa: ativa));
    lista = lista.copyWith(
      conexoes: [
        for (final c in lista.conexoes)
          c.id == conexaoId ? c.copyWith(ativa: ativa) : c,
      ],
    );
    return lista.conexoes.firstWhere((c) => c.id == conexaoId);
  }

  @override
  Future<ResultadoBusca> buscarAgora(String conexaoId) async {
    buscas.add(conexaoId);
    if (erro case final e?) throw e;
    return resultadoBusca;
  }
}
