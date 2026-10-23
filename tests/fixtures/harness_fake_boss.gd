extends Node
## Fixture boss for tests/harness_hooks_inert_test.gd: counts die() calls. Its script path ends in
## "harness_fake_boss.gd", which the test hands to HarnessHooks as the script suffix to aim at.
var is_dead: bool = false
var died: int = 0

func die() -> void:
	died += 1
	is_dead = true
