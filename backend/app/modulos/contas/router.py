"""Rotas de contas. Só traduzem HTTP; as regras estão no service."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.deps import HojeDep, SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.contas import service
from app.modulos.contas.schemas import ContaEntrada, ContaSaida, ContasResumo, InstituicaoSaida

# `dependencies` no router: toda rota daqui exige o access token, sem repetir
# `UsuarioDep` em cada uma (as rotas não precisam do usuário em si).
router = APIRouter(
    prefix="/contas",
    tags=["contas"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}


@router.get("")
def listar(sessao: SessaoDep) -> ContasResumo:
    """Todas as contas com o saldo atual, e o total disponível (correntes e carteiras)."""
    resumo = service.listar_contas(sessao)
    return ContasResumo(
        total_disponivel=resumo.total_disponivel,
        contas=[_saida(conta) for conta in resumo.contas],
    )


@router.post("", status_code=status.HTTP_201_CREATED)
def criar(dados: ContaEntrada, sessao: SessaoDep, hoje: HojeDep) -> ContaSaida:
    """Cadastra uma conta corrente ou a carteira (dinheiro em espécie)."""
    conta = service.criar_conta(
        sessao,
        nome=dados.nome,
        tipo=dados.tipo,
        nome_instituicao=dados.instituicao,
        saldo_inicial=dados.saldo_inicial,
        data_saldo_inicial=dados.data_saldo_inicial,
        hoje=hoje,
    )
    return _saida(conta)


@router.get("/{conta_id}", responses=_NAO_ENCONTRADA)
def obter(conta_id: uuid.UUID, sessao: SessaoDep) -> ContaSaida:
    try:
        conta = service.obter_conta(sessao, conta_id)
    except service.ContaNaoEncontrada as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Conta não encontrada.") from exc
    return _saida(conta)


def _saida(item: service.ContaComSaldo) -> ContaSaida:
    conta = item.conta
    instituicao = conta.instituicao
    return ContaSaida(
        id=conta.id,
        nome=conta.nome,
        tipo=conta.tipo,
        instituicao=InstituicaoSaida.model_validate(instituicao) if instituicao else None,
        saldo_inicial=conta.saldo_inicial,
        data_saldo_inicial=conta.data_saldo_inicial,
        saldo_atual=item.saldo_atual,
        ativa=conta.ativa,
    )
