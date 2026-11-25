#!/usr/bin/env bash
# Prepara a instancia App (Ubuntu) e coloca o Flask no ar na porta 5000.
#
# Uso, dentro da instancia App, a partir da pasta do projeto:
#   bash deploy/setup_app.sh IP_PRIVADO_DO_DB
#
# Se o .env ainda nao existir, o script cria pedindo a senha do banco
# (sem mostrar na tela). O .env fica so nesta instancia (nao vai pro GitHub).
set -euo pipefail

DB_HOST_ARG="${1:-}"
PROJETO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USUARIO="$(whoami)"
SERVICO="webserver"
cd "$PROJETO_DIR"

echo ">> Atualizando pacotes e instalando Python, venv, pip e cliente MySQL..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip git mysql-client

echo ">> [Etapa 5] Ambiente virtual e dependencias..."
[ -d venv ] || python3 -m venv venv
# shellcheck disable=SC1091
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip list

echo ">> [Etapa 6] Arquivo .env..."
if [ ! -f .env ]; then
    [ -n "$DB_HOST_ARG" ] || read -r -p "IP privado da instancia DB: " DB_HOST_ARG
    read -r -s -p "Senha do usuario app_user no MySQL: " DB_PASSWORD; echo
    cat > .env <<EOF
DB_HOST=${DB_HOST_ARG}
DB_PORT=3306
DB_USER=app_user
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=atividade4
SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
EOF
    chmod 600 .env
    echo ".env criado (permissao 600)."
else
    echo ".env ja existe, mantido."
fi

echo ">> [Etapa 4] Testando conexao com o MySQL pelo IP privado..."
set -a; source .env; set +a
MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" \
    -e "SHOW DATABASES; SHOW TABLES;" || { echo "Falhou: confira Security Group, bind-address e usuario."; exit 1; }

echo ">> [Etapa 8] Servico systemd '$SERVICO' (Gunicorn em 0.0.0.0:5000)..."
sudo tee /etc/systemd/system/${SERVICO}.service > /dev/null <<EOF
[Unit]
Description=Servidor Web Flask (Atividade 4)
After=network.target

[Service]
User=${USUARIO}
WorkingDirectory=${PROJETO_DIR}
ExecStart=${PROJETO_DIR}/venv/bin/gunicorn --workers 2 --bind 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICO"
sudo systemctl restart "$SERVICO"
sleep 2
sudo systemctl --no-pager status "$SERVICO" | head -n 5

IP_PUBLICO="$(curl -s --max-time 3 https://checkip.amazonaws.com || echo 'IP_PUBLICO')"
echo
echo ">> Pronto! http://${IP_PUBLICO}:5000  e  http://${IP_PUBLICO}:5000/listar"
