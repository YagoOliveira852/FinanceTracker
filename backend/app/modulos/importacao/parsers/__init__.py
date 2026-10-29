"""Leitores de extrato: o formato é reconhecido pelo conteúdo do arquivo,
não pela extensão."""

from app.modulos.importacao.parsers import csv_mercadopago, ofx
from app.modulos.importacao.parsers.extrato import Extrato, FormatoNaoReconhecido, decodificar


def ler_extrato(dados: bytes) -> Extrato:
    """OFX (Nubank, conta e cartão) ou CSV do extrato do Mercado Pago."""
    texto = decodificar(dados)
    if "<OFX>" in texto.upper():
        return ofx.ler_ofx(dados)
    if csv_mercadopago.reconhece(texto):
        return csv_mercadopago.ler_csv_mercadopago(dados)
    raise FormatoNaoReconhecido(
        "Não reconheci este arquivo: não é um OFX nem um CSV do Mercado Pago."
    )
