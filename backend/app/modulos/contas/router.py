"""Rotas de contas. Só traduzem HTTP; as regras estão no service."""

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.cartoes import faturas
from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.schemas import CartaoSaida, resumo_saida
from app.modulos.contas import service
from app.modulos.contas.models import TipoConta
from app.modulos.contas.schemas import ContaEntrada, ContaSaida, ContasResumo, InstituicaoSaida

# `dependencies` no router: toda rota daqui exige o access token, sem repetir
# `UsuarioDep` em cada uma (as rotas não precisam do usuário em si).
router = APIRouter(
    prefix="/contas",
    tags=["contas"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}


@router.get("")
def listar(sessao: SessaoDep, hoje: HojeDep) -> ContasResumo:
    """Todas as contas com o saldo atual, e o total disponível (correntes e carteiras).
    Cartões trazem também a fatura atual."""
    resumo = service.listar_contas(sessao)
    return ContasResumo(
        total_disponivel=resumo.total_disponivel,
        contas=[conta_saida(sessao, conta, hoje) for conta in resumo.contas],
    )


@router.post("", status_code=status.HTTP_201_CREATED)
def criar(dados: ContaEntrada, sessao: SessaoDep, hoje: HojeDep) -> ContaSaida:
    """Cadastra uma conta corrente ou a carteira (dinheiro em espécie)."""
    conta = service.criar_conta(
        sessao,
        nome=dados.nome,
        tipo=dados.tipo,
        nome_instituicao=dados.instituicao,
        saldo_inicial=dados.saldo_inicial,
        data_saldo_inicial=dados.data_saldo_inicial,
        hoje=hoje,
    )
    return conta_saida(sessao, conta, hoje)


@router.get("/{conta_id}", responses=_NAO_ENCONTRADA)
def obter(conta_id: uuid.UUID, sessao: SessaoDep, hoje: HojeDep) -> ContaSaida:
    try:
        conta = service.obter_conta(sessao, conta_id)
    except service.ContaNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Conta não encontrada.") from exc
    return conta_saida(sessao, conta, hoje)


def conta_saida(sessao: Session, item: service.ContaComSaldo, hoje: date) -> ContaSaida:
    """Monta a saída da conta; também usada pelas rotas de cartões."""
    conta = item.conta
    instituicao = conta.instituicao
    return ContaSaida(
        id=conta.id,
        nome=conta.nome,
        tipo=conta.tipo,
        instituicao=InstituicaoSaida.model_validate(instituicao) if instituicao else None,
        saldo_inicial=conta.saldo_inicial,
        data_saldo_inicial=conta.data_saldo_inicial,
        saldo_atual=item.saldo_atual,
        ativa=conta.ativa,
        cartao=_cartao_saida(sessao, conta.id, hoje)
        if conta.tipo == TipoConta.cartao_credito
        else None,
    )


def _cartao_saida(sessao: Session, conta_id: uuid.UUID, hoje: date) -> CartaoSaida:
    cartao = cartoes_service.obter_cartao(sessao, conta_id)
    return CartaoSaida(
        conta_pagamento_id=cartao.conta_pagamento_id,
        dia_fechamento=cartao.dia_fechamento,
        dia_vencimento=cartao.dia_vencimento,
        limite=cartao.limite,
        fatura_atual=resumo_saida(faturas.resumo_atual(sessao, cartao, hoje)),
    )
