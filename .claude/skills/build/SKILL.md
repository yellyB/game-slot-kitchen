---
name: build
description: Build a signed release Android App Bundle (.aab) for Slot Kitchen. Auto-increments versionCode. If the user did not give a versionName in the invocation, ask for it before building.
---

# /build — Slot Kitchen 릴리스 AAB 빌드

이 스킬은 서명된 `.aab`를 뽑는다. versionCode는 자동 +1, versionName은 인자로 받거나 없으면 물어본다.

> **브랜치 규칙:** 일상 개발은 `develop`에서, `main`은 릴리즈 전용이다. 이 스킬(=릴리즈 배포 순간)에서만 `develop`→`main` 머지 + `vX.Y.Z` 태그를 남긴다. 빌드는 `develop`에서 시작하는 것이 기본이다.

## 절차

### 0. 브랜치 확인
`develop`에 있는지 확인한다(`git rev-parse --abbrev-ref HEAD`). 아니면 `git checkout develop`. 버전 커밋(3)은 `develop`에 쌓고, 그 후 `main`에 머지(4)한다.

### 1. versionName 결정
- 사용자의 이번 호출 텍스트에 버전이 있으면(예: `/build 1.1.0`, `빌드 버전 1.2.0`) 그 값을 versionName으로 쓴다.
- **없으면 반드시 `AskUserQuestion`으로 물어본다.** 추천 기본값 = `export_presets.cfg`의 현재 `version/name` 패치 +1 (예: 현재 `1.0.0` → 추천 `1.0.1`). 절대 임의로 정하고 진행하지 말 것.

### 2. 빌드 실행
아래 스크립트를 Bash로 실행한다. `VERSION`만 1단계에서 정한 값으로 바꾼다.

```bash
set -e
cd /Users/oto/Workspace/game-slot-kitchen
VERSION="__여기에_versionName__"   # 예: 1.0.1

# --- 키스토어/도구 환경 ---
export ANDROID_HOME=/Users/oto/Library/Android/sdk
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
# 키스토어 클론 없으면 프라이빗 레포에서 가져옴
[ -d /Users/oto/keystores_work ] || gh repo clone yellyB/keystores /Users/oto/keystores_work
KS=/Users/oto/keystores_work/slot-kitchen/slot_kitchen_release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KS"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload
# 비번은 프라이빗 keystores 레포의 credentials.md에서 읽음(하드코딩 X)
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$(grep -i 'Key password' /Users/oto/keystores_work/slot-kitchen/credentials.md | grep -oE '`[^`]+`' | tr -d '`')

# --- 빌드 템플릿 없으면 설치(1회) ---
if [ ! -f android/.build_version ]; then
  mkdir -p android/build
  unzip -o -q "$HOME/Library/Application Support/Godot/export_templates/4.6.2.stable/android_source.zip" -d android/build
  printf '4.6.2.stable' > android/.build_version
  touch android/.gdignore
fi

# --- versionCode +1, versionName 설정 ---
python3 - "$VERSION" <<'PY'
import sys, re
ver = sys.argv[1]
p = "export_presets.cfg"; s = open(p, encoding="utf-8").read()
code = int(re.search(r'version/code=(\d+)', s).group(1)) + 1
s = re.sub(r'version/code=\d+', f'version/code={code}', s)
s = re.sub(r'version/name="[^"]*"', f'version/name="{ver}"', s)
open(p, "w", encoding="utf-8").write(s)
print(f"versionCode={code}  versionName={ver}")
PY

# --- gradle+AAB 플래그 임시 ON → 빌드 → 원복 ---
sed -i '' 's/use_gradle_build=false/use_gradle_build=true/; s/export_format=0/export_format=1/' export_presets.cfg
OUT="$HOME/SlotKitchen-$VERSION.aab"
rm -f "$OUT"
godot4 --headless --export-release "Android" "$OUT"
sed -i '' 's/use_gradle_build=true/use_gradle_build=false/; s/export_format=1/export_format=0/' export_presets.cfg

# --- 검증 ---
"$JAVA_HOME/bin/jarsigner" -verify "$OUT" | grep -i verified || echo "서명 검증 실패!"
ls -la "$OUT"
```

### 3. 버전 커밋 (develop)
versionCode를 다음 빌드까지 유지해야 하므로, `export_presets.cfg`의 **`version/code`·`version/name` 두 줄만** `develop`에 커밋한다(gradle/format 플래그는 이미 원복됨 — 스테이지 금지). 다른 에이전트 hunk가 섞이지 않게 `git add export_presets.cfg` 전 `git diff`로 그 두 줄만인지 확인.

```
git add export_presets.cfg
git commit -m "release: v<VERSION> (versionCode <N>)"
```

### 4. main 머지 + 릴리즈 태그
릴리즈 배포 순간이므로 `develop`을 `main`에 머지하고 `v<VERSION>` 태그를 남긴다. 머지는 develop의 커밋을 그대로 올리는 것이므로 hunk 선별 규칙과 무관(브랜치 통째 머지).

```
git checkout main
git merge --no-ff develop -m "release: v<VERSION> merge develop→main"
git tag -a v<VERSION> -m "release v<VERSION> (versionCode <N>)"
git checkout develop
```

푸시는 사용자가 원할 때만: `git push origin main develop --tags`.

### 5. 릴리즈 노트 자동 작성
지난 릴리즈 태그와 이번 커밋을 비교해 **묻지 말고 항상** 릴리즈 노트를 함께 출력한다.

- 직전 태그를 찾는다: `git describe --tags --abbrev=0 v<VERSION>^` (또는 `git tag --sort=-creatordate`에서 v<VERSION> 바로 다음). 커밋 목록: `git log <이전태그>..v<VERSION> --oneline`.
- 그 커밋들을 **사용자 관점**으로 묶어 간략히 요약한다(내부 리팩터·주석·시뮬 전용 변경은 제외, 기능/연출/밸런스/UI만). 각 항목 한 줄, 3~5개 이내.
- **Play 콘솔 5개 언어 블록** 형식으로 출력한다(ko-KR 원문 → 나머지 번역). 언어·형식은 아래 고정:

```
<en-IN>
...
</en-IN>
<es-ES>
...
</es-ES>
<ja-JP>
...
</ja-JP>
<ko-KR>
...
</ko-KR>
<zh-CN>
...
</zh-CN>
```

### 6. 보고
`~/SlotKitchen-<VERSION>.aab` 경로 · versionName · versionCode · 서명 검증 결과 · 남긴 태그(`v<VERSION>`) · 5번 릴리즈 노트를 알려준다. Play 콘솔 업로드와 push는 사용자가 직접(원하면 push 대행).

## 참고(이 머신 기준)
- 키스토어: `~/keystores_work/slot-kitchen/slot_kitchen_release.keystore` (alias `upload`, 비번은 credentials.md)
- 패키지: `com.yelly.slotkitchen` / JDK 17 / Android SDK: `~/Library/Android/sdk`
- `android/`는 gitignore(빌드 템플릿) — 커밋 안 함. 리포 config는 항상 gradle=off/APK 상태로 원복 유지.
