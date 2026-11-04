"""Cliente da Pluggy: **somente leitura**. Além do `POST /auth`, só `GET`.

Conferido no MCP pluggy-docs em 2026-11-04 (plano `2026-11-04-sync-pluggy`):
a chave do `/auth` vale 2 horas e vai no header `X-API-KEY`; as transações
vêm de `GET /v2/transactions` com cursor (`next`), e contas e faturas, em
páginas. O cliente percorre as páginas e devolve as dataclasses de
`pluggy/tipos.py`; os erros viram `ErroPluggy`, com a mensagem em português
que o app mostra.
"""

import time
from collections.abc import Callable
from datetime import UTC, date, datetime
from decimal import Decimal
from typing import Any, Self

import httpx

from app.modulos.pluggy.tipos import ContaPluggy, FaturaPluggy, ItemPluggy, TransacaoPluggy

# A chave vale 2 horas; renova com 10 minutos de folga.
_VALIDADE_DA_CHAVE = 110 * 60
_TIMEOUT = httpx.Timeout(30.0)


class ErroPluggy(Exception):
    """Falha ao ler a Pluggy; `mensagem` vai para `conexao_pluggy.ultimo_erro`."""

    def __init__(self, mensagem: str):
        super().__init__(mensagem)
        self.mensagem = mensagem


class ItemNaoEncontrado(ErroPluggy):
    def __init__(self):
        super().__init__("A Pluggy não encontrou esta conexão. Confira o ID do item no Meu Pluggy.")


class ClientePluggy:
    def __init__(
        self,
        client_id: str,
        client_secret: str,
        url: str,
        *,
        relogio: Callable[[], float] = time.monotonic,
    ):
        self._credenciais = {"clientId": client_id, "clientSecret": client_secret}
        self._http = httpx.Client(base_url=url, timeout=_TIMEOUT)
        self._relogio = relogio
        self._chave: str | None = None
        self._chave_desde = 0.0

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        self.fechar()

    def fechar(self) -> None:
        self._http.close()

    def obter_item(self, item_id: str) -> ItemPluggy:
        dados = self._get(f"/items/{item_id}", nao_encontrado=ItemNaoEncontrado)
        return ItemPluggy(
            id=dados["id"],
            instituicao=(dados.get("connector") or {}).get("name") or "Banco",
            status=dados.get("status") or "",
            consentimento_expira_em=_momento(dados.get("consentExpiresAt")),
            atualizado_em=_momento(dados.get("lastUpdatedAt")),
        )

    def listar_contas(self, item_id: str) -> list[ContaPluggy]:
        return [
            ContaPluggy(
                id=conta["id"],
                tipo=conta.get("type") or "",
                subtipo=conta.get("subtype") or "",
                nome=conta.get("name") or conta.get("marketingName") or "Conta",
                numero=conta.get("number"),
                saldo=_decimal(conta.get("balance")),
            )
            for conta in self._paginas("/accounts", {"itemId": item_id})
        ]

    def listar_transacoes(self, account_id: str, *, desde: date) -> list[TransacaoPluggy]:
        """As transações da conta com data a partir de `desde`, incluindo as
        `PENDING` com data futura (parcelas e agendamentos)."""
        transacoes = []
        caminho = "/v2/transactions"
        parametros: dict[str, str] | None = {"accountId": account_id, "dateFrom": desde.isoformat()}
        while True:
            dados = self._get(caminho, parametros)
            transacoes.extend(_transacao(t) for t in dados.get("results") or [])
            proxima = dados.get("next")
            if not proxima:
                return transacoes
            # `next` é a query string pronta da próxima página.
            caminho, parametros = f"/v2/transactions{proxima}", None

    def listar_faturas(self, account_id: str) -> list[FaturaPluggy]:
        return [
            FaturaPluggy(
                id=fatura["id"],
                vencimento=_dia(fatura["dueDate"]),
                fechamento=_dia(fatura.get("billClosingDate")),
                total=_decimal(fatura.get("totalAmount")) or Decimal(0),
            )
            for fatura in self._paginas("/bills", {"accountId": account_id})
        ]

    def _paginas(self, caminho: str, parametros: dict[str, str]) -> list[dict[str, Any]]:
        resultados = []
        pagina = 1
        while True:
            dados = self._get(caminho, {**parametros, "page": str(pagina)})
            resultados.extend(dados.get("results") or [])
            if pagina >= int(dados.get("totalPages") or 1):
                return resultados
            pagina += 1

    def _get(
        self,
        caminho: str,
        parametros: dict[str, str] | None = None,
        *,
        nao_encontrado: type[ErroPluggy] | None = None,
    ) -> dict[str, Any]:
        resposta = self._pedir(caminho, parametros)
        if resposta.status_code == 401:
            # Chave vencida antes da hora: renova uma vez e repete.
            self._chave = None
            resposta = self._pedir(caminho, parametros)
        if resposta.status_code == 404 and nao_encontrado is not None:
            raise nao_encontrado()
        _verificar(resposta)
        return resposta.json()

    def _pedir(self, caminho: str, parametros: dict[str, str] | None) -> httpx.Response:
        chave = self._chave_valida()
        try:
            return self._http.get(caminho, params=parametros, headers={"X-API-KEY": chave})
        except httpx.HTTPError as erro:
            raise ErroPluggy("Não deu para falar com a Pluggy: sem resposta.") from erro

    def _chave_valida(self) -> str:
        if self._chave is None or self._relogio() - self._chave_desde >= _VALIDADE_DA_CHAVE:
            try:
                resposta = self._http.post("/auth", json=self._credenciais)
            except httpx.HTTPError as erro:
                raise ErroPluggy("Não deu para falar com a Pluggy: sem resposta.") from erro
            if resposta.status_code in (400, 401, 403):
                raise ErroPluggy("As credenciais da Pluggy foram recusadas. Confira o .env.")
            _verificar(resposta)
            self._chave = resposta.json()["apiKey"]
            self._chave_desde = self._relogio()
        return self._chave


def _verificar(resposta: httpx.Response) -> None:
    if resposta.status_code == 429:
        raise ErroPluggy("A Pluggy recusou por limite de requisições. Tente mais tarde.")
    if resposta.status_code >= 400:
        raise ErroPluggy(f"A Pluggy respondeu com erro ({resposta.status_code}).")


def _transacao(dados: dict[str, Any]) -> TransacaoPluggy:
    cartao = dados.get("creditCardMetadata") or {}
    return TransacaoPluggy(
        id=dados["id"],
        descricao=dados.get("description") or "",
        descricao_bruta=dados.get("descriptionRaw"),
        valor=_decimal(dados.get("amount")) or Decimal(0),
        momento=_momento(dados["date"]),
        sentido=dados.get("type") or "",
        status=dados.get("status") or "POSTED",
        tipo_operacao=dados.get("operationType"),
        categoria=dados.get("category"),
        parcela_numero=_inteiro(cartao.get("installmentNumber")),
        total_parcelas=_inteiro(cartao.get("totalInstallments")),
        data_compra=_momento(cartao.get("purchaseDate")),
        bill_id=cartao.get("billId"),
    )


def _decimal(valor: Any) -> Decimal | None:
    """Pela representação textual do número: o `float` do JSON nunca entra
    numa conta."""
    return None if valor is None else Decimal(str(valor))


def _inteiro(valor: Any) -> int | None:
    return None if valor is None else int(valor)


def _momento(texto: str | None) -> datetime | None:
    if not texto:
        return None
    momento = datetime.fromisoformat(texto)
    return momento if momento.tzinfo else momento.replace(tzinfo=UTC)


def _dia(texto: str | None) -> date | None:
    """Vencimento e fechamento são dias: a parte da data como veio (meia-noite
    UTC), sem trocar de fuso, que levaria o dia 13 para o dia 12."""
    if not texto:
        return None
    return date.fromisoformat(texto[:10])
