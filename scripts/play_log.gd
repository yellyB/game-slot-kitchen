class_name PlayLog
extends RefCounted
## 실플레이 로그 — 하루 마감마다 지표를 user://playlog.jsonl 에 JSON 한 줄씩 추가(분석용).
## day==1 줄이 곧 새 판 시작. 파일 절대경로는 abs_path()(에디터 실행 시 콘솔에 출력).

const PATH := "user://playlog.jsonl"

static var _ver_cache := ""

## 현재 코드 버전 — 짧은 커밋 해시(+미커밋 변경 있으면 -dirty). 세션당 1회 계산·캐시.
## 에디터/디버그(프로젝트 폴더에서 git 사용 가능)에서만 유효. 아니면 "unknown".
static func version() -> String:
	if _ver_cache != "":
		return _ver_cache
	var out: Array = []
	var dir := ProjectSettings.globalize_path("res://")
	var rc := OS.execute("git", ["-C", dir, "describe", "--always", "--dirty", "--abbrev=7"], out)
	var v := String(out[0]).strip_edges() if out.size() > 0 else ""
	_ver_cache = v if (rc == 0 and v != "") else "unknown"
	return _ver_cache

## 항목 1건을 파일 끝에 JSON 한 줄로 추가. 코드 버전(commit)을 자동 첨부.
static func append(entry: Dictionary) -> void:
	if not entry.has("commit"):
		entry["commit"] = version()
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
