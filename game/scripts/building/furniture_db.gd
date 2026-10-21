class_name FurnitureDB
extends RefCounted
## Catálogo dos objetos do prédio: modelo, tamanho no chão, ações possíveis
## (affordances), pontos de uso e assentos, conforto e se a jogadora pode
## mover o objeto no modo decoração.
##
## Coordenadas locais do objeto: frente voltada para +Z (convenção do Blender
## exportado). `use` é onde o personagem fica para usar o objeto; `seats`/`lie`
## são posições locais de sentar/deitar.

const DEFS := {
	# Quarto
	"cama": {"label": "Cama", "model": "furniture/cama", "size": Vector2(1.6, 2.1), "aff": ["dormir", "cochilar"], "use": Vector3(1.05, 0, 0.3), "lie": Vector3(0, 0.5, 0.15), "comfort": 95, "movable": true, "height": 0.9},
	"cama_simples": {"label": "Cama de solteiro", "model": "furniture/cama_simples", "size": Vector2(1.0, 2.0), "aff": ["dormir", "cochilar"], "use": Vector3(0.75, 0, 0.3), "lie": Vector3(0, 0.46, 0.15), "comfort": 90, "movable": true, "height": 0.8},
	"criado_mudo": {"label": "Criado-mudo", "model": "furniture/criado_mudo", "size": Vector2(0.45, 0.4), "aff": [], "movable": true, "height": 0.9},
	"guarda_roupa": {"label": "Guarda-roupa", "model": "furniture/guarda_roupa", "size": Vector2(1.26, 0.64), "aff": [], "movable": false, "height": 2.1},
	"luminaria": {"label": "Luminária", "model": "furniture/luminaria", "size": Vector2(0.36, 0.36), "aff": [], "movable": true, "height": 1.7, "light": true},
	"tapete": {"label": "Tapete", "model": "furniture/tapete", "size": Vector2(2.0, 1.4), "aff": [], "movable": true, "flat": true, "dirt": true, "height": 0.02},
	# Sala
	"sofa": {"label": "Sofá", "model": "furniture/sofa", "size": Vector2(2.0, 0.9), "aff": ["sentar"], "use": Vector3(0, 0, 0.8), "seats": [Vector3(-0.47, 0.45, 0.02), Vector3(0.47, 0.45, 0.02)], "comfort": 90, "movable": true, "height": 0.95},
	"poltrona": {"label": "Poltrona", "model": "furniture/poltrona", "size": Vector2(0.9, 0.85), "aff": ["sentar"], "use": Vector3(0, 0, 0.75), "seats": [Vector3(0, 0.45, 0.0)], "comfort": 85, "movable": true, "height": 0.95},
	"cadeira": {"label": "Cadeira", "model": "furniture/cadeira", "size": Vector2(0.46, 0.46), "aff": ["sentar"], "use": Vector3(0, 0, 0.55), "seats": [Vector3(0, 0.47, 0.0)], "comfort": 65, "movable": true, "height": 1.0},
	"cadeira_simples": {"label": "Cadeira simples", "model": "furniture/cadeira_simples", "size": Vector2(0.46, 0.46), "aff": ["sentar"], "use": Vector3(0, 0, 0.55), "seats": [Vector3(0, 0.47, 0.0)], "comfort": 60, "movable": true, "height": 1.0},
	"mesa_jantar": {"label": "Mesa de jantar", "model": "furniture/mesa_jantar", "size": Vector2(1.4, 0.9), "aff": [], "movable": true, "dirt": true, "table": true, "height": 0.8},
	"mesa_pequena": {"label": "Mesa pequena", "model": "furniture/mesa_pequena", "size": Vector2(0.8, 0.8), "aff": [], "movable": true, "dirt": true, "table": true, "height": 0.75},
	"mesa_centro": {"label": "Mesa de centro", "model": "furniture/mesa_centro", "size": Vector2(1.0, 0.6), "aff": [], "movable": true, "height": 0.42},
	"tv": {"label": "TV", "model": "furniture/tv", "size": Vector2(1.3, 0.45), "aff": ["assistir_tv"], "use": Vector3(0, 0, 2.4), "movable": true, "height": 1.3},
	"estante": {"label": "Estante", "model": "furniture/estante", "size": Vector2(1.0, 0.36), "aff": ["ler"], "use": Vector3(0, 0, 0.7), "movable": true, "height": 1.6},
	"vaso_decorativo": {"label": "Vaso decorativo", "model": "furniture/vaso_decorativo", "size": Vector2(0.35, 0.35), "aff": ["regar"], "use": Vector3(0, 0, 0.6), "movable": true, "height": 0.7, "decor": 6},
	"banco": {"label": "Banco", "model": "furniture/banco", "size": Vector2(1.2, 0.4), "aff": ["sentar"], "use": Vector3(0, 0, 0.6), "seats": [Vector3(-0.3, 0.47, 0.0), Vector3(0.3, 0.47, 0.0)], "comfort": 55, "movable": true, "height": 0.5},
	"planta_grande": {"label": "Planta", "model": "furniture/planta_grande", "size": Vector2(0.5, 0.5), "aff": ["regar"], "use": Vector3(0, 0, 0.65), "movable": true, "height": 1.3, "decor": 8},
	"quadro": {"label": "Quadro", "model": "furniture/quadro", "size": Vector2(0.0, 0.0), "aff": [], "movable": false, "wall": true, "decor": 6},
	# Cozinha
	"geladeira": {"label": "Geladeira", "model": "furniture/geladeira", "size": Vector2(0.75, 0.7), "aff": ["comer_lanche"], "use": Vector3(0, 0, 0.75), "movable": false, "height": 1.8},
	"fogao": {"label": "Fogão", "model": "furniture/fogao", "size": Vector2(0.76, 0.66), "aff": ["cozinhar"], "use": Vector3(0, 0, 0.72), "movable": false, "dirt": true, "height": 1.1},
	"pia_cozinha": {"label": "Pia da cozinha", "model": "furniture/pia_cozinha", "size": Vector2(1.24, 0.68), "aff": [], "use": Vector3(0, 0, 0.72), "movable": false, "dirt": true, "height": 1.1},
	"balcao": {"label": "Balcão", "model": "furniture/balcao", "size": Vector2(1.04, 0.68), "aff": [], "use": Vector3(0, 0, 0.72), "movable": false, "dirt": true, "height": 1.0},
	"forno_lenha": {"label": "Forno a lenha", "model": "furniture/forno_lenha", "size": Vector2(1.0, 0.85), "aff": ["cozinhar"], "use": Vector3(0, 0, 0.8), "movable": false, "dirt": true, "height": 1.7},
	# Banheiro
	"chuveiro": {"label": "Chuveiro", "model": "furniture/chuveiro", "size": Vector2(0.95, 0.95), "aff": ["banho"], "use": Vector3(-0.05, 0, 0.0), "movable": false, "dirt": true, "height": 2.1, "enter": true},
	"vaso_sanitario": {"label": "Vaso sanitário", "model": "furniture/vaso_sanitario", "size": Vector2(0.45, 0.75), "aff": ["banheiro"], "use": Vector3(0, 0, 0.6), "seats": [Vector3(0, 0.42, 0.02)], "movable": false, "dirt": true, "height": 0.85},
	"pia_banheiro": {"label": "Pia do banheiro", "model": "furniture/pia_banheiro", "size": Vector2(0.62, 0.46), "aff": ["lavar_maos"], "use": Vector3(0, 0, 0.6), "movable": false, "dirt": true, "height": 1.8},
	# Hobbies e trabalho
	"bancada_trabalho": {"label": "Bancada de trabalho", "model": "furniture/bancada_trabalho", "size": Vector2(1.4, 0.75), "aff": ["fabricar"], "use": Vector3(0, 0, 0.8), "movable": false, "height": 1.7},
	"maquina_costura": {"label": "Máquina de costura", "model": "furniture/maquina_costura", "size": Vector2(1.0, 0.55), "aff": ["costurar"], "use": Vector3(0, 0, 0.8), "movable": false, "height": 1.2},
	"piano": {"label": "Piano", "model": "furniture/piano", "size": Vector2(1.44, 0.6), "aff": ["tocar"], "use": Vector3(0, 0, 0.85), "movable": false, "height": 1.3, "loud": true},
	"violao_suporte": {"label": "Violão", "model": "furniture/violao_suporte", "size": Vector2(0.4, 0.3), "aff": ["tocar"], "use": Vector3(0, 0, 0.6), "movable": false, "height": 1.2, "loud": true},
	"cavalete_pintura": {"label": "Cavalete", "model": "furniture/cavalete_pintura", "size": Vector2(0.7, 0.6), "aff": ["pintar"], "use": Vector3(0, 0, 0.75), "movable": false, "height": 1.6},
	"telescopio": {"label": "Telescópio", "model": "props/telescope", "size": Vector2(0.8, 0.8), "aff": ["observar"], "use": Vector3(0, 0, 0.85), "movable": false, "height": 1.6},
	"organizador_cartas": {"label": "Organizador de cartas", "model": "furniture/organizador_cartas", "size": Vector2(1.2, 0.4), "aff": ["organizar_cartas"], "use": Vector3(0, 0, 0.7), "movable": false, "height": 1.3},
	"escrivaninha": {"label": "Escrivaninha", "model": "furniture/escrivaninha", "size": Vector2(1.2, 0.6), "aff": ["estudar"], "use": Vector3(0, 0, 0.75), "movable": false, "height": 0.8},
	"prancha_surf": {"label": "Prancha", "model": "furniture/prancha_surf", "size": Vector2(0.6, 0.3), "aff": [], "movable": false, "height": 2.0},
	"rolos_tecido": {"label": "Tecidos", "model": "furniture/rolos_tecido", "size": Vector2(1.2, 0.6), "aff": [], "movable": false, "height": 0.6},
	# Áreas comuns
	"espreguicadeira": {"label": "Espreguiçadeira", "model": "furniture/espreguicadeira", "size": Vector2(0.7, 1.9), "aff": ["relaxar"], "use": Vector3(0.7, 0, 0.0), "seats": [Vector3(0, 0.38, 0.15)], "seat_facing": PI, "comfort": 92, "movable": false, "height": 0.8},
	"churrasqueira": {"label": "Churrasqueira", "model": "furniture/churrasqueira", "size": Vector2(1.56, 0.8), "aff": ["churrasco"], "use": Vector3(0, 0, 0.8), "movable": false, "dirt": true, "height": 2.7},
	"mesa_redonda": {"label": "Mesa", "model": "furniture/mesa_redonda", "size": Vector2(1.1, 1.1), "aff": [], "movable": false, "dirt": true, "table": true, "height": 2.2},
	"cadeira_externa": {"label": "Cadeira", "model": "furniture/cadeira_externa", "size": Vector2(0.5, 0.5), "aff": ["sentar"], "use": Vector3(0, 0, 0.55), "seats": [Vector3(0, 0.45, 0.0)], "comfort": 65, "movable": false, "height": 0.95},
	"piscina": {"label": "Piscina", "model": "furniture/piscina", "size": Vector2(6.8, 4.4), "aff": ["nadar"], "use": Vector3(2.4, 0, 2.5), "movable": false, "height": 0.2, "pool": true},
	"pergolado": {"label": "Pergolado", "model": "furniture/pergolado", "size": Vector2(0.0, 0.0), "aff": [], "movable": false, "posts": [Vector2(-1.8, -1.3), Vector2(1.8, -1.3), Vector2(-1.8, 1.3), Vector2(1.8, 1.3)], "light": true},
	"luzinhas": {"label": "Luzinhas", "model": "furniture/luzinhas", "size": Vector2(0.3, 0.3), "aff": [], "movable": false, "height": 2.6, "light": true},
	"canteiro_horta": {"label": "Canteiro da horta", "model": "furniture/canteiro_horta", "size": Vector2(1.8, 0.9), "aff": ["cuidar_horta"], "use": Vector3(0, 0, 0.8), "movable": false, "height": 0.6},
	"esteira": {"label": "Esteira", "model": "furniture/esteira", "size": Vector2(0.75, 1.8), "aff": ["exercitar"], "use": Vector3(0.75, 0, 0.3), "stand_on": Vector3(0, 0.25, 0.15), "movable": false, "height": 1.4},
	"banco_supino": {"label": "Banco de supino", "model": "furniture/banco_supino", "size": Vector2(1.4, 1.3), "aff": ["exercitar"], "use": Vector3(0, 0, 1.0), "movable": false, "height": 1.3},
	"halteres": {"label": "Halteres", "model": "furniture/halteres", "size": Vector2(1.0, 0.4), "aff": ["exercitar"], "use": Vector3(0, 0, 0.7), "movable": false, "height": 0.5},
	"maquina_lavar": {"label": "Máquina de lavar", "model": "furniture/maquina_lavar", "size": Vector2(0.62, 0.62), "aff": ["lavar_roupa"], "use": Vector3(0, 0, 0.65), "movable": false, "height": 0.9},
	"varal": {"label": "Varal", "model": "furniture/varal", "size": Vector2(1.5, 0.6), "aff": [], "movable": false, "height": 1.2},
	"estante_mercado": {"label": "Prateleira", "model": "furniture/estante_mercado", "size": Vector2(1.8, 0.5), "aff": ["comprar", "repor", "organizar"], "use": Vector3(0, 0, 0.75), "movable": false, "height": 1.7, "shelf": true},
	"caixa_mercado": {"label": "Caixa do mercadinho", "model": "furniture/caixa_mercado", "size": Vector2(1.66, 0.76), "aff": ["comprar", "emprego", "atender"], "use": Vector3(0, 0, 0.85), "movable": false, "height": 1.3},
	"freezer_mercado": {"label": "Refrigerador", "model": "furniture/freezer_mercado", "size": Vector2(1.2, 0.7), "aff": ["comprar"], "use": Vector3(0, 0, 0.8), "movable": false, "height": 1.9},
	"caixa_estoque": {"label": "Estoque", "model": "props/crate", "size": Vector2(1.2, 1.0), "aff": ["pegar_estoque"], "use": Vector3(0, 0, 0.9), "movable": false, "height": 1.2, "stack": true},
	"recepcao": {"label": "Recepção", "model": "furniture/recepcao", "size": Vector2(2.3, 0.8), "aff": [], "movable": false, "height": 1.3},
	"mesa_cowork": {"label": "Mesa compartilhada", "model": "furniture/mesa_cowork", "size": Vector2(2.4, 0.9), "aff": ["estudar"], "use": Vector3(0, 0, 0.8), "movable": false, "height": 1.0},
	"maquina_cafe": {"label": "Cantinho do café", "model": "furniture/maquina_cafe", "size": Vector2(1.04, 0.64), "aff": ["cafe"], "use": Vector3(0, 0, 0.72), "movable": false, "height": 1.4},
	"caixas_correio": {"label": "Caixas de correio", "model": "furniture/caixas_correio", "size": Vector2(1.8, 0.3), "aff": ["correio"], "use": Vector3(0, 0, 0.65), "movable": false, "height": 1.9},
	"sofa_lounge": {"label": "Sofá da convivência", "model": "furniture/sofa_lounge", "size": Vector2(2.8, 0.95), "aff": ["sentar"], "use": Vector3(0, 0, 0.85), "seats": [Vector3(-0.92, 0.45, 0.02), Vector3(0.0, 0.45, 0.02), Vector3(0.92, 0.45, 0.02)], "comfort": 88, "movable": false, "height": 0.95},
	"fonte": {"label": "Fonte", "model": "props/fountain", "size": Vector2(3.7, 3.7), "aff": [], "movable": false, "round": 1.9, "height": 1.9},
	"banco_praca": {"label": "Banco do pátio", "model": "props/bench", "size": Vector2(1.8, 0.7), "aff": ["sentar"], "use": Vector3(0, 0, 0.7), "seats": [Vector3(-0.45, 0.46, -0.05), Vector3(0.45, 0.46, -0.05)], "comfort": 60, "movable": false, "height": 1.0},
	"mesa_piquenique": {"label": "Mesa de piquenique", "model": "props/picnic_table", "size": Vector2(1.9, 1.6), "aff": [], "movable": false, "table": true, "height": 0.9},
	"caixote": {"label": "Caixote", "model": "props/crate", "size": Vector2(0.8, 0.8), "aff": [], "movable": false, "height": 0.8},
	"barril": {"label": "Barril", "model": "props/barrel", "size": Vector2(0.8, 0.8), "aff": [], "movable": false, "height": 1.0},
}

## Rótulos das ações (o que aparece no menu de interação).
const AFF_LABELS := {
	"dormir": "Dormir", "cochilar": "Tirar um cochilo", "sentar": "Sentar e descansar", "assistir_tv": "Assistir TV",
	"ler": "Ler um livro", "regar": "Regar", "comer_lanche": "Pegar um lanche", "cozinhar": "Cozinhar uma refeição",
	"banho": "Tomar banho", "banheiro": "Usar o banheiro", "lavar_maos": "Lavar as mãos", "fabricar": "Fabricar móveis",
	"costurar": "Costurar", "tocar": "Tocar música", "pintar": "Pintar", "observar": "Observar o céu",
	"organizar_cartas": "Organizar cartas", "estudar": "Estudar", "relaxar": "Relaxar", "churrasco": "Churrasco",
	"cuidar_horta": "Cuidar da horta", "exercitar": "Exercitar-se", "lavar_roupa": "Lavar roupa", "nadar": "Nadar",
	"comprar": "Fazer compras", "repor": "Repor prateleira", "organizar": "Organizar prateleira", "emprego": "Trabalho no mercadinho",
	"atender": "Atender cliente", "pegar_estoque": "Pegar caixa de produtos", "cafe": "Tomar um café", "correio": "Ver o correio",
	"limpar": "Limpar",
}


static func has(def_id: String) -> bool:
	return DEFS.has(def_id)


static func get_def(def_id: String) -> Dictionary:
	return DEFS.get(def_id, {})


static func label(def_id: String) -> String:
	return str(DEFS.get(def_id, {}).get("label", def_id))


static func affordances(def_id: String) -> Array:
	return DEFS.get(def_id, {}).get("aff", [])


static func is_movable(def_id: String) -> bool:
	return bool(DEFS.get(def_id, {}).get("movable", false))


static func can_get_dirty(def_id: String) -> bool:
	return bool(DEFS.get(def_id, {}).get("dirt", false))


## Tamanho no chão considerando a rotação (múltiplos de 90°).
static func footprint(def_id: String, rot: float) -> Vector2:
	var s: Vector2 = DEFS.get(def_id, {}).get("size", Vector2.ZERO)
	var quarter := absi(int(round(rot / (PI / 2.0)))) % 2
	return Vector2(s.y, s.x) if quarter == 1 else s


## Retângulo ocupado no chão (centro em pos).
static func rect_of(def_id: String, pos: Vector2, rot: float) -> Rect2:
	var f := footprint(def_id, rot)
	return Rect2(pos - f * 0.5, f)


static func local_to_world(pos: Vector2, rot: float, local: Vector3) -> Vector3:
	var v := local.rotated(Vector3.UP, rot)
	return Vector3(pos.x + v.x, v.y, pos.y + v.z)


## Ponto (no chão) onde o personagem fica para usar o objeto.
static func use_point(obj: Dictionary) -> Vector3:
	var d := get_def(str(obj["def"]))
	var u: Vector3 = d.get("use", Vector3(0, 0, 0.7))
	var w := local_to_world(obj["pos"], float(obj.get("rot", 0.0)), u)
	return Vector3(w.x, 0.0, w.z)


## Assentos do objeto (posições no mundo do andar).
static func seats(obj: Dictionary) -> Array:
	var d := get_def(str(obj["def"]))
	var out := []
	for s in d.get("seats", []):
		out.append(local_to_world(obj["pos"], float(obj.get("rot", 0.0)), s))
	return out


static func comfort(def_id: String) -> float:
	return float(DEFS.get(def_id, {}).get("comfort", 45))
