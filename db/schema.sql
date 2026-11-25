-- Tabela da aplicacao (Atividade 4).
-- Executada automaticamente pelo container MySQL na primeira inicializacao (docker-entrypoint-initdb.d).
CREATE TABLE IF NOT EXISTS cadastros (
    id        INT AUTO_INCREMENT PRIMARY KEY,
    nome      VARCHAR(100) NOT NULL,
    email     VARCHAR(150) NOT NULL,
    curso     VARCHAR(100) NOT NULL,
    mensagem  VARCHAR(500),
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
