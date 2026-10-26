"""Classificação dos rascunhos: funções puras, sem banco.

O padrão de uma regra é a descrição original normalizada: o que sobra quando
saem acentos, maiúsculas, datas, números, códigos e os termos genéricos que os
bancos põem em toda linha. Ex.: `PIX ENVIADO 12/11 PADARIA SAO JOSE LTDA 0349`
→ `padaria sao jose ltda`. A regra casa quando o padrão aparece como palavras
inteiras na descrição normalizada; entre as que casam, a ordem sai dos dados
(spec `2026-10-19-revisao-classificacao`).
"""

import re
import unicodedata
import uuid
from collections.abc import Iterable
from typing import Protocol

from app.modulos.categorias.models import GrupoCategoria, OrigemRegra
from app.modulos.transacoes.models import TipoTransacao

# Já normalizados. Expressões e palavras saem só inteiras ("pix" sai, "pixel" fica).
TERMOS_GENERICOS = (
    "transferencia enviada pelo pix",
    "transferencia recebida pelo pix",
    "transferencia enviada",
    "transferencia recebida",
    "deposito recebido por boleto",
    "pagamento de fatura",
    "pagamento de boleto",
    "pagamento recebido",
    "compra no debito",
    "compra no credito",
    "debito em conta",
    "pix enviado",
    "pix recebido",
    "transferencia",
    "pagamento",
    "estorno",
    "compra",
    "debito",
    "credito",
    "pix",
    "ted",
    "doc",
)
# Mais longas primeiro: "pix enviado" sai inteira antes de "pix" sozinho.
_TERMOS_EM_PALAVRAS = sorted((tuple(t.split()) for t in TERMOS_GENERICOS), key=len, reverse=True)

_GASTO = frozenset({GrupoCategoria.essencial, GrupoCategoria.variavel})
_GRUPOS_DO_TIPO = {
    TipoTransacao.despesa: _GASTO,
    # O estorno devolve um gasto: o de uma compra no mercado é Mercado.
    TipoTransacao.estorno: _GASTO,
    TipoTransacao.receita: frozenset({GrupoCategoria.renda}),
    TipoTransacao.aporte: frozenset({GrupoCategoria.investimento}),
    TipoTransacao.resgate: frozenset({GrupoCategoria.investimento}),
}


def normalizar(descricao: str) -> str:
    """Minúsculas, sem acentos, sem palavras com dígito (datas, números,
    códigos), sem pontuação e sem termos genéricos dos bancos."""
    sem_acentos = "".join(
        c for c in unicodedata.normalize("NFKD", descricao) if not unicodedata.combining(c)
    )
    palavras = re.sub(r"[^a-z0-9]+", " ", sem_acentos.lower()).split()
    palavras = [p for p in palavras if not any(c.isdigit() for c in p)]
    return " ".join(_sem_termos_genericos(palavras))


def _sem_termos_genericos(palavras: list[str]) -> list[str]:
    restantes = []
    i = 0
    while i < len(palavras):
        termo = next((t for t in _TERMOS_EM_PALAVRAS if tuple(palavras[i : i + len(t)]) == t), None)
        if termo is None:
            restantes.append(palavras[i])
            i += 1
        else:
            i += len(termo)
    return restantes


def casa(padrao: str, descricao_normalizada: str) -> bool:
    """O padrão aparece como palavras inteiras na descrição (`bar` não casa
    `barbearia`). Os dois já normalizados."""
    return f" {padrao} " in f" {descricao_normalizada} "


def grupos_do_tipo(tipo: TipoTransacao) -> frozenset[GrupoCategoria]:
    """Grupos de categoria que combinam com o tipo; vazio para os tipos sem
    categoria (transferência, pagamento de fatura e ajuste)."""
    return _GRUPOS_DO_TIPO.get(tipo, frozenset())


def natureza(grupo: GrupoCategoria) -> str:
    """Gasto (essencial e variável), renda ou investimento: grupos da mesma
    natureza combinam com os mesmos tipos de transação."""
    return "gasto" if grupo in _GASTO else grupo


class RegraCandidata(Protocol):
    @property
    def padrao(self) -> str: ...
    @property
    def origem(self) -> str: ...
    @property
    def conta_id(self) -> uuid.UUID | None: ...


def escolher_regra[R: RegraCandidata](
    descricao_normalizada: str, conta_id: uuid.UUID, regras: Iterable[R]
) -> R | None:
    """A regra que sugere a categoria, ou `None` se nenhuma casa.

    Casam as regras gerais e as da própria conta cujo padrão aparece na
    descrição. Entre elas: manual antes de aprendida, restrita a uma conta antes
    de geral, padrão mais longo antes; por fim a ordem alfabética, só para o
    resultado não depender da ordem da lista. Quem chama passa só as regras que
    podem sugerir (categoria ativa e compatível com o tipo).
    """
    candidatas = [
        regra
        for regra in regras
        if regra.conta_id in (None, conta_id) and casa(regra.padrao, descricao_normalizada)
    ]
    return min(
        candidatas,
        key=lambda regra: (
            regra.origem != OrigemRegra.manual,
            regra.conta_id is None,
            -len(regra.padrao),
            regra.padrao,
        ),
        default=None,
    )
