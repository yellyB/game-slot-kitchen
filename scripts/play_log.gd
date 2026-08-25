class_name PlayLog
extends RefCounted
## 실플레이 로그 — 하루 마감마다 지표를 user://playlog.jsonl 에 JSON 한 줄씩 추가(분석용).
## day==1 줄이 곧 새 판 시작. 파일 절대경로는 abs_path()(에디터 실행 시 콘솔에 출력).

const PATH := "user://playlog.jsonl"

## 항목 1건을 파일 끝에 JSON 한 줄로 추가.
static func append(entry: Dictionary) -> void:
	var f: FileAccess
	if FileAccess.file_exists(PATH):
		f = FileAccess.open(PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(JSON.stringify(entry))
	f.close()

## OS 파일시스템 절대경로(에디터에서 이 경로를 열어 확인/공유).
static func abs_path() -> String:
	return ProjectSettings.globalize_path(PATH)

## 로그 전체 텍스트(JSONL). 없으면 빈 문자열.
static func read_text() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s

## 로그 비우기(새 분석 세션 시작 전).
static func clear() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.close()
