"""Tabela `feriado`: o seed da migration e a consulta por período."""

from datetime import date

import holidays
import pytest
from sqlalchemy import select

from app.modulos.cartoes.feriados import FeriadosAusentes, feriados_entre
from app.modulos.cartoes.models import Feriado


def _bancarios(anos: range) -> dict[date, str]:
    """Critério do seed: feriados nacionais e a segunda e a terça de Carnaval."""
    nacionais = holidays.Brazil(years=anos, categories=("public",))
    facultativos = holidays.Brazil(years=anos, categories=("optional",))
    carnaval = {dia: nome for dia, nome in facultativos.items() if nome == "Carnaval"}
    return {**dict(nacionais.items()), **carnaval}


def test_tabela_bate_com_a_biblioteca(sessao):
    na_tabela = {f.data: f.descricao for f in sessao.scalars(select(Feriado))}

    assert na_tabela == _bancarios(range(2024, 2041))


def test_carnaval_entra_e_cinzas_e_corpus_christi_nao(sessao):
    datas = set(sessao.scalars(select(Feriado.data)))

    assert {date(2026, 2, 16), date(2026, 2, 17)} <= datas
    assert date(2026, 2, 18) not in datas
    assert date(2026, 6, 4) not in datas


def test_feriados_entre(sessao):
    assert feriados_entre(sessao, date(2026, 10, 1), date(2026, 10, 31)) == {
        date(2026, 10, 12): "Nossa Senhora Aparecida"
    }


@pytest.mark.parametrize(
    ("de", "ate"),
    [
        (date(2041, 1, 1), date(2041, 1, 31)),
        (date(2040, 12, 1), date(2041, 1, 31)),
        (date(2023, 12, 1), date(2024, 1, 31)),
    ],
)
def test_periodo_fora_da_tabela_levanta(sessao, de, ate):
    with pytest.raises(FeriadosAusentes):
        feriados_entre(sessao, de, ate)
