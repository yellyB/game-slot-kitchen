import os
import platform
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRESETS = ROOT / "export_presets.cfg"
PROJECT = ROOT / "project.godot"
LOCAL_ENV = ROOT / ".claude" / "release.env"
OUT_DIR = ROOT / "build"
KS_VARS = ("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", "GODOT_ANDROID_KEYSTORE_RELEASE_USER", "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD")


def fail(msg):
    print(f"[build] {msg}")
    sys.exit(1)


def load_local_env():
    if not LOCAL_ENV.exists():
        return
    for line in LOCAL_ENV.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.removeprefix("export ").split("=", 1)
        v = os.path.expanduser(os.path.expandvars(v.strip().strip('"').strip("'")))
        os.environ.setdefault(k.strip(), v)


def find_godot():
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    for name in ("godot4", "godot", "Godot"):
        p = shutil.which(name)
        if p:
            return p
    fail("Godot 실행 파일을 찾지 못했다. GODOT 환경변수로 지정한다.")


def default_dirs():
    home = Path.home()
    system = platform.system()
    if system == "Darwin":
        return home / "Library/Android/sdk", home / "Library/Application Support/Godot/export_templates"
    if system == "Windows":
        local = Path(os.environ.get("LOCALAPPDATA", home / "AppData/Local"))
        roaming = Path(os.environ.get("APPDATA", home / "AppData/Roaming"))
        return local / "Android/Sdk", roaming / "Godot/export_templates"
    return home / "Android/Sdk", home / ".local/share/godot/export_templates"


def find_java_home():
    if os.environ.get("JAVA_HOME"):
        return os.environ["JAVA_HOME"]
    if platform.system() == "Darwin":
        r = subprocess.run(["/usr/libexec/java_home", "-v", "17"], capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout.strip()
    java = shutil.which("java")
    if java:
        return str(Path(java).resolve().parent.parent)
    fail("JDK 17을 찾지 못했다. JAVA_HOME 환경변수로 지정한다.")


def prepare_env():
    load_local_env()
    sdk, templates = default_dirs()
    os.environ.setdefault("ANDROID_HOME", str(sdk))
    os.environ["JAVA_HOME"] = find_java_home()
    os.environ.setdefault("GODOT_TEMPLATES", str(templates))
    exe = "java.exe" if platform.system() == "Windows" else "java"
    r = subprocess.run([str(Path(os.environ["JAVA_HOME"]) / "bin" / exe), "-version"], capture_output=True, text=True)
    if not re.search(r'version "17[."]', r.stderr + r.stdout):
        fail(f"JDK 17이 아니다: {os.environ['JAVA_HOME']}. JAVA_HOME을 JDK 17로 지정한다.")
    if not Path(os.environ["ANDROID_HOME"]).is_dir():
        fail(f"Android SDK가 없다: {os.environ['ANDROID_HOME']}. ANDROID_HOME 환경변수로 지정한다.")


def godot_config_dir():
    home = Path.home()
    system = platform.system()
    if system == "Darwin":
        return home / "Library/Application Support/Godot"
    if system == "Windows":
        return Path(os.environ.get("APPDATA", home / "AppData/Roaming")) / "Godot"
    return Path(os.environ.get("XDG_CONFIG_HOME", home / ".config")) / "godot"


def ensure_editor_settings(godot):
    major_minor = ".".join(godot_version(godot).split(".")[:2])
    f = godot_config_dir() / f"editor_settings-{major_minor}.tres"
    if not f.exists():
        return
    wanted = {
        "export/android/android_sdk_path": os.environ["ANDROID_HOME"],
        "export/android/java_sdk_path": os.environ["JAVA_HOME"],
    }
    text = f.read_text(encoding="utf-8")
    changed = False
    for key, path in wanted.items():
        value = '"' + Path(path).as_posix() + '"'
        m = re.search(rf'^{re.escape(key)} = "(.*)"$', text, re.M)
        if m and m.group(1) and Path(m.group(1)).is_dir():
            continue
        if m:
            text = text[:m.start()] + f"{key} = {value}" + text[m.end():]
        else:
            text = re.sub(r"^\[resource\]$", f"[resource]\n{key} = {value}", text, count=1, flags=re.M)
        changed = True
    if changed:
        f.write_text(text, encoding="utf-8")
        print(f"[build] Godot 에디터 설정에 Android SDK와 JDK 경로를 채웠다: {f}")


def godot_version(godot):
    out = subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.strip()
    m = re.match(r"\d+\.\d+(?:\.\d+)?\.[a-z0-9]+", out)
    if not m:
        fail(f"Godot 버전을 읽지 못했다: {out}")
    return m.group(0)


def ensure_android_template(godot):
    marker = ROOT / "android/.build_version"
    if marker.exists():
        return
    ver = godot_version(godot)
    src = Path(os.environ["GODOT_TEMPLATES"]) / ver / "android_source.zip"
    if not src.exists():
        fail(f"Android 빌드 템플릿이 없다: {src}. Godot 에디터에서 내보내기 템플릿을 설치한다.")
    (ROOT / "android/build").mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(src) as z:
        z.extractall(ROOT / "android/build")
    marker.write_text(ver, encoding="utf-8")
    (ROOT / "android/.gdignore").touch()


def write_build_commit():
    h = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()
    (ROOT / "build_commit.txt").write_text(h + "\n", encoding="utf-8")
    return h


def set_preset(text, key, value):
    return re.sub(rf"^{re.escape(key)}=.*$", f"{key}={value}", text, flags=re.M)


def bump_version(name):
    s = PRESETS.read_text(encoding="utf-8")
    code = int(re.search(r"^version/code=(\d+)", s, re.M).group(1)) + 1
    s = set_preset(s, "version/code", code)
    s = set_preset(s, "version/name", f'"{name}"')
    PRESETS.write_text(s, encoding="utf-8")
    t = PROJECT.read_text(encoding="utf-8")
    t = re.sub(r'^config/version="[^"]*"', f'config/version="{name}"', t, flags=re.M)
    PROJECT.write_text(t, encoding="utf-8")
    return code


def export(godot, mode, out, aab):
    original = PRESETS.read_text(encoding="utf-8")
    s = set_preset(original, "gradle_build/use_gradle_build", "true")
    if aab:
        s = set_preset(s, "gradle_build/export_format", "1")
    PRESETS.write_text(s, encoding="utf-8")
    try:
        out.unlink(missing_ok=True)
        subprocess.run([godot, "--headless", "--path", str(ROOT), f"--export-{mode}", "Android", str(out)], check=True)
    finally:
        cur = PRESETS.read_text(encoding="utf-8")
        cur = set_preset(cur, "gradle_build/use_gradle_build", "false")
        cur = set_preset(cur, "gradle_build/export_format", "0")
        PRESETS.write_text(cur, encoding="utf-8")
    if not out.exists():
        fail("내보내기 결과물이 없다.")


def verify_signature(out):
    exe = "jarsigner.exe" if platform.system() == "Windows" else "jarsigner"
    jarsigner = Path(os.environ["JAVA_HOME"]) / "bin" / exe
    r = subprocess.run([str(jarsigner), "-verify", str(out)], capture_output=True, text=True)
    return "verified" in r.stdout.lower()


def run_debug():
    godot = find_godot()
    prepare_env()
    ensure_editor_settings(godot)
    env = dict(os.environ, SIM_N="1")
    subprocess.run([godot, "--headless", "--path", str(ROOT), "res://scenes/Main.tscn", "--", "--sim"], env=env, check=True)
    ensure_android_template(godot)
    h = write_build_commit()
    OUT_DIR.mkdir(exist_ok=True)
    out = OUT_DIR / "SlotKitchen-test.apk"
    export(godot, "debug", out, aab=False)
    print(f"[build] APK {out}  commit {h}")


def run_release(version):
    godot = find_godot()
    prepare_env()
    ensure_editor_settings(godot)
    missing = [k for k in KS_VARS if not os.environ.get(k)]
    if missing:
        fail("서명 정보가 없다: " + ", ".join(missing))
    if not Path(os.environ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"]).is_file():
        fail("키스토어 파일이 없다: " + os.environ["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"])
    ensure_android_template(godot)
    code = bump_version(version)
    h = write_build_commit()
    OUT_DIR.mkdir(exist_ok=True)
    out = OUT_DIR / f"SlotKitchen-{version}.aab"
    export(godot, "release", out, aab=True)
    ok = verify_signature(out)
    print(f"[build] AAB {out}  versionName {version}  versionCode {code}  commit {h}  서명 {'확인' if ok else '실패'}")
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "debug":
        run_debug()
    elif len(sys.argv) >= 3 and sys.argv[1] == "release":
        run_release(sys.argv[2])
    else:
        fail("사용법: android_build.py debug | release <versionName>")
