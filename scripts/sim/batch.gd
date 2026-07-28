class_name SimBatch
extends RefCounted

func run(n: int, buff_loadout: Array = []) -> Dictionary:
	var wins := 0
	var cash := 0
	var served := 0
	var lost := 0
	var days := 0
	for i in n:
		var sim := SimCore.new()
		var r := sim.run(buff_loadout, i)
		if r["won"]:
			wins += 1
		cash += int(r["cash"])
		served += int(r["served"])
		lost += int(r["lost"])
		days += int(r["days"])
	var nf := float(maxi(n, 1))
	return {
		"runs": n,
		"loadout": buff_loadout,
		"win_rate": float(wins) / nf,
		"avg_cash": float(cash) / nf,
		"avg_served": float(served) / nf,
		"avg_lost": float(lost) / nf,
		"avg_days": float(days) / nf,
	}


func compare(n: int, loadouts: Array) -> Array:
	var out := []
	for lo in loadouts:
		var res := run(n, lo.get("buffs", []))
		res["name"] = lo.get("name", "?")
		out.append(res)
	return out
