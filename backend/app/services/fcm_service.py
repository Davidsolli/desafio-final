import os
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Optional, Dict, Any
from app.config.settings import settings

logger = logging.getLogger(__name__)

class FCMService:
    _initialized = False

    def __init__(self):
        if not FCMService._initialized:
            try:
                try:
                    firebase_admin.get_app()
                    FCMService._initialized = True
                except ValueError:
                    cred_path = settings.FIREBASE_CREDENTIALS_PATH
                    if os.path.exists(cred_path):
                        cred = credentials.Certificate(cred_path)
                        firebase_admin.initialize_app(cred)
                        FCMService._initialized = True
                        logger.info(f"Firebase Admin inicializado com: {cred_path}")
                    else:
                        logger.warning(f"Arquivo {cred_path} não encontrado.")
            except Exception as e:
                logger.error(f"Falha ao inicializar o Firebase: {str(e)}")

    def send_notification(self, token: str, title: str, body: str, data: Optional[Dict[str, Any]] = None) -> bool:
        if not FCMService._initialized:
            return False

        try:
            processed_data = None
            if data:
                processed_data = {k: str(v) for k, v in data.items()}

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=processed_data,
                token=token,
            )
            
            response = messaging.send(message)
            logger.info(f"Notificação enviada com sucesso: {response}")
            return True

        except Exception as e:
            logger.error(f"Erro ao enviar notificação pro FCM: {str(e)}")
            return False
