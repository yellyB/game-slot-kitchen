class_name SimShard
extends RefCounted
## 버프 순위 시뮬(--simbuffs)의 병렬 샤딩 워커.
## 버프 리스트의 [start, start+count) 구간만 측정해 탭 구분 행을 stdout에 찍는다.
## 오케스트레이터(tools/sim_parallel.sh)가 코어 수만큼 이 워커를 띄우고 출력을 합쳐 정렬한다.
## batch.gd의 buff_report(다른 작업이 편집 중)는 건드리지 않고 깨끗한 SimBatch.run()만 호출.

## start==0 워커만 base 요약을 찍는다(중복 방지). 행은 dscore를 앞세워 셸에서 sort -rn로 병합.
static func buff_shard(n: int, start: int, count: int) -> void:
	var batch := SimBatch.new()
	var ids := BuffDefs.ids()
	var base := batch.run(n, [], false)
	if start == 0:
		print("[BUFFRPT-BASE]\t%.1f\t%.1f\t%.1f\t%.2f\t%d" % [
			base["win_rate"] * 100.0, base["avg_cash"], base["avg_score"], base["avg_days"], n])
	var stop := mini(start + count, ids.size())
	for i in range(start, stop):
		var id: String = ids[i]
		var r := batch.run(n, [id], false)
		print("[BUFFRPT-ROW]\t%.1f\t%s\t%.1f\t%.1f\t%.1f" % [
			r["avg_score"] - base["avg_score"], id,
			(r["win_rate"] - base["win_rate"]) * 100.0,
			r["avg_cash"] - base["avg_cash"], r["win_rate"] * 100.0])


## 상점ON 생존 한계기여 — 모든 카드를 한 잣대(Δ생존주수)로. 슬롯만 사는 백드롭에 단독 카드.
## 경제/처리량/정산 카드도 자기 채널(돈→슬롯, 병목 완화 등)로 생존에 기여 → 사각지대 해소.
static func surv_shard(n: int, start: int, count: int) -> void:
	var batch := SimBatch.new()
	var ids := BuffDefs.ids()
	var base := batch.run(n, [], true, true)   # 상점ON·슬롯만
	if start == 0:
		print("[SURV-BASE]\t%.3f\t%.1f\t%d" % [base["avg_days"], base["win_rate"] * 100.0, n])
	var stop := mini(start + count, ids.size())
	for i in range(start, stop):
		var id: String = ids[i]
		if BuffDefs.get_def(id).get("blocked", false):
			continue
		var r := batch.run(n, [id], true, true)
		print("[SURV-ROW]\t%.3f\t%s\t%.3f\t%.1f" % [
			r["avg_days"] - base["avg_days"], id, r["avg_days"], r["win_rate"] * 100.0])
