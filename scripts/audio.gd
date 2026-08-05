extends Node
## 효과음 재생소(autoload=Audio). 소비처는 Audio.play("id")만 호출.
## 새 효과음: SFX 딕셔너리에 한 줄 추가 → 어디서든 Audio.play("...")로 재생.
## 겹쳐 재생(휴지통 연타 등) 대비 플레이어 풀 사용.

const SFX := {
	"trash": preload("res://assets/audio/sfx/trash.wav"),  # 휴지통 버리기(종이 구기기)
}

const POOL_SIZE := 8          # 동시 재생 가능한 효과음 수
const SFX_VOLUME_DB := 0.0    # 효과음 볼륨(dB) — 튜닝 시 조정

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_players.append(p)


## 효과음 재생. id는 SFX 키. 풀에서 라운드로빈으로 빈 플레이어 사용.
func play(id: String) -> void:
	var stream: AudioStream = SFX.get(id)
	if stream == null:
		push_warning("Audio.play: 없는 효과음 id '%s'" % id)
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.play()
