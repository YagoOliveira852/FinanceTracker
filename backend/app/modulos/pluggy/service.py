"""Conexões da Pluggy pelo app: cadastro do item, vínculo de contas, renovação,
desativar/reativar e "Buscar agora" (spec `2026-10-20-conexoes-pluggy-design`,
decisões do código).

Tudo o que se grava fica no nosso banco: na Pluggy, só leitura.
"""

import uuid
from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from decimal import Decimal
from typing import Protocol
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.erros import CampoInvalido
from app.modulos.cartoes.models import Cartao
from app.modulos.contas.models import Conta, TipoConta
from app.modulos.contas.service import obter_ou_criar_instituicao
from app.modulos.pluggy import sync
from app.modulos.pluggy.client import ErroPluggy, ItemNaoEncontrado
from app.modulos.pluggy.models import ConexaoPluggy
from app.modulos.pluggy.problema import (
    EstadoSync,
    Problema,
    mais_grave,
    problema_da_conexao,
    proximo_sync,
)
from app.modulos.pluggy.tipos import ContaPluggy, ItemPluggy

INTERVALO_BUSCAR_AGORA = timedelta(hours=1)


class FonteConexoes(sync.FontePluggy, Protocol):
    def listar_contas(self, item_id: str) -> list[ContaPluggy]: ...


class ConexaoNaoEncontrada(Exception):
    pass


class BuscarMaisTarde(Exception):
    def __init__(self, pode_em: datetime):
        super().__init__(pode_em)
        self.pode_em = pode_em


@dataclass(frozen=True)
class EstadoConexao:
    conexao: ConexaoPluggy
    contas: list[Conta]
    problema: Problema | None
    proximo_sync: datetime | None
    # Nulo quando já pode buscar.
    buscar_a_partir_de: datetime | None


@dataclass(frozen=True)
class ListaConexoes:
    conexoes: list[EstadoConexao]
    # O mais grave entre as ativas: o card do Início.
    problema: Problema | None
    # A conexão do problema mais grave (a primeira, se houver empate).
    conexao_do_problema: ConexaoPluggy | None


@dataclass(frozen=True)
class ContaDaPrevia:
    conta: ContaPluggy
    # A conta do app sugerida pelo final do número; nula sem sugestão.
    sugestao: Conta | None
    # Cartão sem dias na Pluggy não pode virar conta nova.
    pode_criar: bool


@dataclass(frozen=True)
class Previa:
    item: ItemPluggy
    contas: list[ContaDaPrevia]


@dataclass(frozen=True)
class Vinculo:
    pluggy_account_id: str
    # Nulo = criar uma conta nova.
    conta_id: uuid.UUID | None


def listar(sessao: Session, *, agora: datetime, fuso: ZoneInfo) -> ListaConexoes:
    """Ativas primeiro, pela criação; o problema só vale para as ativas."""
    conexoes = list(
        sessao.scalars(
            select(ConexaoPluggy).order_by(ConexaoPluggy.ativa.desc(), ConexaoPluggy.criado_em)
        )
    )
    contas = list(
        sessao.scalars(
            select(Conta)
            .where(Conta.conexao_pluggy_id.in_([c.id for c in conexoes]))
            .order_by(Conta.nome, Conta.id)
        )
    )
    estados = []
    for conexao in conexoes:
        problema = (
            problema_da_conexao(_estado(conexao), agora=agora, fuso=fuso) if conexao.ativa else None
        )
        estados.append(
            EstadoConexao(
                conexao=conexao,
                contas=[c for c in contas if c.conexao_pluggy_id == conexao.id],
                problema=problema,
                proximo_sync=proximo_sync(agora, fuso) if conexao.ativa else None,
                buscar_a_partir_de=_buscar_a_partir_de(conexao, agora),
            )
        )
    pior = mais_grave(e.problema for e in estados)
    return ListaConexoes(
        conexoes=estados,
        problema=pior,
        conexao_do_problema=next((e.conexao for e in estados if e.problema == pior), None)
        if pior
        else None,
    )


def previa(sessao: Session, fonte: FonteConexoes, item_id: str) -> Previa:
    """Valida o item na Pluggy e lista as contas com a sugestão de vínculo.
    Não grava nada."""
    item = _item(fonte, item_id)
    if sessao.scalar(select(ConexaoPluggy).where(ConexaoPluggy.item_id == item.id)) is not None:
        raise CampoInvalido("item_id", "Esta conexão já está cadastrada.")
    return Previa(item=item, contas=_contas_da_previa(sessao, fonte, item.id, conexao_id=None))


def criar(
    sessao: Session,
    fonte: FonteConexoes,
    *,
    item_id: str,
    vinculos: Sequence[Vinculo],
    hoje: date,
) -> ConexaoPluggy:
    item = _item(fonte, item_id)
    if sessao.scalar(select(ConexaoPluggy).where(ConexaoPluggy.item_id == item.id)) is not None:
        raise CampoInvalido("item_id", "Esta conexão já está cadastrada.")
    instituicao = obter_ou_criar_instituicao(sessao, item.instituicao)
    conexao = ConexaoPluggy(
        item_id=item.id,
        instituicao=instituicao,
        status=item.status,
        consentimento_expira_em=item.consentimento_expira_em,
    )
    sessao.add(conexao)
    sessao.flush()
    _vincular(sessao, fonte, conexao, vinculos, hoje)
    sessao.commit()
    return conexao


def renovar(
    sessao: Session,
    fonte: FonteConexoes,
    conexao_id: uuid.UUID,
    *,
    item_id: str,
    vinculos: Sequence[Vinculo],
    agora: datetime,
    hoje: date,
) -> ConexaoPluggy:
    """O item novo (ou o mesmo, renovado) passa a alimentar a conexão. As
    contas ligadas ao item antigo deixam de estar vinculadas, a não ser que
    voltem nos vínculos."""
    conexao = _conexao(sessao, conexao_id)
    item = _item(fonte, item_id)
    outra = sessao.scalar(select(ConexaoPluggy).where(ConexaoPluggy.item_id == item.id))
    if outra is not None and outra.id != conexao.id:
        raise CampoInvalido("item_id", "Este item já está em outra conexão.")
    for conta in sessao.scalars(select(Conta).where(Conta.conexao_pluggy_id == conexao.id)):
        conta.pluggy_account_id = None
        conta.conexao_pluggy_id = None
    sessao.flush()
    conexao.item_id = item.id
    conexao.status = item.status
    conexao.consentimento_expira_em = item.consentimento_expira_em
    conexao.ativa = True
    conexao.renovada_em = agora
    _vincular(sessao, fonte, conexao, vinculos, hoje)
    sessao.commit()
    return conexao


def previa_da_renovacao(
    sessao: Session, fonte: FonteConexoes, conexao_id: uuid.UUID, item_id: str
) -> Previa:
    """Como a prévia do cadastro, mas o item pode ser o mesmo da conexão e as
    sugestões consideram as contas que ela já alimentava."""
    conexao = _conexao(sessao, conexao_id)
    item = _item(fonte, item_id)
    outra = sessao.scalar(select(ConexaoPluggy).where(ConexaoPluggy.item_id == item.id))
    if outra is not None and outra.id != conexao.id:
        raise CampoInvalido("item_id", "Este item já está em outra conexão.")
    return Previa(item=item, contas=_contas_da_previa(sessao, fonte, item.id, conexao.id))


def alterar_ativa(
    sessao: Session, fonte: FonteConexoes, conexao_id: uuid.UUID, *, ativa: bool
) -> ConexaoPluggy:
    """Desativar só para o sync; as contas continuam ativas. Reativar confere o
    item: se ele não responde mais, a tela leva à renovação."""
    conexao = _conexao(sessao, conexao_id)
    if ativa and not conexao.ativa:
        item = _item(fonte, conexao.item_id)
        conexao.status = item.status
        conexao.consentimento_expira_em = item.consentimento_expira_em
    conexao.ativa = ativa
    sessao.commit()
    return conexao


def buscar_agora(
    sessao: Session,
    fonte: FonteConexoes,
    conexao_id: uuid.UUID,
    *,
    agora: datetime,
    hoje: date,
    fuso: ZoneInfo,
) -> sync.ResultadoSync:
    """Roda o nosso sync para a conexão, no máximo uma vez por hora: a Pluggy
    atualiza o item uma vez por dia, e reler não traz dado novo."""
    conexao = _conexao(sessao, conexao_id)
    if not conexao.ativa:
        raise CampoInvalido("ativa", "Reative a conexão antes de buscar.")
    pode_em = _buscar_a_partir_de(conexao, agora)
    if pode_em is not None:
        raise BuscarMaisTarde(pode_em)
    return sync.sincronizar(sessao, fonte, conexao.id, agora=agora, hoje=hoje, fuso=fuso)


def _estado(conexao: ConexaoPluggy) -> EstadoSync:
    return EstadoSync(
        criada_em=conexao.criado_em,
        consentimento_expira_em=conexao.consentimento_expira_em,
        ultimo_sync_em=conexao.ultimo_sync_em,
        ultima_tentativa_em=conexao.ultima_tentativa_em,
        ultimo_erro=conexao.ultimo_erro,
    )


def _buscar_a_partir_de(conexao: ConexaoPluggy, agora: datetime) -> datetime | None:
    if conexao.ultima_tentativa_em is None:
        return None
    pode_em = conexao.ultima_tentativa_em + INTERVALO_BUSCAR_AGORA
    return pode_em if pode_em > agora else None


def _conexao(sessao: Session, conexao_id: uuid.UUID) -> ConexaoPluggy:
    conexao = sessao.get(ConexaoPluggy, conexao_id)
    if conexao is None:
        raise ConexaoNaoEncontrada
    return conexao


def _item(fonte: FonteConexoes, item_id: str) -> ItemPluggy:
    item_id = item_id.strip()
    try:
        uuid.UUID(item_id)
    except ValueError as erro:
        raise CampoInvalido(
            "item_id", "O ID tem o formato 8f3c2a91-…: copie o id inteiro do item."
        ) from erro
    try:
        return fonte.obter_item(item_id)
    except ItemNaoEncontrado as erro:
        raise CampoInvalido(
            "item_id",
            "Não encontramos uma conexão com esse ID. Confira se copiou o id inteiro do "
            "item MeuPluggy.",
        ) from erro
    except ErroPluggy as erro:
        raise CampoInvalido("item_id", erro.mensagem) from erro


def _tipo_da_conta(conta: ContaPluggy) -> TipoConta:
    return TipoConta.cartao_credito if conta.cartao else TipoConta.corrente


def _contas_da_previa(
    sessao: Session, fonte: FonteConexoes, item_id: str, conexao_id: uuid.UUID | None
) -> list[ContaDaPrevia]:
    contas_pluggy = fonte.listar_contas(item_id)
    ja_vinculadas = set(
        sessao.scalars(
            select(Conta.pluggy_account_id).where(
                Conta.pluggy_account_id.is_not(None),
                Conta.conexao_pluggy_id.is_distinct_from(conexao_id),
            )
        )
    )
    do_app = list(sessao.scalars(select(Conta).where(Conta.ativa).order_by(Conta.nome, Conta.id)))
    usadas: set[uuid.UUID] = set()
    previas = []
    for conta in contas_pluggy:
        if conta.id in ja_vinculadas:
            continue
        sugestao = _sugestao(conta, do_app, usadas, conexao_id)
        if sugestao is not None:
            usadas.add(sugestao.id)
        previas.append(
            ContaDaPrevia(
                conta=conta,
                sugestao=sugestao,
                pode_criar=not conta.cartao
                or (conta.dia_fechamento is not None and conta.dia_vencimento is not None),
            )
        )
    return previas


def _sugestao(
    conta: ContaPluggy, do_app: list[Conta], usadas: set[uuid.UUID], conexao_id: uuid.UUID | None
) -> Conta | None:
    """Mesmo tipo e mesmo final: primeiro pelo final gravado num vínculo
    anterior (renovação), depois pelo final no nome (primeira conexão)."""
    final = conta.numero_final
    if final is None:
        return None
    candidatas = [
        c
        for c in do_app
        if c.tipo == _tipo_da_conta(conta)
        and c.id not in usadas
        and (c.conexao_pluggy_id is None or c.conexao_pluggy_id == conexao_id)
    ]
    pelo_vinculo = [c for c in candidatas if c.pluggy_numero_final == final]
    pelo_nome = [c for c in candidatas if final in "".join(ch for ch in c.nome if ch.isdigit())]
    return (pelo_vinculo or pelo_nome or [None])[0]


def _vincular(
    sessao: Session,
    fonte: FonteConexoes,
    conexao: ConexaoPluggy,
    vinculos: Sequence[Vinculo],
    hoje: date,
) -> None:
    """Valida todos os vínculos antes de gravar: nada fica pela metade."""
    contas_pluggy = {c.id: c for c in fonte.listar_contas(conexao.item_id)}
    if not vinculos:
        raise CampoInvalido("vinculos", "Escolha o que fazer com pelo menos uma conta.")
    escolhidas: set[uuid.UUID] = set()
    planos: list[tuple[ContaPluggy, Conta | None]] = []
    for vinculo in vinculos:
        conta_pluggy = contas_pluggy.get(vinculo.pluggy_account_id)
        if conta_pluggy is None:
            raise CampoInvalido("vinculos", "Uma das contas não é deste item.")
        outra = sessao.scalar(select(Conta).where(Conta.pluggy_account_id == conta_pluggy.id))
        if outra is not None:
            raise CampoInvalido("vinculos", f"{conta_pluggy.nome} já alimenta {outra.nome}.")
        existente = None
        if vinculo.conta_id is not None:
            existente = sessao.get(Conta, vinculo.conta_id)
            if existente is None or not existente.ativa:
                raise CampoInvalido("vinculos", "Escolha uma conta ativa do app.")
            if existente.tipo != _tipo_da_conta(conta_pluggy):
                raise CampoInvalido(
                    "vinculos", f"{conta_pluggy.nome} só pode alimentar uma conta do mesmo tipo."
                )
            if existente.id in escolhidas:
                raise CampoInvalido("vinculos", "Cada conta do app recebe uma conta da Pluggy.")
            if existente.conexao_pluggy_id not in (None, conexao.id):
                raise CampoInvalido("vinculos", f"{existente.nome} já tem Open Finance.")
            escolhidas.add(existente.id)
        planos.append((conta_pluggy, existente))

    tem_corrente = any(not conta_pluggy.cartao for conta_pluggy, _ in planos)
    for conta_pluggy, existente in planos:
        if conta_pluggy.cartao and existente is None:
            if conta_pluggy.dia_fechamento is None or conta_pluggy.dia_vencimento is None:
                raise CampoInvalido(
                    "vinculos",
                    f"A Pluggy não informa o fechamento de {conta_pluggy.nome}: vincule a um "
                    "cartão já cadastrado.",
                )
            if conta_pluggy.dia_fechamento == conta_pluggy.dia_vencimento or not tem_corrente:
                raise CampoInvalido(
                    "vinculos",
                    f"Para criar {conta_pluggy.nome}, vincule também a conta corrente que paga "
                    "a fatura.",
                )

    # Correntes primeiro: o cartão novo paga pela primeira corrente do vínculo.
    instituicao = conexao.instituicao
    pagadora: Conta | None = None
    for conta_pluggy, existente in planos:
        if conta_pluggy.cartao:
            continue
        conta = existente or Conta(
            nome=conta_pluggy.nome,
            tipo=TipoConta.corrente,
            instituicao=instituicao,
            saldo_inicial=Decimal("0.00"),
            data_saldo_inicial=hoje,
        )
        sessao.add(conta)
        _ligar(conta, conta_pluggy, conexao)
        pagadora = pagadora or conta
    sessao.flush()

    for conta_pluggy, existente in planos:
        if not conta_pluggy.cartao:
            continue
        if existente is not None:
            _ligar(existente, conta_pluggy, conexao)
            continue
        assert pagadora is not None
        assert conta_pluggy.dia_fechamento and conta_pluggy.dia_vencimento
        conta = Conta(
            nome=conta_pluggy.nome,
            tipo=TipoConta.cartao_credito,
            instituicao=instituicao,
            saldo_inicial=Decimal("0.00"),
            data_saldo_inicial=hoje,
        )
        _ligar(conta, conta_pluggy, conexao)
        sessao.add(
            Cartao(
                conta=conta,
                conta_pagamento_id=pagadora.id,
                dia_fechamento=conta_pluggy.dia_fechamento,
                dia_vencimento=conta_pluggy.dia_vencimento,
                limite=conta_pluggy.limite or None,
            )
        )
    sessao.flush()


def _ligar(conta: Conta, conta_pluggy: ContaPluggy, conexao: ConexaoPluggy) -> None:
    conta.pluggy_account_id = conta_pluggy.id
    conta.conexao_pluggy_id = conexao.id
    conta.pluggy_numero_final = conta_pluggy.numero_final
