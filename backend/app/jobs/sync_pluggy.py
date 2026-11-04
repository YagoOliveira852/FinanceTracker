"""Sync diário da Pluggy: `uv run python -m app.jobs.sync_pluggy [--repescagem]`.

Na VPS, o `financas-sync.timer` roda às 07:00 (`America/Fortaleza`) e o
`financas-sync-repescagem.timer`, às 13:00, só para as conexões que falharam
(plano `2026-11-04-sync-pluggy`). Sai com 1 se alguma conexão falhou, para o
systemd marcar a execução; o detalhe fica em `conexao_pluggy.ultimo_erro`.
"""

import argparse
import logging
import sys
from datetime import UTC, datetime
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_engine
from app.modulos.pluggy.client import ClientePluggy
from app.modulos.pluggy.sync import FontePluggy, sincronizar_todas


def executar(
    sessao: Session, fonte: FontePluggy, config: Settings, *, agora: datetime, repescagem: bool
) -> int:
    fuso = ZoneInfo(config.tz_negocio)
    resultados = sincronizar_todas(
        sessao,
        fonte,
        agora=agora,
        hoje=agora.astimezone(fuso).date(),
        fuso=fuso,
        repescagem=repescagem,
    )
    if not resultados:
        print("Nenhuma conexão para sincronizar.")
    for r in resultados:
        if r.ok:
            print(
                f"Conexão {r.conexao_id}: {r.novas} novas, {r.atualizadas} atualizadas, "
                f"{r.removidas} removidas, {r.marcadas_removidas} marcadas como removidas."
            )
        else:
            print(f"Conexão {r.conexao_id}: erro — {r.erro}", file=sys.stderr)
    return 0 if all(r.ok for r in resultados) else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--repescagem", action="store_true", help="só as conexões cuja última tentativa falhou"
    )
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    config = get_settings()
    segredo = config.pluggy_client_secret
    if not config.pluggy_client_id or segredo is None or not segredo.get_secret_value():
        print("Defina PLUGGY_CLIENT_ID e PLUGGY_CLIENT_SECRET no .env.", file=sys.stderr)
        return 2
    with (
        ClientePluggy(
            config.pluggy_client_id,
            segredo.get_secret_value(),
            config.pluggy_url,
        ) as cliente,
        Session(get_engine()) as sessao,
    ):
        return executar(
            sessao, cliente, config, agora=datetime.now(UTC), repescagem=args.repescagem
        )


if __name__ == "__main__":
    sys.exit(main())
