"""Atividade 4 - Aplicacao Flask e Banco de Dados MySQL em containers Docker.

Arquivo principal: cria o app Flask, a conexao com o MySQL e as rotas.
As credenciais do banco ficam no arquivo .env (nunca no codigo-fonte).
"""
import os
from datetime import datetime

import pymysql
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, url_for

# Carrega as variaveis do arquivo .env para o ambiente.
load_dotenv()

app = Flask(__name__)
# Chave usada pelo Flask para as mensagens de sucesso/erro (flash).
app.secret_key = os.getenv("SECRET_KEY") or os.urandom(24)

NOME_ALUNO = os.getenv("NOME_ALUNO", "Khalil Ayoub de Lima Krayem")
ATIVIDADE = "Atividade 4 - Flask e MySQL em containers Docker"


def conectar():
    """Abre uma conexao com o MySQL (container db) usando os dados do .env."""
    return pymysql.connect(
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        connect_timeout=5,
    )


@app.context_processor
def dados_globais():
    """Variaveis disponiveis em todos os templates."""
    return {
        "nome_aluno": NOME_ALUNO,
        "atividade": ATIVIDADE,
        "ano": datetime.now().year,
    }


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/sobre")
def sobre():
    return render_template("sobre.html")


@app.route("/cadastro", methods=["GET", "POST"])
def cadastro():
    if request.method == "GET":
        return render_template("cadastro.html", dados={})

    dados = {
        "nome": request.form.get("nome", "").strip(),
        "email": request.form.get("email", "").strip(),
        "curso": request.form.get("curso", "").strip(),
        "mensagem": request.form.get("mensagem", "").strip(),
    }
    if not dados["nome"] or not dados["email"] or not dados["curso"]:
        flash("Preencha nome, e-mail e curso.", "erro")
        return render_template("cadastro.html", dados=dados), 400

    # Consulta parametrizada: os valores vao separados do SQL (evita SQL Injection).
    sql = "INSERT INTO cadastros (nome, email, curso, mensagem) VALUES (%s, %s, %s, %s)"
    conexao = None
    try:
        conexao = conectar()
        with conexao.cursor() as cursor:
            cursor.execute(sql, (dados["nome"], dados["email"], dados["curso"], dados["mensagem"]))
        conexao.commit()
    except pymysql.MySQLError as erro:
        app.logger.error("Erro ao inserir: %s", erro)
        flash("Não foi possível salvar no banco de dados.", "erro")
        return render_template("cadastro.html", dados=dados), 500
    finally:
        # Fecha a conexao ao final da operacao, com ou sem erro.
        if conexao:
            conexao.close()

    flash(f"Cadastro de {dados['nome']} salvo com sucesso!", "sucesso")
    return redirect(url_for("listar"))


@app.route("/listar")
def listar():
    sql = "SELECT id, nome, email, curso, mensagem, criado_em FROM cadastros ORDER BY id"
    conexao = None
    try:
        conexao = conectar()
        with conexao.cursor() as cursor:
            cursor.execute(sql)
            registros = cursor.fetchall()
    except pymysql.MySQLError as erro:
        app.logger.error("Erro ao listar: %s", erro)
        flash("Não foi possível consultar o banco de dados.", "erro")
        return render_template("listar.html", registros=[]), 500
    finally:
        if conexao:
            conexao.close()

    return render_template("listar.html", registros=registros)


@app.errorhandler(404)
def pagina_nao_encontrada(erro):
    return render_template("404.html"), 404


if __name__ == "__main__":
    # host="0.0.0.0" aceita conexoes externas; porta 5000 publicada pelo Docker e liberada no Security Group.
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)
