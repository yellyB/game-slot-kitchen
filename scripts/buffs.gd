extends Node

var _owned: Array[String] = []

func clear() -> void:
	_owned.clear()

func add(id: String) -> void:
	_owned.append(id)

func owned() -> Array[String]:
	return _owned

func mod(stat: String, base: float) -> float:
	var m := 1.0
	for id in _owned:
		var def := BuffDefs.get_def(id)
		if def.get("stat", "") == stat:
			m *= float(def.get("value", 1.0))
	return base * m
