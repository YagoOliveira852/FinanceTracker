"""Rotas de cartões. Só traduzem HTTP; as regras estão no service."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from fastapi.exceptions import RequestValidationError

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.cartoes import service
from app.modulos.cartoes.schemas import CartaoEntrada, DatasFaturaSaida
from app.modulos.contas import service as contas_service
from app.modulos.contas.router import conta_saida
from app.modulos.contas.schemas import ContaSaida

router = APIRouter(
    prefix="/cartoes",
    tags=["cartoes"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)

Dia = Annotated[int, Query(ge=1, le=31)]


@router.post("", status_code=status.HTTP_201_CREATED)
def criar(dados: CartaoEntrada, sessao: SessaoDep, hoje: HojeDep) -> ContaSaida:
    """Cadastra um cartão de crédito: a conta e os dados do cartão."""
    cartao = service.criar_cartao(
        sessao,
        nome=dados.nome,
        nome_instituicao=dados.instituicao,
        conta_pagamento_id=dados.conta_pagamento_id,
        dia_fechamento=dados.dia_fechamento,
        dia_vencimento=dados.dia_vencimento,
        limite=dados.limite,
        hoje=hoje,
    )
    return conta_saida(sessao, contas_service.obter_conta(sessao, cartao.conta_id), hoje)


@router.get("/previa")
def previa(
    dia_fechamento: Dia, dia_vencimento: Dia, sessao: SessaoDep, hoje: HojeDep
) -> DatasFaturaSaida:
    """Próxima fatura (a de uma compra feita hoje) para dias ainda não salvos."""
    if dia_fechamento == dia_vencimento:
        raise RequestValidationError(
            [
                {
                    "type": "dias_iguais",
                    "loc": ("query", "dia_vencimento"),
                    "msg": "O vencimento precisa ser num dia diferente do fechamento.",
                    "input": dia_vencimento,
                }
            ]
        )
    datas = service.previa(
        sessao, dia_fechamento=dia_fechamento, dia_vencimento=dia_vencimento, hoje=hoje
    )
    return DatasFaturaSaida(
        competencia=datas.competencia,
        data_fechamento=datas.fechamento,
        data_vencimento=datas.vencimento,
    )
