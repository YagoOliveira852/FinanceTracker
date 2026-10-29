"""O que os leitores de extrato devolvem, qualquer que seja o formato do
arquivo (OFX ou CSV do Mercado Pago), e os erros comuns a eles."""

from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from enum import StrEnum

from app.modulos.importacao.models import FonteImportacao


class TipoExtrato(StrEnum):
    conta = "conta"
    fatura = "fatura"


@dataclass(frozen=True)
class Parcela:
    numero: int
    total: int
    # A descrição sem o sufixo " - Parcela N/M": a da compra parcelada.
    descricao: str


@dataclass(frozen=True)
class Linha:
    # O identificador do lançamento no arquivo: FITID no OFX, REFERENCE_ID no CSV.
    identificador: str
    # O identificador; na linha de IOF do OFX, `FITID:iof` (o Nubank repete o
    # FITID da compra).
    id_externo: str
    data: date
    # Com sinal, como no arquivo: negativo é saída.
    valor: Decimal
    descricao: str
    parcela: Parcela | None = None


@dataclass(frozen=True)
class Saldo:
    valor: Decimal
    data: date


@dataclass(frozen=True)
class Extrato:
    fonte: FonteImportacao
    tipo: TipoExtrato
    periodo_inicio: date | None
    periodo_fim: date | None
    # Saldo da conta ou, na fatura do OFX, o total da fatura (negativo).
    saldo: Saldo | None
    linhas: list[Linha]


class FormatoNaoReconhecido(Exception):
    def __init__(self, mensagem: str) -> None:
        super().__init__(mensagem)
        self.mensagem = mensagem


class IdentificadorRepetido(Exception):
    """O arquivo tem lançamentos com o mesmo identificador: nada é importado,
    porque o app não escolhe sozinho qual descartar."""

    def __init__(self, campo: str, linhas: list[Linha]) -> None:
        super().__init__(f"{len(linhas)} lançamentos com {campo} repetido.")
        # O nome do identificador no arquivo, para a mensagem: FITID ou REFERENCE_ID.
        self.campo = campo
        self.linhas = linhas


def decodificar(dados: bytes) -> str:
    """UTF-8 (com ou sem BOM) ou, se não decodificar, cp1252."""
    try:
        return dados.decode("utf-8-sig")
    except UnicodeDecodeError:
        return dados.decode("cp1252", errors="replace")


def recusar_repetidos(linhas: list[Linha], campo: str) -> None:
    contagem: dict[str, int] = {}
    for linha in linhas:
        contagem[linha.id_externo] = contagem.get(linha.id_externo, 0) + 1
    repetidas = [linha for linha in linhas if contagem[linha.id_externo] > 1]
    if repetidas:
        raise IdentificadorRepetido(campo, repetidas)
