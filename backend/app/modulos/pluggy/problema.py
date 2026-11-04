"""O problema de uma conexão, para o card do Início e a tela Open Finance:
função pura (spec `2026-10-20-conexoes-pluggy-design`, "Estado do sync" e
decisões do código). O card só aparece quando há problema."""

from collections.abc import Iterable
from dataclasses import dataclass
from datetime import UTC, datetime, time, timedelta
from enum import StrEnum
from zoneinfo import ZoneInfo


class Problema(StrEnum):
    # Na ordem de gravidade: a lista vem do mais para o menos grave.
    vencido = "vencido"
    erro = "erro"
    sem_dados = "sem_dados"
    vencendo = "vencendo"


_HORA_DO_SYNC = time(7, 0)
_HORA_DA_REPESCAGEM = time(13, 0)
_SEM_DADOS = timedelta(hours=30)
_AVISO_DO_CONSENTIMENTO = timedelta(days=30)


@dataclass(frozen=True)
class EstadoSync:
    criada_em: datetime
    consentimento_expira_em: datetime | None
    ultimo_sync_em: datetime | None
    ultima_tentativa_em: datetime | None
    ultimo_erro: str | None


def problema_da_conexao(estado: EstadoSync, *, agora: datetime, fuso: ZoneInfo) -> Problema | None:
    expira = estado.consentimento_expira_em
    if expira is not None and expira <= agora:
        return Problema.vencido
    if _falhou_nas_duas(estado, agora, fuso):
        return Problema.erro
    desde = estado.ultimo_sync_em or estado.criada_em
    if agora - desde > _SEM_DADOS:
        return Problema.sem_dados
    if expira is not None and expira - agora <= _AVISO_DO_CONSENTIMENTO:
        return Problema.vencendo
    return None


def _falhou_nas_duas(estado: EstadoSync, agora: datetime, fuso: ZoneInfo) -> bool:
    """O sync das 07:00 e a repescagem das 13:00 de hoje falharam: há erro e
    nenhum sucesso desde as 07:00, e a repescagem já passou."""
    if estado.ultimo_erro is None:
        return False
    hoje = agora.astimezone(fuso).date()
    sync_de_hoje = datetime.combine(hoje, _HORA_DO_SYNC, fuso)
    repescagem = datetime.combine(hoje, _HORA_DA_REPESCAGEM, fuso)
    sem_sucesso_hoje = estado.ultimo_sync_em is None or estado.ultimo_sync_em < sync_de_hoje
    return sem_sucesso_hoje and agora >= repescagem


def mais_grave(problemas: Iterable[Problema | None]) -> Problema | None:
    ordem = list(Problema)
    presentes = [p for p in problemas if p is not None]
    return min(presentes, key=ordem.index, default=None)


def proximo_sync(agora: datetime, fuso: ZoneInfo) -> datetime:
    """O próximo 07:00 no fuso de negócio, em UTC como os outros instantes."""
    local = agora.astimezone(fuso)
    hoje = datetime.combine(local.date(), _HORA_DO_SYNC, fuso)
    return (hoje if local < hoje else hoje + timedelta(days=1)).astimezone(UTC)
