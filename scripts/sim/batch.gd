class_name SimBatch
extends RefCounted

func run(n: int, buff_loadout: Array = [], shop_enabled := true) -> Dictionary:
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
	for i in n:
		var sim := SimCore.new()
		var r := sim.run(buff_loadout, i, shop_enabled)
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
	return {
		"runs": n,
		"loadout": buff_loadout,
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
	}


func compare(n: int, loadouts: Array) -> Array:
	var out := []
	for lo in loadouts:
		var res := run(n, lo.get("buffs", []))
		res["name"] = lo.get("name", "?")
		out.append(res)
	return out


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
