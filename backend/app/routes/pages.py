"""Páginas HTML estáticas (política de privacidade, termos, etc.)."""

from fastapi import APIRouter
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["pages"])

_PRIVACY_POLICY_HTML = """<!DOCTYPE html>
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
</html>"""


@router.get("/privacy-policy", response_class=HTMLResponse)
async def privacy_policy():
    """Política de privacidade do aplicativo."""
    return HTMLResponse(content=_PRIVACY_POLICY_HTML)
