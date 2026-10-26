"""Rotas de faturas de um cartão. Só traduzem HTTP; as regras estão nos services.

A fatura é endereçada pela competência (`AAAA-MM`), não pelo id: ela pode
ainda não estar gravada (é calculada pela regra do cartão), e uma `GET` nunca
grava nada.
"""

import uuid
from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Path, status

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.cartoes import faturas, service
from app.modulos.cartoes.models import Cartao
from app.modulos.cartoes.schemas import (
    AjusteEntrada,
    DatasFaturaSaida,
    FaturaDetalheSaida,
    FaturaEdicao,
    ListaFaturasSaida,
    PagamentoEntrada,
    detalhe_saida,
    lista_saida,
)
from app.modulos.cartoes.service import CartaoNaoEncontrado

router = APIRouter(
    prefix="/cartoes/{conta_id}/faturas",
    tags=["faturas"],
    dependencies=[Depends(get_usuario_atual)],
    responses={
        status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro},
        status.HTTP_404_NOT_FOUND: {"model": RespostaErro},
    },
)

Competencia = Annotated[
    str,
    Path(pattern=r"^\d{4}-(0[1-9]|1[0-2])$", description="Mês da fatura, `AAAA-MM`."),
]


def _cartao(conta_id: uuid.UUID, sessao: SessaoDep) -> Cartao:
    try:
        return service.obter_cartao(sessao, conta_id)
    except CartaoNaoEncontrado as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Cartão não encontrado.") from exc


CartaoDep = Annotated[Cartao, Depends(_cartao)]


def _competencia(texto: str) -> date:
    ano, mes = texto.split("-")
    return date(int(ano), int(mes), 1)


@router.get("")
def listar(cartao: CartaoDep, sessao: SessaoDep, hoje: HojeDep) -> ListaFaturasSaida:
    """A fatura atual (a de uma compra feita hoje) e as gravadas antes e depois dela."""
    return lista_saida(faturas.listar(sessao, cartao, hoje))


# Antes de `/{competencia}`: senão "para-compra" seria lido como competência.
@router.get("/para-compra")
def para_compra(
    data: date, cartao: CartaoDep, sessao: SessaoDep, hoje: HojeDep
) -> DatasFaturaSaida:
    """Em que fatura entra uma compra feita em `data`."""
    competencia = service.competencia_para_data(sessao, cartao, data)
    resumo = faturas.resumo(sessao, cartao, competencia, hoje)
    return DatasFaturaSaida(
        competencia=resumo.competencia,
        data_fechamento=resumo.data_fechamento,
        data_vencimento=resumo.data_vencimento,
    )


@router.get("/{competencia}")
def obter(
    competencia: Competencia, cartao: CartaoDep, sessao: SessaoDep, hoje: HojeDep
) -> FaturaDetalheSaida:
    """Detalhe da fatura: datas efetivas e calculadas, valores e transações."""
    return detalhe_saida(faturas.detalhe(sessao, cartao, _competencia(competencia), hoje))


@router.put("/{competencia}")
def editar(
    competencia: Competencia,
    dados: FaturaEdicao,
    cartao: CartaoDep,
    sessao: SessaoDep,
    hoje: HojeDep,
) -> FaturaDetalheSaida:
    """Edita datas e valor informado; mudar o fechamento realoca compras."""
    detalhe = faturas.editar(
        sessao,
        cartao,
        _competencia(competencia),
        data_fechamento=dados.data_fechamento,
        data_vencimento=dados.data_vencimento,
        valor_informado=dados.valor_informado,
        hoje=hoje,
    )
    return detalhe_saida(detalhe)


@router.post("/{competencia}/ajuste")
def ajustar(
    competencia: Competencia,
    dados: AjusteEntrada,
    cartao: CartaoDep,
    sessao: SessaoDep,
    hoje: HojeDep,
) -> FaturaDetalheSaida:
    """Ajusta a fatura para o valor real: cria, substitui ou remove o ajuste."""
    detalhe = faturas.ajustar(
        sessao,
        cartao,
        _competencia(competencia),
        valor_real=dados.valor_real,
        descricao=dados.descricao,
        hoje=hoje,
    )
    return detalhe_saida(detalhe)


@router.post("/{competencia}/pagamentos", status_code=status.HTTP_201_CREATED)
def pagar(
    competencia: Competencia,
    dados: PagamentoEntrada,
    cartao: CartaoDep,
    sessao: SessaoDep,
    hoje: HojeDep,
) -> FaturaDetalheSaida:
    """Registra um pagamento da fatura (não é gasto); devolve o detalhe."""
    detalhe = faturas.pagar(
        sessao,
        cartao,
        _competencia(competencia),
        conta_id=dados.conta_id,
        valor=dados.valor,
        data=dados.data,
        hoje=hoje,
    )
    return detalhe_saida(detalhe)
