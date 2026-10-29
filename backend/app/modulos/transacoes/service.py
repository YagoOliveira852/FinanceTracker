"""Regras de transações: lançamento manual (à vista ou parcelado), transferência
entre contas próprias e consulta."""

import uuid
from datetime import date
from decimal import Decimal

from sqlalchemy import exists, select
from sqlalchemy.orm import Session, selectinload

from app.core.erros import CampoInvalido
from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.datas import mes_seguinte
from app.modulos.categorias import service as categorias_service
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.transacoes.models import (
    CompraParcelada,
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)
from app.modulos.transacoes.parcelas import data_da_parcela, dividir_em_parcelas

_CENTAVO = Decimal("0.01")
DESCRICAO_TRANSFERENCIA = "Transferência"


class TransacaoNaoEncontrada(Exception):
    pass


def lancar(
    sessao: Session,
    *,
    conta_id: uuid.UUID,
    tipo: TipoTransacao,
    valor: Decimal,
    data: date,
    descricao: str,
    categoria_id: uuid.UUID | None = None,
) -> Transacao:
    """Lançamento manual: entra confirmado e já conta no saldo da conta.

    Em cartão de crédito, só despesa (compra à vista), ligada à fatura da data.
    A categoria é opcional e não cria regra: a descrição é do usuário, não do banco.
    """
    conta = conta_ativa(sessao, conta_id)
    em_cartao = conta.tipo == TipoConta.cartao_credito
    if em_cartao and tipo != TipoTransacao.despesa:
        raise CampoInvalido("conta_id", "Num cartão de crédito, lance só despesas.")
    if categoria_id is not None:
        categorias_service.categoria_para_tipo(sessao, categoria_id, tipo)
    fatura_id = None
    if em_cartao:
        cartao = cartoes_service.obter_cartao(sessao, conta_id)
        competencia = cartoes_service.competencia_para_data(sessao, cartao, data)
        fatura_id = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia).id

    transacao = Transacao(
        conta_id=conta_id,
        tipo=tipo,
        valor=valor,
        data=data,
        descricao_original=descricao,
        descricao=descricao,
        categoria_id=categoria_id,
        status=StatusTransacao.confirmada,
        fonte=FonteTransacao.manual,
        fatura_id=fatura_id,
    )
    sessao.add(transacao)
    sessao.commit()
    return transacao


def lancar_parcelada(
    sessao: Session,
    *,
    conta_id: uuid.UUID,
    valor_total: Decimal,
    qtd_parcelas: int,
    data_compra: date,
    descricao: str,
    categoria_id: uuid.UUID | None = None,
) -> CompraParcelada:
    """Compra parcelada num cartão: uma despesa confirmada por parcela.

    A parcela k tem a data da compra mais k−1 meses e entra na fatura da
    compra mais k−1 competências (não na fatura da própria data: com
    fechamento em dia útil, a data avançada poderia pular uma fatura). Entra
    tudo ou nada.
    """
    conta = conta_ativa(sessao, conta_id)
    if conta.tipo != TipoConta.cartao_credito:
        raise CampoInvalido("conta_id", "Só compra no cartão de crédito pode ser parcelada.")
    if valor_total < _CENTAVO * qtd_parcelas:
        raise CampoInvalido("valor_total", "Cada parcela precisa ser de pelo menos R$ 0,01.")
    if categoria_id is not None:
        categorias_service.categoria_para_tipo(sessao, categoria_id, TipoTransacao.despesa)

    cartao = cartoes_service.obter_cartao(sessao, conta_id)
    compra = CompraParcelada(
        descricao=descricao,
        valor_total=valor_total,
        qtd_parcelas=qtd_parcelas,
        data_compra=data_compra,
    )
    try:
        competencia = cartoes_service.competencia_para_data(sessao, cartao, data_compra)
        valores = dividir_em_parcelas(valor_total, qtd_parcelas)
        for numero, valor in enumerate(valores, start=1):
            fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
            compra.parcelas.append(
                Transacao(
                    conta_id=conta_id,
                    tipo=TipoTransacao.despesa,
                    valor=valor,
                    data=data_da_parcela(data_compra, numero),
                    descricao_original=descricao,
                    descricao=descricao,
                    categoria_id=categoria_id,
                    status=StatusTransacao.confirmada,
                    fonte=FonteTransacao.manual,
                    fatura_id=fatura.id,
                    parcela_numero=numero,
                )
            )
            competencia = mes_seguinte(competencia)
        sessao.add(compra)
        sessao.commit()
    except Exception:
        sessao.rollback()
        raise
    return compra


def transferir(
    sessao: Session,
    *,
    conta_origem_id: uuid.UUID,
    conta_destino_id: uuid.UUID,
    valor: Decimal,
    data: date,
    descricao: str | None,
) -> tuple[Transacao, Transacao]:
    """Transferência entre contas próprias: uma saída na origem e uma entrada no
    destino, ligadas pelo par. Muda os saldos, mas não é gasto nem renda.

    Só corrente e carteira: pagar o cartão é pagamento de fatura. Devolve
    (saída, entrada); entra o par inteiro ou nada.
    """
    conta_de_transferencia(sessao, conta_origem_id, "conta_origem_id")
    conta_de_transferencia(sessao, conta_destino_id, "conta_destino_id")
    if conta_destino_id == conta_origem_id:
        raise CampoInvalido("conta_destino_id", "Escolha uma conta diferente da de origem.")

    descricao = descricao or DESCRICAO_TRANSFERENCIA
    lados = [
        Transacao(
            conta_id=conta_id,
            tipo=tipo,
            valor=valor,
            data=data,
            descricao_original=descricao,
            descricao=descricao,
            status=StatusTransacao.confirmada,
            fonte=FonteTransacao.manual,
        )
        for conta_id, tipo in (
            (conta_origem_id, TipoTransacao.transferencia_saida),
            (conta_destino_id, TipoTransacao.transferencia_entrada),
        )
    ]
    saida, entrada = lados
    saida.transferencia_par = entrada
    entrada.transferencia_par = saida
    sessao.add_all(lados)
    sessao.commit()
    return saida, entrada


def listar(
    sessao: Session,
    *,
    conta_id: uuid.UUID | None = None,
    de: date | None = None,
    ate: date | None = None,
) -> list[Transacao]:
    """Transações de todos os status, da mais recente para a mais antiga."""
    consulta = (
        select(Transacao)
        # A saída mostra cartão e competência da fatura: uma consulta só para todas.
        .options(selectinload(Transacao.fatura))
        .order_by(Transacao.data.desc(), Transacao.criado_em.desc(), Transacao.id)
    )
    if conta_id is not None:
        consulta = consulta.where(Transacao.conta_id == conta_id)
    if de is not None:
        consulta = consulta.where(Transacao.data >= de)
    if ate is not None:
        consulta = consulta.where(Transacao.data <= ate)
    return list(sessao.scalars(consulta))


def obter(sessao: Session, transacao_id: uuid.UUID) -> Transacao:
    transacao = sessao.get(Transacao, transacao_id)
    if transacao is None:
        raise TransacaoNaoEncontrada
    return transacao


def conta_ativa(sessao: Session, conta_id: uuid.UUID, campo: str = "conta_id") -> Conta:
    """A conta, se existe e está ativa; senão, recusa no `campo` do corpo."""
    conta = sessao.get(Conta, conta_id)
    if conta is None:
        raise CampoInvalido(campo, "Conta não encontrada.")
    if not conta.ativa:
        raise CampoInvalido(campo, "Esta conta está desativada.")
    return conta


def conta_tem_fonte(sessao: Session, conta_id: uuid.UUID) -> bool:
    """A conta é alimentada por extrato ou Open Finance: tem alguma transação
    que não foi lançada à mão. A carteira nunca tem."""
    return bool(
        sessao.scalar(
            select(
                exists().where(
                    Transacao.conta_id == conta_id, Transacao.fonte != FonteTransacao.manual.value
                )
            )
        )
    )


def conta_de_transferencia(sessao: Session, conta_id: uuid.UUID, campo: str) -> Conta:
    """Corrente ou carteira ativa; senão, recusa no `campo` do corpo."""
    conta = conta_ativa(sessao, conta_id, campo)
    if conta.tipo == TipoConta.cartao_credito:
        raise CampoInvalido(campo, "Para pagar o cartão, use Pagamento de fatura.")
    return conta
