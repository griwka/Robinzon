extends Node
## Звук (autoload "Audio"): музыка дня/ночи с плавной сменой, прибой, птицы, сверчки, эффекты.
## Громкость — через шины Music / SFX / Ambience (настраивается в меню).

const DIR := "res://assets/audio/"
const POOL := 14

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var music_day: AudioStreamPlayer
var music_night: AudioStreamPlayer
var ocean: AudioStreamPlayer
var crickets: AudioStreamPlayer
var _bird_t := 3.0
var _last_play: Dictionary = {}
var _night_mix := 0.0
var listener: Node3D   # игрок — для затухания звуков с расстоянием
var island: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	music_day = _loop_player("music_day", "Music")
	music_night = _loop_player("music_night", "Music")
	ocean = _loop_player("amb_ocean", "Ambience")
	crickets = _loop_player("amb_night", "Ambience")
	# щелчок у всех кнопок интерфейса
	get_tree().node_added.connect(func(n):
		if n is BaseButton:
			n.pressed.connect(func(): play("click", -4.0, 0.05)))
	apply_volumes()


func _stream(name_: String) -> AudioStream:
	if _streams.has(name_):
		return _streams[name_]
	var path := DIR + name_ + (".ogg" if name_.begins_with("music") or name_.begins_with("amb") else ".wav")
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name_] = s
	return s


func _loop_player(name_: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	var s := _stream(name_)
	if s is AudioStreamOggVorbis:
		s.loop = true
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	if s:
		p.play()
	return p


func apply_volumes() -> void:
	var st: Dictionary = Game.settings
	for pair in [["Music", "music"], ["SFX", "sfx"], ["Ambience", "ambience"]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: float = st.get(pair[1], 0.7)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


## Проиграть эффект. pos — точка в мире (звук тише, если далеко от игрока).
func play(name_: String, volume_db := 0.0, pitch_var := 0.08, pos = null) -> void:
	var s := _stream("sfx_" + name_)
	if s == null:
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name_, 0)) < 45:
		return  # не дублируем один и тот же звук в одном кадре
	_last_play[name_] = now
	var vol := volume_db
	if pos != null and listener and is_instance_valid(listener):
		var d: float = listener.global_position.distance_to(pos)
		if d > 30.0:
			return
		vol -= d * 0.9
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func _process(delta: float) -> void:
	var night := 0.0 if Game.is_day() else 1.0
	_night_mix = move_toward(_night_mix, night, delta / 6.0)  # плавная смена за ~6 секунд
	music_day.volume_db = linear_to_db(maxf(1.0 - _night_mix, 0.0001)) - 6.0
	music_night.volume_db = linear_to_db(maxf(_night_mix, 0.0001)) - 6.0
	crickets.volume_db = linear_to_db(maxf(_night_mix, 0.0001)) - 4.0
	# прибой громче у берега
	var shore := 0.6
	if listener and is_instance_valid(listener) and island:
		var h: float = island.height_at(listener.global_position.x, listener.global_position.z)
		shore = clampf(1.0 - (h - 0.5) / 9.0, 0.25, 1.0)
	ocean.volume_db = linear_to_db(shore) - 4.0
	# птицы днём
	if not get_tree().paused and _night_mix < 0.5:
		_bird_t -= delta
		if _bird_t <= 0.0:
			_bird_t = randf_range(4.0, 11.0)
			play("bird%d" % (randi() % 4), randf_range(-16.0, -8.0), 0.12)


func _exit_tree() -> void:
	# аккуратно останавливаем все звуки при выходе из игры
	for p in get_children():
		if p is AudioStreamPlayer:
			p.stop()
			p.stream = null
	_streams.clear()
