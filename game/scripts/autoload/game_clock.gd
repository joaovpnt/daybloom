extends Node
## Relógio do mundo. Por padrão, 1 dia de jogo = 24 minutos reais
## (1 minuto de jogo por segundo real). Pausa junto com a árvore de cenas.

signal minute_ticked(day: int, minute: float, elapsed_minutes: int)
signal hour_changed(day: int, hour: int)
signal day_started(day: int)

const MINUTES_PER_DAY := 1440.0

var minutes_per_second: float = 1.0
var day: int = 1
var minute: float = 480.0
var running: bool = false
var _accum: float = 0.0


func _process(delta: float) -> void:
	if running:
		advance(delta * minutes_per_second)


func reset(new_day: int = 1, new_minute: float = 480.0) -> void:
	day = max(new_day, 1)
	minute = clampf(new_minute, 0.0, MINUTES_PER_DAY - 0.001)
	_accum = 0.0


func advance(game_minutes: float) -> void:
	if game_minutes <= 0.0:
		return
	_accum += game_minutes
	var whole := int(floor(_accum))
	if whole <= 0:
		return
	_accum -= whole
	var remaining := whole
	while remaining > 0:
		var to_hour := int(60.0 - fmod(minute, 60.0))
		to_hour = max(to_hour, 1)
		var step: int = min(remaining, to_hour)
		var prev_hour := int(minute / 60.0)
		minute += step
		remaining -= step
		if minute >= MINUTES_PER_DAY:
			minute -= MINUTES_PER_DAY
			day += 1
			minute_ticked.emit(day, minute, step)
			hour_changed.emit(day, 0)
			day_started.emit(day)
			continue
		minute_ticked.emit(day, minute, step)
		var new_hour := int(minute / 60.0)
		if new_hour != prev_hour:
			hour_changed.emit(day, new_hour)


func hour() -> int:
	return int(minute / 60.0)


func abs_minutes() -> float:
	return (day - 1) * MINUTES_PER_DAY + minute


func time_dict() -> Dictionary:
	return {"day": day, "minute": snappedf(minute, 0.01)}


static func format_hm(m: float) -> String:
	var total := int(m)
	return "%02d:%02d" % [total / 60, total % 60]


static func period_for(m: float) -> String:
	var h := m / 60.0
	if h >= 5.0 and h < 12.0:
		return "manhã"
	if h >= 12.0 and h < 18.0:
		return "tarde"
	if h >= 18.0 and h < 21.0:
		return "entardecer"
	return "noite"


func period() -> String:
	return period_for(minute)
