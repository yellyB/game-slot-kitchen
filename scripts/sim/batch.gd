class_name SimBatch
extends RefCounted
## SimCore를 N판 반복 실행하고 지표 집계. 버프 로드아웃별 상대 비교용.
## 실행: godot4 --headless res://scenes/Main.tscn -- --sim

## n판 실행(시드 0..n-1). buff_loadout=보유 버프 id 배열.
func run(n: int, buff_loadout: Array = [], shop_enabled := true, slots_only := false) -> Dictionary:
	var wins := 0
	var cash := 0
	var served := 0
	var lost := 0
	var l_miss := 0
	var l_queue := 0
	var l_order := 0
	var l_qfull := 0
	var days := 0
	var slots := 0
	var buffs := 0
	var score := 0
	var days_list: Array = []   # 판별 생존주 — 분포(바이모달) 확인용
	var ctx := {"filled": 0.0, "empty": 0.0, "orders": 0.0, "dishes": 0.0, "ingr": 0.0, "buffs": 0.0}
	for i in n:
		var sim := SimCore.new()
		var r := sim.run(buff_loadout, i, shop_enabled, slots_only)
		days_list.append(int(r["days"]))
		for k in ctx:
			ctx[k] = float(ctx[k]) + float(r.get("ctx_" + k, 0.0))
		if r["won"]:
			wins += 1
		cash += int(r["cash"])
		served += int(r["served"])
		lost += int(r["lost"])
		l_miss += int(r.get("lost_miss", 0))
		l_queue += int(r.get("lost_queue", 0))
		l_order += int(r.get("lost_order", 0))
		l_qfull += int(r.get("lost_qfull", 0))
		days += int(r["days"])
		slots += int(r.get("slots", 0))
		buffs += int(r.get("buffs", 0))
		score += int(r.get("score", 0))
	var nf := float(maxi(n, 1))
	var ctx_avg := {}
	for k in ctx:
		ctx_avg[k] = float(ctx[k]) / nf
	return {
		"runs": n,
		"loadout": buff_loadout,
		"ctx": ctx_avg,
		"win_rate": float(wins) / nf,
		"avg_score": float(score) / nf,
		"avg_cash": float(cash) / nf,
		"avg_served": float(served) / nf,
		"avg_lost": float(lost) / nf,
		"avg_lost_miss": float(l_miss) / nf,
		"avg_lost_queue": float(l_queue) / nf,
		"avg_lost_order": float(l_order) / nf,
		"avg_lost_qfull": float(l_qfull) / nf,
		"avg_days": float(days) / nf,
		"avg_slots": float(slots) / nf,
		"avg_buffs": float(buffs) / nf,
		"days_list": days_list,
	}


## 여러 로드아웃 비교. loadouts=[{name, buffs}] → 각 배치 결과 배열.
func compare(n: int, loadouts: Array) -> Array:
	var out := []
	for lo in loadouts:
		var res := run(n, lo.get("buffs", []))
		res["name"] = lo.get("name", "?")
		out.append(res)
	return out


## 버프 효과 측정 — 기준(버프0·상점off) vs 각 버프 1개(상점off)를 N판 비교, Δ 출력.
## 상점 off로 두어 '그 버프만'의 순효과를 격리. 승률이 민감한 구간이 되도록 SIM_RENT로 가혹도 조절.
func buff_report(n: int) -> void:
	var base := run(n, [], false)
	print("[BUFFRPT] base(버프0)  승률 %.0f%%  점수 %.0f  현금 %.0f  일수 %.2f  (n=%d, SIM_RENT=%s SIM_MAXDAY=%s)" % [
		base["win_rate"] * 100.0, base["avg_score"], base["avg_cash"], base["avg_days"], n,
		OS.get_environment("SIM_RENT") if OS.has_environment("SIM_RENT") else "1",
		OS.get_environment("SIM_MAXDAY") if OS.has_environment("SIM_MAXDAY") else "-"])
	var only: Array = []
	if OS.has_environment("SIM_BUFF_ONLY"):
		only = Array(OS.get_environment("SIM_BUFF_ONLY").split(","))
	var rows := []
	for id in BuffDefs.ids():
		if not only.is_empty() and not (id in only):
			continue
		var r := run(n, [id], false)
		rows.append({
			"id": id,
			"dscore": r["avg_score"] - base["avg_score"],
			"dcash": r["avg_cash"] - base["avg_cash"],
			"win": r["win_rate"] * 100.0,
		})
	rows.sort_custom(func(a, b): return a["dscore"] > b["dscore"])
	for row in rows:
		print("[BUFFRPT] %-14s Δ점수 %+9.0f  Δ현금 %+9.0f  (승률 %.0f%%)" % [
			row["id"], row["dscore"], row["dcash"], row["win"]])
