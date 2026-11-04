"""Entrada e saída HTTP das conexões da Pluggy."""

import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.modulos.contas.models import TipoConta
from app.modulos.pluggy.problema import Problema
from app.modulos.pluggy.service import ContaDaPrevia, EstadoConexao, ListaConexoes, Previa
from app.modulos.pluggy.sync import ResultadoSync


class ContaDoAppSaida(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str
    tipo: TipoConta


class ConexaoSaida(BaseModel):
    id: uuid.UUID
    item_id: str
    instituicao: str = Field(description="Nome do banco (do conector da Pluggy).")
    status: str | None = Field(
        description="Como a Pluggy informa o item (UPDATED, LOGIN_ERROR...)."
    )
    ativa: bool
    consentimento_expira_em: datetime | None
    ultimo_sync_em: datetime | None = Field(description="Último sync bem-sucedido.")
    ultima_tentativa_em: datetime | None
    ultimo_erro: str | None = Field(description="Em português; nulo depois de um sucesso.")
    proximo_sync: datetime | None = Field(description="Próximo sync diário; nulo se desativada.")
    buscar_a_partir_de: datetime | None = Field(
        description="Quando o Buscar agora volta a valer (1×/hora); nulo se já vale."
    )
    problema: Problema | None = Field(description="Só nas ativas; nulo quando está tudo bem.")
    contas: list[ContaDoAppSaida] = Field(description="Contas do app que a conexão alimenta.")


class ProblemaSaida(BaseModel):
    problema: Problema
    conexao_id: uuid.UUID
    instituicao: str


class ListaConexoesSaida(BaseModel):
    conexoes: list[ConexaoSaida] = Field(description="Ativas primeiro, pela criação.")
    problema: ProblemaSaida | None = Field(
        description="O mais grave entre as ativas (vencido > erro > sem_dados > vencendo): o "
        "card do Início; nulo sem problema."
    )


class ItemEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    item_id: str = Field(min_length=1, max_length=100, description="ID do item MeuPluggy.")


class ContaDaPreviaSaida(BaseModel):
    pluggy_account_id: str
    tipo: TipoConta = Field(description="Tipo que a conta tem (ou teria) no app.")
    nome: str
    numero_final: str | None = Field(description="4 últimos dígitos do número.")
    sugestao: ContaDoAppSaida | None = Field(
        description="Conta do app sugerida pelo final do número; nula sem sugestão."
    )
    pode_criar: bool = Field(
        description="Falso no cartão sem fechamento na Pluggy: só vincular a um existente."
    )


class PreviaSaida(BaseModel):
    item_id: str
    instituicao: str
    consentimento_expira_em: datetime | None
    contas: list[ContaDaPreviaSaida]


class VinculoEntrada(BaseModel):
    model_config = ConfigDict(extra="forbid")

    pluggy_account_id: str
    conta_id: uuid.UUID | None = Field(description="Conta do app a alimentar; nulo = criar nova.")


class ConexaoEntrada(ItemEntrada):
    vinculos: list[VinculoEntrada] = Field(min_length=1)


class ConexaoEdicao(BaseModel):
    model_config = ConfigDict(extra="forbid")

    ativa: bool


class ResultadoSyncSaida(BaseModel):
    ok: bool
    erro: str | None
    novas: int
    atualizadas: int
    removidas: int = Field(description="Rascunhos que sumiram da Pluggy e foram apagados.")
    marcadas_removidas: int = Field(
        description="Confirmadas que sumiram da Pluggy (alerta na revisão)."
    )


def conexao_saida(estado: EstadoConexao) -> ConexaoSaida:
    conexao = estado.conexao
    return ConexaoSaida(
        id=conexao.id,
        item_id=conexao.item_id,
        instituicao=conexao.instituicao.nome,
        status=conexao.status,
        ativa=conexao.ativa,
        consentimento_expira_em=conexao.consentimento_expira_em,
        ultimo_sync_em=conexao.ultimo_sync_em,
        ultima_tentativa_em=conexao.ultima_tentativa_em,
        ultimo_erro=conexao.ultimo_erro,
        proximo_sync=estado.proximo_sync,
        buscar_a_partir_de=estado.buscar_a_partir_de,
        problema=estado.problema,
        contas=[ContaDoAppSaida.model_validate(c) for c in estado.contas],
    )


def lista_saida(lista: ListaConexoes) -> ListaConexoesSaida:
    problema = None
    if lista.problema is not None and lista.conexao_do_problema is not None:
        problema = ProblemaSaida(
            problema=lista.problema,
            conexao_id=lista.conexao_do_problema.id,
            instituicao=lista.conexao_do_problema.instituicao.nome,
        )
    return ListaConexoesSaida(
        conexoes=[conexao_saida(e) for e in lista.conexoes], problema=problema
    )


def _conta_da_previa(conta: ContaDaPrevia) -> ContaDaPreviaSaida:
    return ContaDaPreviaSaida(
        pluggy_account_id=conta.conta.id,
        tipo=TipoConta.cartao_credito if conta.conta.cartao else TipoConta.corrente,
        nome=conta.conta.nome,
        numero_final=conta.conta.numero_final,
        sugestao=None if conta.sugestao is None else ContaDoAppSaida.model_validate(conta.sugestao),
        pode_criar=conta.pode_criar,
    )


def previa_saida(previa: Previa) -> PreviaSaida:
    return PreviaSaida(
        item_id=previa.item.id,
        instituicao=previa.item.instituicao,
        consentimento_expira_em=previa.item.consentimento_expira_em,
        contas=[_conta_da_previa(c) for c in previa.contas],
    )


def resultado_saida(resultado: ResultadoSync) -> ResultadoSyncSaida:
    return ResultadoSyncSaida(
        ok=resultado.ok,
        erro=resultado.erro,
        novas=resultado.novas,
        atualizadas=resultado.atualizadas,
        removidas=resultado.removidas,
        marcadas_removidas=resultado.marcadas_removidas,
    )
