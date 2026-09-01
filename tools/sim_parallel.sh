#!/usr/bin/env bash
# 버프 순위 시뮬(--simbuffs)을 코어 수만큼 샤딩해 병렬 실행하고 결과를 합쳐 정렬 출력.
# 시드/게임은 완전 동일하게 재현되며(같은 시드=같은 게임) 단지 CPU만 나눠 쓴다 → 정확도 손실 0.
#
# 사용:   tools/sim_parallel.sh [N] [JOBS]
# 예:     SIM_RENT=1.2 tools/sim_parallel.sh 400          # JOBS=코어수 자동
#         SIM_MAXDAY=8 tools/sim_parallel.sh 400 12
# 환경변수(SIM_RENT/SIM_MAXDAY/SIM_HANDLE 등)는 그대로 각 워커에 상속된다.
set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-40}"
JOBS="${2:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)}"
MODE="${3:-buffs}"    # buffs=상점off 점수Δ(기본) | surv=상점ON 생존Δ(모든 카드 한 잣대)
G=(godot4 --headless res://scenes/Main.tscn --)
[ "$MODE" = surv ] && export SIM_HANDLE="${SIM_HANDLE:-0.6}"   # 생존 측정은 현실모드

CNT="$("${G[@]}" --simcount 2>/dev/null | sed -n 's/.*\[SIMCOUNT\] \([0-9]*\).*/\1/p' | tail -1)"
[ -z "${CNT:-}" ] && { echo "버프 개수 조회 실패 — godot4 실행 확인" >&2; exit 1; }
CHUNK=$(( (CNT + JOBS - 1) / JOBS ))

echo "[PAR] mode=${MODE} · 버프 ${CNT}개 · N=${N} · JOBS=${JOBS} · chunk=${CHUNK}  (SIM_RENT=${SIM_RENT:-1} SIM_HANDLE=${SIM_HANDLE:-0} SIM_MAXDAY=${SIM_MAXDAY:-12})" >&2
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pids=()
for (( j=0; j<JOBS; j++ )); do
	ST=$(( j * CHUNK ))
	[ "$ST" -ge "$CNT" ] && break
	if [ "$MODE" = surv ]; then
		"${G[@]}" --simshard "$N" "$ST" "$CHUNK" surv >"$TMP/shard_$j.txt" 2>/dev/null &
	else
		"${G[@]}" --simshard "$N" "$ST" "$CHUNK" >"$TMP/shard_$j.txt" 2>/dev/null &
	fi
	pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

if [ "$MODE" = surv ]; then
	# 생존Δ: base 생존주수 + Δ생존주수 내림차순
	awk -F'\t' '/\[SURV-BASE\]/{printf "[SURV] base(버프0)  생존주수 %.2f/12  승률 %.1f%%  (n=%d)\n",$2,$3,$4}' "$TMP"/*.txt | head -1
	grep -h '\[SURV-ROW\]' "$TMP"/*.txt | sort -t$'\t' -k2 -rn | \
		awk -F'\t' '{printf "[SURV] %-14s Δ생존 %+6.3f주  (생존 %.2f  승률 %.0f%%)\n",$3,$2,$4,$5}'
else
	# base 요약(한 줄) + dscore 내림차순 정렬한 행
	awk -F'\t' '/\[BUFFRPT-BASE\]/{printf "[BUFFRPT] base(버프0)  승률 %.1f%%  현금 %.0f  점수 %.1f  일수 %.2f  (n=%d)\n",$2,$3,$4,$5,$6}' "$TMP"/*.txt | head -1
	grep -h '\[BUFFRPT-ROW\]' "$TMP"/*.txt | sort -t$'\t' -k2 -rn | \
		awk -F'\t' '{printf "[BUFFRPT] %-14s Δ점수 %+10.1f  Δ승률 %+6.1f%%  Δ현금 %+9.1f  (승률 %.0f%%)\n",$3,$2,$4,$5,$6}'
fi
