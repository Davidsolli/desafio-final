"""
Serviço de envio de emails via Resend.

Responsável por ferramentas de comunicação por email,
templates HTML, e integração com Resend SDK.
"""

import asyncio
from datetime import datetime

import resend

from app.config.settings import settings


class EmailSendError(Exception):
    """Exceção quando falha ao enviar email."""

    pass


class EmailService:
    """Serviço de envio de emails."""

    def __init__(self):
        """Inicializar serviço com cliente Resend."""
        if not settings.RESEND_API_KEY:
            raise EmailSendError(
                "RESEND_API_KEY não configurada nas variáveis de ambiente"
            )

        resend.api_key = settings.RESEND_API_KEY
        self.from_email = settings.RESEND_FROM_EMAIL
        self.from_name = settings.RESEND_FROM_NAME

    async def send_password_reset_email(
        self,
        user_name: str,
        to_email: str,
        token: str,
    ) -> None:
        """
        Enviar email de recuperação de senha.

        Args:
            user_name: Nome do usuário
            to_email: Email do destinatário
            token: Token temporário (enviado no link)

        Raises:
            EmailSendError: Se falhar ao enviar
        """
        reset_link = (
            f"{settings.FRONTEND_URL}{settings.FRONTEND_RESET_PASSWORD_ROUTE}"
            f"?token={token}"
        )

        html_body = self._render_password_reset_template(user_name, reset_link)

        try:
            # O SDK Resend é síncrono; executar em thread separada para não
            # bloquear o event loop assíncrono do FastAPI.
            await asyncio.to_thread(
                resend.Emails.send,
                {
                    "from": f"{self.from_name} <{self.from_email}>",
                    "to": to_email,
                    "subject": "Recupere sua senha — OmniConnect Fitness",
                    "html": html_body,
                },
            )
        except Exception as e:
            raise EmailSendError(f"Falha ao enviar email: {str(e)}")

    @staticmethod
    def _render_password_reset_template(user_name: str, reset_link: str) -> str:
        """
        Renderizar template HTML do email de reset.

        Args:
            user_name: Nome do usuário
            reset_link: Link completo de reset

        Returns:
            HTML do email
        """
        current_year = datetime.now().year
        return f"""
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Recupere sua senha</title>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background-color: #f5f5f5;
            margin: 0;
            padding: 0;
        }}
        .container {{
            max-width: 600px;
            margin: 40px auto;
            background-color: #fff;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
        }}
        .header h1 {{
            margin: 0;
            font-size: 24px;
        }}
        .content {{
            padding: 30px 20px;
        }}
        .greeting {{
            font-size: 16px;
            margin-bottom: 20px;
        }}
        .message {{
            color: #666;
            line-height: 1.8;
            margin-bottom: 30px;
        }}
        .reset-button {{
            display: inline-block;
            background-color: #667eea;
            color: white;
            text-decoration: none;
            padding: 12px 30px;
            border-radius: 6px;
            font-weight: 600;
            margin: 20px 0;
            transition: background-color 0.3s;
        }}
        .reset-button:hover {{
            background-color: #764ba2;
        }}
        .link-text {{
            color: #999;
            font-size: 12px;
            word-break: break-all;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 20px 0;
        }}
        .expiration {{
            background-color: #fff3cd;
            border: 1px solid #ffecb5;
            color: #856404;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
            font-size: 14px;
        }}
        .security-warning {{
            background-color: #f8d7da;
            border: 1px solid #f5c6cb;
            color: #721c24;
            padding: 15px;
            border-radius: 4px;
            margin: 20px 0;
            font-size: 14px;
        }}
        .footer {{
            background-color: #f9f9f9;
            border-top: 1px solid #eee;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #999;
        }}
        .button-container {{
            text-align: center;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏋️ OmniConnect Fitness</h1>
            <p>Recuperação de Senha</p>
        </div>

        <div class="content">
            <div class="greeting">Olá, <strong>{user_name}</strong>!</div>

            <div class="message">
                <p>Você solicitou para recuperar sua senha. Para redefinir sua senha e acessar sua conta, clique no botão abaixo:</p>
            </div>

            <div class="button-container">
                <a href="{reset_link}" class="reset-button">Redefinir Minha Senha</a>
            </div>

            <p style="color: #999; font-size: 14px; text-align: center;">Ou copie este link:</p>
            <div class="link-text">{reset_link}</div>

            <div class="expiration">
                ⏰ <strong>Atenção!</strong> Este link expira em <strong>60 minutos</strong>. Se não usar neste período, solicite um novo link de recuperação.
            </div>

            <div class="security-warning">
                🔒 <strong>Aviso de Segurança:</strong> Se você não solicitou esta mudança de senha, ignore este email. Sua conta permanecerá protegida. Nunca compartilhe este link com terceiros.
            </div>

            <p style="color: #666; font-size: 14px; margin-top: 30px;">
                Se tiver dúvidas, entre em contato com nosso suporte:<br>
                <a href="mailto:suporte@omniconnect.fit" style="color: #667eea;">suporte@omniconnect.fit</a>
            </p>
        </div>

        <div class="footer">
            <p>© {current_year} OmniConnect Fitness. Todos os direitos reservados.</p>
            <p>Este é um email automático. Por favor, não responda.</p>
        </div>
    </div>
</body>
</html>
        """.strip()
