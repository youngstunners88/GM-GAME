class_name Ep2Extras
extends RefCounted
## EPISODE 2 EXTRAS, STREAMED (founder 2026-10-19: "Stream Episode 2 extras").
##
## The web build has a hard 190 MiB gate on index.pck (itch rejects any file over 200 MB). New Episode 2 art that does not fit -
## the two-storey Armory, the founder's Tripo Rich and Utah with their mocap clips - lives under res://src/episode2/extras/.
## CI leaves that folder OUT of index.pck and packs it into a second file, ep2_extras.pck, deployed next to it
## (tools/ep2_extras/pack_extras.gd). When Episode 2 starts, the web build downloads that pack into user:// and mounts it with
## ProjectSettings.load_resource_pack; from then on ResourceLoader.exists() finds the extras like any other resource.
##
## Rules: callers ALWAYS check `has(path)` and keep their old asset as the fallback, so a slow or failed download only means the
## old Armory / old Rich and Utah are shown - never a missing building. In the editor, tests and a desktop run the files are on
## disk (has() is true at once, nothing downloads).

const PACK := "ep2_extras.pck"
const LOCAL := "user://ep2_extras.pck"
const ARMORY := "res://src/episode2/extras/armory/armory2.glb"
const RICH := "res://src/episode2/extras/folk/rich_armory2.glb"
const UTAH := "res://src/episode2/extras/folk/utah_armory2.glb"
## The town kit with REAL openings (windows, doors, side windows; 2026-10-19 openings pass): same piece names as town_kit.glb.
const TOWN_KIT := "res://src/episode2/extras/town/town_kit2.glb"
## The townspeople (Ep2TownPeople), one rigged GLB each.
const PEOPLE_DIR := "res://src/episode2/extras/people/"

static var _state: String = ""            # "" never started, "loading", "ready", "failed"


## True when `path` can be loaded now (on disk in the editor/desktop, or after the web pack mounted).
static func has(path: String) -> bool:
	return ResourceLoader.exists(path)


## "ready" once the pack mounted (or the files are already present), "loading", "failed" or "" (not started).
static func state() -> String:
	if _state == "" and has(ARMORY):
		return "ready"
	return _state


## Start the background download once, from any node in the tree (Episode 2's entry calls it). No-op off the web or when the
## extras are already loadable.
##
## WHY NOT HTTPRequest (2026-10-19 incident): itch's CDN gzips ep2_extras.pck for browsers and reports the COMPRESSED size as
## Content-Length while the browser hands Godot the decompressed bytes. Godot 4.3's web HTTPClient treats that mismatch as an
## error ("err != 0 && err != 1") and the download "failed (http 200)", so the town never got its new art. The browser's own
## fetch() handles compression correctly, so the bytes come from a literal JS fetch and are written straight into the engine's
## virtual file system (Godot 4.3's public `Engine.copyToFS(path, buffer)` on the page's `engine` object - GodotFS.copy_to_fs makes the
## folder and writes the file) at the real path of
## user://ep2_extras.pck; Godot then mounts that file like any other pack.
static func start(from: Node) -> void:
	if _state != "" or has(ARMORY) or not OS.has_feature("web") or from == null or not from.is_inside_tree():
		return
	_state = "loading"
	var win: JavaScriptObject = JavaScriptBridge.get_interface("window")
	win.set("__ep2x_state", "loading")
	win.set("__ep2x_path", ProjectSettings.globalize_path(LOCAL))
	win.set("__ep2x_tag", GameManager.BUILD_TAG)       # CI stamps it per build, so a new pack is never served stale
	# Pure literal (security-sentinel INJ-003 form (a)): page base + pack name + the tag read from window, never interpolated.
	JavaScriptBridge.eval("(function(){var base=window.location.href.substring(0,window.location.href.lastIndexOf('/')+1);fetch(base+'ep2_extras.pck?v='+encodeURIComponent(window.__ep2x_tag)).then(function(r){if(!r.ok){throw new Error('http '+r.status);}return r.arrayBuffer();}).then(function(b){engine.copyToFS(window.__ep2x_path,b);window.__ep2x_state='ready';}).catch(function(e){window.__ep2x_state='failed: '+e;});})();", true)
	_watch(from.get_tree())


## Poll the JS side twice a second until the file is written (or it failed / 5 minutes passed), then mount it.
static func _watch(tree: SceneTree) -> void:
	var waited: float = 0.0
	while waited < 300.0:
		await tree.create_timer(0.5).timeout
		waited += 0.5
		var st: String = str(JavaScriptBridge.eval("window.__ep2x_state", true))
		if st == "loading":
			continue
		if st == "ready" and ProjectSettings.load_resource_pack(LOCAL, false):
			_state = "ready" if has(ARMORY) else "failed"
		else:
			_state = "failed"
		print("[EP2] extras ", _state, " (", st, ")")
		return
	_state = "failed"
	print("[EP2] extras failed (timeout)")
