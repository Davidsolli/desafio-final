# Usa a imagem oficial do Python numa versão mais leve (slim)
FROM python:3.11-slim

# Impede a criação de arquivos .pyc compilados e evita buffers no stdout
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Define o diretório de trabalho dentro do container
WORKDIR /app

# Instala ferramentas do sistema para pacotes que usam compilador C (como o psycopg2, caso precisem depois)
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copia o arquivo de dependências e instala ANTES do código fonte 
# Isso otimiza o uso do cache do Docker
COPY requirements.txt .

# Instala torch CPU-only antes dos demais pacotes para evitar baixar a versão CUDA (~2 GB a mais)
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir -r requirements.txt

# Copia todo o código fonte para dentro do container
COPY . .

# Expõe a porta padrão
EXPOSE 8000

# Comando padrão para subir o servidor Uvicorn escutando na porta 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
