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

# --- generated: begin (tools/ep2_perf/hideout_warm_manifest.tscn -- write; 118 paths)
const LIST := "H4sIAAAAAAAAA51Xy3bbOAzdz1f0C+J6zplpvqObLnkgkaJYUwQHpKymX19QkmPRJqVkNnGke4ELwnjQQPE0oI3Kic7i9KJl6EEq+gtCUDGcGhwtPwrC9vKibVN6LxzSAPblp9c3WKOVwhurtja9kQrHeAIakN4EUNubqNo4UpHWKCDRK5C7oPi61c3gEMFJ43TV/kYo+2ghRMEoxpKDzjgTeoHwfnzvnlyspBDRqV0apSga5dq+qIWklWhpbE1TTmk3koNWLUoT0qVEQmInQMXj3LByKjyOJCzIsjiB4/C8hf/GQ1y8P7iLaErJWAgTWLv1ZVynyKFoRmsFGa2VPIBF9BhYT3XbE+XE0bmU+NYaX/UWTJwJ4ZghovqVqjlPYsblc13KklxnnJy8yzhLkW2zV8aKxo4ucvUT1pFyLHdO7ex3Ri3UwTiVes8OKtbe56oZcq4if2+RNXyeNCltYBslsY6zOfD3iaPutzWVk54b8B23qHH5y4eH30pIAwM6GY7YH+XNAzGd9ogYDQ+lX0UW/yNanFKjVHFNcFW2mKgEe+NGL7gxuKyqpHmmzw1YY0QzNLmDSYFHF9bZvoxXIEob5V4hJZJFp5sDGukBnBODP78K06Lbnv6RjLxVgGQ8Jk5HlBah5eHdY9SjOyKnL5iXKKkr2ivXdIej4wW5c66KRXpRqPdPGD+v4wNjPt4n4kzJ+F8x3gwP4yPFnaJ5lYnz67d/5t7Zia/AFt9v7760aJF2vrd96+eR8QHzH2DdGL9wK5q9irmbajJe9HwX+dAp39mi88IqiDzuPyeTDN+APhbcQd3zdZF48zVj14HFI3bscfAhxZISdUBeHpeI0ZqrEtriVe1ZGL5BqTTcnn33JlzUG7vgF1met0C+t3LoXIeyzbUJ4vz6+m+mlUMPag/geQ9cFHkmE9z7DaJNCzuN91l1hW83qzAomxxcTAb7hk4NpWPwxdGdNm1dJmzat0xg/BHtoCHTcpWQBV+RyDlllZxTEDLEFeO58aKSFZ2MUpbJKAWVtetEwwuulrGcU9bJOQWh+Z4c+F44VVQ2hLLEhlD3Py1xVFP2RNvVutMKioReVVRmqOx5hgreuCHUfF+thr5llH1vGUWJ9ONN8tUn7IhsOTWZLacgNCFKIYEuFZE7Xha44zXn07yY9tyvjB2BlfEgEVP9LtfKsH6Kn/xjhof3MKzraYc6AA9TyT/c+AoTkt8/dAUOU5cQAAA="
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
