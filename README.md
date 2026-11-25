# Atividade 4 – Flask + MySQL em instâncias EC2 separadas

Aplicação Flask (instância **App**) que grava e lista dados em um MySQL (instância **DB**). As duas conversam pela rede privada da AWS. O banco não fica exposto à internet e as credenciais ficam só no `.env` da App.

```
Navegador → http://IP_PUBLICO_APP:5000 → Flask (App) → IP_PRIVADO_DB:3306 → MySQL (DB)
```

Rodapé: **Khalil Ayoub de Lima Krayem – Atividade 4**.

## Estrutura

```
├── app.py                 # app Flask, conexão com o MySQL (PyMySQL) e rotas
├── requirements.txt       # Flask, python-dotenv, PyMySQL, Gunicorn (com versões)
├── .env.example           # nomes das variáveis, sem valores
├── .env                   # credenciais reais – só na instância App (no .gitignore)
├── .gitignore             # venv/, .env, *.pem
├── db/schema.sql          # tabela cadastros
├── templates/             # base.html, index, sobre, cadastro, listar, 404
├── static/                # css, js, img
└── deploy/
    ├── setup_db.sh        # instância DB: MySQL, bind-address, banco, usuário, tabela
    └── setup_app.sh       # instância App: venv, dependências, .env, teste, serviço
```

## Rotas

| Rota | O que faz |
|---|---|
| `/` | Página inicial |
| `/sobre` | Explica a arquitetura |
| `/cadastro` | GET mostra o formulário; POST insere no banco (consulta parametrizada) e redireciona para `/listar` |
| `/listar` | Lista todos os registros em tabela HTML (ou mensagem se estiver vazio) |

A conexão é aberta em cada operação e fechada no `finally`.

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

---

## Passo a passo do deploy

### Etapa 1 – Instâncias (console EC2)
Crie **duas** instâncias Ubuntu Server, na mesma VPC e com o mesmo par de chaves:
- `app-seunome` → anote o **IP público**
- `db-seunome` → anote o **IP privado**

### Etapa 2 – Security Groups

| SG | Regra | Origem |
|---|---|---|
| App (`app-seunome-sg`) | 22/tcp SSH | 0.0.0.0/0 |
| App | 5000/tcp Flask | 0.0.0.0/0 |
| DB (`db-seunome-sg`) | 22/tcp SSH | 0.0.0.0/0 |
| DB | 3306/tcp MySQL | **o Security Group da App** (nunca 0.0.0.0/0) |

### Etapa 3 – MySQL (instância DB)
Copie o projeto para a DB (`git clone ...`) e rode:

```bash
bash deploy/setup_db.sh IP_PRIVADO_DA_APP
```

O script pede a senha do usuário `app_user` sem mostrar na tela (12+ letras e números). Ele faz o seguinte:
- instala o MySQL Server;
- troca o `bind-address` para `0.0.0.0` e reinicia o serviço;
- cria o banco `atividade4`;
- cria o usuário `app_user`@`IP_PRIVADO_DA_APP` só com SELECT, INSERT, UPDATE e DELETE nesse banco;
- cria a tabela.

### Etapas 4 a 6 e 8 – App
Na instância App:

```bash
git clone https://github.com/SEU_USUARIO/SEU_REPO.git atividade4
cd atividade4
bash deploy/setup_app.sh IP_PRIVADO_DO_DB
```

O script faz o seguinte:
- instala Python, venv e `mysql-client`;
- cria o venv e instala o `requirements.txt`;
- cria o `.env` (pede a senha sem mostrar e aplica `chmod 600`);
- **testa a conexão com o MySQL pelo IP privado**;
- sobe o Gunicorn em `0.0.0.0:5000` como serviço `webserver`.

Teste manual da conexão (Etapa 4):

```bash
mysql -h IP_PRIVADO_DO_DB -u app_user -p atividade4 -e "SHOW TABLES;"
```

Para conferir que a porta 3306 **não** abre pela internet (no seu PC, PowerShell):

```powershell
Test-NetConnection IP_PUBLICO_DO_DB -Port 3306
```

O resultado deve ser `TcpTestSucceeded : False`.

### Etapa 8 – Testes
1. Abra `http://IP_PUBLICO_APP:5000/cadastro` e cadastre **5 ou mais** registros.
2. Confira em `http://IP_PUBLICO_APP:5000/listar`.
3. Na DB, rode o SELECT e tire o print:
   ```bash
   sudo mysql atividade4 -e "SELECT * FROM cadastros;"
   ```

### Comandos úteis (App)

```bash
sudo systemctl status webserver
sudo systemctl restart webserver
sudo journalctl -u webserver -n 50
```

## Entrega (Teams)
- `http://IP_PUBLICO_APP:5000`
- `http://IP_PUBLICO_APP:5000/listar`
- Link do repositório no GitHub (com `.env.example`, sem `.env`)
- Print do SELECT na instância DB
- Print das regras de entrada do Security Group da DB

---

## Docker (Flask em container na instância App)

O Flask roda num container Docker na instância **App**. O MySQL continua na instância **DB**, e o container acessa o banco pelo IP privado definido no `.env`.

```bash
# na instância App, dentro da pasta do projeto (com o .env criado)
sudo apt-get install -y docker.io docker-compose-v2
sudo docker compose up -d --build     # cria a imagem e sobe o container
sudo docker ps                        # container atividade4-web na porta 5000
sudo docker logs -f atividade4-web    # logs do Gunicorn
```

- `Dockerfile`: imagem `python:3.12-slim` + `requirements.txt` + Gunicorn em `0.0.0.0:5000`.
- `docker-compose.yml`: serviço `web` com `env_file: .env`, porta `5000:5000` e `restart: always` (volta sozinho se a máquina reiniciar).
- `.dockerignore`: o `.env` e o `venv/` **não** entram na imagem.
