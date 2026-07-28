class_name SimBatch
extends RefCounted
## SimCore를 N판 반복 실행하고 지표 집계. 버프 로드아웃별 상대 비교용.
## 실행: godot4 --headless res://scenes/Main.tscn -- --sim

## n판 실행(시드 0..n-1). buff_loadout=보유 버프 id 배열.
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


## 여러 로드아웃 비교. loadouts=[{name, buffs}] → 각 배치 결과 배열.
func compare(n: int, loadouts: Array) -> Array:
	var out := []
	for lo in loadouts:
		var res := run(n, lo.get("buffs", []))
		res["name"] = lo.get("name", "?")
		out.append(res)
	return out
