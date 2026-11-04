"""Rotas das conexões da Pluggy. Só traduzem HTTP; as regras estão no service.

As rotas de escrita gravam só no nosso banco: na Pluggy, só leitura.
"""

import uuid
from collections.abc import Iterator
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import AgoraDep, ConfigDep, HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.pluggy import service
from app.modulos.pluggy.client import ClientePluggy
from app.modulos.pluggy.schemas import (
    ConexaoEdicao,
    ConexaoEntrada,
    ConexaoSaida,
    ItemEntrada,
    ListaConexoesSaida,
    PreviaSaida,
    ResultadoSyncSaida,
    conexao_saida,
    lista_saida,
    previa_saida,
    resultado_saida,
)
from app.modulos.pluggy.service import Vinculo

router = APIRouter(
    prefix="/pluggy",
    tags=["pluggy"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}


def get_fonte_pluggy(config: ConfigDep) -> Iterator[service.FonteConexoes]:
    """O cliente da Pluggy, só leitura; os testes o trocam por um falso."""
    segredo = config.pluggy_client_secret
    if not config.pluggy_client_id or segredo is None or not segredo.get_secret_value():
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="O Open Finance não está configurado no servidor.",
        )
    with ClientePluggy(
        config.pluggy_client_id, segredo.get_secret_value(), config.pluggy_url
    ) as cliente:
        yield cliente


FonteDep = Annotated[service.FonteConexoes, Depends(get_fonte_pluggy)]


def _estado(sessao: SessaoDep, config: ConfigDep, agora, conexao_id: uuid.UUID) -> ConexaoSaida:
    lista = service.listar(sessao, agora=agora, fuso=ZoneInfo(config.tz_negocio))
    return conexao_saida(next(e for e in lista.conexoes if e.conexao.id == conexao_id))


def _nao_encontrada(exc: Exception) -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, detail="Conexão não encontrada.")


@router.get("/conexoes")
def listar(sessao: SessaoDep, config: ConfigDep, agora: AgoraDep) -> ListaConexoesSaida:
    """Conexões com o estado do sync e o problema mais grave (card do Início)."""
    return lista_saida(service.listar(sessao, agora=agora, fuso=ZoneInfo(config.tz_negocio)))


@router.post("/conexoes/previa")
def previa(dados: ItemEntrada, sessao: SessaoDep, fonte: FonteDep) -> PreviaSaida:
    """Valida o item na Pluggy e lista as contas com a sugestão de vínculo. Não grava."""
    return previa_saida(service.previa(sessao, fonte, dados.item_id))


@router.post("/conexoes", status_code=status.HTTP_201_CREATED)
def criar(
    dados: ConexaoEntrada,
    sessao: SessaoDep,
    fonte: FonteDep,
    config: ConfigDep,
    hoje: HojeDep,
    agora: AgoraDep,
) -> ConexaoSaida:
    """Cadastra a conexão e vincula as contas (cria as novas)."""
    conexao = service.criar(
        sessao, fonte, item_id=dados.item_id, vinculos=_vinculos(dados), hoje=hoje
    )
    return _estado(sessao, config, agora, conexao.id)


@router.post("/conexoes/{conexao_id}/renovacao/previa", responses=_NAO_ENCONTRADA)
def previa_renovacao(
    conexao_id: uuid.UUID, dados: ItemEntrada, sessao: SessaoDep, fonte: FonteDep
) -> PreviaSaida:
    """Prévia da renovação: o item pode ser o mesmo; sugere as contas que a
    conexão já alimentava."""
    try:
        return previa_saida(service.previa_da_renovacao(sessao, fonte, conexao_id, dados.item_id))
    except service.ConexaoNaoEncontrada as exc:
        raise _nao_encontrada(exc) from exc


@router.post("/conexoes/{conexao_id}/renovacao", responses=_NAO_ENCONTRADA)
def renovar(
    conexao_id: uuid.UUID,
    dados: ConexaoEntrada,
    sessao: SessaoDep,
    fonte: FonteDep,
    config: ConfigDep,
    hoje: HojeDep,
    agora: AgoraDep,
) -> ConexaoSaida:
    """Associa o item renovado à conexão, com os vínculos confirmados."""
    try:
        service.renovar(
            sessao,
            fonte,
            conexao_id,
            item_id=dados.item_id,
            vinculos=_vinculos(dados),
            agora=agora,
            hoje=hoje,
        )
    except service.ConexaoNaoEncontrada as exc:
        raise _nao_encontrada(exc) from exc
    return _estado(sessao, config, agora, conexao_id)


@router.put("/conexoes/{conexao_id}", responses=_NAO_ENCONTRADA)
def editar(
    conexao_id: uuid.UUID,
    dados: ConexaoEdicao,
    sessao: SessaoDep,
    fonte: FonteDep,
    config: ConfigDep,
    agora: AgoraDep,
) -> ConexaoSaida:
    """Desativa (o sync para; as contas continuam) ou reativa (confere o item)."""
    try:
        service.alterar_ativa(sessao, fonte, conexao_id, ativa=dados.ativa)
    except service.ConexaoNaoEncontrada as exc:
        raise _nao_encontrada(exc) from exc
    return _estado(sessao, config, agora, conexao_id)


@router.post(
    "/conexoes/{conexao_id}/sync",
    responses={**_NAO_ENCONTRADA, status.HTTP_429_TOO_MANY_REQUESTS: {"model": RespostaErro}},
)
def buscar_agora(
    conexao_id: uuid.UUID,
    sessao: SessaoDep,
    fonte: FonteDep,
    config: ConfigDep,
    hoje: HojeDep,
    agora: AgoraDep,
) -> ResultadoSyncSaida:
    """Roda o nosso sync para a conexão, no máximo 1×/hora. A Pluggy atualiza
    os dados uma vez por dia."""
    fuso = ZoneInfo(config.tz_negocio)
    try:
        resultado = service.buscar_agora(
            sessao, fonte, conexao_id, agora=agora, hoje=hoje, fuso=fuso
        )
    except service.ConexaoNaoEncontrada as exc:
        raise _nao_encontrada(exc) from exc
    except service.BuscarMaisTarde as exc:
        hora = exc.pode_em.astimezone(fuso).strftime("%H:%M")
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Já buscou há pouco. Dá para buscar de novo a partir das {hora}.",
        ) from exc
    return resultado_saida(resultado)


def _vinculos(dados: ConexaoEntrada) -> list[Vinculo]:
    return [
        Vinculo(pluggy_account_id=v.pluggy_account_id, conta_id=v.conta_id) for v in dados.vinculos
    ]
