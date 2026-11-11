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
## PATHS is generated: `<godot> --headless --path . res://tools/ep2_perf/hideout_warm_manifest.tscn -- write` observes every load
## the facility asks for while it builds. tests/ep2_hideout_warm_test fails when the room starts loading something the list misses.

# --- generated: begin (tools/ep2_perf/hideout_warm_manifest.tscn -- write)
const PATHS: PackedStringArray = [
	"res://src/episode2/art/molten_flow.gdshader",
	"res://src/episode2/assets/boulder_rock.glb",
	"res://src/episode2/assets/boulder_rock_normal.jpg",
	"res://src/episode2/assets/gold_pile.glb",
	"res://src/episode2/assets/hideout/armory_architecture.glb",
	"res://src/episode2/assets/hideout/bear_head.glb",
	"res://src/episode2/assets/hideout/bear_head_0.jpg",
	"res://src/episode2/assets/hideout/bear_standing.glb",
	"res://src/episode2/assets/hideout/bear_standing_0.jpg",
	"res://src/episode2/assets/hideout/cast_ingot.glb",
	"res://src/episode2/assets/hideout/finish_oak_normal.png",
	"res://src/episode2/assets/hideout/finish_stone_normal.png",
	"res://src/episode2/assets/hideout/firing_bench.glb",
	"res://src/episode2/assets/hideout/forge_crucible.glb",
	"res://src/episode2/assets/hideout/furnace_stonework.glb",
	"res://src/episode2/assets/hideout/ore_cart.glb",
	"res://src/episode2/assets/hideout/ore_cart_0.jpg",
	"res://src/episode2/assets/hideout/pour_ladle.glb",
	"res://src/episode2/assets/hideout/range_plaque.glb",
	"res://src/episode2/assets/hideout/range_plaque_range_plank_b.png",
	"res://src/episode2/assets/hideout/range_wall.glb",
	"res://src/episode2/assets/inferno_bull_rigged.glb",
	"res://src/episode2/assets/inferno_bull_rigged_0.jpg",
	"res://src/episode2/assets/inferno_bull_rigged_1.jpg",
	"res://src/episode2/assets/inferno_bull_rigged_2.jpg",
	"res://src/episode2/assets/inferno_bull_rigged_3.jpg",
	"res://src/episode2/assets/inferno_bull_running_clip.glb",
	"res://src/episode2/assets/inferno_bull_sit_clips.glb",
	"res://src/episode2/assets/inferno_bull_sit_clips_texture_0.jpg",
	"res://src/episode2/assets/inferno_bull_walking_clip.glb",
	"res://src/episode2/assets/ingot_rack.glb",
	"res://src/episode2/assets/lantern.glb",
	"res://src/episode2/assets/lil_blunt_hero.glb",
	"res://src/episode2/assets/lil_blunt_hero_texture_0.jpg",
	"res://src/episode2/assets/lil_blunt_running_clip.glb",
	"res://src/episode2/assets/lil_blunt_walking_clip.glb",
	"res://src/episode2/assets/miner_helmet.glb",
	"res://src/episode2/assets/miner_helmet_0.jpg",
	"res://src/episode2/assets/miner_helmet_1.jpg",
	"res://src/episode2/assets/miner_helmet_2.jpg",
	"res://src/episode2/assets/textures/bull_albedo.jpg",
	"res://src/episode2/assets/textures/bull_metal_rough.png",
	"res://src/episode2/assets/textures/bull_normal.png",
	"res://src/episode2/assets/textures/logos/logo_blaze_diamonds.png",
	"res://src/episode2/assets/textures/logos/logo_diamonds.png",
	"res://src/episode2/assets/textures/logos/logo_gold_mine.png",
	"res://src/episode2/assets/textures/logos/logo_titanx.png",
	"res://src/episode2/assets/textures/tex_cowhide.png",
	"res://src/episode2/assets/textures/tex_gravel.jpg",
	"res://src/episode2/assets/textures/tex_pinup_poster.jpg",
	"res://src/episode2/assets/textures/tex_rock_wall.jpg",
	"res://src/episode2/assets/textures/tex_timber.jpg",
	"res://src/episode2/assets/weapons/armory/bear_arrow.glb",
	"res://src/episode2/assets/weapons/armory/bear_longbow.glb",
	"res://src/episode2/assets/weapons/armory/bergmann_mp18_icon.png",
	"res://src/episode2/assets/weapons/armory/borchardt_icon.png",
	"res://src/episode2/assets/weapons/armory/bow_icon.png",
	"res://src/episode2/assets/weapons/armory/coach_shotgun_icon.png",
	"res://src/episode2/assets/weapons/armory/golden_revolver_founder.glb",
	"res://src/episode2/assets/weapons/armory/golden_revolver_founder_rev_albedo.jpg",
	"res://src/episode2/assets/weapons/armory/golden_revolver_founder_rev_normal.jpg",
	"res://src/episode2/assets/weapons/armory/golden_revolver_gun.glb",
	"res://src/episode2/assets/weapons/armory/golden_revolver_gun_rev_albedo.jpg",
	"res://src/episode2/assets/weapons/armory/golden_revolver_gun_rev_normal.jpg",
	"res://src/episode2/assets/weapons/armory/remington_1875_gold.glb",
	"res://src/episode2/assets/weapons/armory/remington_1875_gold_Remington color.png",
	"res://src/episode2/assets/weapons/armory/remington_1875_gold_Remington normal.png",
	"res://src/episode2/assets/weapons/armory/remington_1875_gold_Walnut grain.png",
	"res://src/episode2/assets/weapons/armory/remington_grip_hand.glb",
	"res://src/episode2/assets/weapons/armory/remington_grip_hand_fp_leather.png",
	"res://src/episode2/assets/weapons/armory/remington_grip_hand_fp_yarn.png",
	"res://src/episode2/assets/weapons/armory/remington_icon.png",
	"res://src/episode2/assets/weapons/armory/sharps_buffalo_icon.png",
	"res://src/episode2/assets/weapons/armory/thompson_gold_icon.png",
	"res://src/episode2/assets/weapons/armory/weapon_hand_olive_glove.png",
	"res://src/episode2/assets/weapons/armory/winchester_icon.png",
	"res://src/episode2/assets/whiskey_glass.glb",
	"res://src/episode2/assets/whiskey_glass_0.jpg",
	"res://src/episode2/assets/whiskey_glass_1.jpg",
	"res://src/episode2/assets/whiskey_glass_2.jpg",
	"res://src/episode2/assets/winchester_1886.glb",
	"res://src/episode2/assets/winchester_1886_0.jpg",
	"res://src/episode2/assets/winchester_1886_1.jpg",
	"res://src/episode2/assets/winchester_1886_2.jpg",
	"res://src/episode2/extras/armory/gatling_post.glb",
	"res://src/episode2/extras/hideout/smelter_kit.glb",
	"res://src/episode2/extras/pbr/brass_worn/albedo.jpg",
	"res://src/episode2/extras/pbr/brass_worn/normal.jpg",
	"res://src/episode2/extras/pbr/brass_worn/orm.jpg",
	"res://src/episode2/extras/pbr/fabric_burlap/albedo.jpg",
	"res://src/episode2/extras/pbr/fabric_burlap/normal.jpg",
	"res://src/episode2/extras/pbr/fabric_burlap/orm.jpg",
	"res://src/episode2/extras/pbr/iron_painted/albedo.jpg",
	"res://src/episode2/extras/pbr/iron_painted/normal.jpg",
	"res://src/episode2/extras/pbr/iron_painted/orm.jpg",
	"res://src/episode2/extras/pbr/leather_brown/albedo.jpg",
	"res://src/episode2/extras/pbr/leather_brown/normal.jpg",
	"res://src/episode2/extras/pbr/leather_brown/orm.jpg",
	"res://src/episode2/extras/pbr/planks_raw/albedo.jpg",
	"res://src/episode2/extras/pbr/planks_raw/normal.jpg",
	"res://src/episode2/extras/pbr/planks_raw/orm.jpg",
	"res://src/episode2/extras/pbr/planks_weathered/albedo.jpg",
	"res://src/episode2/extras/pbr/planks_weathered/normal.jpg",
	"res://src/episode2/extras/pbr/planks_weathered/orm.jpg",
	"res://src/episode2/extras/pbr/rope/albedo.jpg",
	"res://src/episode2/extras/pbr/rope/normal.jpg",
	"res://src/episode2/extras/pbr/rope/orm.jpg",
	"res://src/episode2/extras/pbr/steel_blued/albedo.jpg",
	"res://src/episode2/extras/pbr/steel_blued/normal.jpg",
	"res://src/episode2/extras/pbr/steel_blued/orm.jpg",
	"res://src/episode2/extras/pbr/stone_dressed/albedo.jpg",
	"res://src/episode2/extras/pbr/stone_dressed/normal.jpg",
	"res://src/episode2/extras/pbr/stone_dressed/orm.jpg",
	"res://src/episode2/extras/pbr/wood_dark/albedo.jpg",
	"res://src/episode2/extras/pbr/wood_dark/normal.jpg",
	"res://src/episode2/extras/pbr/wood_dark/orm.jpg",
	"res://src/episode2/extras/pbr/wood_walnut/albedo.jpg",
	"res://src/episode2/extras/pbr/wood_walnut/normal.jpg",
	"res://src/episode2/extras/pbr/wood_walnut/orm.jpg",
	"res://src/episode2/extras/town/posters/poster_jack_hammer.jpg",
	"res://src/episode2/extras/town/posters/poster_masked_riders.jpg",
]
# --- generated: end

static var _held: Array = []
static var _next: int = 0
## Tests only: behave as the web build does on any platform.
static var force: bool = false


## Is the warm-up worth doing here? Only where the film and the build share one thread (the web export).
static func wanted() -> bool:
	return force or OS.has_feature("web")


static func done() -> bool:
	return _next >= PATHS.size()


## 0..1, for the wait's progress bar.
static func progress() -> float:
	return 1.0 if PATHS.is_empty() else float(_next) / float(PATHS.size())


## Load the next resources: always at least one, then more until `budget_ms` of this frame is spent. A resource that is not in this
## build (a streamed extra, a stripped file) is skipped; the room copes with that exactly as it does today.
static func step(budget_ms: float) -> void:
	var t0: int = Time.get_ticks_usec()
	while _next < PATHS.size():
		var path: String = PATHS[_next]
		_next += 1
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res != null:
				_held.append(res)
		if float(Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			return


## The room is built (or will not be, this run): let go. A later run from the cliff warms again; what is still alive is a cache hit.
static func release() -> void:
	_held.clear()
	_next = 0


static func held_count() -> int:
	return _held.size()
