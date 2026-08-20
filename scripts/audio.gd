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
	"pack_open": preload("res://assets/audio/sfx/pack_open.ogg"),   # 카드팩 개봉 순간
	"card_slide": preload("res://assets/audio/sfx/card_slide.ogg"), # 팩 카드 등장 완료
	"footstep": preload("res://assets/audio/sfx/footstep.wav"),    # 창고 입장(발소리 0→1)
	"footstep_back": preload("res://assets/audio/sfx/footstep_back.wav"),  # 창고 퇴장(발소리 1→0, 역순)
	"switch": preload("res://assets/audio/sfx/switch.ogg"),        # 설정 토글 스위치(딸깍)
	"reject": preload("res://assets/audio/sfx/reject.ogg"),        # 다른 메뉴 서빙(반려·땡)
	"cook_done": preload("res://assets/audio/sfx/cook_done.mp3"),  # 조리 완료(완성품 나옴)
	"fail": preload("res://assets/audio/sfx/fail.wav"),          # 런 실패/폐업(재즈 스팅)
	"day_pass": preload("res://assets/audio/sfx/day_pass.mp3"),   # 하루 통과(정산 성공)
	"customer_in": preload("res://assets/audio/sfx/customer_in.mp3"),  # 손님 방문(큐 등장)
	"door_open": preload("res://assets/audio/sfx/door_open.mp3"),   # 창고 들어갈 때(문 열림)
	"door_close": preload("res://assets/audio/sfx/door_close.mp3"), # 창고 나올 때(문 닫힘)
	"countdown": preload("res://assets/audio/sfx/countdown.wav"),   # 막판 카운트다운 틱(나무 똑딱)
	"day_close": preload("res://assets/audio/sfx/day_close.mp3"),   # 영업 종료(마감 종·딩동)
	"customer_leave": preload("res://assets/audio/sfx/customer_leave.mp3"),  # 손님 성나서 떠남(왈왈)
	"order_take": preload("res://assets/audio/sfx/order_take.wav"),  # 주문 받음(영수증 찢기, 앞무음 제거)
	"disabled": preload("res://assets/audio/sfx/disabled.wav"),     # 더 못 받음/불가(순한 거절음)
}

const POOL_SIZE := 8          # 동시 재생 가능한 효과음 수
const SFX_VOLUME_DB := 0.0    # 효과음 볼륨(dB) — 튜닝 시 조정
const SFX_GAIN_DB := {        # 특정 효과음만 상대 볼륨 보정(dB). 없으면 0.
	"fail": 2.3,          # 런 실패/폐업음 +30%(≈+2.3dB)
}

## 배경음(홈·플레이 화면 통틀어 계속 재생, 곡 끝나면 다시). Audio는 오토로드라 화면 전환에도 안 끊김.
const BGM := preload("res://assets/audio/bgm/kitchen_table_notes.mp3")
const BGM_VOLUME_DB := -10.0  # 배경음 볼륨(dB) — 효과음보다 낮게

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _bgm: AudioStreamPlayer

func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		add_child(p)
		_players.append(p)
	# 배경음 — 한 곡 끝나면 다시 재생(루프). 설정에서 켜져 있을 때만.
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = BGM
	_bgm.volume_db = BGM_VOLUME_DB
	_bgm.finished.connect(_bgm.play)   # 끝나면 재생
	add_child(_bgm)
	if SettingsPanel.settings.get("bgm", true):
		_bgm.play()


## 배경음 켜기/끄기 — 설정 토글에서 호출.
func set_bgm(on: bool) -> void:
	if on:
		if not _bgm.playing:
			_bgm.play()
	else:
		_bgm.stop()


## 진동(모바일) — 설정에서 켜져 있을 때만. 데스크톱은 무동작.
func vibrate(ms := 30) -> void:
	if SettingsPanel.settings.get("vibrate", true):
		Input.vibrate_handheld(ms)


## UI 버튼에 클릭음 부착 — 클릭음을 넣을 버튼에만 명시적으로 호출(화이트리스트).
func attach_click(btn: BaseButton) -> void:
	if is_instance_valid(btn) and not btn.pressed.is_connected(_play_click):
		btn.pressed.connect(_play_click)


func _play_click() -> void:
	play("click")


## 효과음 재생. id는 SFX 키. 풀에서 라운드로빈으로 빈 플레이어 사용. (효과음 꺼져 있으면 무음)
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
	p.volume_db = SFX_VOLUME_DB + SFX_GAIN_DB.get(id, 0.0)   # 매번 재설정(풀 재사용 시 이전 보정 초기화)
	p.pitch_scale = pitch   # 카운트다운 등 긴박감 고조용(기본 1.0)
	p.play()
