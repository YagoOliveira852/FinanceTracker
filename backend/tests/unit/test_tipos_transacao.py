from app.modulos.transacoes.models import TIPOS_ENTRADA, TIPOS_SAIDA, TipoTransacao


def test_todo_tipo_tem_exatamente_um_sentido():
    """Tipo novo sem sentido definido faria o saldo tratá-lo como saída."""
    assert TIPOS_ENTRADA.isdisjoint(TIPOS_SAIDA)
    assert TIPOS_ENTRADA | TIPOS_SAIDA == set(TipoTransacao)
