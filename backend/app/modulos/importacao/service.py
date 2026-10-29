"""Regras da importação de extratos: importar (tudo ou nada), consultar e
desfazer. Spec `2026-10-28-importacao-design`.

Uma importação lê o arquivo inteiro antes de gravar qualquer coisa e faz um
commit só no fim: qualquer erro deixa o banco como estava, sem a linha de
`importacao` e sem o `hash_arquivo`, para o arquivo poder ser reenviado.
"""

import hashlib
import uuid
from collections import Counter
from dataclasses import dataclass
from datetime import date, timedelta
from decimal import Decimal

from sqlalchemy import delete, exists, func, select
from sqlalchemy.orm import Session, aliased

from app.core.erros import CampoInvalido
from app.modulos.cartoes import service as cartoes_service
from app.modulos.cartoes.datas import competencia_de, mes_anterior, mes_seguinte
from app.modulos.cartoes.models import Cartao, Fatura
from app.modulos.contas.models import Conta, FonteSnapshot, SnapshotSaldo, TipoConta
from app.modulos.importacao.duplicatas import DIAS_MAXIMOS, marcar_duplicatas
from app.modulos.importacao.models import FonteImportacao, Importacao, StatusImportacao
from app.modulos.importacao.parsers import ler_extrato
from app.modulos.importacao.parsers.extrato import (
    Extrato,
    FormatoNaoReconhecido,
    Linha,
    Parcela,
    TipoExtrato,
)
from app.modulos.transacoes import service as transacoes_service
from app.modulos.transacoes.models import (
    TIPOS_ENTRADA,
    CompraParcelada,
    FonteTransacao,
    StatusTransacao,
    TipoTransacao,
    Transacao,
)
from app.modulos.transacoes.parcelas import data_da_compra

TAMANHO_MAXIMO = 5 * 1024 * 1024
# Tolerância para a mesma compra parcelada chegar em arquivos de meses
# diferentes com a data de cobrança mudando um pouco.
DIAS_COMPRA_PARCELADA = 3
DESCRICAO_VAZIA = "Lançamento sem descrição"

_PAGAMENTO_FATURA = "Pagamento de fatura"
_PAGAMENTO_RECEBIDO = "Pagamento recebido"
_ESTORNO = "Estorno"
# Cofrinho do Mercado Pago: guardar e tirar dinheiro não é gasto nem renda.
_COFRINHO_GUARDADO = "Dinheiro reservado"
_COFRINHO_RETIRADO = "Dinheiro retirado"


class ImportacaoNaoEncontrada(Exception):
    pass


class NaoDaParaDesfazer(Exception):
    """Alguma transação da importação já foi confirmada na revisão."""


@dataclass(frozen=True)
class ResultadoImportacao:
    importacao: Importacao
    # O arquivo já tinha sido importado: `importacao` é a anterior, nada mudou.
    ja_importada: bool


@dataclass(frozen=True)
class ResumoImportacao:
    importacao: Importacao
    qtd_confirmadas: int
    qtd_pendentes: int
    saldo: SnapshotSaldo | None

    @property
    def pode_desfazer(self) -> bool:
        return self.qtd_confirmadas == 0


@dataclass(frozen=True)
class _Lancamento:
    """O que a deduplicação precisa de uma transação (nova ou existente)."""

    id: uuid.UUID
    valor: Decimal
    data: date
    entrada: bool


def importar(
    sessao: Session, *, conta_id: uuid.UUID, nome_arquivo: str | None, dados: bytes
) -> ResultadoImportacao:
    """Importa um extrato (OFX ou CSV do Mercado Pago) na conta, ou devolve a
    importação anterior do mesmo arquivo.

    Levanta `CampoInvalido` (arquivo ou conta) e `IdentificadorRepetido` (do
    parser); nos dois casos nada é gravado.
    """
    if len(dados) > TAMANHO_MAXIMO:
        raise CampoInvalido("arquivo", "O arquivo passa de 5 MB.")
    hash_arquivo = hashlib.sha256(dados).hexdigest()
    anterior = sessao.scalar(select(Importacao).where(Importacao.hash_arquivo == hash_arquivo))
    if anterior is not None:
        return ResultadoImportacao(importacao=anterior, ja_importada=True)

    try:
        extrato = ler_extrato(dados)
    except FormatoNaoReconhecido as erro:
        raise CampoInvalido("arquivo", erro.mensagem) from erro
    conta = transacoes_service.conta_ativa(sessao, conta_id)
    _validar_conta(conta, extrato)
    # Tudo o que pode recusar o arquivo vem antes da primeira escrita.
    cartao, fatura_do_arquivo = None, None
    if extrato.tipo == TipoExtrato.fatura:
        cartao = cartoes_service.obter_cartao(sessao, conta.id)
        fatura_do_arquivo = _fatura_do_arquivo(sessao, cartao, extrato)

    importacao = Importacao(
        fonte=extrato.fonte,
        conta_id=conta.id,
        nome_arquivo=nome_arquivo,
        hash_arquivo=hash_arquivo,
        periodo_inicio=extrato.periodo_inicio,
        periodo_fim=extrato.periodo_fim,
        status=StatusImportacao.ok,
    )
    sessao.add(importacao)
    sessao.flush()

    fatura = None
    if cartao is not None and fatura_do_arquivo is not None:
        competencia, fechamento = fatura_do_arquivo
        fatura = _gravar_fatura(sessao, importacao, cartao, competencia, fechamento, extrato)
    else:
        _gravar_saldo(sessao, importacao, extrato)

    fonte = FonteTransacao(extrato.fonte)
    linhas = [linha for linha in extrato.linhas if _tipo(extrato, linha) is not None]
    ja_importados = _ids_ja_importados(
        sessao, conta.id, fonte, [linha.id_externo for linha in linhas]
    )
    novas = [linha for linha in linhas if linha.id_externo not in ja_importados]
    duplicatas = _duplicatas(sessao, conta.id, fonte, novas)

    for indice, linha in enumerate(novas):
        transacao = Transacao(
            conta_id=conta.id,
            tipo=_tipo(extrato, linha),
            valor=abs(linha.valor),
            data=linha.data,
            descricao_original=linha.descricao or DESCRICAO_VAZIA,
            descricao=linha.descricao or DESCRICAO_VAZIA,
            status=StatusTransacao.rascunho,
            fonte=fonte,
            id_externo=linha.id_externo,
            importacao_id=importacao.id,
            fatura_id=None if fatura is None else fatura.id,
            possivel_duplicata_de=duplicatas.get(indice),
        )
        if linha.parcela is not None:
            transacao.compra_parcelada = _compra_da_parcela(sessao, conta.id, linha, linha.parcela)
            transacao.parcela_numero = linha.parcela.numero
        sessao.add(transacao)
        # A próxima parcela do mesmo arquivo precisa enxergar a compra criada.
        sessao.flush()

    importacao.qtd_possiveis_duplicatas = len(duplicatas)
    importacao.qtd_novas = len(novas) - len(duplicatas)
    importacao.qtd_ja_importadas = len(linhas) - len(novas)
    importacao.qtd_parcelas = sum(1 for linha in novas if linha.parcela is not None)
    sessao.commit()
    return ResultadoImportacao(importacao=importacao, ja_importada=False)


def listar(sessao: Session) -> list[ResumoImportacao]:
    """O histórico, da mais recente para a mais antiga."""
    importacoes = list(
        sessao.scalars(
            select(Importacao).order_by(Importacao.criado_em.desc(), Importacao.id.desc())
        )
    )
    ids = [importacao.id for importacao in importacoes]
    status = _status_das_transacoes(sessao, ids)
    saldos = {
        snapshot.importacao_id: snapshot
        for snapshot in sessao.scalars(
            select(SnapshotSaldo).where(SnapshotSaldo.importacao_id.in_(ids))
        )
    }
    return [
        _resumo(importacao, status.get(importacao.id, Counter()), saldos.get(importacao.id))
        for importacao in importacoes
    ]


def obter(sessao: Session, importacao_id: uuid.UUID) -> ResumoImportacao:
    importacao = _importacao(sessao, importacao_id)
    saldo = sessao.scalar(select(SnapshotSaldo).where(SnapshotSaldo.importacao_id == importacao.id))
    status = _status_das_transacoes(sessao, [importacao.id]).get(importacao.id, Counter())
    return _resumo(importacao, status, saldo)


def desfazer(sessao: Session, importacao_id: uuid.UUID) -> None:
    """Apaga o que a importação trouxe e devolve a fatura ao que era.

    Só enquanto nenhuma transação dela está confirmada. É a única vez que o app
    apaga transações: rascunhos e ignoradas daquele arquivo, que pode voltar
    inteiro. As marcas de duplicata que apontavam para elas viram nulas (FK
    `SET NULL`).
    """
    importacao = _importacao(sessao, importacao_id)
    if obter(sessao, importacao.id).qtd_confirmadas:
        raise NaoDaParaDesfazer

    compras = set(
        sessao.scalars(
            select(Transacao.compra_parcelada_id).where(
                Transacao.importacao_id == importacao.id,
                Transacao.compra_parcelada_id.is_not(None),
            )
        )
    )
    sessao.execute(delete(Transacao).where(Transacao.importacao_id == importacao.id))
    if compras:
        sessao.execute(
            delete(CompraParcelada).where(
                CompraParcelada.id.in_(compras),
                ~exists().where(Transacao.compra_parcelada_id == CompraParcelada.id),
            )
        )
    sessao.execute(delete(SnapshotSaldo).where(SnapshotSaldo.importacao_id == importacao.id))
    if importacao.fatura is not None:
        _restaurar_fatura(sessao, importacao)
    sessao.delete(importacao)
    sessao.commit()
    sessao.expire_all()


def _importacao(sessao: Session, importacao_id: uuid.UUID) -> Importacao:
    importacao = sessao.get(Importacao, importacao_id)
    if importacao is None:
        raise ImportacaoNaoEncontrada
    return importacao


def _validar_conta(conta: Conta, extrato: Extrato) -> None:
    if extrato.fonte == FonteImportacao.csv_mercadopago:
        if conta.tipo != TipoConta.corrente:
            raise CampoInvalido(
                "conta_id",
                "Este CSV é de extrato do Mercado Pago. Escolha uma conta corrente.",
            )
        return
    tipo = extrato.tipo
    if tipo == TipoExtrato.fatura and conta.tipo != TipoConta.cartao_credito:
        raise CampoInvalido("conta_id", "Este OFX é de fatura de cartão. Escolha um cartão.")
    if tipo == TipoExtrato.conta and conta.tipo != TipoConta.corrente:
        raise CampoInvalido(
            "conta_id", "Este OFX é de extrato de conta. Escolha uma conta corrente."
        )


def _tipo(extrato: Extrato, linha: Linha) -> TipoTransacao | None:
    """O tipo da transação que a linha vira; `None` = não importar."""
    entrada = linha.valor > 0
    if extrato.fonte == FonteImportacao.csv_mercadopago:
        return _tipo_no_mercado_pago(linha, entrada)
    if extrato.tipo == TipoExtrato.fatura:
        if not entrada:
            return TipoTransacao.despesa
        # O lado do cartão do pagamento da fatura: o pagamento já vem do
        # extrato da conta, e não há transação do lado do cartão.
        if linha.descricao.startswith(_PAGAMENTO_RECEBIDO):
            return None
        return TipoTransacao.estorno
    if entrada:
        return (
            TipoTransacao.estorno if linha.descricao.startswith(_ESTORNO) else TipoTransacao.receita
        )
    if linha.descricao.startswith(_PAGAMENTO_FATURA):
        return TipoTransacao.pagamento_fatura
    return TipoTransacao.despesa


def _tipo_no_mercado_pago(linha: Linha, entrada: bool) -> TipoTransacao:
    if entrada:
        if linha.descricao.startswith(_COFRINHO_RETIRADO):
            return TipoTransacao.resgate
        if linha.descricao.startswith(_ESTORNO):
            return TipoTransacao.estorno
        return TipoTransacao.receita
    if linha.descricao.startswith(_COFRINHO_GUARDADO):
        return TipoTransacao.aporte
    return TipoTransacao.despesa


def _ids_ja_importados(
    sessao: Session, conta_id: uuid.UUID, fonte: FonteTransacao, ids: list[str]
) -> set[str]:
    """Os `id_externo` que já estão na conta por esta fonte, em qualquer status
    (inclusive ignorada: ignorar não pode fazer a linha voltar)."""
    return set(
        sessao.scalars(
            select(Transacao.id_externo).where(
                Transacao.conta_id == conta_id,
                Transacao.fonte == fonte,
                Transacao.id_externo.in_(ids),
            )
        )
    )


def _duplicatas(
    sessao: Session, conta_id: uuid.UUID, fonte: FonteTransacao, novas: list[Linha]
) -> dict[int, uuid.UUID]:
    """Índice da nova → id da transação existente de que ela parece duplicata."""
    if not novas:
        return {}
    datas = [linha.data for linha in novas]
    folga = timedelta(days=DIAS_MAXIMOS)
    ja_marcadas = select(Transacao.possivel_duplicata_de).where(
        Transacao.possivel_duplicata_de.is_not(None),
        Transacao.status != StatusTransacao.ignorada,
    )
    existentes = sessao.scalars(
        select(Transacao).where(
            Transacao.conta_id == conta_id,
            Transacao.fonte != fonte,
            Transacao.status != StatusTransacao.ignorada,
            Transacao.possivel_duplicata_de.is_(None),
            Transacao.id.not_in(ja_marcadas),
            Transacao.data.between(min(datas) - folga, max(datas) + folga),
        )
    )
    marcadas = marcar_duplicatas(
        [
            _Lancamento(
                id=uuid.uuid4(), valor=abs(linha.valor), data=linha.data, entrada=linha.valor > 0
            )
            for linha in novas
        ],
        [
            _Lancamento(
                id=transacao.id,
                valor=transacao.valor,
                data=transacao.data,
                entrada=transacao.tipo in TIPOS_ENTRADA,
            )
            for transacao in existentes
        ],
    )
    return {indice: existente.id for indice, existente in marcadas.items()}


def _compra_da_parcela(
    sessao: Session, conta_id: uuid.UUID, linha: Linha, parcela: Parcela
) -> CompraParcelada:
    """A compra parcelada da linha: a que já existe no cartão (mesma descrição
    e número de parcelas, data estimada perto e sem esta parcela) ou uma nova,
    com a data e o total estimados."""
    estimada = data_da_compra(linha.data, parcela.numero)
    folga = timedelta(days=DIAS_COMPRA_PARCELADA)
    outra = aliased(Transacao)
    tem_esta_parcela = exists().where(
        outra.compra_parcelada_id == CompraParcelada.id,
        outra.parcela_numero == parcela.numero,
    )
    candidatas = sessao.scalars(
        select(CompraParcelada)
        .join(Transacao, Transacao.compra_parcelada_id == CompraParcelada.id)
        .where(
            Transacao.conta_id == conta_id,
            CompraParcelada.descricao == parcela.descricao,
            CompraParcelada.qtd_parcelas == parcela.total,
            CompraParcelada.data_compra.between(estimada - folga, estimada + folga),
            ~tem_esta_parcela,
        )
        .distinct()
    )
    existente = min(
        candidatas,
        key=lambda compra: (
            abs((compra.data_compra - estimada).days),
            compra.data_compra,
            compra.id,
        ),
        default=None,
    )
    if existente is not None:
        return existente
    compra = CompraParcelada(
        descricao=parcela.descricao,
        valor_total=abs(linha.valor) * parcela.total,
        qtd_parcelas=parcela.total,
        data_compra=estimada,
        data_compra_estimada=True,
    )
    sessao.add(compra)
    return compra


def _fatura_do_arquivo(sessao: Session, cartao: Cartao, extrato: Extrato) -> tuple[date, date]:
    """Competência e fechamento (`DTEND`) da fatura do arquivo, já validados."""
    fechamento = extrato.periodo_fim
    if fechamento is None:
        raise CampoInvalido(
            "arquivo", "Não reconheci este arquivo: a fatura não tem fechamento (DTEND)."
        )
    competencia = _competencia_do_fechamento(sessao, cartao, fechamento)
    _validar_fechamento(sessao, cartao, competencia, fechamento)
    return competencia, fechamento


def _gravar_fatura(
    sessao: Session,
    importacao: Importacao,
    cartao: Cartao,
    competencia: date,
    fechamento: date,
    extrato: Extrato,
) -> Fatura:
    """Grava na fatura do arquivo o fechamento (`DTEND`) e o valor do banco
    (−`BALAMT`), guardando os anteriores na importação para o desfazer."""
    fatura = cartoes_service.obter_ou_criar_fatura(sessao, cartao, competencia)
    antigo = fatura.data_fechamento
    importacao.fatura_id = fatura.id
    importacao.fatura_valor_antes = fatura.valor_informado
    importacao.fatura_fechamento_antes = antigo
    fatura.data_fechamento = fechamento
    if extrato.saldo is not None:
        fatura.valor_informado = max(Decimal("0.00"), -extrato.saldo.valor)
    importacao.fatura_valor_gravado = fatura.valor_informado
    importacao.fatura_fechamento_gravado = fechamento
    sessao.flush()
    if antigo != fechamento:
        cartoes_service.realocar_compras(
            sessao, cartao, min(antigo, fechamento), max(antigo, fechamento)
        )
    return fatura


def _competencia_do_fechamento(sessao: Session, cartao: Cartao, fechamento: date) -> date:
    """A competência cujo fechamento (gravado ou calculado) fica mais perto do
    fechamento do arquivo; empate fica com a mais antiga. A regra do cartão
    pode errar o fechamento real por alguns dias."""
    base = competencia_de(fechamento)
    candidatas = [mes_anterior(base), base, mes_seguinte(base), mes_seguinte(mes_seguinte(base))]
    return min(
        candidatas,
        key=lambda competencia: (
            abs(
                (cartoes_service.fechamento_efetivo(sessao, cartao, competencia) - fechamento).days
            ),
            competencia,
        ),
    )


def _validar_fechamento(
    sessao: Session, cartao: Cartao, competencia: date, fechamento: date
) -> None:
    # Os mesmos limites da edição de fatura: entre os fechamentos vizinhos e
    # antes do vencimento.
    anterior = cartoes_service.fechamento_efetivo(sessao, cartao, mes_anterior(competencia))
    seguinte = cartoes_service.fechamento_efetivo(sessao, cartao, mes_seguinte(competencia))
    gravada = cartoes_service.fatura_gravada(sessao, cartao, competencia)
    vencimento = (
        gravada.data_vencimento
        if gravada is not None
        else cartoes_service.datas_calculadas(sessao, cartao, competencia).vencimento
    )
    if not anterior < fechamento < seguinte or fechamento >= vencimento:
        raise CampoInvalido("arquivo", "O fechamento do arquivo não combina com o cartão.")


def _restaurar_fatura(sessao: Session, importacao: Importacao) -> None:
    """Devolve à fatura o valor e o fechamento de antes da importação, se ela
    ainda estiver como a importação deixou; senão, alguém mexeu depois e fica."""
    fatura = importacao.fatura
    if (fatura.valor_informado, fatura.data_fechamento) != (
        importacao.fatura_valor_gravado,
        importacao.fatura_fechamento_gravado,
    ):
        return
    antigo, novo = fatura.data_fechamento, importacao.fatura_fechamento_antes
    fatura.valor_informado = importacao.fatura_valor_antes
    fatura.data_fechamento = novo
    sessao.flush()
    if antigo != novo:
        cartao = cartoes_service.obter_cartao(sessao, fatura.cartao_id)
        cartoes_service.realocar_compras(sessao, cartao, min(antigo, novo), max(antigo, novo))


def _gravar_saldo(sessao: Session, importacao: Importacao, extrato: Extrato) -> None:
    """O saldo do extrato (`LEDGERBAL` no OFX, o da última linha no CSV) vira
    o snapshot da conta naquela data; um que já exista na data é substituído e
    passa a ser desta importação."""
    if extrato.saldo is None:
        return
    snapshot = sessao.scalar(
        select(SnapshotSaldo).where(
            SnapshotSaldo.conta_id == importacao.conta_id,
            SnapshotSaldo.data == extrato.saldo.data,
        )
    )
    if snapshot is None:
        snapshot = SnapshotSaldo(conta_id=importacao.conta_id, data=extrato.saldo.data)
        sessao.add(snapshot)
    snapshot.saldo = extrato.saldo.valor
    snapshot.fonte = FonteSnapshot(extrato.fonte)
    snapshot.importacao_id = importacao.id


def _status_das_transacoes(
    sessao: Session, importacao_ids: list[uuid.UUID]
) -> dict[uuid.UUID, Counter]:
    contagens: dict[uuid.UUID, Counter] = {}
    linhas = sessao.execute(
        select(Transacao.importacao_id, Transacao.status, func.count())
        .where(Transacao.importacao_id.in_(importacao_ids))
        .group_by(Transacao.importacao_id, Transacao.status)
    )
    for importacao_id, status, quantidade in linhas:
        contagens.setdefault(importacao_id, Counter())[status] = quantidade
    return contagens


def _resumo(
    importacao: Importacao, status: Counter, saldo: SnapshotSaldo | None
) -> ResumoImportacao:
    return ResumoImportacao(
        importacao=importacao,
        qtd_confirmadas=status[StatusTransacao.confirmada],
        qtd_pendentes=status[StatusTransacao.rascunho],
        saldo=saldo,
    )
