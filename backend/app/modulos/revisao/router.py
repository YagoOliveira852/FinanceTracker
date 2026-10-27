"""Rotas da revisão. Só traduzem HTTP; as regras estão no service."""

import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.categorias.schemas import CategoriaResumo
from app.modulos.revisao import service
from app.modulos.revisao.schemas import (
    ConfirmacaoEntrada,
    ConfirmacaoSaida,
    DuplicataSaida,
    FaturaCandidataSaida,
    LoteEntrada,
    LoteSaida,
    PagamentoRevisaoEntrada,
    ParEntrada,
    ParRecusaEntrada,
    ParSaida,
    RascunhoSaida,
    RevisaoSaida,
    SugestaoSaida,
    TransacaoRevisao,
    TransferenciaRevisaoEntrada,
)
from app.modulos.transacoes.service import TransacaoNaoEncontrada

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}
_JA_REVISADA = {status.HTTP_409_CONFLICT: {"model": RespostaErro}}
_NAO_E_PAGAMENTO = {status.HTTP_422_UNPROCESSABLE_CONTENT: {"model": RespostaErro}}

router = APIRouter(
    prefix="/revisao",
    tags=["revisao"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.get("")
def listar(sessao: SessaoDep) -> RevisaoSaida:
    """O que espera o usuário: as decisões ("Precisam de você") e os rascunhos
    comuns com a categoria sugerida pelas regras agora."""
    revisao = service.listar(sessao)
    return RevisaoSaida(
        total=revisao.total,
        qtd_sugeridos=revisao.qtd_sugeridos,
        pares=[
            ParSaida(
                saida=TransacaoRevisao.model_validate(par.saida),
                entrada=TransacaoRevisao.model_validate(par.entrada),
                dias=par.dias,
            )
            for par in revisao.pares
        ],
        pagamentos=[TransacaoRevisao.model_validate(t) for t in revisao.pagamentos],
        duplicatas=[
            DuplicataSaida(
                rascunho=TransacaoRevisao.model_validate(d.rascunho),
                outra=TransacaoRevisao.model_validate(d.outra),
            )
            for d in revisao.duplicatas
        ],
        sumidas=[TransacaoRevisao.model_validate(t) for t in revisao.sumidas],
        rascunhos=[_rascunho(r) for r in revisao.rascunhos],
    )


@router.post("/transacoes/{transacao_id}/confirmar", responses=_NAO_ENCONTRADA | _JA_REVISADA)
def confirmar(
    transacao_id: uuid.UUID, dados: ConfirmacaoEntrada, sessao: SessaoDep
) -> ConfirmacaoSaida:
    """Confirma o rascunho com a categoria e ensina as regras: cria, reforça ou
    corrige a aprendida; a manual não muda."""
    with _erros_da_acao():
        aprendizado = service.confirmar(
            sessao,
            transacao_id,
            descricao=dados.descricao,
            categoria_id=dados.categoria_id,
            tipo=dados.tipo,
        )
    regra = aprendizado.regra
    return ConfirmacaoSaida(
        efeito=aprendizado.efeito, regra_padrao=None if regra is None else regra.padrao
    )


@router.post(
    "/transacoes/{transacao_id}/ignorar",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=_NAO_ENCONTRADA | _JA_REVISADA,
)
def ignorar(transacao_id: uuid.UUID, sessao: SessaoDep) -> None:
    """O rascunho fica ignorado (no histórico, fora do saldo e dos gastos) e não
    volta numa nova importação."""
    with _erros_da_acao():
        service.ignorar(sessao, transacao_id)


@router.post("/confirmar-lote")
def confirmar_lote(dados: LoteEntrada, sessao: SessaoDep) -> LoteSaida:
    """Confirma com a categoria sugerida os rascunhos que ainda têm sugestão."""
    return LoteSaida(confirmados=service.confirmar_lote(sessao, dados.ids))


@router.post(
    "/pares",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=_NAO_ENCONTRADA | _JA_REVISADA,
)
def ligar_par(dados: ParEntrada, sessao: SessaoDep) -> None:
    """ "Ligar": as duas viram transferência entre contas próprias, confirmadas."""
    with _erros_da_acao():
        service.ligar_par(sessao, dados.saida_id, dados.entrada_id, dados.descricao)


@router.post("/pares/recusados", status_code=status.HTTP_204_NO_CONTENT, responses=_NAO_ENCONTRADA)
def recusar_par(dados: ParRecusaEntrada, sessao: SessaoDep) -> None:
    """ "Não é par": a sugestão deste par não volta; cada lado ainda pareia com outro."""
    with _erros_da_acao():
        service.recusar_par(sessao, dados.saida_id, dados.entrada_id)


@router.post(
    "/transacoes/{transacao_id}/transferencia",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=_NAO_ENCONTRADA | _JA_REVISADA,
)
def transferir(
    transacao_id: uuid.UUID, dados: TransferenciaRevisaoEntrada, sessao: SessaoDep
) -> None:
    """O rascunho é transferência com a outra conta: liga com o rascunho que veio
    de lá ou, se ela não recebe extrato nem Open Finance, cria o outro lado."""
    with _erros_da_acao():
        service.transferir(sessao, transacao_id, conta_id=dados.conta_id, descricao=dados.descricao)


@router.get(
    "/transacoes/{transacao_id}/faturas",
    responses=_NAO_ENCONTRADA | _JA_REVISADA | _NAO_E_PAGAMENTO,
)
def faturas_do_pagamento(
    transacao_id: uuid.UUID, sessao: SessaoDep, hoje: HojeDep
) -> list[FaturaCandidataSaida]:
    """As faturas que este pagamento pode ter pago, com a sugerida e se cada
    uma fica paga com ele."""
    with _erros_da_acao():
        candidatas = service.faturas_do_pagamento(sessao, transacao_id, hoje)
    return [
        FaturaCandidataSaida(
            cartao_id=c.cartao.conta_id,
            cartao_nome=c.cartao.conta.nome,
            competencia=c.resumo.competencia,
            status=c.resumo.status,
            data_vencimento=c.resumo.data_vencimento,
            valor=c.resumo.valor,
            valor_pago=c.resumo.valor_pago,
            fica_paga=c.fica_paga,
            sugerida=c.sugerida,
        )
        for c in candidatas
    ]


@router.post(
    "/transacoes/{transacao_id}/pagamento",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=_NAO_ENCONTRADA | _JA_REVISADA | _NAO_E_PAGAMENTO,
)
def pagar(transacao_id: uuid.UUID, dados: PagamentoRevisaoEntrada, sessao: SessaoDep) -> None:
    """Confirma o pagamento ligado à fatura escolhida."""
    ano, mes = dados.competencia.split("-")
    with _erros_da_acao():
        service.pagar(
            sessao, transacao_id, cartao_id=dados.cartao_id, competencia=date(int(ano), int(mes), 1)
        )


def _rascunho(rascunho: service.Rascunho) -> RascunhoSaida:
    regra = rascunho.sugerida
    sugestao = None
    if regra is not None:
        sugestao = SugestaoSaida(
            regra_id=regra.id,
            padrao=regra.padrao,
            origem=regra.origem,
            categoria=CategoriaResumo.model_validate(regra.categoria),
        )
    return RascunhoSaida(
        **TransacaoRevisao.model_validate(rascunho.transacao).model_dump(),
        padrao=rascunho.padrao,
        sugestao=sugestao,
        efeito_confirmando=rascunho.efeito_confirmando,
        efeito_corrigindo=rascunho.efeito_corrigindo,
    )


@contextmanager
def _erros_da_acao() -> Iterator[None]:
    """Traduz os erros comuns das ações sobre uma transação."""
    try:
        yield
    except TransacaoNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Transação não encontrada.") from exc
    except service.NaoEhPagamento as exc:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, detail="Este rascunho não é pagamento de fatura."
        ) from exc
    except service.JaRevisada as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT, detail="Esta transação já foi revisada."
        ) from exc
