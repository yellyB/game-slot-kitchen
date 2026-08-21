class_name SimBatch
extends RefCounted
## SimCore를 N판 반복 실행하고 지표 집계. 버프 로드아웃별 상대 비교용.
## 실행: godot4 --headless res://scenes/Main.tscn -- --sim

## n판 실행(시드 0..n-1). buff_loadout=보유 버프 id 배열.
func run(n: int, buff_loadout: Array = [], shop_enabled := true) -> Dictionary:
	var wins := 0
	var cash := 0
	var served := 0
	var lost := 0
	var days := 0
	var slots := 0
	var buffs := 0
	for i in n:
		var sim := SimCore.new()
		var r := sim.run(buff_loadout, i, shop_enabled)
		if r["won"]:
			wins += 1
		cash += int(r["cash"])
		served += int(r["served"])
		lost += int(r["lost"])
		days += int(r["days"])
		slots += int(r.get("slots", 0))
		buffs += int(r.get("buffs", 0))
	var nf := float(maxi(n, 1))
	return {
		"runs": n,
		"loadout": buff_loadout,
		"win_rate": float(wins) / nf,
		"avg_cash": float(cash) / nf,
		"avg_served": float(served) / nf,
		"avg_lost": float(lost) / nf,
		"avg_days": float(days) / nf,
		"avg_slots": float(slots) / nf,
		"avg_buffs": float(buffs) / nf,
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
	print("[BUFFRPT] base(버프0)  승률 %.0f%%  현금 %.0f  일수 %.2f  (n=%d, SIM_RENT=%s)" % [
		base["win_rate"] * 100.0, base["avg_cash"], base["avg_days"], n,
		OS.get_environment("SIM_RENT") if OS.has_environment("SIM_RENT") else "1"])
	var rows := []
	for id in BuffDefs.ids():
		var r := run(n, [id], false)
		rows.append({
			"id": id,
			"dwin": (r["win_rate"] - base["win_rate"]) * 100.0,
			"dcash": r["avg_cash"] - base["avg_cash"],
			"win": r["win_rate"] * 100.0,
		})
	rows.sort_custom(func(a, b): return a["dcash"] > b["dcash"])
	for row in rows:
		print("[BUFFRPT] %-14s Δ승률 %+6.1f%%  Δ현금 %+9.0f  (승률 %.0f%%)" % [
			row["id"], row["dwin"], row["dcash"], row["win"]])
