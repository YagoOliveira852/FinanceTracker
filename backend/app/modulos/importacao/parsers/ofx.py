"""Leitor de OFX 1.x (SGML) e 2.x (XML): função pura, bytes → `ExtratoOfx`.

Spec `2026-10-28-importacao-design`, "Leitura do OFX". Atende o extrato da
conta (`BANKMSGSRSV1`) e a fatura do cartão (`CREDITCARDMSGSRSV1`) do Nubank.

No SGML do OFX 1.x, os agregados (`<STMTTRN>…</STMTTRN>`) sempre fecham, mas
as folhas (`<TRNAMT>-18.50`) podem não fechar: o valor de uma folha vai até o
próximo `<` ou o fim da linha. O Nubank fecha todas; outros bancos, não.
"""

import html
import re
from dataclasses import dataclass
from datetime import date
from decimal import Decimal, InvalidOperation
from enum import StrEnum

SUFIXO_IOF = ":iof"
_CENTAVO = Decimal("0.01")
_PREFIXO_IOF = "IOF de"
_PARCELA = re.compile(r"^(?P<descricao>.+?)\s+-\s+Parcela\s+(?P<numero>\d+)/(?P<total>\d+)$")
_MARCAS = {"BANKMSGSRSV1": "conta", "CREDITCARDMSGSRSV1": "fatura"}


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
class LinhaOfx:
    fitid: str
    # O FITID; na linha de IOF, `FITID:iof` (o Nubank repete o FITID da compra).
    id_externo: str
    data: date
    # Com sinal, como no arquivo: negativo é saída.
    valor: Decimal
    descricao: str
    parcela: Parcela | None


@dataclass(frozen=True)
class Saldo:
    valor: Decimal
    data: date


@dataclass(frozen=True)
class ExtratoOfx:
    tipo: TipoExtrato
    periodo_inicio: date | None
    periodo_fim: date | None
    # `LEDGERBAL`: saldo da conta ou, no cartão, o total da fatura (negativo).
    saldo: Saldo | None
    linhas: list[LinhaOfx]


class FormatoNaoReconhecido(Exception):
    def __init__(self, mensagem: str) -> None:
        super().__init__(mensagem)
        self.mensagem = mensagem


class FitidRepetido(Exception):
    """O arquivo tem lançamentos com o mesmo identificador: nada é importado,
    porque o app não escolhe sozinho qual descartar."""

    def __init__(self, linhas: list[LinhaOfx]) -> None:
        super().__init__(f"{len(linhas)} lançamentos com FITID repetido.")
        self.linhas = linhas


def ler_ofx(dados: bytes) -> ExtratoOfx:
    """Lê o arquivo inteiro ou falha: `FormatoNaoReconhecido` se não é um
    extrato OFX legível, `FitidRepetido` se sobra identificador repetido."""
    texto = _decodificar(dados)
    if "<OFX>" not in texto.upper():
        raise FormatoNaoReconhecido("Não reconheci este arquivo: não é um OFX.")
    tipo = _tipo(texto)
    lista = _agregado(texto, "BANKTRANLIST") or ""
    linhas = [
        linha
        for numero, bloco in enumerate(_agregados(lista, "STMTTRN"), start=1)
        if (linha := _linha(bloco, numero)) is not None
    ]
    _recusar_repetidos(linhas)
    return ExtratoOfx(
        tipo=tipo,
        periodo_inicio=_data_opcional(lista, "DTSTART"),
        periodo_fim=_data_opcional(lista, "DTEND"),
        saldo=_saldo(texto),
        linhas=linhas,
    )


def _decodificar(dados: bytes) -> str:
    # O cabeçalho do Nubank diz CHARSET:1252 na fatura, mas o extrato da conta
    # vem em UTF-8: tenta UTF-8 (com ou sem BOM) e cai para cp1252.
    try:
        return dados.decode("utf-8-sig")
    except UnicodeDecodeError:
        return dados.decode("cp1252", errors="replace")


def _tipo(texto: str) -> TipoExtrato:
    for marca, tipo in _MARCAS.items():
        if _agregado(texto, marca) is not None:
            return TipoExtrato(tipo)
    raise FormatoNaoReconhecido(
        "Não reconheci este arquivo: o OFX não tem extrato de conta nem fatura de cartão."
    )


def _linha(bloco: str, numero: int) -> LinhaOfx | None:
    fitid = _folha(bloco, "FITID")
    if not fitid:
        raise _incompleto(numero, "não tem identificador (FITID)")
    data = _data(_folha(bloco, "DTPOSTED"))
    if data is None:
        raise _incompleto(numero, "não tem uma data válida (DTPOSTED)")
    valor = _valor(_folha(bloco, "TRNAMT"))
    if valor is None:
        raise _incompleto(numero, "não tem um valor válido (TRNAMT)")
    if valor == 0:
        # Não muda saldo nem fatura, e transação tem valor > 0.
        return None
    descricao = _folha(bloco, "MEMO") or _folha(bloco, "NAME") or ""
    iof = descricao.startswith(_PREFIXO_IOF)
    return LinhaOfx(
        fitid=fitid,
        id_externo=f"{fitid}{SUFIXO_IOF}" if iof else fitid,
        data=data,
        valor=valor,
        descricao=descricao,
        parcela=_parcela(descricao),
    )


def _incompleto(numero: int, problema: str) -> FormatoNaoReconhecido:
    return FormatoNaoReconhecido(f"Não reconheci este arquivo: o lançamento {numero} {problema}.")


def _parcela(descricao: str) -> Parcela | None:
    achado = _PARCELA.match(descricao)
    if achado is None:
        return None
    numero, total = int(achado["numero"]), int(achado["total"])
    if not 1 <= numero <= total or total < 2:
        return None
    return Parcela(numero=numero, total=total, descricao=achado["descricao"])


def _recusar_repetidos(linhas: list[LinhaOfx]) -> None:
    contagem: dict[str, int] = {}
    for linha in linhas:
        contagem[linha.id_externo] = contagem.get(linha.id_externo, 0) + 1
    repetidas = [linha for linha in linhas if contagem[linha.id_externo] > 1]
    if repetidas:
        raise FitidRepetido(repetidas)


def _saldo(texto: str) -> Saldo | None:
    bloco = _agregado(texto, "LEDGERBAL")
    if bloco is None:
        return None
    valor = _valor(_folha(bloco, "BALAMT"))
    data = _data(_folha(bloco, "DTASOF"))
    if valor is None or data is None:
        raise FormatoNaoReconhecido(
            "Não reconheci este arquivo: o saldo (LEDGERBAL) está ilegível."
        )
    return Saldo(valor=valor, data=data)


def _agregado(texto: str, tag: str) -> str | None:
    blocos = _agregados(texto, tag, limite=1)
    return blocos[0] if blocos else None


def _agregados(texto: str, tag: str, limite: int | None = None) -> list[str]:
    """O conteúdo de cada `<TAG>…</TAG>`, em ordem; um agregado sem fechamento
    encerra a busca. Busca linear: `<TAG>(.*?)</TAG>` ficaria quadrático num
    arquivo com muitas aberturas sem fechamento."""
    abre = re.compile(rf"<{tag}>", re.IGNORECASE)
    fecha = re.compile(rf"</{tag}>", re.IGNORECASE)
    blocos: list[str] = []
    posicao = 0
    while limite is None or len(blocos) < limite:
        inicio = abre.search(texto, posicao)
        if inicio is None:
            break
        fim = fecha.search(texto, inicio.end())
        if fim is None:
            break
        blocos.append(texto[inicio.end() : fim.start()])
        posicao = fim.end()
    return blocos


def _folha(bloco: str, tag: str) -> str | None:
    achado = re.search(rf"<{tag}>([^<\r\n]*)", bloco, re.IGNORECASE)
    if achado is None:
        return None
    return html.unescape(achado.group(1)).strip() or None


def _data(texto: str | None) -> date | None:
    # `aaaammdd[hhmmss[.xxx]][[-3:BRT]]`: os 8 primeiros dígitos já são a data
    # local do banco; diferente da Pluggy, o OFX não vem em UTC.
    if texto is None or not re.match(r"\d{8}", texto):
        return None
    try:
        return date(int(texto[:4]), int(texto[4:6]), int(texto[6:8]))
    except ValueError:
        return None


def _data_opcional(bloco: str, tag: str) -> date | None:
    return _data(_folha(bloco, tag))


def _valor(texto: str | None) -> Decimal | None:
    if texto is None:
        return None
    if "," in texto and "." not in texto:
        texto = texto.replace(",", ".")
    try:
        valor = Decimal(texto)
    except InvalidOperation:
        return None
    # Fração de centavo não existe no extrato; seria arredondada em silêncio.
    if not valor.is_finite() or valor != valor.quantize(_CENTAVO):
        return None
    return valor
