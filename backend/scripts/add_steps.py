import urllib.request
import json
import random
from datetime import date, timedelta

# Gera as datas dos últimos 14 dias até hoje
today = date.today()
dates = [(today - timedelta(days=i)).strftime('%Y-%m-%d') for i in range(14)]
dates.reverse()

students = [
    'bruno.aluno@omniconnect.fit',
    'juliana.aluna@omniconnect.fit',
    'leonardo.aluno@omniconnect.fit',
    'patricia.aluna@omniconnect.fit',
]

for email in students:
    print(f"=== Sincronizando passos para {email} ===")
    login_data = json.dumps({'email': email, 'password': 'AlunoForte123!'}).encode('utf-8')
    req = urllib.request.Request(
        'http://localhost:8000/api/v1/auth/login', 
        data=login_data,
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req) as response:
            token_data = json.loads(response.read().decode())
            token = token_data['access_token']
            print('Token gerado com sucesso!\n')
            
            # Enviar os passos para cada dia
            for d in dates:
                steps = random.randint(3000, 12000)
                distance_meters = int(steps * 0.75) # Média de 0.75m por passo
                
                steps_data = json.dumps({'date': d, 'steps': steps, 'distance_meters': distance_meters}).encode('utf-8')
                steps_req = urllib.request.Request(
                    'http://localhost:8000/api/v1/steps/sync',
                    data=steps_data,
                    headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
                )
                
                try:
                    with urllib.request.urlopen(steps_req) as steps_res:
                        print(f'Data: {d} | Passos: {steps} | Status: Sucesso')
                except Exception as e_req:
                    print(f'Data: {d} | Erro: {e_req}')
            print("\n")

    except Exception as e:
        if hasattr(e, 'read'):
            print(f'Erro no login de {email}:', e.read().decode())
        else:
            print(f'Erro em {email}:', e)
