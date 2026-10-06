## 타이틀 하단 빌드 표기용. 릴리스=v<버전>, 디버그/테스트빌드=test: <커밋해시>.
## 해시는 기기(APK)에 git이 없어 런타임 조회 불가 → 빌드 때 build_commit.txt로 구워 넣는다.
## (에디터 실행 땐 파일이 없으니 git으로 직접 조회하는 폴백.)

const COMMIT_FILE := "res://build_commit.txt"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


static func commit() -> String:
	if FileAccess.file_exists(COMMIT_FILE):
		return FileAccess.get_file_as_string(COMMIT_FILE).strip_edges()
	var out: Array = []
	var proj := ProjectSettings.globalize_path("res://")
	if OS.execute("git", ["-C", proj, "rev-parse", "--short", "HEAD"], out) == 0 and not out.is_empty():
		return str(out[0]).strip_edges()
	return "?"


## 타이틀에 찍을 한 줄.
static func label() -> String:
	return "test: " + commit() if OS.is_debug_build() else "v" + version()
