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
## The list is generated: `<godot> --headless --path . res://tools/ep2_perf/hideout_warm_manifest.tscn -- write` observes every load
## the facility asks for while it builds. tests/ep2_hideout_warm_test fails when the room starts loading something the list misses.

# --- generated: begin (tools/ep2_perf/hideout_warm_manifest.tscn -- write; 121 paths)
const LIST := "H4sIAAAAAAAAA52XQZbjKAyG93OKPkFlMv26u84xm1nyZBvbdDCiBY675vQjbKdiEmFXzaZS8f+hX2CECFA8DWijdqq1OL10Teih0fQHhKBjOFU4Wv6qCOvLS2cr6blySAPYl5++u8kd2kZ5Y/V2TG8ajWM8AQ1Ibwqo7k3UdRxJxCoNpHoNza6o/tz6ZnKI4BrjuuL4GyDHqCFExSpGKUBrnAm9QnifvndPIVYoRHR6F6OURaVd3YteSJ1WNY21qeQlbUdyUOvFaUK6SBASBwESp3PT5KXwOJKy0MjmBI7T8xZ+jYe6ev/iLqqSFmMBJrB2G8u4VpNDVY3WKjJdp5sDOZ+JBJyPgL+OgK9lYHQuvdPaGl9MNJg4A+GYUFH/ToWyMytesotsyVuY1z0vYH4Bkcdmj4xVlR1d5MIiLCtyLnemNPc7UUp1ME6nsraDjqXnuWumnItK9ibX9PkQS8sGttINlnUeDvw+cez67XbNoefaftctdrj85cnDv1o1BgZ0TTiiP8rNZ22a7REYDZ93v0WK/1E1TqkGi3pHcNVWXKgke+NGrzwG3lZFaG4Xc22XiGiGKg8wafDowto2lpMbiFKzuu8QCbLouuoAo24A59Tgz6/K1Oi2s3+EkRsWUBOPwekIqRFq7gs9xm50R3B6wdyfSV/RXnlPtzg67r078yqMSA+E/f6Jwc+d/mAwT+8TeabF+F853gYe5keaK6XjLqnOrz++zbWzk59Aq79vz77UaJF23tv+6Ocj4wPD/wHrxviFS9Hs7Zj70I6MVz1fcz40y3datV5ZDZGP+8/ZpIFvQB9L7mDf802UuPNVY9uCxSM69jj4kHJJC3UAL1+XjNGaq1adxaveG2H4cqbT4fYcuzfhot84BD/I1nkr5H0rl85lKetcmyTOr6/fM69cenB7EM974uLIZzLBvd4g2tSw0/E+u67y7dIWBm1TgIvJZF/RqaI0Db6TutOmrGVgU74ywPqj2kJFpuZdQhZ8wSJnZJecEYwM8Y7xXHhRNwWfDJFtMkRwWatOVdzgSiuWM7JPzghG8xU88L1wKrhsANliA5TjT0sexSV7wna97pjgSOh1wWWW5MizJETjgtDzfbWY+paQY28J0SL9Lmz46hN2TLZMyWbLCEYTYqMaoEvB5K7LBne9FHyaG9Ne+JXYMViJB4uY9u9yrQzrp/rJP2b48B6G9aa4gw7Ah2nDP9j4ChMS/B+bSxM28hAAAA=="
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
