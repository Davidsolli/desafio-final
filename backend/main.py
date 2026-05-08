from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse

from app.config.database import init_db
from app.routes import user, auth, chat, logbook, goal, invitation, webhooks
from app.routes.workout_sheet import router as workout_sheet_router, catalog_router as exercise_catalog_router
from app.routes.food_catalog import router as food_catalog_router
from app.routes.diet import custom_food_router, diet_router
from app.routes.diet_logbook import router as diet_logbook_router

# Rota básica de Health Check
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Gerenciar lifecycle da aplicação.
    Inicializa o banco de dados na startup.
    """
    # Startup
    await init_db()
    yield
    # Shutdown (aqui iria lógica de cleanup se necessário)


# Inicialização da aplicação
app = FastAPI(
    title="OmniConnect API",
    version="1.0.0",
    description="Backend do sistema OmniConnect Fitness",
    lifespan=lifespan,
)

# Configurar CORS para permitir requisições do Flutter web (desenvolvimento)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permitir todas as origens em desenvolvimento
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health Check
@app.get("/")
async def health_check():
    """Health check da API."""
    return {
        "status": "online",
        "message": "Servidor OmniConnect rodando com sucesso!",
        "docs": "Acesse http://localhost:8000/docs para ver a documentação interativa.",
        "version": "1.0.1"
    }

# Política de Privacidade
@app.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy():
    """Política de privacidade do aplicativo."""
    return """
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Política de Privacidade - OmniConnect Fitness</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; line-height: 1.6; }
            h1 { color: #333; }
            p { color: #666; }
        </style>
    </head>
    <body>
        <h1>Política de Privacidade - OmniConnect Fitness</h1>
        <h2>Introdução</h2>
        <p>Sua privacidade é importante para nós. Esta política de privacidade explica como coletamos, usamos e protegemos seus dados.</p>

        <h2>Dados Coletados</h2>
        <p>O OmniConnect Fitness coleta os seguintes dados:</p>
        <ul>
            <li>Número de telefone para autenticação e contato</li>
            <li>Mensagens de texto via WhatsApp</li>
            <li>Dados de perfil e fitness</li>
            <li>Informações de treinos e nutrição</li>
        </ul>

        <h2>Uso de Dados</h2>
        <p>Os dados são usados exclusivamente para:</p>
        <ul>
            <li>Autenticação no aplicativo</li>
            <li>Comunicação via WhatsApp</li>
            <li>Personalização de conteúdo de fitness</li>
            <li>Melhorias nos serviços</li>
        </ul>

        <h2>Proteção de Dados</h2>
        <p>Implementamos medidas de segurança para proteger seus dados contra acesso não autorizado.</p>

        <h2>Compartilhamento de Dados</h2>
        <p>Não compartilhamos seus dados com terceiros sem seu consentimento explícito.</p>

        <h2>Contato</h2>
        <p>Para dúvidas sobre esta política, entre em contato através do aplicativo.</p>

        <p><small>Última atualização: 08 de Maio de 2026</small></p>
    </body>
    </html>
    """

# Registrar rotas
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(invitation.router)
app.include_router(chat.router)
app.include_router(logbook.router)
app.include_router(goal.router)
app.include_router(workout_sheet_router)
app.include_router(exercise_catalog_router)
app.include_router(food_catalog_router)
app.include_router(custom_food_router)
app.include_router(diet_router)
app.include_router(diet_logbook_router)
app.include_router(webhooks.router)

