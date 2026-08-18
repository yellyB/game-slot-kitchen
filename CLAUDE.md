# CLAUDE.md

## 커밋 규칙 (중요)

여러 작업 에이전트가 항상 동시에 이 저장소를 편집한다. 그냥 `git add -A`/`git add .`/`git commit -a`로 막 커밋하면 **다른 에이전트가 작업 중인 변경분까지 섞여 들어간다.**

- **자기 자신이 이번 세션에 직접 수정한 파일(그리고 그 hunk)만 커밋한다.**
- 파일 전체를 `git add <file>`로 담기 전에, 그 파일의 diff가 **전부 내 변경분인지** 반드시 확인한다. 한 파일에 남의 변경분이 섞여 있으면 **내 hunk만** 골라서 스테이징한다 (`git apply --cached`로 해당 hunk만 패치 적용 등).
- `git add -A`, `git add .`, `git commit -a`, 파일 단위 무분별한 add 금지.
- 커밋 전 `git status` / `git diff`로 내가 안 건드린 파일이 스테이징되지 않았는지 재확인한다.
