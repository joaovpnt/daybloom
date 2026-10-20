extends Node
## Executor de testes headless. Uso:
##   godot --headless --fixed-fps 60 --path game res://tests/test_runner.tscn
## Opcional: -- --filtro=persistencia  (roda só arquivos que contenham o texto)

const TEST_FILES := [
	"res://tests/test_clock.gd",
	"res://tests/test_npcs.gd",
	"res://tests/test_social.gd",
	"res://tests/test_inventory_gifts.gd",
	"res://tests/test_dialogue.gd",
	"res://tests/test_persistence.gd",
	"res://tests/test_world.gd",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filtro="):
			filter = arg.trim_prefix("--filtro=")
	var total := 0
	var failed := 0
	var report := []
	var started := Time.get_ticks_msec()
	print("\n=== Testes do Daybloom (Godot %s) ===" % Engine.get_version_info()["string"])
	for path in TEST_FILES:
		if filter != "" and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		var suite: TestCase = script.new()
		suite.runner = self
		print("\n[%s]" % path.get_file())
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			suite.current_test = name
			var before: int = suite.failures.size()
			var t0 := Time.get_ticks_msec()
			await suite.before_each()
			await suite.call(name)
			await suite.after_each()
			var ok: bool = suite.failures.size() == before
			if not ok:
				failed += 1
			var line := "  %s %s (%d ms)" % ["OK  " if ok else "FALHOU", name, Time.get_ticks_msec() - t0]
			print(line)
			for f in suite.failures.slice(before):
				print("      - " + f)
			report.append({"suite": path.get_file(), "test": name, "ok": ok, "failures": suite.failures.slice(before)})
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\n=== %d testes, %d falhas, %.1f s ===" % [total, failed, elapsed])
	var out_dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir + "/resultado_godot.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"total": total, "failed": failed, "seconds": elapsed, "results": report}, "  "))
		f.close()
	get_tree().paused = false
	get_tree().quit(1 if failed > 0 or total == 0 else 0)
