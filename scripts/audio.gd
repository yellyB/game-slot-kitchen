extends Node
## 효과음 재생소(autoload=Audio). 소비처는 Audio.play("id")만 호출.
## 새 효과음: SFX 딕셔너리에 한 줄 추가 → 어디서든 Audio.play("...")로 재생.
## 겹쳐 재생(휴지통 연타 등) 대비 플레이어 풀 사용.

const SFX := {
	"trash": preload("res://assets/audio/sfx/trash.wav"),  # 휴지통 버리기(종이 구기기)
	"card_pick": preload("res://assets/audio/sfx/card_pick.wav"),   # 카드 집기(종이 플릭)
	"card_place": preload("res://assets/audio/sfx/card_place.wav"),  # 카드 놓기(탁)
	"cook_start": preload("res://assets/audio/sfx/cook_start.wav"),  # 조리 시작(팝)
	"serve": preload("res://assets/audio/sfx/serve.wav"),           # 서빙 완료(리워드)
	"coins": preload("res://assets/audio/sfx/coins.wav"),           # 소지금 변동(동전)
	"day_start": preload("res://assets/audio/sfx/day_start.mp3"),   # 하루 시작(어서오세요)
	"click": preload("res://assets/audio/sfx/click.wav"),           # 버튼 클릭(종이 크런치)
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
	# 모든 버튼 클릭음: 씬에 추가되는 BaseButton마다 pressed → click 자동 연결.
	# (버튼이 곳곳에서 생성돼 중앙 팩토리가 없으므로 트리 훅으로 일괄 처리)
	get_tree().node_added.connect(_hook_button)


## 새로 트리에 붙는 노드가 버튼이면 클릭음을 붙인다.
func _hook_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_play_click):
		node.pressed.connect(_play_click)


func _play_click() -> void:
	play("click")


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
