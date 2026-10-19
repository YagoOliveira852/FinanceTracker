from sqlalchemy import Engine, inspect, text
from sqlalchemy.orm import Session


def test_commit_do_codigo_testado_nao_vaza_para_o_banco(sessao: Session, engine: Engine):
    sessao.execute(text("CREATE TABLE marcador_isolamento (id int)"))
    sessao.commit()

    # Dentro do teste, o commit vale (virou SAVEPOINT)...
    assert inspect(sessao.connection()).has_table("marcador_isolamento")
    # ...mas outra conexão não enxerga nada: a transação externa será revertida.
    with engine.connect() as outra_conexao:
        assert not inspect(outra_conexao).has_table("marcador_isolamento")
