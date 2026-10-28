"""Saída HTTP da importação. A entrada é multipart (arquivo + `conta_id`),
declarada direto na rota."""

import uuid
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field

from app.core.dinheiro import Dinheiro
from app.core.erros import RespostaErro
from app.modulos.contas.models import TipoConta
from app.modulos.importacao.models import FonteImportacao
from app.modulos.importacao.parsers.ofx import LinhaOfx
from app.modulos.importacao.service import ResumoImportacao


class ContaDaImportacao(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    nome: str
    tipo: TipoConta


class SaldoExtratoSaida(BaseModel):
    valor: Dinheiro = Field(description="Saldo final do extrato (`LEDGERBAL`).")
    data: date


class FaturaDaImportacao(BaseModel):
    competencia: date = Field(description="Primeiro dia do mês do vencimento.")
    valor_informado: Dinheiro | None = Field(description="O valor do banco gravado na fatura.")
    data_fechamento: date = Field(description="O fechamento do arquivo, gravado na fatura.")


class ImportacaoSaida(BaseModel):
    id: uuid.UUID
    criado_em: datetime
    nome_arquivo: str | None
    fonte: FonteImportacao
    conta: ContaDaImportacao | None
    periodo_inicio: date | None
    periodo_fim: date | None
    qtd_novas: int = Field(description="Entraram como rascunho (sem as possíveis duplicatas).")
    qtd_possiveis_duplicatas: int = Field(description="Entraram como rascunho, marcadas.")
    qtd_ja_importadas: int = Field(description="Já estavam no app; ficaram de fora.")
    qtd_parcelas: int = Field(description="Parcelas, com a data da compra estimada.")
    qtd_confirmadas: int = Field(description="Transações desta importação já confirmadas.")
    qtd_pendentes: int = Field(description="Transações desta importação ainda na revisão.")
    pode_desfazer: bool = Field(description="Nenhuma transação desta importação foi confirmada.")
    saldo_extrato: SaldoExtratoSaida | None = Field(description="Só no extrato da conta.")
    fatura: FaturaDaImportacao | None = Field(description="Só na fatura do cartão.")


class ResultadoImportacaoSaida(BaseModel):
    ja_importada: bool = Field(
        description="O arquivo já tinha sido importado: `importacao` é a anterior, nada mudou."
    )
    importacao: ImportacaoSaida


class LinhaRepetidaSaida(BaseModel):
    fitid: str
    data: date
    valor: Dinheiro = Field(description="Com sinal, como no arquivo: negativo é saída.")
    descricao: str


class ErroImportacao(RespostaErro):
    """O formato único de erro; no FITID repetido, também as linhas repetidas."""

    linhas_repetidas: list[LinhaRepetidaSaida] | None = None


def importacao_saida(resumo: ResumoImportacao) -> ImportacaoSaida:
    importacao = resumo.importacao
    fatura = None
    if importacao.fatura is not None:
        fatura = FaturaDaImportacao(
            competencia=importacao.fatura.competencia,
            valor_informado=importacao.fatura_valor_gravado,
            data_fechamento=importacao.fatura_fechamento_gravado,
        )
    saldo = None
    if resumo.saldo is not None:
        saldo = SaldoExtratoSaida(valor=resumo.saldo.saldo, data=resumo.saldo.data)
    return ImportacaoSaida(
        id=importacao.id,
        criado_em=importacao.criado_em,
        nome_arquivo=importacao.nome_arquivo,
        fonte=FonteImportacao(importacao.fonte),
        conta=None
        if importacao.conta is None
        else ContaDaImportacao.model_validate(importacao.conta),
        periodo_inicio=importacao.periodo_inicio,
        periodo_fim=importacao.periodo_fim,
        qtd_novas=importacao.qtd_novas,
        qtd_possiveis_duplicatas=importacao.qtd_possiveis_duplicatas,
        qtd_ja_importadas=importacao.qtd_ja_importadas,
        qtd_parcelas=importacao.qtd_parcelas,
        qtd_confirmadas=resumo.qtd_confirmadas,
        qtd_pendentes=resumo.qtd_pendentes,
        pode_desfazer=resumo.pode_desfazer,
        saldo_extrato=saldo,
        fatura=fatura,
    )


def linha_repetida_saida(linha: LinhaOfx) -> LinhaRepetidaSaida:
    return LinhaRepetidaSaida(
        fitid=linha.fitid, data=linha.data, valor=linha.valor, descricao=linha.descricao
    )
