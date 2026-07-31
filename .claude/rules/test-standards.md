---
paths:
  - "tests/**"
---

# Test Standards

- Test naming: `test_[system]_[scenario]_[expected_result]` pattern
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug
- In a Godot test file where multiple test functions run in sequence against
  one shared `SceneTree` (real-physics behaviour tests, not GUT-style isolated
  units): never select a spawned object by group membership alone. An earlier
  test's real-physics run can leave long-lived objects alive well past its own
  return (e.g. a 4s-lifetime projectile from a 900-physics-frame test), and a
  later test's `get_children()` search will silently pick one up as if it were
  its own. Filter by an identifier scoped to *this* test's own invocation
  (a run/volley/session ID read back from the system under test at the moment
  this test triggered it). Confirmed real bug, not hypothetical — see
  `docs/engine-reference/godot/gdscript-gotchas.md` #3.
- When a test loop needs to create N short-lived physics objects (`Area2D` +
  `CollisionShape2D`) to drive N overlaps, create all N up front and free them
  together at the end — never create/wait/`queue_free()`/create-next in a tight
  sequential loop. That exact pattern crashed Godot 4.3 itself with SIGSEGV in
  this project. See `docs/engine-reference/godot/gdscript-gotchas.md` #2.

## Examples

**Correct** (proper naming + Arrange/Act/Assert):

```gdscript
func test_health_system_take_damage_reduces_health() -> void:
    # Arrange
    var health := HealthComponent.new()
    health.max_health = 100
    health.current_health = 100

    # Act
    health.take_damage(25)

    # Assert
    assert_eq(health.current_health, 75)
```

**Incorrect**:

```gdscript
func test1() -> void:  # VIOLATION: no descriptive name
    var h := HealthComponent.new()
    h.take_damage(25)  # VIOLATION: no arrange step, no clear assert
    assert_true(h.current_health < 100)  # VIOLATION: imprecise assertion
```
