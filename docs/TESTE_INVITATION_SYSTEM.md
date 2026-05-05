# 🧪 Guia de Teste - Sistema de Convites

## Pré-requisitos
- Backend rodando em `http://localhost:8000`
- Frontend rodando (Flutter web ou emulador)
- Docker com PostgreSQL ativo

---

## 📱 Teste Completo do Fluxo

### **1️⃣ Criar um Personal Trainer (PT)**

**Via API (curl):**
```bash
curl -X POST http://localhost:8000/api/v1/users \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "name": "Maria Treinadora",
    "email": "maria@example.com",
    "password": "SenhaForte123!",
    "role": "personal_trainer"
  }'
```

**Resposta esperada:**
```json
{
  "id": "8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea",
  "name": "Maria Treinadora",
  "email": "maria@example.com",
  "role": "personal_trainer",
  "is_active": true,
  "created_at": "2026-05-05T13:00:24.213458",
  "updated_at": "2026-05-05T13:00:24.213461"
}
```

**Guarde o `id` para depois!** (exemplo: `8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea`)

---

### **2️⃣ Fazer Login do PT**

**Via API (curl):**
```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{
    "email": "maria@example.com",
    "password": "SenhaForte123!"
  }'
```

**Resposta esperada:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 86400
}
```

**Guarde o `access_token` para depois!**

---

### **3️⃣ Gerar um Código de Convite**

**Via API (curl) - substitua TOKEN pelo access_token acima:**
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X POST http://localhost:8000/api/v1/invitations \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}'
```

**Resposta esperada:**
```json
{
  "id": "fd24370e-4194-4c34-96d6-469dba1658e3",
  "code": "I806YC6MYS",
  "trainer_id": "8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea",
  "used": false,
  "used_by_id": null,
  "created_at": "2026-05-05T13:01:09.893741",
  "used_at": null
}
```

**Guarde o `code`!** (exemplo: `I806YC6MYS`)

---

### **4️⃣ Testar na Tela do Frontend - InviteCodeScreen**

**No LoginScreen da app:**
1. Clique no botão **"Tenho um Código de Acesso"**
2. Você vai ser levado para a tela **InviteCodeScreen**
3. Digite o código gerado acima (ex: `I806YC6MYS`)
4. Clique em **"Validar Código"**

**Resultado esperado:**
- ✅ Mensagem "Código válido e pronto para usar"
- ✅ Você é levado para a tela de **RegisterScreen** com o código pré-carregado

**Se digitar um código inválido:**
- ❌ Mensagem "Código inválido, expirado ou já utilizado"

---

### **5️⃣ Registrar um Aluno (Client) com o Código**

**Na tela RegisterScreen (após validar código):**
1. Preencha os dados pessoais (nome, email, senha)
2. Clique **"Próximo"**
3. Preencha dados de físicos (peso, altura, idade) - opcional
4. Clique **"Próximo"**
5. Selecione um objetivo (Ganhar Massa, Emagrecer, etc)
6. Clique **"Criar Conta"**

**Resultado esperado:**
- ✅ Usuário criado com sucesso
- ✅ Login automático realizado
- ✅ Você é levado para a **HomeScreen**

---

### **6️⃣ Verificar no Banco se Ficou Vinculado**

**Via PostgreSQL:**
```sql
-- Conecte no banco
docker exec -i omniconnect-db psql -U omni_user -d omniconnect_db

-- Verifique se o aluno está vinculado ao PT
SELECT id, name, email, role, trainer_id 
FROM users 
WHERE email IN ('joao@example.com', 'maria@example.com');
```

**Resultado esperado:**
```
id                  |       name       |       email       |       role       |              trainer_id              
--------------------------------------+------------------+-------------------+------------------+--------------------------------------
 8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea | Maria Treinadora | maria@example.com | personal_trainer | 
 46b1541f-d636-42ce-b5df-66f7e529260d | João Aluno       | joao@example.com  | client           | 8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea
```

✅ O `trainer_id` de João aponta para Maria!

---

### **7️⃣ Verificar se o Código Foi Marcado como Usado**

**Via PostgreSQL:**
```sql
SELECT id, code, trainer_id, used, used_by_id, created_at, used_at 
FROM invitations 
WHERE code = 'I806YC6MYS';
```

**Resultado esperado:**
```
id                  |    code    |              trainer_id              | used |              used_by_id              |         created_at         |          used_at           
--------------------------------------+------------+--------------------------------------+------+--------------------------------------+----------------------------+----------------------------
 fd24370e-4194-4c34-96d6-469dba1658e3 | I806YC6MYS | 8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea | t    | 46b1541f-d636-42ce-b5df-66f7e529260d | 2026-05-05 13:01:09.893741 | 2026-05-05 13:02:23.273146
```

✅ Código marcado como `used = true` e `used_by_id` preenchido!

---

### **8️⃣ Listar Códigos do PT (Tela GenerateInviteScreen)**

**Via API:**
```bash
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X GET http://localhost:8000/api/v1/invitations \
  -H "Authorization: Bearer $TOKEN"
```

**Resposta esperada:**
```json
{
  "total": 1,
  "pending": 0,
  "used": 1,
  "invitations": [
    {
      "id": "fd24370e-4194-4c34-96d6-469dba1658e3",
      "code": "I806YC6MYS",
      "trainer_id": "8781b5da-8ccc-4f77-9cdb-7ad87cb8c6ea",
      "used": true,
      "used_by_id": "46b1541f-d636-42ce-b5df-66f7e529260d",
      "created_at": "2026-05-05T13:01:09.893741",
      "used_at": "2026-05-05T13:02:23.273146"
    }
  ]
}
```

**No Frontend (GenerateInviteScreen):**
1. Logue como PT (Maria)
2. Vá para **TrainerDashboard**
3. Clique no ícone **🎁** (canto superior direito)
4. Você será levado para **GenerateInviteScreen**
5. Veja as estatísticas: Total 1, Usado 1, Pendente 0
6. Veja o histórico com o código usado

---

## 🐛 Casos de Teste - Erros

### **Teste 1: Código Inválido**
```bash
curl -X POST http://localhost:8000/api/v1/invitations/validate \
  -H "Content-Type: application/json" \
  -d '{"code": "INVALIDO"}'
```
**Esperado:** `{"valid": false, "code": null, "message": "Código inválido..."}`

### **Teste 2: Código Já Usado**
Digite o mesmo código de antes (I806YC6MYS) novamente
**Esperado:** `{"valid": false, "code": null, "message": "Código inválido..."}`

### **Teste 3: Cadastrar Sem Código (cliente)**
Na tela RegisterScreen, não preencha invitation_code
**Esperado:** Erro 400 "Código de convite obrigatório para clientes"

### **Teste 4: Criar Código Sem Ser PT**
```bash
TOKEN="usuario_comum_token"

curl -X POST http://localhost:8000/api/v1/invitations \
  -H "Authorization: Bearer $TOKEN" \
  -d '{}'
```
**Esperado:** Erro 403 "Apenas personal trainers podem gerar convites"

---

## 📊 Fluxo Resumido

```
┌─────────────────────┐
│   LoginScreen       │
└──────────┬──────────┘
           │
           ├─→ "Tenho um Código" ──→ InviteCodeScreen
           │                             │
           │                             ├─ Digite código
           │                             └─ Valida (API)
           │                                  │
           │                                  ↓
           │                         RegisterScreen
           │                              │
           │                              ├─ Preenche dados
           │                              └─ Cadastra com código
           │                                  │
           │                                  ↓
           │                    ✅ Aluno vinculado ao PT!
           │
           └─→ "Entrar" ──→ Login
                              │
                              ↓
                         HomeScreen
```

---

## ✅ Checklist de Validação

- [ ] Código gerado com 10 caracteres aleatórios
- [ ] Código validado corretamente (válido/inválido)
- [ ] Aluno criado com código é vinculado ao PT
- [ ] Código marcado como `used = true` após uso
- [ ] PT consegue listar seus códigos
- [ ] Estatísticas (total, usado, pendente) corretas
- [ ] Código não pode ser reutilizado
- [ ] Erro ao tentar gerar código sem ser PT
- [ ] Erro ao tentar cadastrar sem código (cliente)
- [ ] Botão voltar funciona em InviteCodeScreen
- [ ] Botão "Tenho um código" aparece em LoginScreen

---

## 🚀 Pronto para Produção?

Se todos os testes passarem, o sistema está 100% funcional! 🎉

