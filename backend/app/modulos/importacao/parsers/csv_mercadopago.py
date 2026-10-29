"""Leitor do CSV do extrato da conta do Mercado Pago: função pura, bytes →
`Extrato`. Spec `2026-10-28-importacao-design`, adendo de 2026-10-29.

O CSV sai do site (o app só exporta PDF). São dois blocos separados por uma
linha vazia: o resumo (`INITIAL_BALANCE;CREDITS;DEBITS;FINAL_BALANCE`), que
não é usado, e os lançamentos, em ordem de data. Separador `;`, sem aspas, data
`dd-mm-aaaa` e valor `1.234,56` com sinal (negativo é saída).
"""

import re
from datetime import date, datetime
from decimal import Decimal

from app.modulos.importacao.models import FonteImportacao
from app.modulos.importacao.parsers.extrato import (
    Extrato,
    FormatoNaoReconhecido,
    Linha,
    Saldo,
    TipoExtrato,
    decodificar,
    recusar_repetidos,
)

CABECALHO = "RELEASE_DATE;TRANSACTION_TYPE;REFERENCE_ID;TRANSACTION_NET_AMOUNT;PARTIAL_BALANCE"
_COLUNAS = CABECALHO.count(";") + 1
_VALOR = re.compile(r"^-?(\d{1,3}(\.\d{3})*|\d+),\d{2}$")


def reconhece(texto: str) -> bool:
    """O arquivo tem a linha de cabeçalho dos lançamentos."""
    return any(linha.strip() == CABECALHO for linha in texto.splitlines())


def ler_csv_mercadopago(dados: bytes) -> Extrato:
    """Lê o arquivo inteiro ou falha: `FormatoNaoReconhecido` se não é o CSV
    do Mercado Pago ou tem lançamento ilegível, `IdentificadorRepetido` se um
    REFERENCE_ID aparece mais de uma vez."""
    linhas_do_arquivo = decodificar(dados).splitlines()
    try:
        inicio = [linha.strip() for linha in linhas_do_arquivo].index(CABECALHO) + 1
    except ValueError:
        raise FormatoNaoReconhecido(
            "Não reconheci este arquivo: não é um CSV do extrato do Mercado Pago."
        ) from None
    celulas = [linha.split(";") for linha in linhas_do_arquivo[inicio:] if linha.strip()]

    lidas = [_linha(colunas, numero) for numero, colunas in enumerate(celulas, start=1)]
    # Valor zero não muda o saldo, e transação tem valor > 0.
    linhas = [linha for linha in lidas if linha.valor != 0]
    recusar_repetidos(linhas, "REFERENCE_ID")
    return Extrato(
        fonte=FonteImportacao.csv_mercadopago,
        tipo=TipoExtrato.conta,
        periodo_inicio=lidas[0].data if lidas else None,
        periodo_fim=lidas[-1].data if lidas else None,
        saldo=_saldo(celulas[-1], len(celulas), lidas[-1].data) if lidas else None,
        linhas=linhas,
    )


def _linha(colunas: list[str], numero: int) -> Linha:
    if len(colunas) != _COLUNAS:
        raise _incompleto(numero, f"não tem as {_COLUNAS} colunas do extrato")
    data_texto, descricao, identificador, valor_texto, _ = (c.strip() for c in colunas)
    if not identificador:
        raise _incompleto(numero, "não tem identificador (REFERENCE_ID)")
    data = _data(data_texto)
    if data is None:
        raise _incompleto(numero, "não tem uma data válida (RELEASE_DATE)")
    valor = _valor(valor_texto)
    if valor is None:
        raise _incompleto(numero, "não tem um valor válido (TRANSACTION_NET_AMOUNT)")
    return Linha(
        identificador=identificador,
        id_externo=identificador,
        data=data,
        valor=valor,
        descricao=descricao,
    )


def _saldo(colunas: list[str], numero: int, data: date) -> Saldo:
    # O saldo depois do último lançamento é o do fim do período (o
    # FINAL_BALANCE do resumo): nada muda o saldo depois dele.
    valor = _valor(colunas[-1].strip())
    if valor is None:
        raise _incompleto(numero, "não tem um saldo válido (PARTIAL_BALANCE)")
    return Saldo(valor=valor, data=data)


def _incompleto(numero: int, problema: str) -> FormatoNaoReconhecido:
    return FormatoNaoReconhecido(f"Não reconheci este arquivo: o lançamento {numero} {problema}.")


def _data(texto: str) -> date | None:
    try:
        return datetime.strptime(texto, "%d-%m-%Y").date()
    except ValueError:
        return None


def _valor(texto: str) -> Decimal | None:
    # Só o formato do extrato: o regex já recusa fração de centavo.
    if not _VALOR.match(texto):
        return None
    return Decimal(texto.replace(".", "").replace(",", "."))
