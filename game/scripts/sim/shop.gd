class_name Shop
extends RefCounted
## Mercadinho do térreo. Estoque nas prateleiras (`stock`) e no depósito dos
## fundos (`backstock`). O depósito é reabastecido de manhã; as prateleiras
## são repostas por quem trabalha no mercadinho (tarefa "repor") ou, se
## ninguém trabalhar, automaticamente às 7h. Comprar reduz o estoque real.

const PRODUCTS := {
	"pao": {"price": 8, "max": 12, "shelf": "prateleira_1"},
	"leite": {"price": 6, "max": 10, "shelf": "freezer"},
	"ingredientes": {"price": 14, "max": 8, "shelf": "prateleira_1"},
	"kit_churrasco": {"price": 30, "max": 4, "shelf": "freezer"},
	"pao_de_mel": {"price": 14, "max": 6, "shelf": "prateleira_1", "locked": true},
	"maca_verde": {"price": 5, "max": 12, "shelf": "prateleira_2"},
	"pessego": {"price": 6, "max": 12, "shelf": "prateleira_2"},
	"margarida": {"price": 9, "max": 6, "shelf": "prateleira_2"},
	"tulipa_coral": {"price": 9, "max": 6, "shelf": "prateleira_2"},
	"campanula": {"price": 9, "max": 6, "shelf": "prateleira_2"},
	"girassol": {"price": 9, "max": 6, "shelf": "prateleira_2"},
	"tabua": {"price": 12, "max": 20, "shelf": "prateleira_3"},
	"tecido": {"price": 10, "max": 15, "shelf": "prateleira_3"},
	"argila": {"price": 8, "max": 12, "shelf": "prateleira_3"},
	"lampada": {"price": 15, "max": 6, "shelf": "prateleira_3"},
	"tinta": {"price": 12, "max": 8, "shelf": "prateleira_3"},
	"concha": {"price": 12, "max": 3, "shelf": "prateleira_4"},
	"pedra_lisa": {"price": 6, "max": 8, "shelf": "prateleira_4"},
	"movel_vaso": {"price": 35, "max": 3, "shelf": "prateleira_4"},
	"movel_tapete": {"price": 40, "max": 2, "shelf": "prateleira_4"},
	"movel_planta": {"price": 45, "max": 2, "shelf": "prateleira_4"},
}
const SHELVES := ["prateleira_1", "prateleira_2", "prateleira_3", "prateleira_4", "freezer"]
const SHELF_LABELS := {"prateleira_1": "padaria e mercearia", "prateleira_2": "frutas e flores", "prateleira_3": "materiais", "prateleira_4": "casa e presentes", "freezer": "refrigerador"}

var stock: Dictionary = {}
var backstock: Dictionary = {}
## Arrumação de cada prateleira (0..1): compras bagunçam, a tarefa "organizar" arruma.
var tidiness: Dictionary = {}
var unlocked: Array = []
var last_restock_day: int = 0
var sales_today: int = 0


func _init() -> void:
	for item_id in PRODUCTS:
		stock[item_id] = int(PRODUCTS[item_id]["max"])
		backstock[item_id] = int(PRODUCTS[item_id]["max"])
	for s in SHELVES:
		tidiness[s] = 1.0


func is_available(item_id: String) -> bool:
	if not PRODUCTS.has(item_id):
		return false
	return not bool(PRODUCTS[item_id].get("locked", false)) or unlocked.has(item_id)


func price(item_id: String) -> int:
	return int(PRODUCTS.get(item_id, {}).get("price", 0))


func unlock(item_id: String) -> bool:
	if not PRODUCTS.has(item_id) or unlocked.has(item_id):
		return false
	unlocked.append(item_id)
	backstock[item_id] = int(PRODUCTS[item_id]["max"])
	stock[item_id] = int(PRODUCTS[item_id]["max"]) / 2
	return true


func products_list() -> Array:
	var out := []
	for item_id in PRODUCTS:
		if is_available(item_id):
			out.append({"item_id": item_id, "price": price(item_id), "stock": int(stock.get(item_id, 0)), "shelf": PRODUCTS[item_id]["shelf"]})
	return out


## Compra da jogadora: valida produto, estoque, espaço e saldo; debita e entrega.
func buy(item_id: String, qty: int, wallet: Wallet, inventory: Inventory, time: Dictionary) -> Dictionary:
	if qty <= 0 or qty > 20:
		return {"ok": false, "reason": "quantidade inválida"}
	if not is_available(item_id):
		return {"ok": false, "reason": "produto indisponível"}
	if int(stock.get(item_id, 0)) < qty:
		return {"ok": false, "reason": "estoque insuficiente"}
	if inventory.room_for(item_id) < qty:
		return {"ok": false, "reason": "inventário cheio"}
	var total := price(item_id) * qty
	var res := wallet.debit(total, "compra", "%dx %s" % [qty, ItemDB.display_name(item_id)], "compra:%s" % item_id, time)
	if not res["ok"]:
		return {"ok": false, "reason": res["reason"]}
	var added := inventory.add(item_id, qty)
	if added < qty:
		# Nunca deve acontecer (espaço foi verificado), mas não perde dinheiro.
		inventory.remove(item_id, added)
		wallet.balance += total
		return {"ok": false, "reason": "inventário cheio"}
	stock[item_id] = int(stock[item_id]) - qty
	_mess(str(PRODUCTS[item_id]["shelf"]), 0.08 * qty)
	sales_today += qty
	return {"ok": true, "total": total, "tx": res["tx"]}


## Compra de um morador (dinheiro dos moradores é abstrato; o estoque é real).
func npc_buy(item_id: String, qty: int = 1) -> bool:
	if not is_available(item_id) or int(stock.get(item_id, 0)) < qty:
		return false
	stock[item_id] = int(stock[item_id]) - qty
	_mess(str(PRODUCTS[item_id]["shelf"]), 0.06 * qty)
	sales_today += qty
	return true


func _mess(shelf: String, amount: float) -> void:
	tidiness[shelf] = clampf(float(tidiness.get(shelf, 1.0)) - amount, 0.0, 1.0)


## Proporção de produtos na prateleira (para mostrar os produtos no modelo).
func shelf_fill(shelf: String) -> float:
	var have := 0
	var cap := 0
	for item_id in PRODUCTS:
		if PRODUCTS[item_id]["shelf"] == shelf and is_available(item_id):
			have += int(stock.get(item_id, 0))
			cap += int(PRODUCTS[item_id]["max"])
	return float(have) / float(maxi(cap, 1))


## Move produtos do depósito para uma prateleira (tarefa "repor"). Retorna quantos.
func restock_shelf(shelf: String) -> int:
	var moved := 0
	for item_id in PRODUCTS:
		if PRODUCTS[item_id]["shelf"] != shelf or not is_available(item_id):
			continue
		var room := int(PRODUCTS[item_id]["max"]) - int(stock.get(item_id, 0))
		var n := mini(room, int(backstock.get(item_id, 0)))
		if n > 0:
			stock[item_id] = int(stock.get(item_id, 0)) + n
			backstock[item_id] = int(backstock[item_id]) - n
			moved += n
	return moved


func organize_shelf(shelf: String) -> void:
	tidiness[shelf] = 1.0


## Entrega do fornecedor (manhã) e reposição automática se ninguém repôs.
func on_new_day(day: int) -> void:
	if last_restock_day == day:
		return
	last_restock_day = day
	sales_today = 0
	for item_id in PRODUCTS:
		if is_available(item_id):
			backstock[item_id] = int(PRODUCTS[item_id]["max"])


func auto_restock() -> int:
	var moved := 0
	for s in SHELVES:
		if shelf_fill(s) < 0.5:
			moved += restock_shelf(s)
	return moved


func to_dict() -> Dictionary:
	return {"stock": stock.duplicate(), "backstock": backstock.duplicate(), "tidiness": tidiness.duplicate(), "unlocked": unlocked.duplicate(), "last_restock_day": last_restock_day}


func load_from(data: Dictionary) -> void:
	var st: Dictionary = data.get("stock", {})
	var bk: Dictionary = data.get("backstock", {})
	for item_id in PRODUCTS:
		if st.has(item_id):
			stock[item_id] = clampi(int(st[item_id]), 0, int(PRODUCTS[item_id]["max"]))
		if bk.has(item_id):
			backstock[item_id] = clampi(int(bk[item_id]), 0, int(PRODUCTS[item_id]["max"]))
	var td: Dictionary = data.get("tidiness", {})
	for s in SHELVES:
		if td.has(s):
			tidiness[s] = clampf(float(td[s]), 0.0, 1.0)
	unlocked = []
	for it in data.get("unlocked", []):
		if PRODUCTS.has(str(it)):
			unlocked.append(str(it))
	last_restock_day = int(data.get("last_restock_day", 0))
