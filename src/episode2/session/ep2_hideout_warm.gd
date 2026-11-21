class_name Ep2HideoutWarm
extends RefCounted
## THE HIDEOUT'S RESOURCES, LOADED BEFORE THE RUN STARTS (mobile sprint 2026-11-10: "the mine-cart exit video never plays smoothly").
##
## The Smelting Facility is built behind the cart-exit film so the film can cut straight into it. A non-threaded web build has ONE
## thread for the film's picture, its sound and that build, and almost all of the build's cost is reading its models and textures:
## measured in the browser, the film froze for 7 of its 61 seconds on a desktop CPU and for 27 seconds (single freezes up to 5.5 s) at
## a phone-class 4x throttle, all between film second 3 and 20 (scripts/ep2-mobile-film-probe.mjs).
##
## So the reading is done here instead, one resource at a time, while a static screen is up: the access-code screen, or the short
## wait before the cart starts. The resources are HELD until the room has been built from them (a load is only a cache hit while
## something still holds the resource), then released. Nothing about the room or the film changes; only when the disk work happens.
##
## The list is generated: `<godot> --headless --path . tools/ep2_perf/hideout_warm_manifest.tscn -- write` observes every load
## the facility asks for while it builds. tests/ep2_hideout_warm_test fails when the room starts loading something the list misses.

# --- generated: begin (tools/ep2_perf/hideout_warm_manifest.tscn -- write; 121 paths)
const LIST := "H4sIAAAAAAACA52XQXbjKBCG93OKnCBuz7yZyTl6M0teSSBEG1F0gaykT9+FZMfCBsmZTRzr/6i/QBSFgeJhQBuVE53F6VXL0INU9AeEoGI4NDha/ioI29Ortk3puXBIA9jXH15fZY1WCm+sWo/pjVQ4xgPQgPQhgNreRNXGkYpYo4BEr0BuiuLb2jeTQwQnjdPV8VegHKOFEAWrGEsBOuNM6AXC5/S90xUoRHRqE6OURaNc2xe9kLQSLY2tacpL2o3koFWL04R0KkFIHAQobmnlpfA4krAgy+YEjtPzFn6Ou7r4/OJOoiktxgJMYO06lnGdIoeiGa0VZLRWckfOZ1ICjnvAn3vAX3VgdC6909YaX000mDgDYZ8QUb2nQtmYFS/ZqWzJW5jXPS9gfgGRx2aPjBWNHV3kwiKsK+Vcbkxt7jeilupgnEplbQcVa89z10w5VpXsTV7S50MsLRvYRkms6zwc+H3iqPv1ds2hx9r+1C1qXP7y5OGXEtLAgE6GPfpZbj5r02z3wGj4vHsvUvyPaHFKNVjVNcFZ2eJCJdkbN3rhMfC2qkJzu5hru0ZEMzR5gEmBRxcubWM5uYEoNavbDilBFp1udjDSAzgnBn98E6ZFt579PYzcsIBk3AenPaRFaLkv9Bj16Pbg9IK5P5M6oz3znu5wdNx7N+ZVGZEeFPb7FwY/dvqdwTy9L+SZFuN/5XgduJsfKa4UzV1SHN/+/XuunY38CrT4fn320qJF2nhv26Mfj4wnhv8H1o3xhUvRuKeGajJe9HzNeWqWn7TovLAKIh/3X7NJAz+AnktuZ9/zTZS48zVj14HFPTr2OPiQckkLtQMvX5eM0ZqzEtriWW2NMHw5U+lwe4zdm3BSHxyCH2TrvBbyvpVLx7qUda5VEse3t38yr1y6c7sTj1vi4shnMsGt3iDa1LDT8T67XuTrpS0MyqYAJ5PJvqFDQ2kafCd1h1VZl4FV+ZYB1u/VDhoyLe8SsuArFjlTdsmZgpEh3jGeCy8qWfHJkLJNhhRcLlUnGm5wtRXLmbJPzhSM5it44HvhVHFZAWWLFVCPPy15VJfsAdv0umEFR0KvKi6zVI48S4VoXBBqvq9WU18T5dhromiRfhdKvvqEDZM1U7NZMwWjCVEKCXSqmNz0ssFNrwWf5sa0Ff5CbBhciDuLmPbvcq0Ml0/xg3/M8OE9DJf2tIEOwIep5B9sfIUJKe5vYPAaZvIQAAA="
# --- generated: end

## The paths, read once from LIST (one gzip-compressed string: 121 separate string constants cost 16 KB of the main pack, which has
## almost none to spare).
static func paths() -> PackedStringArray:
	if _paths.is_empty() and LIST != "":
		var raw: PackedByteArray = Marshalls.base64_to_raw(LIST).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
		for rel in raw.get_string_from_utf8().split("\n", false):
			_paths.append("res://src/episode2/" + rel)
	return _paths

static var _paths: PackedStringArray = PackedStringArray()
static var _held: Array = []
static var _next: int = 0
static var _missing: PackedStringArray = PackedStringArray()     # listed but not in the build yet (the streamed extras, before their pack mounts)
static var _retry: PackedStringArray = PackedStringArray()       # ...and now there: read these too
## Tests only: behave as the web build does on any platform.
static var force: bool = false


## Is the warm-up worth doing here? Only where the film and the build share one thread (the web export).
static func wanted() -> bool:
	return force or OS.has_feature("web")


static func done() -> bool:
	return _next >= paths().size() and _retry.is_empty()


## The streamed pack has just mounted: what was skipped for not being there is read after all.
static func extras_arrived() -> void:
	_retry.append_array(_missing)
	_missing.clear()


## 0..1, for the wait's progress bar.
static func progress() -> float:
	return 1.0 if paths().is_empty() else float(_next) / float(paths().size())


## Load the next resources: always at least one, then more until `budget_ms` of this frame is spent. A resource that is not in this
## build (a streamed extra, a stripped file) is skipped; the room copes with that exactly as it does today.
static func step(budget_ms: float) -> void:
	var t0: int = Time.get_ticks_usec()
	while not done():
		var path: String
		if _next < paths().size():
			path = paths()[_next]
			_next += 1
		else:
			path = _retry[_retry.size() - 1]
			_retry.remove_at(_retry.size() - 1)
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res != null:
				_held.append(res)
		else:
			_missing.append(path)
		if float(Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			return


## The room is built (or will not be, this run): let go. A later run from the cliff warms again; what is still alive is a cache hit.
static func release() -> void:
	_held.clear()
	_next = 0
	_missing.clear()
	_retry.clear()


static func held_count() -> int:
	return _held.size()
