"""Sync diário da Pluggy: relê a janela de 40 dias de cada conta vinculada e
grava rascunhos (plano `2026-11-04-sync-pluggy`, spec
`2026-10-19-pluggy-spike-design`).

Cada conexão roda numa transação do banco: se algo falha, nada do que ela
gravou fica, e o erro vai para `conexao_pluggy.ultimo_erro`. A Pluggy é só lida.
"""

import logging
import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Protocol
from zoneinfo import ZoneInfo

from sqlalchemy import delete, exists, select
from sqlalchemy.orm import Session, aliased

from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.datas import competencia_de
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.importacao.duplicatas import DIAS_MAXIMOS, marcar_duplicatas
from app.modulos.pluggy.client import ErroPluggy
from app.modulos.pluggy.models import ConexaoPluggy
from app.modulos.pluggy.normalizacao import (
    data_local,
    descricao_original,
    tipo_da_transacao,
    valor_da_transacao,
)
from app.modulos.pluggy.tipos import FaturaPluggy, ItemPluggy, TransacaoPluggy
from app.modulos.transacoes.models import (
    TIPOS_ENTRADA,
    CompraParcelada,
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)

log = logging.getLogger(__name__)

# Cobre a sobreposição de 4 dias da Pluggy e a fatura aberta do cartão.
DIAS_DA_JANELA = 40
ERRO_INESPERADO = "Erro inesperado no sync. Os detalhes estão no log do servidor."


class FontePluggy(Protocol):
    """O que o sync usa do cliente (um falso nos testes)."""

    def obter_item(self, item_id: str) -> ItemPluggy: ...
    def listar_transacoes(self, account_id: str, *, desde: date) -> list[TransacaoPluggy]: ...
    def listar_faturas(self, account_id: str) -> list[FaturaPluggy]: ...


@dataclass(frozen=True)
class ResultadoSync:
    conexao_id: uuid.UUID
    ok: bool
    erro: str | None = None
    novas: int = 0
    atualizadas: int = 0
    removidas: int = 0
    marcadas_removidas: int = 0


@dataclass
class _Contagem:
    novas: int = 0
    atualizadas: int = 0
    removidas: int = 0
    marcadas_removidas: int = 0


def sincronizar_todas(
    sessao: Session,
    fonte: FontePluggy,
    *,
    agora: datetime,
    hoje: date,
    fuso: ZoneInfo,
    repescagem: bool = False,
) -> list[ResultadoSync]:
    """Todas as conexões ativas; na repescagem (13:00), só as que falharam na
    última tentativa (sem sucesso depois dela)."""
    conexoes = list(
        sessao.scalars(
            select(ConexaoPluggy).where(ConexaoPluggy.ativa).order_by(ConexaoPluggy.criado_em)
        )
    )
    if repescagem:
        conexoes = [c for c in conexoes if _falhou_por_ultimo(c)]
    return [
        sincronizar(sessao, fonte, conexao.id, agora=agora, hoje=hoje, fuso=fuso)
        for conexao in conexoes
    ]


def sincronizar(
    sessao: Session,
    fonte: FontePluggy,
    conexao_id: uuid.UUID,
    *,
    agora: datetime,
    hoje: date,
    fuso: ZoneInfo,
) -> ResultadoSync:
    """Uma conexão. A tentativa fica registrada mesmo se der erro."""
    conexao = sessao.get_one(ConexaoPluggy, conexao_id)
    conexao.ultima_tentativa_em = agora
    sessao.commit()
    try:
        contagem = _sincronizar(sessao, fonte, conexao, agora=agora, hoje=hoje, fuso=fuso)
    except Exception as erro:  # noqa: BLE001 — nenhuma conexão derruba as outras
        sessao.rollback()
        mensagem = erro.mensagem if isinstance(erro, ErroPluggy) else ERRO_INESPERADO
        if not isinstance(erro, ErroPluggy):
            log.exception("Sync da conexão %s falhou", conexao_id)
        conexao = sessao.get_one(ConexaoPluggy, conexao_id)
        conexao.ultimo_erro = mensagem
        sessao.commit()
        return ResultadoSync(conexao_id=conexao_id, ok=False, erro=mensagem)
    return ResultadoSync(
        conexao_id=conexao_id,
        ok=True,
        novas=contagem.novas,
        atualizadas=contagem.atualizadas,
        removidas=contagem.removidas,
        marcadas_removidas=contagem.marcadas_removidas,
    )


def _falhou_por_ultimo(conexao: ConexaoPluggy) -> bool:
    if conexao.ultima_tentativa_em is None:
        return False
    return conexao.ultimo_sync_em is None or conexao.ultimo_sync_em < conexao.ultima_tentativa_em


def _sincronizar(
    sessao: Session,
    fonte: FontePluggy,
    conexao: ConexaoPluggy,
    *,
    agora: datetime,
    hoje: date,
    fuso: ZoneInfo,
) -> _Contagem:
    item = fonte.obter_item(conexao.item_id)
    conexao.status = item.status
    conexao.consentimento_expira_em = item.consentimento_expira_em
    inicio = hoje - timedelta(days=DIAS_DA_JANELA)
    contagem = _Contagem()
    contas = sessao.scalars(
        select(Conta)
        .where(
            Conta.conexao_pluggy_id == conexao.id,
            Conta.pluggy_account_id.is_not(None),
            Conta.ativa,
        )
        .order_by(Conta.nome, Conta.id)
    )
    # Primeiro sync bem-sucedido depois da renovação: o item novo pode trazer
    # as mesmas transações com outros ids.
    renovada = conexao.renovada_em is not None and (
        conexao.ultimo_sync_em is None or conexao.ultimo_sync_em < conexao.renovada_em
    )
    for conta in contas:
        _sincronizar_conta(
            sessao,
            fonte,
            conta,
            inicio=inicio,
            agora=agora,
            fuso=fuso,
            contagem=contagem,
            renovada=renovada,
        )
    conexao.ultimo_sync_em = agora
    conexao.ultimo_erro = None
    sessao.commit()
    return contagem


def _sincronizar_conta(
    sessao: Session,
    fonte: FontePluggy,
    conta: Conta,
    *,
    inicio: date,
    agora: datetime,
    fuso: ZoneInfo,
    contagem: _Contagem,
    renovada: bool = False,
) -> None:
    assert conta.pluggy_account_id is not None
    cartao = None
    faturas_por_bill: dict[str, Fatura] = {}
    if conta.tipo == TipoConta.cartao_credito:
        cartao = cartoes_service.obter_cartao(sessao, conta.id)
        faturas_por_bill = _gravar_faturas(
            sessao, cartao, fonte.listar_faturas(conta.pluggy_account_id), inicio
        )

    recebidas = fonte.listar_transacoes(conta.pluggy_account_id, desde=inicio)
    linhas = []
    for transacao in recebidas:
        tipo = tipo_da_transacao(transacao, cartao=cartao is not None)
        if tipo is not None:
            linhas.append((transacao, tipo))
    ids = [transacao.id for transacao, _ in linhas]
    gravadas = {
        t.id_externo: t
        for t in sessao.scalars(
            select(Transacao).where(
                Transacao.conta_id == conta.id,
                Transacao.fonte == FonteTransacao.pluggy,
                Transacao.id_externo.in_(ids),
            )
        )
    }

    orfas = _orfas_da_renovacao(sessao, conta, inicio, set(ids)) if renovada else []

    novas: list[Transacao] = []
    for transacao, tipo in linhas:
        dia = data_local(transacao.momento, fuso)
        fatura = None
        if cartao is not None:
            fatura = faturas_por_bill.get(transacao.bill_id or "") or _fatura_pela_regra(
                sessao, cartao, dia
            )
        existente = gravadas.get(transacao.id) or _casar_orfa(orfas, transacao, dia)
        if existente is not None:
            if _atualizar(existente, transacao, dia, fatura):
                contagem.atualizadas += 1
            continue
        nova = Transacao(
            conta_id=conta.id,
            tipo=tipo,
            valor=valor_da_transacao(transacao),
            data=dia,
            descricao_original=descricao_original(transacao),
            descricao=descricao_original(transacao),
            status=StatusTransacao.rascunho,
            fonte=FonteTransacao.pluggy,
            id_externo=transacao.id,
            fatura_id=None if fatura is None else fatura.id,
        )
        if _e_parcela(transacao):
            nova.compra_parcelada = _compra_da_parcela(sessao, conta, transacao, nova, fuso)
            nova.parcela_numero = transacao.parcela_numero
        sessao.add(nova)
        # A próxima parcela da mesma compra precisa enxergar a compra criada.
        sessao.flush()
        novas.append(nova)
    _marcar_duplicatas(sessao, conta.id, novas)
    contagem.novas += len(novas)
    _reconciliar(sessao, conta, inicio, set(ids), agora, contagem)


def _orfas_da_renovacao(
    sessao: Session, conta: Conta, inicio: date, recebidas: set[str]
) -> list[Transacao]:
    """As transações da Pluggy na janela que o item novo não trouxe pelo id:
    candidatas a serem as mesmas, com outro id (spec das conexões, renovação)."""
    return list(
        sessao.scalars(
            select(Transacao)
            .where(
                Transacao.conta_id == conta.id,
                Transacao.fonte == FonteTransacao.pluggy,
                Transacao.data >= inicio,
                Transacao.id_externo.not_in(recebidas),
            )
            .order_by(Transacao.data, Transacao.criado_em, Transacao.id)
        )
    )


def _casar_orfa(orfas: list[Transacao], transacao: TransacaoPluggy, dia: date) -> Transacao | None:
    """A primeira órfã com a mesma data local, valor e descrição original: só
    troca o id externo (e sai da lista, para casar uma vez só)."""
    valor = valor_da_transacao(transacao)
    original = descricao_original(transacao)
    for orfa in orfas:
        if (orfa.data, orfa.valor, orfa.descricao_original) == (dia, valor, original):
            orfas.remove(orfa)
            orfa.id_externo = transacao.id
            return orfa
    return None


def _gravar_faturas(
    sessao: Session, cartao: Cartao, faturas: Sequence[FaturaPluggy], inicio: date
) -> dict[str, Fatura]:
    """As faturas do `/bills` que vencem a partir do início da janela: uma
    fatura antiga sem o pagamento no app entraria no cálculo como não paga.

    A competência é o mês do vencimento; o banco manda nas datas e no valor.
    """
    gravadas = {}
    for dados in faturas:
        if dados.vencimento < inicio:
            continue
        fatura = sessao.scalar(select(Fatura).where(Fatura.pluggy_bill_id == dados.id))
        if fatura is None:
            fatura = cartoes_service.obter_ou_criar_fatura(
                sessao, cartao, competencia_de(dados.vencimento)
            )
        fechamento_antigo = fatura.data_fechamento
        fatura.pluggy_bill_id = dados.id
        fatura.data_vencimento = dados.vencimento
        if dados.fechamento is not None and dados.fechamento < dados.vencimento:
            fatura.data_fechamento = dados.fechamento
        fatura.valor_informado = max(dados.total, Decimal(0)).quantize(Decimal("0.01"))
        sessao.flush()
        if fatura.data_fechamento != fechamento_antigo:
            cartoes_service.realocar_compras(
                sessao,
                cartao,
                min(fechamento_antigo, fatura.data_fechamento),
                max(fechamento_antigo, fatura.data_fechamento),
            )
        gravadas[dados.id] = fatura
    return gravadas


def _fatura_pela_regra(sessao: Session, cartao: Cartao, dia: date) -> Fatura:
    """Sem `billId` (compra da fatura aberta ainda `PENDING`): a regra do cartão."""
    competencia = cartoes_service.competencia_para_data(sessao, cartao, dia)
    return cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)


def _atualizar(
    existente: Transacao, transacao: TransacaoPluggy, dia: date, fatura: Fatura | None
) -> bool:
    """O rascunho acompanha a Pluggy (`PENDING` → `POSTED` mantém o id); a
    confirmada e a ignorada não mudam. Reaparecer limpa a marca de removida."""
    mudou = existente.removida_na_origem_em is not None
    existente.removida_na_origem_em = None
    if existente.status != StatusTransacao.rascunho:
        return mudou
    valor = valor_da_transacao(transacao)
    original = descricao_original(transacao)
    fatura_id = existente.fatura_id if fatura is None else fatura.id
    if (existente.valor, existente.data, existente.descricao_original, existente.fatura_id) != (
        valor,
        dia,
        original,
        fatura_id,
    ):
        # A descrição só acompanha se ninguém a editou.
        if existente.descricao == existente.descricao_original:
            existente.descricao = original
        existente.valor = valor
        existente.data = dia
        existente.descricao_original = original
        existente.fatura_id = fatura_id
        mudou = True
    return mudou


def _e_parcela(transacao: TransacaoPluggy) -> bool:
    return (
        transacao.parcela_numero is not None
        and transacao.total_parcelas is not None
        and transacao.total_parcelas >= 2
    )


def _compra_da_parcela(
    sessao: Session, conta: Conta, transacao: TransacaoPluggy, nova: Transacao, fuso: ZoneInfo
) -> CompraParcelada:
    """A compra das parcelas: a mesma descrição, número de parcelas e data da
    compra (`purchaseDate`, a real), sem esta parcela; ou uma nova."""
    assert transacao.total_parcelas is not None
    data_compra = (
        nova.data if transacao.data_compra is None else data_local(transacao.data_compra, fuso)
    )
    outra = aliased(Transacao)
    tem_esta_parcela = exists().where(
        outra.compra_parcelada_id == CompraParcelada.id,
        outra.parcela_numero == transacao.parcela_numero,
    )
    existente = sessao.scalar(
        select(CompraParcelada)
        .join(Transacao, Transacao.compra_parcelada_id == CompraParcelada.id)
        .where(
            Transacao.conta_id == conta.id,
            CompraParcelada.descricao == nova.descricao_original,
            CompraParcelada.qtd_parcelas == transacao.total_parcelas,
            CompraParcelada.data_compra == data_compra,
            ~tem_esta_parcela,
        )
        .order_by(CompraParcelada.criado_em, CompraParcelada.id)
        .limit(1)
    )
    if existente is not None:
        return existente
    compra = CompraParcelada(
        descricao=nova.descricao_original,
        valor_total=nova.valor * transacao.total_parcelas,
        qtd_parcelas=transacao.total_parcelas,
        data_compra=data_compra,
        data_compra_estimada=transacao.data_compra is None,
    )
    sessao.add(compra)
    return compra


@dataclass(frozen=True)
class _Lancamento:
    id: uuid.UUID
    valor: Decimal
    data: date
    entrada: bool


def _marcar_duplicatas(sessao: Session, conta_id: uuid.UUID, novas: list[Transacao]) -> None:
    """A nova que bate com uma de outra fonte (ou manual) da mesma conta vira
    possível duplicata; a revisão decide (spec da importação)."""
    if not novas:
        return
    datas = [t.data for t in novas]
    folga = timedelta(days=DIAS_MAXIMOS)
    ja_marcadas = select(Transacao.possivel_duplicata_de).where(
        Transacao.possivel_duplicata_de.is_not(None),
        Transacao.status != StatusTransacao.ignorada,
    )
    existentes = sessao.scalars(
        select(Transacao).where(
            Transacao.conta_id == conta_id,
            Transacao.fonte != FonteTransacao.pluggy,
            Transacao.status != StatusTransacao.ignorada,
            Transacao.possivel_duplicata_de.is_(None),
            Transacao.id.not_in(ja_marcadas),
            Transacao.data.between(min(datas) - folga, max(datas) + folga),
        )
    )
    marcadas = marcar_duplicatas(
        [_lancamento(t) for t in novas], [_lancamento(t) for t in existentes]
    )
    for indice, existente in marcadas.items():
        novas[indice].possivel_duplicata_de = existente.id
    sessao.flush()


def _lancamento(transacao: Transacao) -> _Lancamento:
    return _Lancamento(
        id=transacao.id,
        valor=transacao.valor,
        data=transacao.data,
        entrada=TipoTransacao(transacao.tipo) in TIPOS_ENTRADA,
    )


def _reconciliar(
    sessao: Session,
    conta: Conta,
    inicio: date,
    recebidas: set[str],
    agora: datetime,
    contagem: _Contagem,
) -> None:
    """Transação da Pluggy na janela que não veio mais: o rascunho é apagado e
    a confirmada ganha `removida_na_origem_em` (a revisão mostra o alerta).
    A Pluggy não tem id estável: uma recriação lá chega como nova aqui."""
    sumidas = list(
        sessao.scalars(
            select(Transacao).where(
                Transacao.conta_id == conta.id,
                Transacao.fonte == FonteTransacao.pluggy,
                Transacao.data >= inicio,
                Transacao.id_externo.not_in(recebidas),
            )
        )
    )
    apagar = [t.id for t in sumidas if t.status == StatusTransacao.rascunho]
    for transacao in sumidas:
        if (
            transacao.status == StatusTransacao.confirmada
            and transacao.removida_na_origem_em is None
        ):
            transacao.removida_na_origem_em = agora
            contagem.marcadas_removidas += 1
    if apagar:
        compras = {
            t.compra_parcelada_id for t in sumidas if t.id in apagar and t.compra_parcelada_id
        }
        sessao.execute(delete(Transacao).where(Transacao.id.in_(apagar)))
        if compras:
            sessao.execute(
                delete(CompraParcelada).where(
                    CompraParcelada.id.in_(compras),
                    ~exists().where(Transacao.compra_parcelada_id == CompraParcelada.id),
                )
            )
        contagem.removidas += len(apagar)
    sessao.flush()
