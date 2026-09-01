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
