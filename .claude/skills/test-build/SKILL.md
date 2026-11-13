---
name: test-build
description: Build a debug APK of Slot Kitchen for device testing. Use when the user says "테스트 빌드". No version bump, commit, merge or tag.
---

# 테스트 빌드

묻지 않고 실행한다. `python3 --version`이 실패하면 `python`, 그것도 실패하면 `py`로 실행한다. Windows의 `python3`는 스토어 안내로 연결될 수 있다.

```bash
python3 tools/android_build.py debug
```

- `--sim` 한 판으로 파싱과 로드를 확인한 뒤 디버그 APK를 `build/SlotKitchen-test.apk`에 만든다.
- 도구 위치를 못 찾으면 스크립트가 멈추고 지정할 환경변수를 알려준다. 변수 목록은 build 스킬과 같다.
- 끝나면 APK 경로와 빌드한 커밋 해시를 알린다.
