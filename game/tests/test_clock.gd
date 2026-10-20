extends TestCase
## Ciclo diário: avanço, virada do dia, sinais e pausa.


func test_dia_tem_24_minutos_reais() -> void:
	assert_eq(GameClock.minutes_per_second * 60.0 * 24.0, 1440.0, "1 dia de jogo deve durar 24 minutos reais")


func test_avanco_e_virada_do_dia() -> void:
	GameClock.reset(1, 1430.0)
	var days := []
	var cb := func(d): days.append(d)
	GameClock.day_started.connect(cb)
	GameClock.advance(15.0)
	GameClock.day_started.disconnect(cb)
	assert_eq(GameClock.day, 2, "o dia deve virar")
	assert_eq(int(GameClock.minute), 5, "minuto após a virada")
	assert_eq(days, [2], "sinal day_started emitido uma vez")


func test_sinal_de_hora() -> void:
	GameClock.reset(3, 535.0)
	var hours := []
	var cb := func(_d, h): hours.append(h)
	GameClock.hour_changed.connect(cb)
	GameClock.advance(130.0)
	GameClock.hour_changed.disconnect(cb)
	assert_eq(hours, [9, 10, 11], "horas cruzadas")


func test_pausa_congela_o_relogio() -> void:
	GameClock.reset(1, 600.0)
	GameClock.running = true
	tree().paused = true
	await wait_frames(30)
	var paused_minute := GameClock.minute
	tree().paused = false
	await wait_frames(150)
	GameClock.running = false
	assert_eq(paused_minute, 600.0, "o relógio não pode andar durante a pausa")
	assert_gt(GameClock.minute, 600.0, "o relógio volta a andar ao despausar")


func test_periodos() -> void:
	assert_eq(GameClock.period_for(8 * 60.0), "manhã")
	assert_eq(GameClock.period_for(14 * 60.0), "tarde")
	assert_eq(GameClock.period_for(19 * 60.0), "entardecer")
	assert_eq(GameClock.period_for(23 * 60.0), "noite")
