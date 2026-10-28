"""Possível duplicata entre uma linha que chega de uma fonte e o que já estava
na conta: função pura, sem banco (spec `2026-10-28-importacao-design`,
"Possível duplicata").

O caso real antes da Pluggy é o lançamento manual de algo que depois chega no
extrato; com a Pluggy (S7), o mesmo gasto pelo OFX e pelo Open Finance. Nada é
fundido: a nova entra como rascunho com `possivel_duplicata_de` e a revisão
decide qual fica.
"""

import uuid
from collections.abc import Iterable, Sequence
from datetime import date
from decimal import Decimal
from typing import Protocol

DIAS_MAXIMOS = 2


class Lancamento(Protocol):
    # Valor sempre positivo; o sentido vem de `entrada`.
    @property
    def valor(self) -> Decimal: ...
    @property
    def data(self) -> date: ...
    @property
    def entrada(self) -> bool: ...


class Existente(Lancamento, Protocol):
    @property
    def id(self) -> uuid.UUID: ...


def marcar_duplicatas[E: Existente](
    novas: Sequence[Lancamento], existentes: Iterable[E]
) -> dict[int, E]:
    """Para cada nova (pelo índice) que parece repetir uma existente, a existente.

    Casam: mesmo valor, mesmo sentido e até `DIAS_MAXIMOS` dias de diferença.
    Um para um: vence a menor diferença de dias, depois a data da nova, o
    índice dela e o id da existente, para o resultado não depender da ordem.
    Quem chama passa só as existentes que podem ser duplicata: mesma conta,
    outra fonte, não ignoradas e que não são elas mesmas uma duplicata.
    """
    existentes = list(existentes)
    candidatos = [
        (abs((nova.data - existente.data).days), nova.data, indice, existente.id, existente)
        for indice, nova in enumerate(novas)
        for existente in existentes
        if _casam(nova, existente)
    ]
    candidatos.sort(key=lambda candidato: candidato[:4])

    marcadas: dict[int, E] = {}
    usadas: set[uuid.UUID] = set()
    for _, _, indice, id_existente, existente in candidatos:
        if indice in marcadas or id_existente in usadas:
            continue
        marcadas[indice] = existente
        usadas.add(id_existente)
    return marcadas


def _casam(nova: Lancamento, existente: Lancamento) -> bool:
    return (
        nova.valor == existente.valor
        and nova.entrada == existente.entrada
        and abs((nova.data - existente.data).days) <= DIAS_MAXIMOS
    )
