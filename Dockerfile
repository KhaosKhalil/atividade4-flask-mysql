# Imagem do servidor web Flask (Atividade 4)
FROM python:3.12-slim

WORKDIR /app

# Dependencias primeiro (aproveita o cache do Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Codigo da aplicacao (o .env NAO entra na imagem; vem por --env-file)
COPY . .

EXPOSE 5000

# Gunicorn em 0.0.0.0:5000 = aceita conexoes externas
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:5000", "app:app"]
