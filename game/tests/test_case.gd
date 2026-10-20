class_name TestCase
extends RefCounted
## Base mínima para testes headless do Daybloom.

var runner: Node
var failures: Array = []
var current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func tree() -> SceneTree:
	return runner.get_tree()


func fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])


func assert_true(cond: bool, msg: String = "esperava verdadeiro") -> bool:
	if not cond:
		fail(msg)
	return cond


func assert_false(cond: bool, msg: String = "esperava falso") -> bool:
	return assert_true(not cond, msg)


func assert_eq(a: Variant, b: Variant, msg: String = "") -> bool:
	if typeof(a) != typeof(b) and not ((a is int or a is float) and (b is int or b is float)):
		fail("%s (tipos diferentes: %s vs %s)" % [msg, str(a), str(b)])
		return false
	if a != b:
		fail("%s (obtido: %s, esperado: %s)" % [msg, str(a), str(b)])
		return false
	return true


func assert_gt(a: float, b: float, msg: String = "") -> bool:
	if not a > b:
		fail("%s (%s não é maior que %s)" % [msg, str(a), str(b)])
		return false
	return true


func assert_lt(a: float, b: float, msg: String = "") -> bool:
	if not a < b:
		fail("%s (%s não é menor que %s)" % [msg, str(a), str(b)])
		return false
	return true


func wait_frames(n: int) -> void:
	for i in range(n):
		await tree().physics_frame


## Cria uma simulação nova e determinística, independente da cena.
func new_sim(seed_value: int = 1234) -> Simulation:
	var sim := Simulation.new()
	sim.set_time(1, 480.0)
	sim.setup_new(Simulation.load_definitions(), "jogadora_teste", "Ana", seed_value)
	return sim
