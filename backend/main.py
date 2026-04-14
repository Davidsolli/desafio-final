from fastapi import FastAPI

# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend Inicial do sistema OmniConnect Fitness"
)

# Rota básica de Health Check para testarmos se o servidor está no ar
@app.get("/")
async def health_check():
    return {
        "status": "online",
        "message": "Servidor OmniConnect rodando com sucesso! 🚀",
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa."
    }
