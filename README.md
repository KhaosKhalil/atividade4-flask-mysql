# Atividade 4 – Flask + MySQL com Docker

Aplicação Flask que grava e lista dados num banco MySQL. A arquitetura é em **duas camadas**, montada com **Docker Compose** numa instância EC2: em vez de duas instâncias, cada camada é um **container**.

```
Navegador → http://IP_PUBLICO:5000 → container web (Flask + Gunicorn) → db:3306 (rede interna do Docker) → container db (MySQL 8)
```

| Camada | Container | O que faz | Porta exposta |
|---|---|---|---|
| App | `web` | Flask + Gunicorn | **5000** publicada para a internet |
| DB | `db` | MySQL 8 (volume `dados-mysql`) | **nenhuma**: só o `web` alcança, pela `rede-interna` |

Rodapé: **Khalil Ayoub de Lima Krayem – Atividade 4**.

## Estrutura

```
├── app.py               # app Flask, conexão com o MySQL (PyMySQL) e rotas
├── requirements.txt     # Flask, python-dotenv, PyMySQL, Gunicorn (com versões)
├── Dockerfile           # imagem do container web (python:3.12-slim + Gunicorn)
├── docker-compose.yml   # serviços web e db, rede interna e volume
├── .dockerignore        # .env e venv/ não entram na imagem
├── .env.example         # nomes das variáveis, sem valores
├── .env                 # credenciais reais – só no servidor (no .gitignore)
├── .gitignore           # venv/, .env, *.pem
├── db/schema.sql        # tabela cadastros (executada pelo MySQL na 1ª inicialização)
├── templates/           # base.html, index, sobre, cadastro, listar, 404
└── static/              # css, js, img
```

## Segurança

- **Banco não exposto:** o container `db` não publica a porta 3306. Só containers da `rede-interna` (o `web`) conseguem conectar. No Security Group da EC2 ficam liberadas só a 22 (SSH) e a 5000 (Flask).
- **Usuário próprio, não root:** o MySQL cria `DB_USER` com acesso **só** ao banco `DB_NAME`. O root fica só para administração.
- **Credenciais no `.env`:** o Flask lê com `load_dotenv()` e `os.getenv()`. O compose também usa o `.env` para criar o banco e o usuário. O `.env` está no `.gitignore` e no `.dockerignore`, então não vai para o GitHub nem para a imagem.
- **SQL Injection:** o `INSERT` usa consulta parametrizada (`%s` + tupla).

## Variáveis do `.env`

| Variável | Conteúdo |
|---|---|
| `DB_HOST` | `db` (nome do serviço MySQL na rede interna) |
| `DB_PORT` | `3306` |
| `DB_USER` | usuário da aplicação |
| `DB_PASSWORD` | senha desse usuário |
| `DB_NAME` | `atividade4` |
| `DB_ROOT_PASSWORD` | senha do root do MySQL (usada só pelo container `db`) |
| `SECRET_KEY` | chave do Flask (mensagens flash) |

## Rotas

| Rota | O que faz |
|---|---|
| `/` | Página inicial |
| `/sobre` | Explica a arquitetura |
| `/cadastro` | GET mostra o formulário; POST insere no banco (consulta parametrizada) e redireciona para `/listar` |
| `/listar` | Lista todos os registros em tabela HTML (ou mensagem se estiver vazio) |

A conexão com o banco é aberta em cada operação e fechada no `finally`.

## Como subir (Ubuntu na EC2)

```bash
# 1. Docker
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 git

# 2. Projeto
git clone https://github.com/KhaosKhalil/atividade4-flask-mysql.git atividade4
cd atividade4
cp .env.example .env
nano .env                      # preencha usuário, senhas e SECRET_KEY

# 3. Containers
sudo docker compose up -d --build
sudo docker compose ps         # db (healthy) e web (Up)
```

Acesse `http://IP_PUBLICO:5000`. O Security Group precisa liberar a porta 5000.

> Em instâncias pequenas (t3.micro, 1 GB) vale criar swap:
> `sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`

## Comandos úteis

```bash
sudo docker compose ps                     # status dos containers
sudo docker compose logs -f web            # logs do Flask/Gunicorn
sudo docker compose restart                # reinicia
# SELECT direto no MySQL do container:
sudo docker exec -it atividade4-db sh -c 'mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" atividade4 -e "SELECT * FROM cadastros;"'
```

## Tabela

```sql
CREATE TABLE cadastros (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL,
    curso VARCHAR(100) NOT NULL,
    mensagem VARCHAR(500),
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```
