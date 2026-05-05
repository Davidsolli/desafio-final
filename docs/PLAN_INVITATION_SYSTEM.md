# Plano: Sistema de Convite de Acesso (Personal → Aluno)

## Contexto
Hoje qualquer pessoa pode se cadastrar no app livremente. O novo fluxo exige que o personal trainer gere um código de convite pelo app e envie ao aluno via WhatsApp/Email. O aluno só consegue se cadastrar usando esse código. Ao usar o código, o aluno fica automaticamente vinculado ao personal trainer. O código não tem prazo de validade e é de uso único.

---

## Arquivos a modificar

### Backend — Novos arquivos
1. `backend/app/models/invitation.py` ← **NOVO** — model `Invitation`
2. `backend/app/dtos/invitation_dto.py` ← **NOVO** — DTOs de convite
3. `backend/app/repositories/invitation_repository.py` ← **NOVO**
4. `backend/app/services/invitation_service.py` ← **NOVO**
5. `backend/app/routes/invitation.py` ← **NOVO**

### Backend — Arquivos existentes
6. `backend/app/models/user.py` — adicionar campo `trainer_id` (FK opcional para users.id)
7. `backend/app/dtos/user_dto.py` — adicionar `invitation_code` em `CreateUserDTO`
8. `backend/app/services/user_service.py` — validar código ao criar usuário e vincular trainer
9. `backend/app/config/database.py` — importar novo model `Invitation`
10. `backend/main.py` — registrar nova rota de convites

### Frontend — Novos arquivos
11. `frontend/lib/screens/auth/invite_code_screen.dart` ← **NOVO** — tela de inserir código
12. `frontend/lib/screens/trainer/generate_invite_screen.dart` ← **NOVO** — tela do PT gerar código
13. `frontend/lib/services/invitation_service.dart` ← **NOVO**
14. `frontend/lib/providers/invitation_provider.dart` ← **NOVO**

### Frontend — Arquivos existentes
15. `frontend/lib/screens/auth/login_screen.dart` — adicionar botão "Tenho um código de acesso"
16. `frontend/lib/screens/auth/register_screen.dart` — receber e enviar `invitationCode`
17. `frontend/lib/routes/app_routes.dart` — adicionar rota `/invite-code`

---

## Implementação

### 1. Model `Invitation`
```python
class Invitation(Base):
    __tablename__ = "invitations"
    id = Column(PG_UUID, primary_key=True, default=uuid4)
    code = Column(String(20), nullable=False, unique=True, index=True)
    trainer_id = Column(PG_UUID, ForeignKey("users.id"), nullable=False)
    used = Column(Boolean, default=False, nullable=False)
    used_by_id = Column(PG_UUID, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    used_at = Column(DateTime, nullable=True)
```

### 2. User model — adicionar trainer_id
```python
trainer_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
```

### 3. Endpoints de convite
- `POST /api/v1/invitations` — PT gera código (requer auth, role=personal_trainer)
- `POST /api/v1/invitations/validate` — valida código sem autenticação (retorna valid: true/false)
- `GET /api/v1/invitations` — PT lista seus convites (requer auth)

### 4. CreateUserDTO — adicionar campo
```python
invitation_code: str = Field(..., description="Código de convite obrigatório")
```

### 5. UserService.create() — validar convite
```python
# Antes de criar o usuário:
invitation = await invitation_repo.get_by_code(dto.invitation_code)
if not invitation or invitation.used:
    raise InvalidInvitationError("Código inválido ou já utilizado")

# Após criar o usuário:
invitation.used = True
invitation.used_by_id = created_user.id
invitation.used_at = datetime.utcnow()
created_user.trainer_id = invitation.trainer_id
await session.commit()
```

### 6. Novo fluxo Flutter
```
LoginScreen
  ├── Botão "Tenho um código" → InviteCodeScreen
  │     └── Valida código → RegisterScreen (passa invitationCode)
  └── Botão "Já tenho conta" → LoginScreen (campo email/senha)
```

### 7. InviteCodeScreen
- Campo de texto para inserir código
- Botão "Validar" → chama `POST /api/v1/invitations/validate`
- Se válido → navega para RegisterScreen passando o código
- Se inválido → mostra erro

### 8. RegisterScreen — modificar
- Recebe `invitationCode` como parâmetro via rota
- Envia `invitation_code` no body do cadastro
- Remove o botão "Cadastrar" da LoginScreen (cadastro só por convite)

### 9. GenerateInviteScreen (tela do PT)
- Botão "Gerar novo código"
- Exibe o código gerado
- Botão "Copiar" para copiar e enviar via WhatsApp/Email
- Lista de convites gerados (usado/pendente)

---

## Geração do código
```python
import secrets, string
def generate_code() -> str:
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(10))
    # Exemplo: "AB3X7KP2QR"
```

---

## Verificação
1. PT logado → vai em Gerar Convite → gera código `AB3X7KP2QR`
2. PT copia código e envia via WhatsApp pro aluno
3. Aluno abre app → clica "Tenho um código" → insere `AB3X7KP2QR`
4. App valida → código válido → abre tela de cadastro
5. Aluno preenche 3 steps e clica "Criar Conta"
6. Banco: usuário criado com `trainer_id = PT.id`, convite marcado como `used = True`
7. PT acessa lista de alunos → vê o novo aluno vinculado
