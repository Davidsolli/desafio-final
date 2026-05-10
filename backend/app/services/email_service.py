"""Serviço de envio de emails transacionais via Resend."""

import asyncio
import logging

import resend

from app.config.settings import settings

logger = logging.getLogger(__name__)


async def send_password_reset_email(to_email: str, to_name: str, reset_link: str) -> None:
    """
    Envia email com link de recuperação de senha.

    Args:
        to_email: Email do destinatário.
        to_name: Nome do destinatário.
        reset_link: URL completa com o token de reset.
    """
    resend.api_key = settings.RESEND_API_KEY

    from_address = f"{settings.RESEND_FROM_NAME} <{settings.RESEND_FROM_EMAIL}>"

    html_body = f"""
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px;">
  <table style="max-width: 600px; margin: 0 auto; background-color: #ffffff;
                border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
    <tr>
      <td style="background-color: #1a1a2e; padding: 24px; text-align: center;">
        <h1 style="color: #ffffff; margin: 0; font-size: 22px;">OmniConnect Fitness</h1>
      </td>
    </tr>
    <tr>
      <td style="padding: 32px 24px;">
        <h2 style="color: #1a1a2e; margin-top: 0;">Redefinição de Senha</h2>
        <p style="color: #555; line-height: 1.6;">Olá, <strong>{to_name}</strong>!</p>
        <p style="color: #555; line-height: 1.6;">
          Recebemos uma solicitação para redefinir a senha da sua conta.
          Clique no botão abaixo para criar uma nova senha:
        </p>
        <div style="text-align: center; margin: 32px 0;">
          <a href="{reset_link}"
             style="background-color: #4f46e5; color: #ffffff; padding: 14px 28px;
                    text-decoration: none; border-radius: 6px; font-weight: bold;
                    font-size: 16px; display: inline-block;">
            Redefinir Minha Senha
          </a>
        </div>
        <p style="color: #555; line-height: 1.6;">
          Este link expira em <strong>60 minutos</strong>.
        </p>
        <p style="color: #555; line-height: 1.6;">
          Se você não solicitou a redefinição, ignore este email — sua senha permanece a mesma.
        </p>
        <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
        <p style="color: #999; font-size: 12px;">
          Se o botão não funcionar, copie e cole este link no navegador:<br>
          <a href="{reset_link}" style="color: #4f46e5; word-break: break-all;">{reset_link}</a>
        </p>
      </td>
    </tr>
    <tr>
      <td style="background-color: #f9f9f9; padding: 16px 24px; text-align: center;">
        <p style="color: #aaa; font-size: 12px; margin: 0;">
          © 2026 OmniConnect Fitness. Todos os direitos reservados.
        </p>
      </td>
    </tr>
  </table>
</body>
</html>
"""

    params = {
        "from": from_address,
        "to": [to_email],
        "subject": "Redefinição de Senha — OmniConnect Fitness",
        "html": html_body,
    }

    try:
        await asyncio.to_thread(resend.Emails.send, params)
        logger.info("Email de recuperação enviado para %s", to_email)
    except Exception as exc:
        logger.error("Falha ao enviar email de recuperação para %s: %s", to_email, exc)
        raise
