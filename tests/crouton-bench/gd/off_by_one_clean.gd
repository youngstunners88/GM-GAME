extends Node

var items: Array[String] = ["a", "b", "c"]

func item_at(idx: int) -> String:
	if idx >= 0 and idx < items.size():
		return items[idx]
	return ""
