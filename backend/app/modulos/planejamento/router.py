"""Rotas do planejamento. Só traduzem HTTP; as regras estão no service."""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.planejamento import service
from app.modulos.planejamento.schemas import (
    ConfiguracaoEntrada,
    ConfiguracaoSaida,
    ProximaDataSaida,
    RendaEdicao,
    RendaEntrada,
    RendaSaida,
    ResumoSaida,
    configuracao_saida,
    proxima_saida,
    renda_saida,
    resumo_saida,
)

router = APIRouter(
    prefix="/planejamento",
    tags=["planejamento"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.get("/rendas")
def listar_rendas(sessao: SessaoDep, hoje: HojeDep) -> list[RendaSaida]:
    """Todas as rendas previstas, com a próxima data: ativas primeiro, depois as
    inativas (renda nunca é excluída)."""
    return [renda_saida(item) for item in service.listar_rendas(sessao, hoje)]


@router.post("/rendas", status_code=status.HTTP_201_CREATED)
def criar_renda(dados: RendaEntrada, sessao: SessaoDep, hoje: HojeDep) -> RendaSaida:
    item = service.criar_renda(
        sessao,
        descricao=dados.descricao,
        valor=dados.valor,
        dia_previsto=dados.dia_previsto,
        conta_id=dados.conta_id,
        hoje=hoje,
    )
    return renda_saida(item)


@router.put("/rendas/{renda_id}", responses={status.HTTP_404_NOT_FOUND: {"model": RespostaErro}})
def editar_renda(
    renda_id: uuid.UUID, dados: RendaEdicao, sessao: SessaoDep, hoje: HojeDep
) -> RendaSaida:
    """Edita a renda ou a desativa/reativa (renda nunca é excluída)."""
    try:
        item = service.editar_renda(
            sessao,
            renda_id,
            descricao=dados.descricao,
            valor=dados.valor,
            dia_previsto=dados.dia_previsto,
            conta_id=dados.conta_id,
            ativa=dados.ativa,
            hoje=hoje,
        )
    except service.RendaNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Renda não encontrada.") from exc
    return renda_saida(item)


@router.get("/rendas/previa")
def previa_renda(
    dia_previsto: Annotated[int, Query(ge=1, le=31)], sessao: SessaoDep, hoje: HojeDep
) -> ProximaDataSaida:
    """Próxima data para um dia ainda não salvo (formulário da renda)."""
    return proxima_saida(service.previa(sessao, dia_previsto, hoje))


@router.get("/configuracao")
def obter_configuracao(sessao: SessaoDep, hoje: HojeDep) -> ConfiguracaoSaida:
    """A configuração do cálculo (nula até o primeiro salvamento), o gasto mensal
    automático e a média semanal real do histórico."""
    return configuracao_saida(service.ler_configuracao(sessao, hoje))


@router.put("/configuracao")
def salvar_configuracao(
    dados: ConfiguracaoEntrada, sessao: SessaoDep, hoje: HojeDep
) -> ConfiguracaoSaida:
    """Cria a configuração no primeiro salvamento; depois, atualiza."""
    leitura = service.salvar_configuracao(
        sessao,
        colchao=dados.colchao,
        meta_reserva_meses=dados.meta_reserva_meses,
        gasto_semanal_estimado=dados.gasto_semanal_estimado,
        gasto_mensal_referencia=dados.gasto_mensal_referencia,
        hoje=hoje,
    )
    return configuracao_saida(leitura)


@router.get("/resumo")
def resumo(sessao: SessaoDep, hoje: HojeDep) -> ResumoSaida:
    """O que o Início mostra: a sobra até o próximo salário e o alerta de ritmo,
    o aporte quando o salário chegou, os rascunhos considerados e a reserva."""
    return resumo_saida(service.resumo(sessao, hoje))
