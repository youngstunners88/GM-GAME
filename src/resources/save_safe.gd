class_name SaveSafe
extends RefCounted
## Coercion helpers for values read back from user://save.json.
##
## The save file is player-editable and can be valid JSON of the WRONG SHAPE
## (a count given as an array, null, an object). GDScript's `int([9])` raises
## "Nonexistent 'int' constructor" and that runtime error aborts the whole
## load_session() part-way, leaving the session half-restored. Every numeric
## read from disk goes through here instead: numbers, bools and numeric
## strings convert, anything else takes the caller's default.

## Untrusted value -> int. Non-finite floats also fall back to `default`.
static func to_int(v: Variant, default: int = 0) -> int:
	match typeof(v):
		TYPE_INT, TYPE_BOOL, TYPE_STRING:
			return int(v)
		TYPE_FLOAT:
			return int(v) if is_finite(v) else default
	return default

## Untrusted value -> float. Non-finite values fall back to `default`.
static func to_float(v: Variant, default: float = 0.0) -> float:
	match typeof(v):
		TYPE_INT, TYPE_BOOL, TYPE_STRING:
			return float(v)
		TYPE_FLOAT:
			return float(v) if is_finite(v) else default
	return default

## Untrusted value -> Dictionary (empty when it is anything else).
static func to_dict(v: Variant) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}

## Untrusted value -> String (empty unless it really is a String).
static func to_str(v: Variant) -> String:
	return v if typeof(v) == TYPE_STRING else ""
