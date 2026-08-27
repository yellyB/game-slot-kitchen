extends Node

const SFX := {
	"trash": preload("res://assets/audio/sfx/trash.wav"),
	"card_pick": preload("res://assets/audio/sfx/card_pick.wav"),
	"card_place": preload("res://assets/audio/sfx/card_place.wav"),
	"cook_start": preload("res://assets/audio/sfx/cook_start.wav"),
	"serve": preload("res://assets/audio/sfx/serve.wav"),
	"coins": preload("res://assets/audio/sfx/coins.wav"),
	"score_up": preload("res://assets/audio/sfx/star_rise.wav"),
	"day_start": preload("res://assets/audio/sfx/day_start.mp3"),
	"click": preload("res://assets/audio/sfx/click.wav"),
	"pack_open": preload("res://assets/audio/sfx/pack_open.ogg"),
	"card_slide": preload("res://assets/audio/sfx/card_slide.ogg"),
	"footstep": preload("res://assets/audio/sfx/footstep.wav"),
	"footstep_back": preload("res://assets/audio/sfx/footstep_back.wav"),
	"switch": preload("res://assets/audio/sfx/switch.ogg"),
	"reject": preload("res://assets/audio/sfx/reject.ogg"),
	"cook_done": preload("res://assets/audio/sfx/cook_done.mp3"),
	"fail": preload("res://assets/audio/sfx/fail.wav"),
	"day_pass": preload("res://assets/audio/sfx/day_pass.mp3"),
	"customer_in": preload("res://assets/audio/sfx/customer_in.mp3"),
	"door_open": preload("res://assets/audio/sfx/door_open.mp3"),
	"door_close": preload("res://assets/audio/sfx/door_close.mp3"),
	"countdown": preload("res://assets/audio/sfx/countdown.wav"),
	"day_close": preload("res://assets/audio/sfx/day_close.mp3"),
	"customer_leave": preload("res://assets/audio/sfx/customer_leave.mp3"),
	"order_take": preload("res://assets/audio/sfx/order_take.wav"),
	"disabled": preload("res://assets/audio/sfx/disabled.wav"),
}

const POOL_SIZE := 8
const SFX_VOLUME_DB := 0.0
const SFX_GAIN_DB := {
	"fail": 2.3,
}

const BGM := preload("res://assets/audio/bgm/kitchen_table_notes.mp3")
const BGM_VOLUME_DB := -10.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bgm: AudioStreamPlayer

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = BGM
	_bgm.volume_db = BGM_VOLUME_DB
	_bgm.finished.connect(_bgm.play)
	add_child(_bgm)
	if SettingsPanel.settings.get("bgm", true):
		_bgm.play()


func set_bgm(on: bool) -> void:
	if on:
		if not _bgm.playing:
			_bgm.play()
	else:
		_bgm.stop()


func vibrate(ms := 30) -> void:
	if SettingsPanel.settings.get("vibrate", true):
		Input.vibrate_handheld(ms)


func attach_click(btn: BaseButton) -> void:
	if is_instance_valid(btn) and not btn.pressed.is_connected(_play_click):
		btn.pressed.connect(_play_click)


func _play_click() -> void:
	play("click")


func play(id: String, pitch := 1.0) -> void:
	if not SettingsPanel.settings.get("sfx", true):
		return
	var stream: AudioStream = SFX.get(id)
	if stream == null:
		push_warning("Audio.play: 없는 효과음 id '%s'" % id)
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = SFX_VOLUME_DB + SFX_GAIN_DB.get(id, 0.0)
	p.pitch_scale = pitch
	p.play()
