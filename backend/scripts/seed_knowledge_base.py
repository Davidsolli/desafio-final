"""Seed da base de conhecimento RAG.

Insere documentos em `knowledge_base` com embeddings 384 dims
gerados pelo HuggingFace `sentence-transformers/all-MiniLM-L6-v2`
(mesmo modelo usado pelo pipeline RAG).

Uso (dentro do container):
    python scripts/seed_knowledge_base.py            # idempotente
    python scripts/seed_knowledge_base.py --force    # substitui base

A função pública `seed(force: bool) -> int` retorna o número de
documentos efetivamente gravados na execução. Idempotente:
    - 1ª execução: insere todos os docs.
    - 2ª execução com `force=False`: retorna 0, sem duplicar.
    - Execução com `force=True`: limpa a tabela e reinsere todos.

Conteúdo humano em `docs/KNOWLEDGE_BASE_CONTENT.md`.
"""

from __future__ import annotations

import asyncio
import logging
import os
import sys
from typing import Any

# Permite rodar como `python scripts/seed_knowledge_base.py`
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

logger = logging.getLogger(__name__)


# ── Conteúdo da base ──────────────────────────────────────────────────────────
# Cada item segue o contrato testado em tests/test_knowledge_base_seed.py:
#   - title começa com o prefixo da categoria
#   - content tem ≥30 caracteres, sem HTML
#   - category ∈ {exercicio, forma, nutricao, periodizacao, sistema}
#   - muscle_group / difficulty_level são opcionais

KNOWLEDGE_DOCUMENTS: list[dict[str, Any]] = [
    # ── exercicio ────────────────────────────────────────────────────────────
    {
        "title": "Exercício: Supino Reto com Barra",
        "content": (
            "O supino reto com barra trabalha principalmente o peitoral maior, "
            "com participação do tríceps e deltóide anterior. Posicione-se no "
            "banco com escápulas retraídas e deprimidas, pés firmes no chão e "
            "pegada um pouco mais larga que a largura dos ombros. Desça a barra "
            "controladamente até tocar a região do peito, mantendo cotovelos a "
            "cerca de 45° em relação ao tronco. Empurre de volta até a extensão "
            "quase completa, sem travar o cotovelo no topo."
        ),
        "category": "exercicio",
        "muscle_group": "peito",
        "difficulty_level": "intermediario",
    },
    {
        "title": "Exercício: Supino Inclinado com Halteres",
        "content": (
            "O supino inclinado com halteres prioriza a porção clavicular do "
            "peitoral. Ajuste o banco entre 30° e 45° — inclinações maiores "
            "transferem carga para o ombro. Comece com os halteres na altura do "
            "peito, palmas voltadas para frente. Empurre verticalmente, sem "
            "estender totalmente o cotovelo no topo. Os halteres permitem "
            "amplitude maior que a barra; não desça além do confortável para o "
            "ombro."
        ),
        "category": "exercicio",
        "muscle_group": "peito",
        "difficulty_level": "intermediario",
    },
    {
        "title": "Exercício: Crucifixo com Halteres",
        "content": (
            "O crucifixo é um exercício de isolamento para o peitoral. Deite no "
            "banco com halteres acima do peito, cotovelos levemente flexionados "
            "(esse ângulo se mantém durante todo o movimento). Abra os braços "
            "em arco até sentir alongamento confortável no peito, sem deixar os "
            "halteres caírem além da linha do tronco. Volte na mesma trajetória, "
            "como se abraçasse uma árvore."
        ),
        "category": "exercicio",
        "muscle_group": "peito",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Agachamento Livre",
        "content": (
            "O agachamento livre com barra é um movimento composto que recruta "
            "quadríceps, glúteos, posteriores de coxa e core. Apoie a barra no "
            "trapézio (high bar) ou na linha dos deltóides posteriores (low bar). "
            "Pés na largura do quadril, pontas levemente abertas. Desça empurrando "
            "o quadril para trás, mantendo joelhos alinhados com os pés. Atinja "
            "no mínimo a paralela da coxa com o solo, sem perder a curvatura "
            "neutra da lombar. Suba com força contínua."
        ),
        "category": "exercicio",
        "muscle_group": "perna_anterior",
        "difficulty_level": "avancado",
    },
    {
        "title": "Exercício: Leg Press 45 Graus",
        "content": (
            "O leg press 45° é uma alternativa segura e eficaz para hipertrofia "
            "de quadríceps e glúteo, especialmente em iniciantes. Posicione os "
            "pés na largura do quadril, no centro da plataforma. Desça o peso "
            "de forma controlada até cerca de 90° de flexão de joelho, sem que "
            "a lombar perca contato com o encosto. Empurre sem travar o joelho "
            "no topo do movimento."
        ),
        "category": "exercicio",
        "muscle_group": "perna_anterior",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Levantamento Terra",
        "content": (
            "O levantamento terra (deadlift) trabalha posterior de coxa, glúteo, "
            "lombar, dorsais e core. Posicione os pés na largura do quadril, "
            "barra próxima à canela. Pegue a barra com pegada pronada (ou mista) "
            "um pouco mais larga que os joelhos. Antes de tirar do chão, infle "
            "o peito, retraia escápulas e fixe a lombar em curvatura neutra. "
            "Empurre o chão com os pés, mantendo a barra colada ao corpo. "
            "Estenda quadril e joelhos juntos."
        ),
        "category": "exercicio",
        "muscle_group": "costa",
        "difficulty_level": "avancado",
    },
    {
        "title": "Exercício: Stiff",
        "content": (
            "O stiff é uma variação do levantamento terra com ênfase em "
            "posteriores de coxa e glúteo. Em pé, segure a barra próxima ao "
            "quadril com pegada pronada. Empurre o quadril para trás (movimento "
            "de quadril, não de coluna) com leve flexão de joelho. Desça a barra "
            "rente ao corpo até sentir alongamento nos isquiotibiais, mantendo a "
            "lombar neutra. Volte estendendo o quadril."
        ),
        "category": "exercicio",
        "muscle_group": "perna_posterior",
        "difficulty_level": "intermediario",
    },
    {
        "title": "Exercício: Cadeira Extensora",
        "content": (
            "A cadeira extensora é um exercício de isolamento para o quadríceps. "
            "Ajuste o encosto e o rolo para que o eixo da máquina alinhe com o "
            "joelho. Empurre o rolo até a extensão completa, segure 1 segundo "
            "no topo e desça controladamente. Evite balanços do tronco — o "
            "quadríceps deve ser o único motor do movimento."
        ),
        "category": "exercicio",
        "muscle_group": "perna_anterior",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Cadeira Flexora",
        "content": (
            "A cadeira flexora isola os posteriores de coxa. Ajuste o rolo para "
            "que ele apoie a parte inferior da panturrilha (não o calcanhar). "
            "Flexione o joelho puxando o rolo até cerca de 90° (ou mais, conforme "
            "a máquina permita), com contração consciente do posterior. Volte de "
            "forma controlada, sem deixar o peso bater na pilha."
        ),
        "category": "exercicio",
        "muscle_group": "perna_posterior",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Puxada Frontal",
        "content": (
            "A puxada frontal recruta principalmente o latíssimo do dorso, com "
            "participação do bíceps e deltóide posterior. Sente-se na máquina "
            "com escápulas retraídas. Pegue a barra com pegada pronada um pouco "
            "mais larga que os ombros. Puxe descendo a barra na linha do peito "
            "(parte alta), levando o cotovelo na linha do tronco. Volte estendendo "
            "os braços sem perder a tensão nas costas."
        ),
        "category": "exercicio",
        "muscle_group": "costa",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Remada Curvada com Barra",
        "content": (
            "A remada curvada é um exercício composto para costas. Em pé, com "
            "tronco inclinado a aproximadamente 45°, segure a barra com pegada "
            "pronada na largura dos ombros. Mantenha lombar neutra e core ativo. "
            "Puxe a barra até o abdômen, levando o cotovelo para trás (não para "
            "cima). Desça controladamente. Evite balançar o tronco para usar "
            "inércia."
        ),
        "category": "exercicio",
        "muscle_group": "costa",
        "difficulty_level": "intermediario",
    },
    {
        "title": "Exercício: Barra Fixa",
        "content": (
            "A barra fixa (pull-up) é uma das melhores expressões de força "
            "relativa para costas e bíceps. Pegue a barra com pegada pronada, "
            "um pouco mais larga que os ombros. Comece em suspensão completa, "
            "ative escápulas e puxe o peito em direção à barra, levando o "
            "cotovelo para baixo. No topo, o queixo deve passar a linha da "
            "barra. Desça controladamente até a extensão completa do braço."
        ),
        "category": "exercicio",
        "muscle_group": "costa",
        "difficulty_level": "avancado",
    },
    {
        "title": "Exercício: Desenvolvimento com Halteres",
        "content": (
            "O desenvolvimento com halteres trabalha o deltóide com "
            "estabilizadores do core. Sente-se em banco com encosto, halteres "
            "na altura do ombro e cotovelos no plano frontal. Empurre os "
            "halteres para cima sem batê-los no topo, mantendo um leve arco. "
            "Desça controlado até a altura do ombro novamente."
        ),
        "category": "exercicio",
        "muscle_group": "ombro",
        "difficulty_level": "intermediario",
    },
    {
        "title": "Exercício: Elevação Lateral",
        "content": (
            "A elevação lateral isola o deltóide medial. Em pé, halteres ao "
            "lado do corpo com leve flexão de cotovelo. Eleve os braços "
            "lateralmente até a altura do ombro, conduzindo o movimento pelo "
            "cotovelo (não pelo punho). Mantenha o tronco fixo, sem balançar. "
            "Desça controlado, sem soltar a tensão."
        ),
        "category": "exercicio",
        "muscle_group": "ombro",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Rosca Direta",
        "content": (
            "A rosca direta com barra é um isolador clássico de bíceps. Em pé, "
            "barra na altura do quadril com pegada supinada na largura dos "
            "ombros. Cotovelos travados próximos ao corpo. Flexione o cotovelo "
            "trazendo a barra até a altura do peito, sem balançar o tronco. "
            "Desça controlado até a extensão quase completa."
        ),
        "category": "exercicio",
        "muscle_group": "bíceps",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Tríceps Pulley com Corda",
        "content": (
            "O tríceps pulley com corda permite separar a corda no final do "
            "movimento, aumentando a contração da cabeça lateral do tríceps. "
            "Em pé de frente para a polia alta, cotovelos travados e colados "
            "ao corpo. Estenda os antebraços para baixo, separando levemente "
            "as pontas da corda no final. Volte controlado até cerca de 90°."
        ),
        "category": "exercicio",
        "muscle_group": "tríceps",
        "difficulty_level": "iniciante",
    },
    {
        "title": "Exercício: Mergulho em Banco",
        "content": (
            "O mergulho em banco é uma alternativa para tríceps em locais sem "
            "máquinas. Sente-se na borda do banco com mãos apoiadas ao lado do "
            "quadril e pés no chão. Avance o quadril para fora do banco e desça "
            "flexionando o cotovelo até cerca de 90°, sem que o ombro avance "
            "demais. Suba estendendo os cotovelos. Para mais carga, apóie os "
            "pés em outro banco."
        ),
        "category": "exercicio",
        "muscle_group": "tríceps",
        "difficulty_level": "iniciante",
    },
    # ── forma ────────────────────────────────────────────────────────────────
    {
        "title": "Forma: Erros comuns no Agachamento",
        "content": (
            "Os três erros mais frequentes no agachamento livre são: joelho "
            "valgo (joelho colapsa para dentro durante a subida), profundidade "
            "incompleta (parar antes da paralela) e perda da curvatura neutra "
            "da lombar (butt wink). Para corrigir o valgo, ative os glúteos "
            "empurrando os joelhos para fora; para profundidade, reduza a carga "
            "e foque no padrão; para o butt wink, trabalhe mobilidade de "
            "tornozelo e quadril."
        ),
        "category": "forma",
    },
    {
        "title": "Forma: Erros comuns no Supino",
        "content": (
            "No supino, os erros típicos são: escápulas soltas (perde "
            "estabilidade e sobrecarrega o ombro), descida sem trajetória "
            "padrão (a barra deve descer próxima da linha mamilar) e cotovelo "
            "totalmente aberto a 90° (estresse excessivo em ombro). A correção "
            "começa retraindo e deprimindo escápulas no banco, mantendo "
            "cotovelos a cerca de 45-60° do tronco e descendo a barra "
            "controladamente até tocar o peito."
        ),
        "category": "forma",
    },
    {
        "title": "Forma: Como respirar nos exercícios compostos",
        "content": (
            "Em exercícios compostos pesados (agachamento, terra, supino), a "
            "respiração coordenada estabiliza o tronco. A Manobra de Valsalva "
            "consiste em inspirar profundamente antes da fase excêntrica, "
            "segurar o ar durante o esforço e expirar parcialmente após o "
            "ponto crítico. Em séries leves, basta expirar na fase concêntrica "
            "e inspirar na excêntrica. Pessoas com hipertensão devem evitar "
            "Valsalva e consultar profissional de saúde."
        ),
        "category": "forma",
    },
    # ── nutricao ─────────────────────────────────────────────────────────────
    {
        "title": "Nutrição: Macronutrientes e papel no treino",
        "content": (
            "Os três macronutrientes principais são: proteína (estrutura e "
            "reparo muscular — 1.6 a 2.2 g/kg/dia para hipertrofia), "
            "carboidrato (energia para treinos de alta intensidade — varia "
            "conforme volume) e gordura (hormônios e absorção de vitaminas "
            "lipossolúveis — pelo menos 0.8 g/kg/dia). A distribuição ideal "
            "depende de objetivo individual; um nutricionista pode prescrever "
            "valores específicos."
        ),
        "category": "nutricao",
    },
    {
        "title": "Nutrição: Hidratação durante o treino",
        "content": (
            "A hidratação afeta diretamente desempenho e recuperação. Como "
            "referência geral, beba 500 ml de água nas 2 horas antes do treino "
            "e 200-300 ml a cada 15-20 minutos durante. Sinais de desidratação "
            "incluem urina escura, boca seca, tontura e queda de performance. "
            "Em treinos longos (>1h) ou em calor, considere bebida com "
            "eletrólitos."
        ),
        "category": "nutricao",
    },
    {
        "title": "Nutrição: Janela anabólica e refeição pós-treino",
        "content": (
            "A 'janela anabólica' clássica (consumir proteína em até 30 minutos "
            "pós-treino) tem evidências modernas mais flexíveis. O que importa "
            "é o consumo total diário de proteína distribuído ao longo do dia "
            "(20-40 g por refeição, 4-5 vezes). Ainda assim, uma refeição com "
            "proteína e carboidrato em até 1-2 horas pós-treino é prática e "
            "favorece a recuperação."
        ),
        "category": "nutricao",
    },
    {
        "title": "Nutrição: Pré-treino básico",
        "content": (
            "Uma refeição pré-treino prática combina carboidrato de digestão "
            "moderada e proteína magra, 1-2 horas antes da atividade. "
            "Exemplos: tapioca com ovo, banana com pasta de amendoim, iogurte "
            "com aveia, ou pão integral com peito de frango. Evite gorduras "
            "muito altas e fibras em excesso muito perto do treino — podem "
            "causar desconforto gástrico."
        ),
        "category": "nutricao",
    },
    {
        "title": "Nutrição: Suplementos populares",
        "content": (
            "Suplementos com mais evidência são whey protein (praticidade para "
            "atingir meta de proteína), creatina monohidratada (3-5 g/dia, "
            "ganhos de força e hipertrofia) e cafeína (3-6 mg/kg pré-treino, "
            "efeito ergogênico). BCAA, glutamina e queimadores têm evidência "
            "fraca. A FitLoop não prescreve suplementos com dosagem "
            "individualizada — consulte um nutricionista esportivo."
        ),
        "category": "nutricao",
    },
    # ── periodizacao ─────────────────────────────────────────────────────────
    {
        "title": "Periodização: Divisões ABC, ABCDE e Full-Body",
        "content": (
            "A divisão Full-Body treina o corpo todo na mesma sessão (2-3x "
            "por semana, ideal para iniciantes ou tempo limitado). O ABC "
            "divide grupos musculares em 3 dias (clássico: peito/tríceps, "
            "costas/bíceps, perna/ombro) e cabe em 3-6 dias por semana. O "
            "ABCDE distribui em 5 dias (mais volume por grupo, frequência "
            "menor). Não existe divisão 'melhor' — depende de tempo, "
            "experiência e recuperação."
        ),
        "category": "periodizacao",
    },
    {
        "title": "Periodização: Frequência por grupo muscular",
        "content": (
            "Para hipertrofia, a referência atual é 10 a 20 séries semanais "
            "por grupo muscular, distribuídas em pelo menos 2 sessões por "
            "semana (frequência 2x). Iniciantes respondem bem a 8-10 séries; "
            "intermediários a 12-16; avançados podem precisar de 18-20. "
            "Volume excessivo sem recuperação adequada gera platô ou queda "
            "de performance."
        ),
        "category": "periodizacao",
    },
    # ── sistema ──────────────────────────────────────────────────────────────
    {
        "title": "Sistema: Horário de funcionamento",
        "content": (
            "A academia FitLoop funciona de segunda a sexta-feira das "
            "06:00 às 23:00 e aos sábados das 08:00 às 18:00. Aos domingos "
            "e feriados o atendimento é fechado. Reservas de aulas coletivas "
            "e avaliações podem ser feitas pelo aplicativo até 24 horas antes."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Como agendar avaliação física",
        "content": (
            "Para agendar uma avaliação física, abra o aplicativo Fitloop, "
            "vá na aba 'Avaliações' e escolha um horário disponível com seu "
            "Personal Trainer. Alternativamente, fale com a recepção. A "
            "avaliação é recomendada a cada 8 a 12 semanas para acompanhar "
            "evolução."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Toalhas e higiene",
        "content": (
            "As toalhas são fornecidas gratuitamente na recepção e seu uso é "
            "obrigatório para higiene e conservação dos equipamentos. Limpe "
            "máquinas e bancos após o uso com os panos disponíveis na sala. "
            "É proibido treinar sem camiseta na musculação."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: O que é falha concêntrica",
        "content": (
            "Falha concêntrica ocorre quando, mesmo com técnica correta, "
            "você não consegue completar a fase de subida (concêntrica) do "
            "peso. É um marcador útil de esforço, mas treinar sempre até a "
            "falha não é necessário e pode atrapalhar a recuperação. Para "
            "hipertrofia, encerrar 1-3 reps antes da falha (RIR 1-3) gera "
            "resultados similares com menos desgaste."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Cardio antes ou depois da musculação",
        "content": (
            "Se o objetivo é ganho de força ou hipertrofia, faça cardio "
            "DEPOIS da musculação ou em horários separados — cardio prévio "
            "intenso reduz performance no peso. Se o objetivo é resistência "
            "cardiovascular, priorize cardio antes. Sessões de cardio leve "
            "(esteira em ritmo conversacional) como aquecimento são "
            "aceitáveis em qualquer caso."
        ),
        "category": "sistema",
    },
    # ── métricas ─────────────────────────────────────────────────────────────
    {
        "title": "Sistema: IMC — Tabela OMS e Interpretação",
        "content": (
            "O Índice de Massa Corporal (IMC) é calculado dividindo o peso (kg) "
            "pela altura ao quadrado (m²). Classificação segundo a OMS: "
            "abaixo de 18,5 = Abaixo do peso; 18,5–24,9 = Peso normal; "
            "25,0–29,9 = Sobrepeso; 30,0–34,9 = Obesidade grau I; "
            "35,0–39,9 = Obesidade grau II; 40,0 ou mais = Obesidade grau III. "
            "Para praticantes de musculação com massa muscular elevada, o IMC pode "
            "superestimar a gordura corporal — nesses casos, percentual de gordura "
            "e circunferências são indicadores mais precisos. "
            "Exemplo: 70 kg / (1,80)² = 70 / 3,24 ≈ 21,6 (Peso normal)."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Frequência Cardíaca Máxima e Zonas de Treino",
        "content": (
            "A FC máxima estimada é calculada pela fórmula: FCmáx = 220 − idade. "
            "As 5 zonas de treino são definidas como percentuais da FCmáx: "
            "Zona 1 (50–60%): aquecimento e recuperação ativa; "
            "Zona 2 (60–70%): queima de gordura e resistência aeróbica de base; "
            "Zona 3 (70–80%): melhora cardiovascular e limiar aeróbico; "
            "Zona 4 (80–90%): limiar anaeróbico, melhora de performance; "
            "Zona 5 (90–100%): esforço máximo, sprints curtos. "
            "Exemplo para 22 anos: FCmáx = 198 bpm. Zona 2 = 119–139 bpm. "
            "Para treino de hipertrofia, o objetivo não é atingir zonas altas; "
            "o cardio complementar costuma ficar nas zonas 2–3."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Gasto Calórico Estimado por Tipo de Exercício",
        "content": (
            "O gasto calórico depende do peso corporal, intensidade e duração. "
            "Estimativas aproximadas para 70 kg em 30 minutos de atividade: "
            "Musculação moderada: 130–180 kcal; "
            "Musculação intensa (alta carga): 180–250 kcal; "
            "Corrida em esteira a 10 km/h: 280–340 kcal; "
            "Bicicleta ergométrica moderada: 200–260 kcal; "
            "HIIT (intervalado de alta intensidade): 300–400 kcal; "
            "Caminhada em esteira 5 km/h: 130–160 kcal. "
            "Para estimar com mais precisão, utilize a fórmula MET × peso (kg) × horas. "
            "Musculação tem MET entre 3 e 6; corrida entre 8 e 12."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Tempo de Descanso Entre Séries por Objetivo",
        "content": (
            "O tempo de descanso entre séries impacta diretamente a qualidade do treino. "
            "Recomendações por objetivo: "
            "Força máxima (1–5 repetições, cargas altas): 3–5 minutos — necessário "
            "para restaurar ATP e fosfocreatina. "
            "Hipertrofia (6–12 repetições, carga moderada-alta): 60–120 segundos — "
            "equilibra estímulo metabólico e recuperação neuromuscular. "
            "Resistência muscular (13+ repetições, carga baixa-moderada): 30–60 segundos — "
            "mantém estresse metabólico e densidade do treino. "
            "Circuitos e HIIT: 15–45 segundos entre exercícios, 1–2 minutos entre rodadas. "
            "Descansar menos não é necessariamente melhor — comprometer a carga prejudica o estímulo."
        ),
        "category": "sistema",
    },
    {
        "title": "Nutrição: Ingestão de Proteína Diária por Objetivo",
        "content": (
            "A proteína é o macronutriente central para preservação e ganho de massa muscular. "
            "Recomendações gerais por objetivo (em gramas por kg de peso corporal/dia): "
            "Sedentário (saúde geral): 0,8 g/kg — referência mínima da OMS. "
            "Perda de peso com preservação muscular: 1,6–2,2 g/kg. "
            "Hipertrofia (ganho de massa): 1,6–2,2 g/kg; evidências indicam pouco benefício "
            "adicional acima de 2,2 g/kg para a maioria das pessoas. "
            "Atletas de força avançados: até 2,5 g/kg em fases de ganho intensivo. "
            "Exemplo: aluno de 70 kg visando hipertrofia → meta de 112–154 g de proteína/dia. "
            "Fontes: frango, ovos, atum, whey protein, iogurte grego, leguminosas. "
            "Distribua a ingestão em 4–5 refeições de 25–40 g para maximizar a síntese proteica."
        ),
        "category": "nutricao",
    },
    {
        "title": "Sistema: Hidratação Durante o Treino",
        "content": (
            "A hidratação adequada mantém a performance e previne cãibras e fadiga precoce. "
            "Recomendações gerais: "
            "Pré-treino: beber 400–600 ml de água nas 2 horas anteriores ao exercício. "
            "Durante o treino: 150–250 ml a cada 15–20 minutos de atividade. "
            "Pós-treino: repor 150% do peso perdido em suor (pesar antes e depois ajuda). "
            "Para treinos de até 60 minutos em temperatura moderada, água é suficiente. "
            "Para treinos acima de 60–90 minutos ou em calor intenso, considerar bebidas "
            "com eletrólitos (sódio, potássio) para repor o que é perdido no suor. "
            "Sinal de hidratação adequada: urina clara a amarelo-pálida."
        ),
        "category": "sistema",
    },
    {
        "title": "Sistema: Aquecimento e Alongamento — Protocolo Básico",
        "content": (
            "O aquecimento prepara o sistema cardiovascular, musculatura e articulações "
            "para o esforço e reduz risco de lesões. "
            "Aquecimento geral (5–10 min): caminhada ou corrida leve na esteira, bicicleta "
            "ergométrica em ritmo suave ou polichinelos. Eleva FC gradualmente. "
            "Aquecimento específico: 1–2 séries do exercício principal com carga reduzida "
            "(30–50% da carga de trabalho) antes das séries efetivas. "
            "Alongamento dinâmico pré-treino: rotações de quadril, leg swing, mobilidade "
            "de tornozelo e ombro — mantém amplitude sem inibir força. "
            "Alongamento estático pós-treino: mantenha cada posição por 20–30 segundos. "
            "Foque nos grupos trabalhados: peitoral, dorsais, posteriores de coxa, quadríceps. "
            "Não é necessário alongar até sentir dor — sensação de 'tensão confortável' é o alvo."
        ),
        "category": "sistema",
    },
    {
        "title": "Periodização: Semana de Deload — Quando e Por Que",
        "content": (
            "O deload é uma semana de treino com volume e/ou intensidade reduzidos, "
            "programado para permitir recuperação sem perda de adaptação. "
            "Quando fazer: a cada 4–8 semanas de treino intenso, ou sempre que houver "
            "sinais de overreaching: queda de força, sono ruim, irritabilidade, fadiga "
            "persistente mesmo após descanso. "
            "Como fazer: reduzir o volume total em 40–60% (menos séries por exercício) "
            "mantendo a intensidade (mesma carga), OU reduzir a carga em 20–30% "
            "mantendo o volume. Ambas as abordagens funcionam. "
            "O que NÃO fazer: eliminar completamente o treino — o deload não é férias, "
            "é treino estrategicamente reduzido. "
            "Resultado: retorno com performance superior na semana seguinte (supercompensação)."
        ),
        "category": "periodizacao",
    },
]


# ── Helpers de infraestrutura ─────────────────────────────────────────────────

def _get_session_factory():
    """Factory de sessão. Substituível por testes via patch."""
    from app.config.settings import settings

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    return async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


def _get_embeddings_model():
    """Embeddings do mesmo modelo do RAG. Lazy import para acelerar testes."""
    from langchain_huggingface import HuggingFaceEmbeddings

    return HuggingFaceEmbeddings(
        model_name="sentence-transformers/all-MiniLM-L6-v2",
    )


# ── Função pública: seed ──────────────────────────────────────────────────────

async def seed(force: bool = False) -> int:
    """Insere documentos da KB com embeddings.

    Args:
        force: Se True, limpa a tabela antes de inserir.

    Returns:
        Número de documentos efetivamente gravados nesta execução.
        Retorna 0 se ``force=False`` e a base já estava povoada.
    """
    from app.models.chatbot import KnowledgeBase

    factory = _get_session_factory()
    embeddings = _get_embeddings_model()

    async with factory() as session:
        # Verificar estado atual
        existing_count = (
            await session.execute(select(KnowledgeBase).limit(1))
        ).scalars().first()

        if existing_count and not force:
            logger.info(
                "[seed_kb] Base já contém dados. Use force=True para reindexar."
            )
            return 0

        if force and existing_count:
            logger.info("[seed_kb] Limpando knowledge_base existente (force=True)...")
            await session.execute(text("DELETE FROM knowledge_base"))
            await session.commit()

        inserted = 0
        for doc in KNOWLEDGE_DOCUMENTS:
            embedding_text = f"{doc['title']}\n\n{doc['content']}"
            try:
                vector = await embeddings.aembed_query(embedding_text)
            except Exception as exc:
                logger.error(
                    "[seed_kb] Falha ao gerar embedding para %r: %s",
                    doc["title"], exc,
                )
                vector = None

            kb_doc = KnowledgeBase(
                title=doc["title"],
                content=doc["content"],
                category=doc["category"],
                muscle_group=doc.get("muscle_group"),
                difficulty_level=doc.get("difficulty_level"),
                embedding=vector,
                embedding_model="huggingface:all-MiniLM-L6-v2",
                is_active=True,
            )
            session.add(kb_doc)
            inserted += 1

        await session.commit()
        logger.info("[seed_kb] %d documentos gravados.", inserted)
        return inserted


if __name__ == "__main__":
    force_flag = "--force" in sys.argv
    print(f"[seed_kb] Iniciando seed{' (force)' if force_flag else ''}...")
    result = asyncio.run(seed(force=force_flag))
    print(f"[seed_kb] Concluido. Documentos gravados: {result}")
