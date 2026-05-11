"""
FAQ Service — respostas determinísticas para perguntas operacionais frequentes.

Quando o aluno faz uma pergunta cuja intenção é claramente operacional
(horário, toalha, mensalidade, Wi-Fi, etc.), respondemos imediatamente
sem invocar o LLM. Isso garante:
  - Latência mínima (sem chamada externa)
  - Resposta consistente (não há variação criativa)
  - Custo zero de tokens

A lógica é simples (match por palavras-chave) e fica isolada do RAGChain
para manter a separação de responsabilidades. Adicionar/editar regras é
trivial: basta atualizar `FAQ_RULES` aqui.

Importante: o matching é conservador por design. Perguntas que envolvem
o contexto pessoal do aluno (ficha ativa, metas, dieta, execução de
exercícios, etc.) DEVEM cair no pipeline RAG real, não no FAQ. Caso
contrário o chatbot perde acesso aos dados reais e devolve respostas
genéricas. O `match()` aplica word boundaries e descarta perguntas com
intenção técnica/pessoal antes de tentar casar com as regras.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


@dataclass(frozen=True)
class FAQRule:
    """Regra única do FAQ: padrões regex que disparam a resposta canônica."""

    patterns: tuple[str, ...]
    response: str


# Conjunto canônico de regras operacionais.
#
# Cada padrão é uma regex com word boundaries (\b) que casa apenas
# perguntas claramente operacionais. Evitamos keywords como "horas",
# "plano" ou "meu treino" porque elas matcham frases pessoais (ex.:
# "quantas horas devo descansar?", "qual meu plano de treino?",
# "explique meu treino A") e bloqueiam o pipeline RAG real.
FAQ_RULES: tuple[FAQRule, ...] = (
    FAQRule(
        patterns=(
            r"\bhor[aá]rio(s)?\b",
            r"\bfuncionamento\b",
            r"\bque\s+horas?\b.*\b(abre|fecha|funciona|abrem|fecham)\b",
            r"\b(abre|fecha|funciona|abrem|fecham)\b.*\bque\s+horas?\b",
            r"\baberto?\s+(at[eé]|das|de)\b",
            r"\bfechado?\s+(at[eé]|aos)\b",
        ),
        response=(
            "A FitLoop funciona de segunda a sexta, das 06:00 às 23:00, "
            "e aos sábados das 08:00 às 18:00. Domingos e feriados não abrimos."
        ),
    ),
    FAQRule(
        patterns=(r"\btoalha(s)?\b",),
        response=(
            "Sim, fornecemos toalhas na recepção. O uso de toalha nos "
            "equipamentos é obrigatório por questões de higiene."
        ),
    ),
    FAQRule(
        patterns=(
            r"\bavalia[cç][aã]o\s+f[ií]sica\b",
            r"\bagendar\s+(uma\s+|minha\s+)?avalia[cç][aã]o\b",
            r"\bcomo\s+agendo\s+(uma\s+|minha\s+)?avalia[cç][aã]o\b",
            r"\bquem\s+[eé]\s+(o\s+)?meu\s+personal\b",
        ),
        response=(
            "Para agendar sua avaliação física, você pode acessar a aba "
            "'Avaliações' aqui mesmo no aplicativo e escolher um horário "
            "disponível com o seu Personal, ou solicitar diretamente na recepção."
        ),
    ),
    FAQRule(
        patterns=(
            r"\bmensalidade(s)?\b",
            r"\b(forma|formas)\s+de\s+pagamento\b",
            r"\bcomo\s+pagar\s+(a\s+)?(mensalidade|matr[ií]cula|assinatura)\b",
            r"\bpagar\s+(o\s+)?plano\s+(da\s+)?academia\b",
            r"\bplano\s+de\s+assinatura\b",
            r"\bvalor\s+(da\s+)?(matr[ií]cula|mensalidade|assinatura)\b",
        ),
        response=(
            "Para detalhes sobre sua assinatura, mensalidade ou planos, "
            "acesse a seção 'Assinatura' no menu do seu perfil ou procure "
            "a recepção."
        ),
    ),
    FAQRule(
        patterns=(
            r"\bwi[\s\-]?fi\b",
            r"\bsenha\s+(do|da)\s+(wi[\s\-]?fi|internet|rede)\b",
            r"\brede\s+(da\s+)?academia\b",
            r"\binternet\s+(da\s+|aqui|na\s+academia)\b",
        ),
        response=(
            "A rede Wi-Fi para alunos é 'OmniConnect_Alunos' e a senha é: "
            "TreinoFocado100"
        ),
    ),
    FAQRule(
        patterns=(
            r"\bcancel(ar|amento|o)\s+(a\s+|minha\s+)?(matr[ií]cula|assinatura|plano)\b",
            r"\btrancar\s+(a\s+|minha\s+)?(matr[ií]cula|assinatura|plano)\b",
            r"\btrancamento\s+(da\s+|de\s+)?(matr[ií]cula|assinatura|plano)\b",
        ),
        response=(
            "Para cancelar sua matrícula, por favor, entre em "
            "contato com a recepção presencialmente. Não é possível fazer "
            "isso pelo app no momento."
        ),
    ),
)


# Palavras que indicam intenção técnica/pessoal — quando aparecem, mesmo
# que algum padrão FAQ case por coincidência, preferimos enviar a pergunta
# ao pipeline RAG real para que dados do aluno sejam considerados.
PERSONAL_CONTEXT_MARKERS: tuple[str, ...] = (
    r"\bminha\s+ficha\b",
    r"\bmeu\s+treino\b",
    r"\bmeus\s+treinos\b",
    r"\bminha\s+meta\b",
    r"\bminhas\s+metas\b",
    r"\bminha\s+dieta\b",
    r"\bmeu\s+(objetivo|peso|hist[oó]rico|progresso)\b",
    r"\bquantas?\s+(s[eé]ries?|repeti[cç][oõ]es?|horas?)\s+(de\s+|para\s+|devo\b)",
    r"\b(execu[cç][aã]o|t[eé]cnica|postura|respira[cç][aã]o|cadencia)\b",
    r"\b(como|qual|quais)\s+(faço|fazer|executar|executo|realizar|realizo)\b",
    r"\b(supino|agachamento|levantamento|leg\s*press|rosca|remada|"
    r"crucifixo|stiff|barra\s+fixa|desenvolvimento)\b",
    r"\b(hipertrofia|emagrecimento|forca|força|resist[eê]ncia|cardio)\b",
    r"\b(macro|prote[ií]na|carbo|caloria|suplemento|whey|creatina)\b",
    r"\bcomo\s+treinar\b",
    r"\btreino\s+(de|para|hoje|amanh[aã]|da\s+semana)\b",
    r"\bficha\s+(ativa|atual|de\s+treino)\b",
    r"\bdieta\s+(ativa|atual)\b",
)

_PERSONAL_REGEX = re.compile(
    "|".join(PERSONAL_CONTEXT_MARKERS), flags=re.IGNORECASE
)


class FAQService:
    """Serviço de FAQ — responde por regex insensível a maiúsculas."""

    def __init__(self, rules: tuple[FAQRule, ...] | None = None) -> None:
        self._rules = rules if rules is not None else FAQ_RULES
        self._compiled: list[tuple[list[re.Pattern[str]], str]] = [
            (
                [re.compile(p, flags=re.IGNORECASE) for p in rule.patterns],
                rule.response,
            )
            for rule in self._rules
        ]

    def match(self, query: str) -> str | None:
        """
        Retorna a resposta canônica se a query bater alguma regra; senão None.

        Args:
            query: Texto bruto enviado pelo aluno.

        Returns:
            Resposta de FAQ ou None (sinal para o RAG seguir adiante).
        """
        if not query or not query.strip():
            return None

        # Se a pergunta tem marcadores de contexto pessoal/técnico, entrega
        # ao RAG real para que dados do aluno sejam usados.
        if _PERSONAL_REGEX.search(query):
            return None

        for patterns, response in self._compiled:
            for pattern in patterns:
                if pattern.search(query):
                    return response
        return None


# Instância singleton importável (consumida pelo RAGChain).
faq_service = FAQService()
