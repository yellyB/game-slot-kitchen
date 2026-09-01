class_name SimSynergy
extends RefCounted

static func _val(batch: SimBatch, n: int, loadout: Array) -> float:
	if OS.has_environment("SIM_SYN_SURV"):
		return float(batch.run(n, loadout, true, true).get("avg_days", 0.0))
	return float(batch.run(n, loadout, false).get("avg_score", 0.0))

static func run_report(n: int) -> void:
	var batch := SimBatch.new()
	var surv := OS.has_environment("SIM_SYN_SURV")
	var bscore := _val(batch, n, [])
	var k := int(OS.get_environment("SIM_SYN_K")) if OS.has_environment("SIM_SYN_K") else 8

	var cands: Array = []
	var solo := {}
	if OS.has_environment("SIM_SYN_IDS"):
		for raw in OS.get_environment("SIM_SYN_IDS").split(","):
			var cid := String(raw).strip_edges()
			if cid != "" and BuffDefs.ids().has(cid):
				cands.append(cid)
	else:
		var scored: Array = []
		for id in BuffDefs.ids():
			if BuffDefs.get_def(id).get("blocked", false):
				continue
			var d := _val(batch, n, [id]) - bscore
			solo[id] = d
			scored.append({"id": id, "d": d})
		scored.sort_custom(func(a, b): return a["d"] > b["d"])
		for i in mini(k, scored.size()):
			cands.append(scored[i]["id"])

	for id in cands:
		if not solo.has(id):
			solo[id] = _val(batch, n, [id]) - bscore

	print("[SYN] base %.2f (%s)  후보 %d개  n=%d  (시너지 = 조합Δ − 단독합; +시너지 / −안티)" % [
		bscore, "생존주수" if surv else "점수", cands.size(), n])
	var rows: Array = []
	for i in cands.size():
		for j in range(i + 1, cands.size()):
			var a: String = cands[i]
			var b: String = cands[j]
			var pd := _val(batch, n, [a, b]) - bscore
			rows.append({"a": a, "b": b, "pair": pd, "syn": pd - float(solo[a]) - float(solo[b])})
	rows.sort_custom(func(x, y): return x["syn"] > y["syn"])
	for r in rows:
		print("[SYN] %-12s + %-12s  조합Δ %+9.1f  단독합 %+9.1f  시너지 %+9.1f" % [
			r["a"], r["b"], r["pair"], float(solo[r["a"]]) + float(solo[r["b"]]), r["syn"]])
