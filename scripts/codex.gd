class_name Codex
extends RefCounted
## 도감 발견 기록 — 버프를 "획득"할 때 discover()로 표시. user://codex.save에 영구 저장.
## 정적(static) 저장소: 앱 실행 동안 유지 + 최초 접근 시 디스크에서 로드.

const PATH := "user://codex.save"

static var _discovered := {}   # id → true
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Array:
		for id in data:
			_discovered[id] = true


## 버프 획득 시 호출 — 처음 발견이면 기록 + 저장.
static func discover(id: String) -> void:
	_ensure_loaded()
	if _discovered.has(id):
		return
	_discovered[id] = true
	_save()


static func is_discovered(id: String) -> bool:
	_ensure_loaded()
	return _discovered.has(id)


static func discovered_count() -> int:
	_ensure_loaded()
	return _discovered.size()


static func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_discovered.keys()))


## 도감 초기화(디버그) — 발견 기록 전부 삭제 + 저장 파일 제거.
static func reset() -> void:
	_discovered.clear()
	_loaded = true
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
