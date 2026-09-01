#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

N="${1:-40}"
JOBS="${2:-$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 8)}"
G=(godot4 --headless res://scenes/Main.tscn --)

CNT="$("${G[@]}" --simcount 2>/dev/null | sed -n 's/.*\[SIMCOUNT\] \([0-9]*\).*/\1/p' | tail -1)"
[ -z "${CNT:-}" ] && { echo "버프 개수 조회 실패 — godot4 실행 확인" >&2; exit 1; }
CHUNK=$(( (CNT + JOBS - 1) / JOBS ))

echo "[PAR] 버프 ${CNT}개 · N=${N} · JOBS=${JOBS} · chunk=${CHUNK}  (SIM_RENT=${SIM_RENT:-1} SIM_MAXDAY=${SIM_MAXDAY:-12})" >&2
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pids=()
for (( j=0; j<JOBS; j++ )); do
	ST=$(( j * CHUNK ))
	[ "$ST" -ge "$CNT" ] && break
	"${G[@]}" --simshard "$N" "$ST" "$CHUNK" >"$TMP/shard_$j.txt" 2>/dev/null &
	pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done

awk -F'\t' '/\[BUFFRPT-BASE\]/{printf "[BUFFRPT] base(버프0)  승률 %.1f%%  현금 %.0f  점수 %.1f  일수 %.2f  (n=%d)\n",$2,$3,$4,$5,$6}' "$TMP"/*.txt | head -1
grep -h '\[BUFFRPT-ROW\]' "$TMP"/*.txt | sort -t$'\t' -k2 -rn | \
	awk -F'\t' '{printf "[BUFFRPT] %-14s Δ점수 %+10.1f  Δ승률 %+6.1f%%  Δ현금 %+9.1f  (승률 %.0f%%)\n",$3,$2,$4,$5,$6}'
