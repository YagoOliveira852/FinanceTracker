"""Rotas da importação de extratos. Só traduzem HTTP; as regras estão no service.

O arquivo chega em multipart (`UploadFile`, que precisa do `python-multipart`,
já incluído no `fastapi[standard]`), junto com a conta de destino.
"""

import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, HTTPException, Response, UploadFile, status
from fastapi.responses import JSONResponse

from app.core.deps import SessaoDep, get_usuario_atual
from app.core.erros import RespostaErro
from app.modulos.importacao import service
from app.modulos.importacao.parsers.extrato import IdentificadorRepetido
from app.modulos.importacao.schemas import (
    ErroImportacao,
    ImportacaoSaida,
    ResultadoImportacaoSaida,
    importacao_saida,
    linha_repetida_saida,
)

_NAO_ENCONTRADA = {status.HTTP_404_NOT_FOUND: {"model": RespostaErro}}

router = APIRouter(
    prefix="/importacoes",
    tags=["importacoes"],
    dependencies=[Depends(get_usuario_atual)],
    responses={status.HTTP_401_UNAUTHORIZED: {"model": RespostaErro}},
)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    responses={
        status.HTTP_200_OK: {
            "model": ResultadoImportacaoSaida,
            "description": "O arquivo já tinha sido importado; nada mudou.",
        },
        status.HTTP_422_UNPROCESSABLE_CONTENT: {"model": ErroImportacao},
    },
)
def importar(
    arquivo: Annotated[
        UploadFile,
        File(description="O OFX do extrato da conta ou da fatura, ou o CSV do Mercado Pago."),
    ],
    conta_id: Annotated[uuid.UUID, Form()],
    sessao: SessaoDep,
    response: Response,
) -> ResultadoImportacaoSaida:
    """Importa o arquivo na conta, tudo ou nada: as linhas entram como rascunho
    e a resposta é o resumo. Arquivo repetido devolve a importação anterior."""
    # Um byte além do limite basta para o service recusar sem ler tudo.
    dados = arquivo.file.read(service.TAMANHO_MAXIMO + 1)
    try:
        resultado = service.importar(
            sessao, conta_id=conta_id, nome_arquivo=arquivo.filename, dados=dados
        )
    except IdentificadorRepetido as exc:
        erro = ErroImportacao(
            detail=(
                "Nada foi importado: o arquivo tem lançamentos com o mesmo identificador"
                f" ({exc.campo}), e o app não escolhe sozinho qual descartar."
            ),
            linhas_repetidas=[linha_repetida_saida(linha) for linha in exc.linhas],
        )
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            content=erro.model_dump(mode="json", exclude_none=True),
        )
    if resultado.ja_importada:
        response.status_code = status.HTTP_200_OK
    return ResultadoImportacaoSaida(
        ja_importada=resultado.ja_importada,
        importacao=importacao_saida(service.obter(sessao, resultado.importacao.id)),
    )


@router.get("")
def listar(sessao: SessaoDep) -> list[ImportacaoSaida]:
    """O histórico de importações, da mais recente para a mais antiga."""
    return [importacao_saida(resumo) for resumo in service.listar(sessao)]


@router.get("/{importacao_id}", responses=_NAO_ENCONTRADA)
def obter(importacao_id: uuid.UUID, sessao: SessaoDep) -> ImportacaoSaida:
    try:
        return importacao_saida(service.obter(sessao, importacao_id))
    except service.ImportacaoNaoEncontrada as exc:
        raise _nao_encontrada() from exc


@router.delete(
    "/{importacao_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses=_NAO_ENCONTRADA | {status.HTTP_409_CONFLICT: {"model": RespostaErro}},
)
def desfazer(importacao_id: uuid.UUID, sessao: SessaoDep) -> None:
    """Desfaz a importação enquanto nada dela foi confirmado: apaga as
    transações e o saldo do extrato, devolve a fatura ao que era e libera o
    arquivo para ser importado de novo."""
    try:
        service.desfazer(sessao, importacao_id)
    except service.ImportacaoNaoEncontrada as exc:
        raise _nao_encontrada() from exc
    except service.NaoDaParaDesfazer as exc:
        raise HTTPException(
            status.HTTP_409_CONFLICT,
            detail="Não dá mais para desfazer: há transações desta importação já confirmadas.",
        ) from exc


def _nao_encontrada() -> HTTPException:
    return HTTPException(status.HTTP_404_NOT_FOUND, detail="Importação não encontrada.")
