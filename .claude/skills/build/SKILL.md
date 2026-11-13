---
name: build
description: Build a signed release Android App Bundle (.aab) for Slot Kitchen. Auto-increments versionCode. If the user did not give a versionName in the invocation, ask for it before building.
---

# 릴리스 빌드

## 1. 브랜치

`develop`에서 시작한다. 다른 브랜치면 `git checkout develop`.

## 2. versionName

호출에 버전이 있으면 그 값을 쓴다. 없으면 `AskUserQuestion`으로 묻고, 추천값은 `export_presets.cfg`의 현재 `version/name`에서 패치를 1 올린 값이다. 임의로 정하지 않는다.

## 3. 빌드

키스토어 비밀번호를 사용자에게 묻는다. 받은 값은 이 명령의 환경변수로만 넘기고 어디에도 저장하지 않는다.

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='<비밀번호>' python3 tools/android_build.py release <VERSION>
```

- `python3 --version`이 실패하면 `python`, 그것도 실패하면 `py`로 실행한다. Windows의 `python3`는 스토어 안내로 연결될 수 있다.
- versionCode를 1 올리고 `project.godot`의 버전도 맞춘 뒤 서명된 AAB를 `build/`에 만들고 서명을 검증한다.
- 키스토어 경로와 alias는 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER` 환경변수나 저장소에 올리지 않는 `.claude/release.env`에서 읽는다. 없으면 사용자에게 묻는다.
- 도구 위치는 환경변수가 있으면 그 값을, 없으면 OS별 기본 위치를 쓴다. 스크립트가 못 찾으면 멈추고 어떤 변수를 지정할지 알려준다.

| 변수 | 대상 |
|---|---|
| `GODOT` | Godot 실행 파일. Windows는 console 실행 파일을 지정한다 |
| `ANDROID_HOME` | Android SDK |
| `JAVA_HOME` | JDK 17 |
| `GODOT_TEMPLATES` | Godot 내보내기 템플릿 폴더 |

## 4. 버전 커밋

`export_presets.cfg`의 `version/code`, `version/name` 두 줄과 `project.godot`의 `config/version` 한 줄만 커밋한다.

```
git add export_presets.cfg project.godot
git commit -m "release: v<VERSION>"
```

## 5. 머지와 태그

```
git checkout main
git merge --no-ff develop -m "release: v<VERSION>"
git tag -a v<VERSION> -m "release v<VERSION>"
git checkout develop
```

푸시는 사용자가 원할 때만 `git push origin main develop --tags`로 한다.

## 6. 릴리스 노트

빌드가 끝나면 항상 작성한다.

- `git log $(git describe --tags --abbrev=0 v<VERSION>^)..v<VERSION> --oneline`으로 이번 커밋을 모은다.
- 기능, 연출, 밸런스, UI 변경만 사용자 관점으로 3~5줄 요약한다. 리팩터, 주석, 시뮬 전용 변경은 뺀다.
- ko-KR로 쓰고 나머지는 번역해 아래 형식으로 출력한다.

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

## 7. 보고

`build/` 안의 AAB 경로, versionName, versionCode, 서명 검증 결과, 태그, 릴리스 노트를 알린다. Play 콘솔 업로드는 사용자가 한다.
