import os
import firebase_admin
from firebase_admin import credentials, messaging
from typing import Optional, Dict, Any

class FCMService:
    _initialized = False

    def __init__(self):
        # Inicializar o app do firebase caso não tenha sido inicializado
        if not FCMService._initialized:
            try:
                # O ideal é pegar do .env, por default usa o path da raiz do backend
                cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccountKey.json")
                if os.path.exists(cred_path):
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred)
                    FCMService._initialized = True
                else:
                    print(f"[Aviso] Arquivo {cred_path} não encontrado. Firebase admin não inicializado.")
            except Exception as e:
                print(f"[Erro] Falha ao inicializar o Firebase: {str(e)}")

    def send_notification(self, token: str, title: str, body: str, data: Optional[Dict[str, str]] = None) -> bool:
        if not FCMService._initialized:
            print("[Aviso] Tentativa de enviar notificação sem FCM inicializado.")
            return False

        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data if data else {},
                token=token,
            )
            
            response = messaging.send(message)
            print(f"Notificação enviada com sucesso: {response}")
            return True
            
        except Exception as e:
            print(f"[Erro] Erro ao enviar notificação pro FCM: {str(e)}")
            return False
