#!/usr/bin/env python3
"""Writes the GDScript review bench fixtures: 12 families, each a CLEAN control and a BUGGY twin with ONE known Godot 4.3 bug.

Ground truth is known by construction (the twin differs from its control in the marked line), so nothing here is a guess about real code. Run:
    python3 tests/crouton-bench/make_gd_fixtures.py
Writes tests/crouton-bench/gd/<family>_clean.gd, <family>_bug.gd and truth.json ({file: {"bug_line": N|null, "family": f, "why": str}}).
GDScript is tab-indented in these fixtures. Add families (real regressions especially) rather than loosening the bench.
"""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent / "gd"
T = "\t"
# family: (clean, buggy, marker found only on the buggy line, why it is a bug in Godot 4.3)
FAMILIES = {
 "connect_called": (
  f"extends Node\n\n@onready var button: Button = $Button\n\nfunc _ready() -> void:\n{T}button.pressed.connect(_on_pressed)\n\nfunc _on_pressed() -> void:\n{T}print(\"pressed\")\n",
  f"extends Node\n\n@onready var button: Button = $Button\n\nfunc _ready() -> void:\n{T}button.pressed.connect(_on_pressed())\n\nfunc _on_pressed() -> void:\n{T}print(\"pressed\")\n",
  "connect(_on_pressed())", "calls the handler immediately and connects its return value (null) instead of the Callable"),
 "missing_delta": (
  f"extends CharacterBody2D\n\nconst SPEED := 120.0\n\nfunc _physics_process(delta: float) -> void:\n{T}position.x += SPEED * delta\n{T}move_and_slide()\n",
  f"extends CharacterBody2D\n\nconst SPEED := 120.0\n\nfunc _physics_process(delta: float) -> void:\n{T}position.x += SPEED\n{T}move_and_slide()\n",
  "+= SPEED\n", "movement not scaled by delta: speed depends on the physics tick rate"),
 "node_in_init": (
  f"extends Control\n\nvar label: Label\n\nfunc _ready() -> void:\n{T}label = $Label\n{T}label.text = \"GM\"\n",
  f"extends Control\n\nvar label: Label\n\nfunc _init() -> void:\n{T}label = $Label\n{T}label.text = \"GM\"\n",
  "func _init()", "$Label is resolved in _init, before the node is in the tree: label is null and .text crashes"),
 "yield_godot3": (
  f"extends Node2D\n\nfunc flash() -> void:\n{T}modulate = Color.WHITE\n{T}await get_tree().create_timer(0.2).timeout\n{T}modulate = Color.TRANSPARENT\n",
  f"extends Node2D\n\nfunc flash() -> void:\n{T}modulate = Color.WHITE\n{T}yield(get_tree().create_timer(0.2), \"timeout\")\n{T}modulate = Color.TRANSPARENT\n",
  "yield(", "yield() is Godot 3 syntax; Godot 4 uses await and this does not parse"),
 "off_by_one": (
  f"extends Node\n\nvar items: Array[String] = [\"a\", \"b\", \"c\"]\n\nfunc item_at(idx: int) -> String:\n{T}if idx >= 0 and idx < items.size():\n{T}{T}return items[idx]\n{T}return \"\"\n",
  f"extends Node\n\nvar items: Array[String] = [\"a\", \"b\", \"c\"]\n\nfunc item_at(idx: int) -> String:\n{T}if idx >= 0 and idx <= items.size():\n{T}{T}return items[idx]\n{T}return \"\"\n",
  "idx <= items.size()", "off by one: idx == size() passes the guard and reads past the end"),
 "int_division": (
  f"extends Node\n\nvar hp: int = 30\nvar max_hp: int = 100\n\nfunc health_ratio() -> float:\n{T}if max_hp <= 0:\n{T}{T}return 0.0\n{T}return float(hp) / float(max_hp)\n",
  f"extends Node\n\nvar hp: int = 30\nvar max_hp: int = 100\n\nfunc health_ratio() -> float:\n{T}if max_hp <= 0:\n{T}{T}return 0.0\n{T}return hp / max_hp\n",
  "return hp / max_hp", "integer division: 30 / 100 is 0, so the health bar ratio is always 0 until full"),
 "variant_infer": (
  f"extends Node\n\nvar config: Dictionary = {{\"speed\": 2.0}}\n\nfunc get_speed() -> float:\n{T}var speed: float = config.get(\"speed\", 1.0)\n{T}return speed * 2.0\n",
  f"extends Node\n\nvar config: Dictionary = {{\"speed\": 2.0}}\n\nfunc get_speed() -> float:\n{T}var speed := config.get(\"speed\", 1.0)\n{T}return speed * 2.0\n",
  "var speed :=", ":= infers from a Variant return, which Godot 4.3 treats as a hard error (the repo's export gate rejects it)"),
 "missing_arg": (
  f"extends Node\n\nfunc take_damage(amount: int) -> void:\n{T}print(\"hit for %d\" % amount)\n\nfunc _ready() -> void:\n{T}take_damage(5)\n",
  f"extends Node\n\nfunc take_damage(amount: int) -> void:\n{T}print(\"hit for %d\" % amount)\n\nfunc _ready() -> void:\n{T}take_damage()\n",
  "take_damage()\n", "take_damage() is called without its required argument"),
 "erase_while_iterating": (
  f"extends Node\n\nvar enemies: Array = []\n\nfunc prune_dead() -> void:\n{T}for e in enemies.duplicate():\n{T}{T}if e.health <= 0:\n{T}{T}{T}enemies.erase(e)\n",
  f"extends Node\n\nvar enemies: Array = []\n\nfunc prune_dead() -> void:\n{T}for e in enemies:\n{T}{T}if e.health <= 0:\n{T}{T}{T}enemies.erase(e)\n",
  "for e in enemies:", "erasing from the array being iterated skips the element after each removal"),
 "signal_typo": (
  f"extends Node\n\nsignal health_changed(hp: int)\n\nvar hp: int = 10\n\nfunc hurt(n: int) -> void:\n{T}hp -= n\n{T}health_changed.emit(hp)\n",
  f"extends Node\n\nsignal health_changed(hp: int)\n\nvar hp: int = 10\n\nfunc hurt(n: int) -> void:\n{T}hp -= n\n{T}emit_signal(\"helth_changed\", hp)\n",
  "helth_changed", "the signal name is misspelled, so nothing listening to health_changed is ever notified (and Godot logs an error)"),
 "timer_before_tree": (
  f"extends Node\n\nfunc start_cooldown() -> void:\n{T}var t := Timer.new()\n{T}t.one_shot = true\n{T}add_child(t)\n{T}t.start(1.0)\n",
  f"extends Node\n\nfunc start_cooldown() -> void:\n{T}var t := Timer.new()\n{T}t.one_shot = true\n{T}t.start(1.0)\n{T}add_child(t)\n",
  "t.start(1.0)\n", "Timer.start() before the timer is in the tree fails (\"Timer was not added to the SceneTree\")"),
 "change_scene_godot3": (
  f"extends Node\n\nfunc go_menu() -> void:\n{T}get_tree().change_scene_to_file(\"res://src/ui/main_menu.tscn\")\n",
  f"extends Node\n\nfunc go_menu() -> void:\n{T}get_tree().change_scene(\"res://src/ui/main_menu.tscn\")\n",
  ".change_scene(", "change_scene() was removed in Godot 4; it is change_scene_to_file()"),
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    truth = {}
    for fam, (clean, bug, marker, why) in FAMILIES.items():
        lines_bug = bug.splitlines(keepends=True)
        hits = [i + 1 for i, l in enumerate(lines_bug) if marker in l]
        clean_hits = [i + 1 for i, l in enumerate(clean.splitlines(keepends=True)) if marker in l]
        assert hits and hits[0] not in clean_hits, f"{fam}: the marked line must differ between the clean control and the buggy twin"
        (OUT / f"{fam}_clean.gd").write_text(clean, encoding="utf-8")
        (OUT / f"{fam}_bug.gd").write_text(bug, encoding="utf-8")
        truth[f"{fam}_clean.gd"] = {"bug_line": None, "family": fam, "why": "clean control"}
        truth[f"{fam}_bug.gd"] = {"bug_line": hits[0], "family": fam, "why": why}
    (OUT / "truth.json").write_text(json.dumps(truth, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {len(FAMILIES) * 2} fixtures and truth.json to {OUT}")


if __name__ == "__main__":
    main()
