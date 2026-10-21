class_name Wallet
extends RefCounted
## Carteira da jogadora em Bloom (moeda do Daybloom). Toda movimentação passa
## por aqui, com validação: valores inteiros positivos, saldo nunca negativo
## em compras e recebimentos com referência única (o mesmo trabalho nunca é
## pago duas vezes). Fala de morador não mexe em dinheiro: só os sistemas do
## jogo (trabalho, loja) chamam credit/debit.

const CURRENCY := "Bloom"
const START_BALANCE := 200
const MAX_HISTORY := 120
const INCOME_KINDS := ["inicial", "salario", "bonus", "venda", "reembolso"]
const EXPENSE_KINDS := ["compra", "evento"]

var balance: int = 0
var transactions: Array = []
var seq: int = 0
var paid_refs: Dictionary = {}


static func format(amount: int) -> String:
	return "%d %s" % [amount, CURRENCY]


func can_afford(amount: int) -> bool:
	return amount >= 0 and balance >= amount


func _tx(amount: int, kind: String, description: String, ref: String, time: Dictionary) -> Dictionary:
	seq += 1
	var tx := {
		"id": "tx_%06d" % seq,
		"amount": amount,
		"kind": kind,
		"description": description.substr(0, 90),
		"ref": ref,
		"day": int(time.get("day", 1)),
		"minute": snappedf(float(time.get("minute", 0.0)), 0.01),
		"balance_after": balance,
	}
	transactions.append(tx)
	while transactions.size() > MAX_HISTORY:
		transactions.pop_front()
	return tx


## Recebimento. `ref` identifica o que gerou o dinheiro (tarefa, turno...).
func credit(amount: int, kind: String, description: String, ref: String, time: Dictionary) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "valor inválido"}
	if not (kind in INCOME_KINDS):
		return {"ok": false, "reason": "tipo de recebimento inválido"}
	if ref.strip_edges() == "":
		return {"ok": false, "reason": "recebimento sem referência"}
	if paid_refs.has(ref):
		return {"ok": false, "reason": "já foi pago"}
	balance += amount
	paid_refs[ref] = true
	return {"ok": true, "tx": _tx(amount, kind, description, ref, time)}


## Gasto. Nunca deixa o saldo negativo.
func debit(amount: int, kind: String, description: String, ref: String, time: Dictionary) -> Dictionary:
	if amount <= 0:
		return {"ok": false, "reason": "valor inválido"}
	if not (kind in EXPENSE_KINDS):
		return {"ok": false, "reason": "tipo de gasto inválido"}
	if balance < amount:
		return {"ok": false, "reason": "saldo insuficiente"}
	balance -= amount
	return {"ok": true, "tx": _tx(-amount, kind, description, ref, time)}


func recent(count: int) -> Array:
	return transactions.slice(maxi(0, transactions.size() - count))


func to_dict() -> Dictionary:
	return {"balance": balance, "seq": seq, "transactions": transactions.duplicate(true), "paid_refs": paid_refs.keys()}


func load_from(data: Dictionary) -> void:
	balance = maxi(0, int(data.get("balance", START_BALANCE)))
	seq = maxi(0, int(data.get("seq", 0)))
	transactions = []
	for t in data.get("transactions", []):
		if t is Dictionary and t.has("id") and t.has("amount"):
			var tx: Dictionary = (t as Dictionary).duplicate()
			tx["amount"] = int(tx["amount"])
			transactions.append(tx)
	paid_refs = {}
	for r in data.get("paid_refs", []):
		paid_refs[str(r)] = true
	for t in transactions:
		if int(t["amount"]) > 0 and str(t.get("ref", "")) != "":
			paid_refs[str(t["ref"])] = true
