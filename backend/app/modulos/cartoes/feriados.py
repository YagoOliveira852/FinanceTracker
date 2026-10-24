"""Consulta aos feriados da tabela `feriado`."""

from datetime import date

from sqlalchemy import extract, func, select
from sqlalchemy.orm import Session

from app.modulos.cartoes.models import Feriado


class FeriadosAusentes(Exception):
    """O período pedido tem ano que não está na tabela `feriado`.

    Calcular sem os feriados daria datas erradas sem aviso; é melhor falhar.
    """


def feriados_entre(sessao: Session, de: date, ate: date) -> dict[date, str]:
    """{data: descrição} dos feriados de `de` a `ate`, inclusive."""
    menor, maior = sessao.execute(
        select(func.min(extract("year", Feriado.data)), func.max(extract("year", Feriado.data)))
    ).one()
    if menor is None or de.year < menor or ate.year > maior:
        raise FeriadosAusentes(f"Sem feriados cadastrados para o período {de} a {ate}.")
    feriados = sessao.scalars(select(Feriado).where(Feriado.data.between(de, ate)))
    return {feriado.data: feriado.descricao for feriado in feriados}
