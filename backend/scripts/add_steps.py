import urllib.request
import json
import random

# Datas solicitadas: 01/05 a 08/05 e 10/05
dates = [
    '2026-05-01',
    '2026-05-02',
    '2026-05-03',
    '2026-05-04',
    '2026-05-05',
    '2026-05-06',
    '2026-05-07',
    '2026-05-08',
    '2026-05-10',
]

# 1. Login para pegar o token
login_data = json.dumps({'email': 'bruno.aluno@omniconnect.fit', 'password': 'AlunoForte123!'}).encode('utf-8')
req = urllib.request.Request(
    'http://localhost:8000/api/v1/auth/login', 
    data=login_data,
    headers={'Content-Type': 'application/json'}
)

try:
    with urllib.request.urlopen(req) as response:
        token_data = json.loads(response.read().decode())
        token = token_data['access_token']
        print('Token do Bruno gerado com sucesso!\n')
        
        # 2. Enviar os passos para cada dia
        for date in dates:
            steps = random.randint(1000, 10000)
            distance_meters = int(steps * 0.75) # Média de 0.75m por passo
            
            steps_data = json.dumps({'date': date, 'steps': steps, 'distance_meters': distance_meters}).encode('utf-8')
            steps_req = urllib.request.Request(
                'http://localhost:8000/api/v1/steps/sync',
                data=steps_data,
                headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
            )
            
            try:
                with urllib.request.urlopen(steps_req) as steps_res:
                    print(f'Data: {date} | Passos: {steps} | Status: Sucesso')
            except Exception as e_req:
                print(f'Data: {date} | Erro: {e_req}')

except Exception as e:
    if hasattr(e, 'read'):
        print('Erro no login:', e.read().decode())
    else:
        print('Erro:', e)
