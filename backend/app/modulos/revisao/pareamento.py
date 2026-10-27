"""Sugestão de pares de transferência entre contas próprias: função pura, sem
banco (spec `2026-10-19-revisao-classificacao`, "Decisões do código da revisão").

Um Pix entre duas contas próprias chega das fontes como uma saída numa conta e
uma entrada na outra. O par é calculado na leitura, como a sugestão de
categoria, e só vira transferência quando o usuário liga na revisão.
"""

import uuid
from collections.abc import Collection, Iterable
from datetime import date
from decimal import Decimal
from typing import Protocol

DIAS_MAXIMOS = 2


class Movimento(Protocol):
    @property
    def id(self) -> uuid.UUID: ...
    @property
    def conta_id(self) -> uuid.UUID: ...
    @property
    def valor(self) -> Decimal: ...
    @property
    def data(self) -> date: ...


def sugerir_pares[S: Movimento, E: Movimento](
    saidas: Iterable[S],
    entradas: Iterable[E],
    recusados: Collection[tuple[uuid.UUID, uuid.UUID]],
) -> list[tuple[S, E]]:
    """Pares (saída, entrada) prováveis, ordenados pela data da saída.

    Casam: mesmo valor, contas diferentes, até `DIAS_MAXIMOS` dias de diferença
    e par fora de `recusados` (pares de ids `(saida, entrada)`). Cada transação
    entra em um par só: vence a menor diferença de dias, depois a data da
    saída e os ids, para o resultado não depender da ordem das listas. Quem
    chama passa só os rascunhos que podem parear.
    """
    entradas = list(entradas)
    candidatos = [
        (abs((entrada.data - saida.data).days), saida.data, saida.id, entrada.id, saida, entrada)
        for saida in saidas
        for entrada in entradas
        if saida.valor == entrada.valor
        and saida.conta_id != entrada.conta_id
        and abs((entrada.data - saida.data).days) <= DIAS_MAXIMOS
        and (saida.id, entrada.id) not in recusados
    ]
    candidatos.sort(key=lambda candidato: candidato[:4])

    usados: set[uuid.UUID] = set()
    pares: list[tuple[S, E]] = []
    for *_, saida, entrada in candidatos:
        if saida.id in usados or entrada.id in usados:
            continue
        usados.update((saida.id, entrada.id))
        pares.append((saida, entrada))
    return sorted(pares, key=lambda par: (par[0].data, par[0].id))
