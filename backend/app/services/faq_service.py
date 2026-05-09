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
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class FAQRule:
    """Regra única do FAQ: palavras-chave que disparam a resposta canônica."""

    keywords: tuple[str, ...]
    response: str


# Conjunto canônico de regras operacionais.
# Mantido fora da classe para permitir extensão por outros módulos (ex.: testes).
FAQ_RULES: tuple[FAQRule, ...] = (
    FAQRule(
        keywords=(
            "horário",
            "horas",
            "aberta",
            "fecha",
            "funcionamento",
        ),
        response=(
            "A OmniConnect funciona de segunda a sexta, das 06:00 às 23:00, "
            "e aos sábados das 08:00 às 18:00. Domingos e feriados não abrimos."
        ),
    ),
    FAQRule(
        keywords=("toalha",),
        response=(
            "Sim, fornecemos toalhas na recepção. O uso de toalha nos "
            "equipamentos é obrigatório por questões de higiene."
        ),
    ),
    FAQRule(
        keywords=(
            "avaliação física",
            "agendar avaliação",
            "com quem agendo minha avaliação",
            "agendar minha avaliação",
            "quem é meu personal",
            "quem é o personal",
        ),
        response=(
            "Para agendar sua avaliação física, você pode acessar a aba "
            "'Avaliações' aqui mesmo no aplicativo e escolher um horário "
            "disponível com o seu Personal, ou solicitar diretamente na recepção."
        ),
    ),
    FAQRule(
        keywords=(
            "onde verifico",
            "onde vejo",
            "onde encontro",
            "lista de treinos",
            "meu treino",
            "treino de hoje",
            "treinos para hoje",
            "qual meu treino",
        ),
        response=(
            "Você pode verificar a sua lista de treinos de hoje e da semana "
            "acessando a aba 'Meus Treinos' na tela inicial do aplicativo. "
            "Lá seu Personal deixa tudo prescrito!"
        ),
    ),
    FAQRule(
        keywords=("mensalidade", "pagamento", "pagar", "plano"),
        response=(
            "Para detalhes sobre sua assinatura, mensalidade ou planos, "
            "acesse a seção 'Assinatura' no menu do seu perfil ou procure "
            "a recepção."
        ),
    ),
    FAQRule(
        keywords=("wi-fi", "wifi", "internet", "senha da internet"),
        response="A rede Wi-Fi para alunos é 'OmniConnect_Alunos' e a senha é: TreinoFocado100",
    ),
    FAQRule(
        # "cancel" cobre cancelar/cancelo/cancelamento; "trancar" cobre trancamento.
        keywords=("cancel", "trancar"),
        response=(
            "Para cancelar ou trancar sua matrícula, por favor, entre em contato "
            "com a recepção presencialmente. Não é possível fazer isso pelo app no momento."
        ),
    ),
)


class FAQService:
    """Serviço de FAQ — responde por keyword-match insensível a maiúsculas."""

    def __init__(self, rules: tuple[FAQRule, ...] | None = None) -> None:
        self._rules = rules if rules is not None else FAQ_RULES

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

        normalized = query.lower()
        for rule in self._rules:
            for keyword in rule.keywords:
                if keyword.lower() in normalized:
                    return rule.response
        return None


# Instância singleton importável (consumida pelo RAGChain).
faq_service = FAQService()
