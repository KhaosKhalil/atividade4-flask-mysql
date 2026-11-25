#!/usr/bin/env bash
# Prepara a instancia DB (Ubuntu): instala e configura o MySQL (Etapa 3).
#
# Uso, dentro da instancia DB, a partir da pasta do projeto:
#   bash deploy/setup_db.sh IP_PRIVADO_DA_APP
#
# O script pede a senha do usuario da aplicacao sem mostrar na tela.
# Use uma senha forte, so com letras e numeros (ex.: 20+ caracteres).
set -euo pipefail

APP_IP="${1:?Informe o IP privado da instancia App. Ex.: bash deploy/setup_db.sh 172.31.10.20}"
DB_NAME="${DB_NAME:-atividade4}"
DB_USER="${DB_USER:-app_user}"
PROJETO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -r -s -p "Senha para o usuario ${DB_USER}: " DB_PASSWORD; echo
read -r -s -p "Repita a senha: " DB_PASSWORD2; echo
[ "$DB_PASSWORD" = "$DB_PASSWORD2" ] || { echo "As senhas nao conferem."; exit 1; }
[[ "$DB_PASSWORD" =~ ^[A-Za-z0-9]{12,}$ ]] || { echo "Use 12+ caracteres, so letras e numeros."; exit 1; }

echo ">> [Etapa 3.1] Atualizando pacotes..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

echo ">> [Etapa 3.2] Instalando o MySQL Server..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server
sudo systemctl enable --now mysql
sudo systemctl --no-pager status mysql | head -n 3

echo ">> [Etapa 3.3] bind-address = 0.0.0.0 (aceitar conexoes da rede)..."
CNF=/etc/mysql/mysql.conf.d/mysqld.cnf
sudo sed -i -E 's/^[#[:space:]]*bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' "$CNF"
grep -q '^bind-address' "$CNF" || echo 'bind-address = 0.0.0.0' | sudo tee -a "$CNF" > /dev/null
grep '^bind-address' "$CNF"
sudo systemctl restart mysql

echo ">> [Etapas 3.4 a 3.7] Banco, usuario restrito e tabela..."
sudo mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'${APP_IP}' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${DB_USER}'@'${APP_IP}' IDENTIFIED BY '${DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${DB_USER}'@'${APP_IP}';
FLUSH PRIVILEGES;
SQL
sudo mysql "${DB_NAME}" < "${PROJETO_DIR}/db/schema.sql"

echo ">> Conferindo:"
sudo mysql -e "SELECT user, host FROM mysql.user WHERE user='${DB_USER}'; SHOW GRANTS FOR '${DB_USER}'@'${APP_IP}';"
sudo mysql "${DB_NAME}" -e "SHOW TABLES; DESCRIBE cadastros;"
sudo ss -tlnp | grep 3306 || true

echo
echo ">> Pronto! Use no .env da App: DB_HOST=$(hostname -I | awk '{print $1}')  DB_NAME=${DB_NAME}  DB_USER=${DB_USER}"
