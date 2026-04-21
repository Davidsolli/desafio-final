# PRD: Notificações - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-21  
**Status:** 📋 Em Especificação  
**Responsável:** David Oliveira

---

## 📋 1. Visão Geral

### Objetivo
Criar sistema de notificações multi-canal:
- ✅ Enviar notificação push (FCM) para lembrar treino do dia
- ✅ Enviar lembretes de horários de refeições configurados
- ✅ Aluno configurar horários de notificações individuais
- ✅ Notificar Personal quando aluno não registra treino
- ✅ Notificar Aluno quando nova ficha é atribuída
- ✅ Silenciar categorias de notificação granularmente

### Por Quê?
- Engajamento: Lembrar treino aumenta adesão
- Suporte: Personal fica atento a alunos inativos
- Flexibilidade: Aluno controla quando quer ser notificado

### Escopo
✅ **Incluído:**
- Push via Firebase Cloud Messaging (FCM)
- Agendamento de notificações
- Preferências de notificação
- Histórico de notificações

❌ **NÃO incluído:**
- Integração com SMS/Email
- WhatsApp (será integrado no Cadastro WhatsApp)
- Machine learning para melhor hora

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: NotificationPreference (Preferências)
```python
class NotificationPreference(Base):
    """Preferências de notificação do aluno"""
    
    __tablename__ = "notification_preferences"
    
    id: UUID
    user_id: UUID                 # Aluno (FK Users)
    
    # Configurações gerais
    notifications_enabled: bool   # Master switch
    
    # Tipos de notificação
    workout_reminder_enabled: bool           # Lembrar treino
    workout_reminder_time: time              # Ex: 17:00 (horário local)
    
    meal_reminder_enabled: bool              # Lembrar refeição
    meal_reminder_time: time                 # Ex: 12:00
    
    new_workout_sheet_enabled: bool          # Nova ficha atribuída
    achievement_enabled: bool                # Meta atingida
    performance_report_enabled: bool         # Relatório de performance
    
    # Preferências
    quiet_hours_start: time                  # Ex: 22:00
    quiet_hours_end: time                    # Ex: 07:00
    
    # Silent days (ex: domingo)
    silent_days: JSON                        # [0, 6] = seg, dom
    
    created_at: datetime
    updated_at: datetime
```

#### Tabela: NotificationLog (Histórico)
```python
class NotificationLog(Base):
    """Registro de cada notificação enviada"""
    
    __tablename__ = "notification_logs"
    
    id: UUID
    user_id: UUID
    notification_type: str         # "workout_reminder", "meal_reminder", "achievement"
    title: str
    body: str
    data: JSON                     # Dados adicionais (ex: workout_sheet_id)
    
    sent_at: datetime
    read_at: datetime              # NULL se não leu
    clicked_at: datetime           # NULL se não clicou
    
    status: str                    # "sent", "failed", "delivered"
    error: str                     # Se falhou
    
    created_at: datetime
```

#### Tabela: WorkoutReminderSchedule (Agendamento)
```python
class WorkoutReminderSchedule(Base):
    """Agendamento de lembrete de treino"""
    
    __tablename__ = "workout_reminder_schedules"
    
    id: UUID
    user_id: UUID
    
    # Qual ficha/dia
    workout_sheet_id: UUID        # Ficha que será lembrança (FK WorkoutSheets)
    scheduled_date: date          # 2026-04-21
    scheduled_time: time          # 17:00
    
    # Status
    sent: bool                    # Já foi enviado?
    sent_at: datetime
    delivery_status: str          # "pending", "sent", "failed"
    
    created_at: datetime
```

---

### 2.2 DTOs

#### UpdateNotificationPreferenceDTO
```json
{
  "notifications_enabled": true,
  "workout_reminder_enabled": true,
  "workout_reminder_time": "17:00",
  "meal_reminder_enabled": false,
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "07:00",
  "silent_days": [0, 6]
}
```

#### NotificationPreferenceResponseDTO
```json
{
  "id": "550e8400...",
  "user_id": "550e8400...",
  "notifications_enabled": true,
  "workout_reminder_enabled": true,
  "workout_reminder_time": "17:00",
  "quiet_hours_start": "22:00",
  "quiet_hours_end": "07:00",
  "silent_days": [0, 6]
}
```

---

## 🔌 3. Endpoints HTTP

### 3.1 GET /api/v1/notifications/preferences (Obter Preferências)

**Request:**
```http
GET /api/v1/notifications/preferences HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "notifications_enabled": true,
  "workout_reminder_enabled": true,
  "workout_reminder_time": "17:00",
  "quiet_hours_start": "22:00",
  "silent_days": [0, 6]
}
```

---

### 3.2 PUT /api/v1/notifications/preferences (Atualizar Preferências)

**Request:**
```http
PUT /api/v1/notifications/preferences HTTP/1.1
Authorization: Bearer {token}

{
  "notifications_enabled": true,
  "workout_reminder_time": "18:00",
  "quiet_hours_start": "23:00"
}
```

**Response 200:** Preferências atualizadas

---

### 3.3 GET /api/v1/notifications/history (Histórico)

**Request:**
```http
GET /api/v1/notifications/history?type=workout_reminder&limit=20 HTTP/1.1
Authorization: Bearer {token}
```

**Response 200:**
```json
{
  "total": 45,
  "data": [
    {
      "id": "550e8400...",
      "title": "Hora do treino!",
      "body": "Treino de peito - Supino, Peck Deck, etc",
      "sent_at": "2026-04-21T17:00:00Z",
      "read_at": "2026-04-21T17:05:00Z",
      "clicked_at": "2026-04-21T17:05:30Z",
      "status": "delivered"
    }
  ]
}
```

---

### 3.4 POST /api/v1/notifications/mark-read (Marcar como Lido)

**Request:**
```http
POST /api/v1/notifications/mark-read HTTP/1.1
Authorization: Bearer {token}

{
  "notification_id": "550e8400..."
}
```

**Response 200:** Marcado como lido

---

## 📤 4. Tipos de Notificação

### 4.1 Workout Reminder (Lembrete de Treino)
```
Título: "Hora do treino! 💪"
Corpo: "Treino de Peito - Supino, Peck Deck (45 min)"
Tipo: Agendada diariamente na hora configurada
Trigger: Se tem ficha ativa para esse dia
Data: {"workout_sheet_id": "550e8400...", "day_of_week": 1}
```

### 4.2 New Workout Sheet (Nova Ficha Atribuída)
```
Título: "Nova ficha de treino!"
Corpo: "Personal atribuiu: Treino A - Peito"
Tipo: Imediata (quando personal cria ficha)
```

### 4.3 Achievement (Meta Atingida)
```
Título: "Parabéns! 🎉"
Corpo: "Você atingiu a meta: Supino 90kg"
Tipo: Imediata (quando logbook mostra evolução)
```

### 4.4 Personal Alert (Aluno Não Registrou)
```
Destinatário: Personal
Título: "Aluno não registrou treino"
Corpo: "João Silva não registrou treino de hoje"
Tipo: Agendada 2h após horário planejado
Destinatários: Personal vinculado + Gestor
```

---

## 🔐 5. Segurança

- ✅ FCM tokens armazenados de forma segura
- ✅ Validar que aluno pode ver apenas SUAS notificações
- ✅ Personal vê alertas apenas de alunos vinculados
- ✅ Não enviar notificação sem consentimento
- ✅ Respeitar quiet hours + silent days

---

## 🧪 6. Testes (8+ testes)

**Teste 1:** Criar preferências de notificação  
**Teste 2:** Atualizar preferências  
**Teste 3:** Agendar notificação de treino  
**Teste 4:** Enviar notificação via FCM (mock)  
**Teste 5:** Respeitar quiet hours  
**Teste 6:** Respeitar silent days  
**Teste 7:** Marcar como lido  
**Teste 8:** Histórico ordenado  

---

## 🎯 Definição de Pronto

- ✅ 4 endpoints
- ✅ Preferências personalizáveis
- ✅ Agendamento funcional
- ✅ FCM integration (mock em testes)
- ✅ Quiet hours + silent days
- ✅ 8+ testes
- ✅ Cobertura ≥80%

---

## ⚙️ 7. Integração com Firebase

### Setup
```bash
# Install
pip install firebase-admin

# Configure
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
```

### Send FCM
```python
import firebase_admin
from firebase_admin import messaging

def send_notification(token: str, title: str, body: str):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        token=token,
    )
    response = messaging.send(message)
    return response
```

---

## ⚡ Tempo Estimado: 12 horas

- Models + DTOs: 2h
- Service + Scheduler: 4h
- FCM Integration: 2h
- Endpoints: 2h
- Testes: 2h

---

## 📁 Arquivos a Criar

```
backend/app/
├── models/notification.py
├── dtos/notification_dto.py
├── services/notification_service.py
├── services/fcm_service.py (Firebase)
├── repositories/notification_repository.py
├── controllers/notification_controller.py
├── routes/notification.py
├── tasks/notification_scheduler.py (Celery/APScheduler)
tests/
├── test_notifications.py
└── unit/test_notification_*.py
```

---

*PRD para OmniConnect Fitness - Data: 21 Abril 2026*
