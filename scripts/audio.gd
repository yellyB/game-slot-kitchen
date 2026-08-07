extends Node

const SFX := {
	"trash": preload("res://assets/audio/sfx/trash.wav"),
	"card_pick": preload("res://assets/audio/sfx/card_pick.wav"),
	"card_place": preload("res://assets/audio/sfx/card_place.wav"),
}

const POOL_SIZE := 8
const SFX_VOLUME_DB := 0.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_players.append(p)


func play(id: String) -> void:
	var stream: AudioStream = SFX.get(id)
	if stream == null:
		push_warning("Audio.play: 없는 효과음 id '%s'" % id)
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.play()
