"""Contratos das respostas estruturadas do modelo de linguagem.

Tudo o que o modelo devolve é tratado como **dado não confiável**: o JSON é
validado por Pydantic, enums são conferidos, referências de memória precisam
existir no contexto enviado e as ações sugeridas só passam se forem permitidas
naquele momento. Partes inválidas são descartadas; a fala só é aproveitada se
for segura. Quem executa (ou não) qualquer ação é o simulador do jogo.
"""

from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass, field
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, ValidationError

EMOCOES = ["neutra", "alegre", "animada", "triste", "surpresa", "pensativa", "envergonhada", "irritada"]
INTENCOES = [
    "cumprimentar",
    "conversar",
    "responder_pergunta",
    "contar_novidade",
    "agradecer",
    "pedir_ajuda",
    "convidar",
    "desabafar",
    "recusar",
    "nao_sei",
    "despedir",
]
# Conjunto pequeno e fechado de ações que o jogo sabe executar ou registrar.
ACOES = ["pedir_item", "convidar_atividade", "registrar_promessa", "compartilhar_lembranca"]

MAX_FALA = 320
MIN_FALA = 2

# Frases que quebram o personagem (o morador nunca se apresenta como IA).
_QUEBRA_PERSONAGEM = [
    "modelo de linguagem",
    "inteligencia artificial",
    "sou uma ia",
    "sou um ia",
    "como ia",
    "assistente virtual",
    "assistente de ia",
    "language model",
    "as an ai",
    "openai",
    "qwen",
    "alibaba",
    "prompt",
    "system:",
]
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL | re.IGNORECASE)
# Emojis e pictogramas (a fonte do jogo não os desenha e destoam do texto).
_EMOJI_RE = re.compile(
    "[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U0001F900-\U0001F9FF\U00002B00-\U00002BFF\uFE0F\u200D]+"
)
# Ações de roleplay entre asteriscos (*sorri*) e comentários meta entre parênteses.
_ASTERISCOS_RE = re.compile(r"\*[^*]{1,80}\*")
_REFS_RE = re.compile(r"\s*[\(\[]\s*m\d{1,2}\s*[\)\]]", re.IGNORECASE)
_FALA_TRUNCADA_RE = re.compile(r'"fala"\s*:\s*"((?:[^"\\]|\\.)*)', re.DOTALL)
_META_PAREN_RE = re.compile(
    r"\((?:[^()]*\b(?:pontua|confian|sussurr|risos?|sorri|pensando|nota|obs|n[aã]o sei o que)[^()]*)\)",
    re.IGNORECASE,
)
# Marcas de "ouvi dizer": só valem se o morador conhecer algum rumor.
# Marcas de quem admite não saber (frases assim podem citar qualquer morador).
_NAO_SEI_RE = re.compile(
    r"\b(n[aã]o sei|n[aã]o vi|n[aã]o ouvi|n[aã]o fiquei sabendo|n[aã]o fa[cç]o ideia|n[aã]o tenho certeza|"
    r"nada sobre|n[aã]o sabia|n[aã]o estava l[aá]|n[aã]o me contaram|sei l[aá])\b",
    re.IGNORECASE,
)
_BOATO_RE = re.compile(
    r"\b(ouvi dizer|ouvi falar|me contaram|me disseram|disseram que|dizem que|fiquei sabendo|andam dizendo|soube que)\b",
    re.IGNORECASE,
)


def _norm(text: str) -> str:
    text = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in text if not unicodedata.combining(c))


class ParametrosAcao(BaseModel):
    model_config = ConfigDict(extra="ignore")

    item_id: Optional[str] = Field(default=None, max_length=40)
    lugar: Optional[str] = Field(default=None, max_length=40)
    descricao: Optional[str] = Field(default=None, max_length=160)
    memoria_ref: Optional[str] = Field(default=None, max_length=12)


class RespostaMorador(BaseModel):
    """Formato pedido ao modelo (o JSON Schema abaixo é derivado dele)."""

    model_config = ConfigDict(extra="ignore")

    fala: str = Field(min_length=1, max_length=900)
    emocao: str = "neutra"
    intencao: str = "conversar"
    memoria_referenciada_ids: list[str] = Field(default_factory=list, max_length=8)
    acao_sugerida: Optional[str] = None
    parametros_acao: Optional[ParametrosAcao] = None


def json_schema_resposta() -> dict[str, Any]:
    """JSON Schema enviado ao Ollama em ``format`` (saída estruturada)."""
    return {
        "type": "object",
        "properties": {
            "fala": {"type": "string", "maxLength": MAX_FALA},
            "emocao": {"type": "string", "enum": EMOCOES},
            "intencao": {"type": "string", "enum": INTENCOES},
            "memoria_referenciada_ids": {"type": "array", "items": {"type": "string"}, "maxItems": 4},
            "acao_sugerida": {"type": ["string", "null"], "enum": ACOES + [None]},
            "parametros_acao": {
                "type": ["object", "null"],
                "properties": {
                    "item_id": {"type": "string"},
                    "lugar": {"type": "string"},
                    "descricao": {"type": "string"},
                    "memoria_ref": {"type": "string"},
                },
            },
        },
        "required": ["fala", "emocao", "intencao", "memoria_referenciada_ids", "acao_sugerida"],
    }


def chaves_falas(a_id: str, b_id: str) -> tuple[str, str]:
    a = re.sub(r"[^a-z0-9_]", "", _norm(a_id)) or "a"
    b = re.sub(r"[^a-z0-9_]", "", _norm(b_id)) or "b"
    return f"fala_de_{a}", (f"fala_de_{b}" if b != a else f"fala_de_{b}_2")


def json_schema_falas_entre_moradores(a_id: str = "a", b_id: str = "b") -> dict[str, Any]:
    ka, kb = chaves_falas(a_id, b_id)
    return {
        "type": "object",
        "properties": {ka: {"type": "string", "maxLength": 140}, kb: {"type": "string", "maxLength": 140}},
        "required": [ka, kb],
    }


def json_schema_plano() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "opcao": {"type": "string"},
            "motivo": {"type": "string", "maxLength": 160},
        },
        "required": ["opcao", "motivo"],
    }


@dataclass
class Permissoes:
    """O que o modelo pode sugerir nesta troca (calculado pelo jogo)."""

    acoes: list[str] = field(default_factory=list)
    itens: list[str] = field(default_factory=list)
    lugares: list[str] = field(default_factory=list)
    memorias: dict[str, str] = field(default_factory=dict)  # ref curta -> id real
    conhece_rumores: bool = False
    # Moradores citados na conversa sobre os quais este morador não sabe nada.
    desconhecidos: list[str] = field(default_factory=list)
    # Moradores citados que este morador viu ou com quem esteve há pouco.
    testemunhados: list[str] = field(default_factory=list)

    @classmethod
    def from_context(cls, ctx: dict[str, Any]) -> "Permissoes":
        allowed = ctx.get("allowed") or {}
        refs: dict[str, str] = {}
        for mem in ctx.get("memories") or []:
            if isinstance(mem, dict) and mem.get("ref") and mem.get("id"):
                refs[str(mem["ref"])] = str(mem["id"])
        rumores = any(
            isinstance(e, dict) and e.get("is_rumor")
            for e in list(ctx.get("known_events") or []) + list(ctx.get("memories") or [])
        )
        desconhecidos = [
            _norm(str(r.get("name", ""))).split(" ")[-1]
            for r in (ctx.get("related_npcs") or [])
            if isinstance(r, dict) and r.get("name") and not r.get("known_facts")
        ]
        testemunhados = [
            _norm(str(r.get("name", ""))).split(" ")[-1]
            for r in (ctx.get("related_npcs") or [])
            if isinstance(r, dict) and r.get("name") and r.get("witnessed")
        ]
        return cls(
            testemunhados=[t for t in testemunhados if len(t) >= 3],
            desconhecidos=[d for d in desconhecidos if len(d) >= 3],
            conhece_rumores=rumores,
            acoes=[a for a in (allowed.get("actions") or []) if a in ACOES],
            itens=[str(i) for i in (allowed.get("items") or [])][:40],
            lugares=[str(p) for p in (allowed.get("places") or [])][:40],
            memorias=refs,
        )


@dataclass
class RespostaValidada:
    fala: str
    emocao: str
    intencao: str
    memoria_ids: list[str]
    acao: Optional[str]
    parametros: dict[str, Any]
    descartes: list[str]


class RespostaInvalida(Exception):
    def __init__(self, reason: str, message: str = "") -> None:
        super().__init__(message or reason)
        self.reason = reason


def limpar_fala(raw: str) -> str:
    text = _THINK_RE.sub("", str(raw or ""))
    text = _EMOJI_RE.sub("", text)
    text = _ASTERISCOS_RE.sub("", text)
    text = _REFS_RE.sub("", text)
    text = _META_PAREN_RE.sub("", text)
    text = re.sub(r"\s+([,.!?…])", r"\1", text)
    text = re.sub(r"\s+", " ", text).strip().strip('"').strip()
    if text and text[0].islower():
        text = text[0].upper() + text[1:]
    if len(text) > MAX_FALA:
        cut = text[:MAX_FALA]
        last = max(cut.rfind("."), cut.rfind("!"), cut.rfind("?"))
        text = cut[: last + 1] if last > 60 else cut.rstrip() + "…"
    return text


def quebra_personagem(fala: str) -> bool:
    n = _norm(fala)
    return any(p in n for p in _QUEBRA_PERSONAGEM)


def extrair_json(raw: str) -> Any:
    text = _THINK_RE.sub("", str(raw or "")).strip()
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end <= start:
        raise RespostaInvalida("json_invalido", "a saída do modelo não contém JSON")
    try:
        return json.loads(text[start : end + 1])
    except json.JSONDecodeError as exc:
        raise RespostaInvalida("json_invalido", "JSON malformado") from exc


def reparar_truncado(raw: str) -> Optional[dict[str, Any]]:
    """Recupera a fala de um JSON cortado pelo limite de tokens (só a fala, sem ações)."""
    m = _FALA_TRUNCADA_RE.search(_THINK_RE.sub("", str(raw or "")))
    if not m:
        return None
    try:
        fala = json.loads('"' + m.group(1).rstrip("\\") + '"')
    except json.JSONDecodeError:
        fala = m.group(1)
    fala = str(fala).strip()
    fim = max(fala.rfind("."), fala.rfind("!"), fala.rfind("?"))
    if fim < 10:
        return None
    return {"fala": fala[: fim + 1], "emocao": "neutra", "intencao": "conversar", "memoria_referenciada_ids": []}


def validar_resposta(raw: str, perm: Permissoes) -> RespostaValidada:
    """Valida a saída do modelo. Levanta ``RespostaInvalida`` se a fala for inutilizável."""
    descartes: list[str] = []
    try:
        data = extrair_json(raw)
    except RespostaInvalida:
        data = reparar_truncado(raw)
        if data is None:
            raise
        descartes.append("json_reparado")
    if not isinstance(data, dict):
        raise RespostaInvalida("json_invalido", "o JSON não é um objeto")
    try:
        resp = RespostaMorador.model_validate(data)
    except ValidationError as exc:
        raise RespostaInvalida("json_fora_do_contrato", str(exc.errors()[:2])) from exc
    fala = limpar_fala(resp.fala)
    fala = _checar_conhecimento(fala, perm, descartes)
    if len(fala) < MIN_FALA:
        raise RespostaInvalida("fala_vazia", "fala vazia")
    if quebra_personagem(fala):
        raise RespostaInvalida("quebra_de_personagem", "o morador saiu do personagem")
    if fala.lstrip().startswith("{") or '"fala"' in fala:
        raise RespostaInvalida("json_na_fala", "a fala contém JSON bruto")
    emocao = resp.emocao if resp.emocao in EMOCOES else "neutra"
    if emocao != resp.emocao:
        descartes.append("emocao_invalida")
    intencao = resp.intencao if resp.intencao in INTENCOES else "conversar"
    if intencao != resp.intencao:
        descartes.append("intencao_invalida")
    memoria_ids: list[str] = []
    for ref in resp.memoria_referenciada_ids:
        real = perm.memorias.get(str(ref)) or (str(ref) if str(ref) in perm.memorias.values() else None)
        if real and real not in memoria_ids:
            memoria_ids.append(real)
        elif not real:
            descartes.append("memoria_inexistente")
    acao: Optional[str] = resp.acao_sugerida
    params: dict[str, Any] = {}
    if acao in (None, "", "null", "nenhuma"):
        acao = None
    elif acao not in ACOES or acao not in perm.acoes:
        descartes.append("acao_proibida")
        acao = None
    else:
        p = resp.parametros_acao or ParametrosAcao()
        if acao == "pedir_item":
            if p.item_id in perm.itens:
                params = {"item_id": p.item_id}
            else:
                descartes.append("parametro_invalido")
                acao = None
        elif acao == "convidar_atividade":
            if p.lugar in perm.lugares:
                params = {"lugar": p.lugar}
            else:
                descartes.append("parametro_invalido")
                acao = None
        elif acao == "registrar_promessa":
            desc = limpar_fala(p.descricao or "")[:120]
            if len(desc) >= 4 and not quebra_personagem(desc):
                params = {"descricao": desc}
            else:
                descartes.append("parametro_invalido")
                acao = None
        elif acao == "compartilhar_lembranca":
            real = perm.memorias.get(str(p.memoria_ref or ""))
            if real:
                params = {"memoria_id": real}
            else:
                descartes.append("parametro_invalido")
                acao = None
    return RespostaValidada(fala, emocao, intencao, memoria_ids, acao, params, descartes)


def validar_falas_entre_moradores(raw: str, a_id: str = "a", b_id: str = "b", nome_a: str = "", nome_b: str = "") -> tuple[str, str]:
    data = extrair_json(raw)
    if not isinstance(data, dict):
        raise RespostaInvalida("json_invalido")
    ka, kb = chaves_falas(a_id, b_id)
    a = limpar_fala(data.get(ka, data.get("fala_a", "")))[:140]
    b = limpar_fala(data.get(kb, data.get("fala_b", "")))[:140]
    # Cada um chamando a si mesmo pelo nome indica falas trocadas: desfaz a troca.
    if nome_a and nome_b and _norm(a).startswith(_norm(nome_a)) and _norm(b).startswith(_norm(nome_b)):
        a, b = b, a
    if len(a) < MIN_FALA or len(b) < MIN_FALA:
        raise RespostaInvalida("fala_vazia")
    if quebra_personagem(a) or quebra_personagem(b):
        raise RespostaInvalida("quebra_de_personagem")
    return a, b


def validar_plano(raw: str, opcoes: list[str]) -> tuple[str, str]:
    data = extrair_json(raw)
    if not isinstance(data, dict):
        raise RespostaInvalida("json_invalido")
    opcao = str(data.get("opcao", ""))
    if opcao not in opcoes:
        raise RespostaInvalida("opcao_invalida", f"opção fora da lista: {opcao[:30]}")
    motivo = limpar_fala(data.get("motivo", ""))[:160]
    if quebra_personagem(motivo):
        motivo = ""
    return opcao, motivo


def _checar_conhecimento(fala: str, perm: Permissoes, descartes: list[str]) -> str:
    """Barreira contra invenções sobre o mundo.

    - "Ouvi dizer..." sem nenhum rumor conhecido: a frase sai; se o que sobrar não
      disser claramente que não sabe, a resposta inteira é recusada (fallback).
    - Afirmação sobre um morador citado de quem este morador não sabe nada
      (sem marcas de "não sei"): resposta recusada (fallback).
    """
    frases = [f for f in re.split(r"(?<=[.!?…])\s+", fala) if f.strip()]
    if not perm.conhece_rumores and any(_BOATO_RE.search(f) for f in frases):
        frases = [f for f in frases if not _BOATO_RE.search(f)]
        descartes.append("boato_sem_fonte")
        if not any(_NAO_SEI_RE.search(f) for f in frases):
            raise RespostaInvalida("boato_sem_fonte", "o morador inventou um boato")
    for f in frases:
        nf = _norm(f)
        if re.search(r"\bn[aã]o (vi|estava|sei)\b", nf):
            for nome in perm.testemunhados:
                if re.search(r"\b" + re.escape(nome) + r"\b", nf):
                    raise RespostaInvalida("contradiz_memoria", f"negou ter visto {nome}, mas lembra")
        if _NAO_SEI_RE.search(nf) or nf.rstrip().endswith("?"):
            continue
        for nome in perm.desconhecidos:
            if re.search(r"\b" + re.escape(nome) + r"\b", nf):
                raise RespostaInvalida("afirmacao_sem_base", f"afirmou algo sobre {nome} sem saber")
    return " ".join(frases).strip()
