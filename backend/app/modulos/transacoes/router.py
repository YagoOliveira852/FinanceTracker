"""Rotas de transações. Só traduzem HTTP; as regras estão no service."""

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.exceptions import RequestValidationError

from app.core.deps import SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.transacoes import service
from app.modulos.transacoes.schemas import (
    CompraParceladaEntrada,
    CompraParceladaSaida,
    TransacaoEntrada,
    TransacaoSaida,
    TransferenciaEntrada,
    TransferenciaSaida,
)

router = APIRouter(
    prefix="/transacoes",
    tags=["transacoes"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.post("", status_code=status.HTTP_201_CREATED)
def lancar(dados: TransacaoEntrada, sessao: SessaoDep) -> TransacaoSaida:
    """Lançamento manual de despesa ou receita, já confirmado."""
    transacao = service.lancar(
        sessao,
        conta_id=dados.conta_id,
        tipo=dados.tipo,
        valor=dados.valor,
        data=dados.data,
        descricao=dados.descricao,
        categoria_id=dados.categoria_id,
    )
    return TransacaoSaida.model_validate(transacao)


@router.post("/parceladas", status_code=status.HTTP_201_CREATED)
def lancar_parcelada(dados: CompraParceladaEntrada, sessao: SessaoDep) -> CompraParceladaSaida:
    """Compra parcelada no cartão: uma despesa por parcela, cada uma na sua fatura."""
    compra = service.lancar_parcelada(
        sessao,
        conta_id=dados.conta_id,
        valor_total=dados.valor_total,
        qtd_parcelas=dados.qtd_parcelas,
        data_compra=dados.data_compra,
        descricao=dados.descricao,
        categoria_id=dados.categoria_id,
    )
    return CompraParceladaSaida.model_validate(compra)


@router.post("/transferencias", status_code=status.HTTP_201_CREATED)
def transferir(dados: TransferenciaEntrada, sessao: SessaoDep) -> TransferenciaSaida:
    """Transferência entre contas próprias: saída na origem e entrada no destino."""
    saida, entrada = service.transferir(
        sessao,
        conta_origem_id=dados.conta_origem_id,
        conta_destino_id=dados.conta_destino_id,
        valor=dados.valor,
        data=dados.data,
        descricao=dados.descricao,
    )
    return TransferenciaSaida(
        saida=TransacaoSaida.model_validate(saida),
        entrada=TransacaoSaida.model_validate(entrada),
    )


@router.get("")
def listar(
    sessao: SessaoDep,
    conta_id: uuid.UUID | None = None,
    de: date | None = None,
    ate: date | None = None,
) -> list[TransacaoSaida]:
    """Transações (todos os status), da mais recente para a mais antiga.

    `de` e `ate` são inclusivos; para um mês, use o primeiro e o último dia dele.
    """
    if de is not None and ate is not None and de > ate:
        raise RequestValidationError(
            [
                {
                    "type": "periodo_invalido",
                    "loc": ("query", "ate"),
                    "msg": "A data final não pode ser antes da inicial.",
                    "input": ate,
                }
            ]
        )
    transacoes = service.listar(sessao, conta_id=conta_id, de=de, ate=ate)
    return [TransacaoSaida.model_validate(transacao) for transacao in transacoes]


@router.get("/{transacao_id}", responses={status.HTTP_404_NOT_FOUND: {"model": RespostaErro}})
def obter(transacao_id: uuid.UUID, sessao: SessaoDep) -> TransacaoSaida:
    try:
        transacao = service.obter(sessao, transacao_id)
    except service.TransacaoNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Transação não encontrada.") from exc
    return TransacaoSaida.model_validate(transacao)
