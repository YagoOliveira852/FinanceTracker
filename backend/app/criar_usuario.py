"""Cria o usuário único do app: `uv run python -m app.criar_usuario`.

Pede e-mail e senha no terminal (a senha não aparece nem fica no histórico do
shell). Não existe endpoint de cadastro: ver spec
`2026-10-19-backend-sincrono-usuario-unico-design.md`.
"""

import getpass
import sys

from sqlalchemy.orm import Session

from app.core.db import get_engine
from app.modulos.auth import service


def executar(sessao: Session) -> int:
    """Lê os dados, cria o usuário e devolve o código de saída do processo."""
    email = input("E-mail: ")
    senha = getpass.getpass("Senha: ")
    if getpass.getpass("Repita a senha: ") != senha:
        print("As senhas não conferem.", file=sys.stderr)
        return 1

    try:
        usuario = service.criar_usuario(sessao, email, senha)
    except service.DadosInvalidos as exc:
        print(exc, file=sys.stderr)
        return 1
    except service.UsuarioJaExiste:
        print("Já existe um usuário cadastrado; o app tem um só.", file=sys.stderr)
        return 1

    print(f"Usuário {usuario.email} criado.")
    return 0


def main() -> int:
    with Session(get_engine()) as sessao:
        return executar(sessao)


if __name__ == "__main__":
    sys.exit(main())
