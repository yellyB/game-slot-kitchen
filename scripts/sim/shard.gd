class_name SimShard
extends RefCounted

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


static func surv_shard(n: int, start: int, count: int) -> void:
	var batch := SimBatch.new()
	var ids := BuffDefs.ids()
	var base := batch.run(n, [], true, true)
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
