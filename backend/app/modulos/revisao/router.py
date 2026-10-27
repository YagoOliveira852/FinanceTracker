"""Rotas da revisão. Só traduzem HTTP; as regras estão no service."""

from fastapi import APIRouter, Depends, status

from app.core.deps import SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.categorias.schemas import CategoriaResumo
from app.modulos.revisao import service
from app.modulos.revisao.schemas import (
    DuplicataSaida,
    ParSaida,
    RascunhoSaida,
    RevisaoSaida,
    SugestaoSaida,
    TransacaoRevisao,
)

router = APIRouter(
    prefix="/revisao",
    tags=["revisao"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.get("")
def listar(sessao: SessaoDep) -> RevisaoSaida:
    """O que espera o usuário: as decisões ("Precisam de você") e os rascunhos
    comuns com a categoria sugerida pelas regras agora."""
    revisao = service.listar(sessao)
    return RevisaoSaida(
        total=revisao.total,
        qtd_sugeridos=revisao.qtd_sugeridos,
        pares=[
            ParSaida(
                saida=TransacaoRevisao.model_validate(par.saida),
                entrada=TransacaoRevisao.model_validate(par.entrada),
                dias=par.dias,
            )
            for par in revisao.pares
        ],
        pagamentos=[TransacaoRevisao.model_validate(t) for t in revisao.pagamentos],
        duplicatas=[
            DuplicataSaida(
                rascunho=TransacaoRevisao.model_validate(d.rascunho),
                outra=TransacaoRevisao.model_validate(d.outra),
            )
            for d in revisao.duplicatas
        ],
        sumidas=[TransacaoRevisao.model_validate(t) for t in revisao.sumidas],
        rascunhos=[_rascunho(r) for r in revisao.rascunhos],
    )


def _rascunho(rascunho: service.Rascunho) -> RascunhoSaida:
    regra = rascunho.sugerida
    sugestao = None
    if regra is not None:
        sugestao = SugestaoSaida(
            regra_id=regra.id,
            padrao=regra.padrao,
            origem=regra.origem,
            categoria=CategoriaResumo.model_validate(regra.categoria),
        )
    return RascunhoSaida(
        **TransacaoRevisao.model_validate(rascunho.transacao).model_dump(),
        padrao=rascunho.padrao,
        sugestao=sugestao,
        efeito_confirmando=rascunho.efeito_confirmando,
        efeito_corrigindo=rascunho.efeito_corrigindo,
    )
