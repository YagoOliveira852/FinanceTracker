"""Transação da Pluggy → dados da nossa transação: funções puras, sem banco
nem I/O (plano `2026-11-04-sync-pluggy`, spec `2026-10-19-pluggy-spike-design`).
"""

from datetime import date, datetime
from decimal import Decimal
from zoneinfo import ZoneInfo

from app.modulos.pluggy.tipos import TransacaoPluggy
from app.modulos.transacoes.models import TipoTransacao

_CENTAVO = Decimal("0.01")
DESCRICAO_VAZIA = "Sem descrição"
# Movimento do cofrinho (saldo reservado), visto no spike. A documentação não
# lista esse valor entre os `operationType` de conta: a marca é procurada também
# na descrição original.
_COFRINHO = "TRANSFERENCIA_SALDO_RESERVADO"
_PAGAMENTO_FATURA = "PAGAMENTO_FATURA"


def data_local(momento: datetime, fuso: ZoneInfo) -> date:
    """A Pluggy manda `date` em UTC com horário: converter antes de truncar,
    senão a compra das 22:00 de Fortaleza cai no dia seguinte."""
    return momento.astimezone(fuso).date()


def valor_da_transacao(transacao: TransacaoPluggy) -> Decimal:
    """Sempre positivo, com duas casas: o sentido vem do tipo."""
    return abs(transacao.valor).quantize(_CENTAVO)


def descricao_original(transacao: TransacaoPluggy) -> str:
    """A descrição da instituição; sem ela, a limpa da Pluggy."""
    for texto in (transacao.descricao_bruta, transacao.descricao):
        if texto and texto.strip():
            return texto.strip()
    return DESCRICAO_VAZIA


def tipo_da_transacao(transacao: TransacaoPluggy, *, cartao: bool) -> TipoTransacao | None:
    """O tipo pelo `type` da Pluggy (nunca pelo sinal) e pela conta. Nulo para
    o que não entra: o pagamento da fatura do lado do cartão, que já vem do
    extrato da conta que pagou (como no OFX)."""
    credito = transacao.sentido == "CREDIT"
    if cartao:
        if transacao.tipo_operacao == _PAGAMENTO_FATURA:
            return None
        return TipoTransacao.estorno if credito else TipoTransacao.despesa
    if _COFRINHO in (transacao.tipo_operacao or "") or _COFRINHO in (
        transacao.descricao_bruta or ""
    ):
        return TipoTransacao.resgate if credito else TipoTransacao.aporte
    return TipoTransacao.receita if credito else TipoTransacao.despesa
