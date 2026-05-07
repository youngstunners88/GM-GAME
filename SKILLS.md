# Lil Blunt: Skills & Progression System

## Overview

This document defines the skill progression system for Lil Blunt's prototype enhancement. Skills unlock gradually through gameplay, giving players increasing agency and making the game progressively deeper.

**Target:** 12 skills across 4 tiers, unlocked through gameplay milestones

---

## Skill Tree Structure

```
TIER 1: Movement Fundamentals (Unlocked at Start)
├── Sprint Walk
├── High Jump
└── Wall Slide

TIER 2: Power-Up Mastery (Unlocked after Level 1 Boss)
├── Blaze Dash
├── Big Smash
└── Diamond Reflection

TIER 3: Advanced Techniques (Unlocked after Level 2 + 30 coins)
├── Air Dash
├── Double Jump Extend
└── Power Combo (Blaze + Big)

TIER 4: Mastery (Unlocked after 100 Ethereum Rings)
├── Perfect Dodge
├── Momentum Banking
└── Void Protocol (Ultimate ability)
```

---

## Tier 1: Movement Fundamentals

### 1.1 Sprint Walk (STARTING SKILL)
- **Description:** Improved running speed
- **Current Value:** Walk Speed = 250 px/s
- **Enhanced Value:** Walk Speed = 320 px/s  
- **Unlock:** Available from start
- **Implementation:** Add `bool has_skill_sprint` to Player.gd
- **GDScript:**
  ```gdscript
  func get_current_speed() -> float:
      var base_speed = WALK_SPEED
      if GameManager.has_skill("sprint_walk"):
          base_speed *= 1.28
      return base_speed * get_speed_multiplier()
  ```
- **Feedback:** Dust clouds trail behind when sprinting
- **Balance:** +28% speed, minimal power (foundation skill)

### 1.2 High Jump (STARTING SKILL)
- **Description:** Increased jump force for higher reaches
- **Current Value:** Jump Force = -480 px/s
- **Enhanced Value:** Jump Force = -540 px/s
- **Unlock:** Available from start
- **Implementation:** Add `float jump_force_multiplier` to Player.gd
- **GDScript:**
  ```gdscript
  var jump_force_base = JUMP_FORCE
  if GameManager.has_skill("high_jump"):
      jump_force_base *= 1.125  # 12.5% higher
  ```
- **Feedback:** Particle burst on jump, slight slow-mo on apex
- **Balance:** +12.5% height, enables reaching new platforms

### 1.3 Wall Slide (STARTING SKILL)
- **Description:** Slow descent when holding against vertical surfaces
- **Current Value:** N/A (not implemented)
- **Enhanced Value:** Slide speed = 60 px/s (vs falling 800+ px/s)
- **Unlock:** Available from start
- **Implementation:** Add `func try_wall_slide()` to Player.gd
- **GDScript:**
  ```gdscript
  func try_wall_slide() -> void:
      if is_on_wall() and velocity.y > 0 and GameManager.has_skill("wall_slide"):
          velocity.y = lerp(velocity.y, WALL_SLIDE_SPEED, 0.15)
          # Visual: green particle trail along wall
          emit_wall_slide_particles()
  ```
- **Feedback:** Green friction particles slide effect
- **Balance:** Removes insta-death from missed jumps, enables wall-jump setups

---

## Tier 2: Power-Up Mastery

**Unlock Condition:** Defeat The Auditor (Level 1 Boss)

### 2.1 Blaze Dash
- **Description:** Enhanced Blaze mode — dash forward with smoke trail
- **Current Blaze Behavior:** Speed 1.4x, jump 1.3x, spawns smoke every 2s
- **Enhancement:** Adds dash ability — press [SHIFT] while in Blaze to dash 200px forward instantly
- **Unlock:** After defeating The Auditor boss
- **Implementation:** Add to Player.gd Blaze handling
- **GDScript:**
  ```gdscript
  func _handle_blaze_dash(delta: float) -> void:
      if Input.is_action_just_pressed("dash") and GameManager.current_power_up == "blaze" \
          and GameManager.has_skill("blaze_dash") and not dashing:
          dashing = true
          velocity.x = 200 if facing_right else -200
          emit_dash_particles()
          await get_tree().create_timer(0.3).timeout
          dashing = false
  ```
- **Feedback:** Yellow streak effect, speed sound (whoosh)
- **Balance:** Once per Blaze activation, 300ms invulnerability frame, 1s cooldown
- **Progression:** Enables dodging projectiles, reaching distance gaps

### 2.2 Big Smash
- **Description:** Enhanced Big mode — ground pound for extra damage
- **Current Big Behavior:** 1.5x scale, breaks blocks on collision
- **Enhancement:** Press [DOWN + SPACE] to smash ground, damage enemies in radius
- **Unlock:** After defeating The Auditor boss
- **Implementation:** Add to Player.gd Big handling
- **GDScript:**
  ```gdscript
  func _handle_big_smash(delta: float) -> void:
      if Input.is_action_just_pressed("down") and Input.is_action_pressed("jump") \
          and GameManager.current_power_up == "big" and GameManager.has_skill("big_smash"):
          velocity.y = 0  # Stop upward momentum
          smashing = true
          var enemies = get_tree().get_nodes_in_group("enemies")
          for enemy in enemies:
              if enemy.global_position.distance_to(global_position) < 100:
                  enemy.take_damage(1)
          emit_smash_particles()
  ```
- **Feedback:** Screenquake, radial burst particles, sound impact
- **Balance:** 150 px radius, damages 1 HP, has 1s cooldown
- **Progression:** Enables crowd control, eliminates weak enemy groups

### 2.3 Diamond Reflection
- **Description:** Enhanced Diamond mode — reflect projectiles back at enemies
- **Current Diamond Behavior:** Invincibility + damaging aura
- **Enhancement:** Incoming projectiles bounce back at attacker (Risk-reward: requires positioning)
- **Unlock:** After defeating The Auditor boss
- **Implementation:** Add to Player.gd Diamond handling
- **GDScript:**
  ```gdscript
  func _on_projectile_hit(projectile: Node) -> void:
      if GameManager.current_power_up == "diamond" and GameManager.has_skill("diamond_reflection"):
          projectile.velocity *= -1  # Reverse direction
          projectile.owner = self  # Change ownership so it damages enemies
          emit_reflection_particles()
  ```
- **Feedback:** Mirror effect on impact, crystalline chime sound
- **Balance:** Timing-based (requires being hit while facing attacker), perfect skill for boss fights
- **Progression:** Makes Diamond mode skillful, not just passive

---

## Tier 3: Advanced Techniques

**Unlock Condition:** Complete Level 2 + Collect 30 coins

### 3.1 Air Dash
- **Description:** Dash mid-air without power-up (costs 1/3 of Blaze duration if active)
- **Current Behavior:** No air movement options
- **Enhancement:** Press [SHIFT] mid-air to dash once per jump (uses Blaze meter if active)
- **Unlock:** Level 2 completion + 30 coins
- **Implementation:** Add to Player.gd advanced movement
- **GDScript:**
  ```gdscript
  func try_air_dash() -> void:
      if Input.is_action_just_pressed("dash") and not is_on_floor and can_air_dash \
          and GameManager.has_skill("air_dash"):
          can_air_dash = false
          velocity.x = 150 if facing_right else -150
          if GameManager.current_power_up == "blaze":
              GameManager.power_up_timer -= GameManager.power_up_timer * 0.33  # Use 33% of duration
          emit_air_dash_particles()
  ```
- **Feedback:** Light blue dash trail, wind sound
- **Balance:** 1 use per jump cycle, no invulnerability, momentum-based (doesn't add speed, redirects)
- **Progression:** Opens up new platforming routes, skill ceiling increases significantly

### 3.2 Double Jump Extend
- **Description:** Air-to-air jump for extended height/distance
- **Current Value:** Single jump only
- **Enhanced Value:** Jump once in air, 60% of ground jump height
- **Unlock:** Level 2 completion + 30 coins
- **Implementation:** Add to Player.gd jump system
- **GDScript:**
  ```gdscript
  func _handle_jump() -> void:
      if Input.is_action_just_pressed("jump"):
          if is_on_floor():
              velocity.y = JUMP_FORCE
              can_double_jump = true
          elif can_double_jump and GameManager.has_skill("double_jump_extend"):
              velocity.y = JUMP_FORCE * 0.6  # 60% height
              can_double_jump = false
              emit_double_jump_particles()
  ```
- **Feedback:** Spiral particle burst on second jump
- **Balance:** Resets on ground/wall-slide, 40% height penalty vs ground jump
- **Progression:** Enables complex aerial routes, skill check for hidden areas

### 3.3 Power Combo (Blaze + Big)
- **Description:** Hybrid power-up state combining Blaze and Big benefits
- **Current Behavior:** Only one power-up at a time
- **Enhancement:** If Blaze expires into Big (or vice versa) within 1s window, activate Combo
- **Unlock:** Level 2 completion + 30 coins
- **Implementation:** Add combo detection to GameManager.gd
- **GDScript:**
  ```gdscript
  func try_combo_activation(last_power_up: String, new_power_up: String) -> void:
      if GameManager.has_skill("power_combo") and combo_timer < 1.0:
          if (last_power_up == "blaze" and new_power_up == "big") or \
             (last_power_up == "big" and new_power_up == "blaze"):
              current_power_up = "combo"  # New state
              # Combo benefits: 1.6x speed + 1.3x jump + break blocks + smoke
              combo_timer = 15.0
  ```
- **Feedback:** Explosive particle effect, power-up combine sound, golden glow
- **Balance:** Very powerful (8 second duration = 15s combined), requires precise timing
- **Progression:** Reward for mastery, enables speedrun strategies

---

## Tier 4: Mastery

**Unlock Condition:** Collect 100 Ethereum Rings (requires skill to not lose rings on respawn)

### 4.1 Perfect Dodge
- **Description:** Frame-perfect dodge becomes a counter-window
- **Current Behavior:** No dodge mechanic
- **Enhancement:** While invulnerable (Diamond mode), time dodge right before hit = instant Blaze activation (5s)
- **Unlock:** 100 Ethereum Rings collected
- **Implementation:** Add to Player.gd damage system
- **GDScript:**
  ```gdscript
  func try_perfect_dodge(attacker: Node) -> bool:
      if not GameManager.has_skill("perfect_dodge"):
          return false
      
      var distance_to_attacker = global_position.distance_to(attacker.global_position)
      var time_until_hit = distance_to_attacker / attacker.get_speed()
      
      # Perfect window is last 100ms before hit
      if time_until_hit < 0.1:
          return true  # Trigger counter
      return false
  ```
- **Feedback:** Slow-mo flash, golden flash on successful dodge, "PERFECT DODGE" text
- **Balance:** Extremely high risk (requires reading enemy patterns), high reward (5s Blaze)
- **Progression:** Separates masters from casual players, speedrun essential

### 4.2 Momentum Banking
- **Description:** Falling/sliding motion charges jump height
- **Current Behavior:** Jump height is fixed
- **Enhancement:** The longer falling/sliding, the higher next jump (max 2x)
- **Unlock:** 100 Ethereum Rings collected
- **Implementation:** Add momentum meter to Player.gd
- **GDScript:**
  ```gdscript
  var momentum_meter: float = 0.0
  
  func _process(delta: float) -> void:
      if not is_on_floor() or is_wall_sliding:
          momentum_meter = min(momentum_meter + delta, 2.0)  # Max 2 seconds
      else:
          momentum_meter = 0.0
      
      if Input.is_action_just_pressed("jump") and GameManager.has_skill("momentum_banking"):
          var jump_multiplier = 1.0 + (momentum_meter / 2.0)  # 1.0x to 2.0x
          velocity.y = JUMP_FORCE * jump_multiplier
  ```
- **Feedback:** Blue charge circle that grows while falling, energy sound on jump release
- **Balance:** Rewards skillful play (managing momentum), skill ceiling very high
- **Progression:** Enables speed-running, sequence breaking in level design

### 4.3 Void Protocol (Ultimate Ability)
- **Description:** Experimental decentralized security system — consume 2 Ethereum Rings for ultimate attack
- **Current Behavior:** Ethereum Rings are just collectibles (+50 score)
- **Enhancement:** Spend 2 Ethereum Rings to spawn expanding void shockwave (damages all enemies, breaks blocks)
- **Unlock:** 100 Ethereum Rings collected (requires keeping them!)
- **Implementation:** Add to Player.gd special ability system
- **GDScript:**
  ```gdscript
  func try_void_protocol() -> void:
      if Input.is_action_just_pressed("ultimate") and GameManager.has_skill("void_protocol") \
          and GameManager.ethereum_rings_collected >= 2:
          GameManager.ethereum_rings_collected -= 2
          var shockwave = preload("res://effects/void_shockwave.tscn").instantiate()
          add_child(shockwave)
          shockwave.global_position = global_position
          shockwave.emit()
  ```
- **Feedback:** Screen-wide purple void explosion, distortion effect, bass audio hit
- **Balance:** Costs real resource (2 Ethereum = 100 points), one-time use
- **Progression:** Gives crypto collectibles strategic value, provides "get out of trouble" button

---

## Skill Unlocking Sequence

### Natural Progression Path

```
GAME START
  ↓
Player learns Tier 1 (Sprint Walk, High Jump, Wall Slide)
  ↓ (5-10 minutes gameplay)
Reach Level 1 Boss (The Auditor)
  ↓
DEFEAT AUDITOR
  ↓
Unlock Tier 2 (Blaze Dash, Big Smash, Diamond Reflection)
  ↓ (10 minutes + new Level 2)
Reach Level 2 + Collect 30 coins
  ↓
Unlock Tier 3 (Air Dash, Double Jump, Power Combo)
  ↓ (15 minutes + dedicated farming)
Collect 100 Ethereum Rings (requires master-level play)
  ↓
Unlock Tier 4 (Perfect Dodge, Momentum Banking, Void Protocol)
  ↓ (End-game content, sequence breaks, speed-run)
```

### Estimated Timeline
- **Tier 1 → Tier 2:** 15-20 minutes (story progression)
- **Tier 2 → Tier 3:** 20-30 minutes (skill check + resource farming)
- **Tier 3 → Tier 4:** 60+ minutes (mastery requirement)

---

## Implementation Checklist

### Phase 1: Skill Framework (Week 1)
- [ ] Add `skill_registry` dict to GameManager.gd
- [ ] Implement `has_skill(skill_name: String) -> bool`
- [ ] Implement `unlock_skill(skill_name: String)` 
- [ ] Create skill unlock triggers in Level.gd
- [ ] Add UI panel showing locked/unlocked skills (stretch goal)

### Phase 2: Tier 1 Skills (Week 1)
- [ ] Implement Sprint Walk (speed multiplier)
- [ ] Implement High Jump (jump force adjustment)
- [ ] Implement Wall Slide (new movement state)
- [ ] Test platforming feel with all three unlocked

### Phase 3: Tier 2 Skills (Week 2)
- [ ] Implement Blaze Dash (dash + invulnerability frames)
- [ ] Implement Big Smash (ground pound + damage)
- [ ] Implement Diamond Reflection (projectile reversal)
- [ ] Add unlock trigger: Boss defeat → Tier 2 skills

### Phase 4: Tier 3 Skills (Week 2-3)
- [ ] Implement Air Dash (mid-air movement + Blaze drain)
- [ ] Implement Double Jump Extend (double jump mechanic)
- [ ] Implement Power Combo (hybrid state system)
- [ ] Add unlock trigger: Level 2 + 30 coins → Tier 3 skills

### Phase 5: Tier 4 Skills (Week 3-4)
- [ ] Implement Perfect Dodge (timing window system)
- [ ] Implement Momentum Banking (momentum meter)
- [ ] Implement Void Protocol (resource consumption + special effect)
- [ ] Add unlock trigger: 100 Ethereum Rings → Tier 4 skills

### Phase 6: Polish & Balance (Week 4-5)
- [ ] Particle effects for all skills
- [ ] Sound effects for all skill activations
- [ ] Tutorial tooltips for skill unlocks
- [ ] Difficulty balancing based on playtester feedback

---

## Skill Design Philosophy

### Progression Principles
1. **Early skills are foundational** - Tier 1 enhances basic movement
2. **Mid-game unlocks are tactical** - Tier 2 adds power-up depth
3. **Late-game skills are mechanical** - Tier 3 enables sequence breaking
4. **End-game is mastery-based** - Tier 4 rewards frame-perfect execution

### Feedback Hierarchy
- **Visual:** Glow, particles, screen effects
- **Audio:** Distinctive sound for each skill
- **Game Feel:** Weight, momentum, impact

### Balance Strategy
- No skill is **mandatory** (all are optional enhancements)
- Each skill has a **counter** (enemy pattern reading, timing)
- **Tier 4 requires sacrifice** (Ethereum Rings = resource cost)

---

## Future Skill Expansion Ideas

### Enemy-Specific Skills (Post v1.0)
- **Tax Collector Mastery:** Reflect his charges back at him
- **Fly Swarm Rhythm:** Time jumps to split swarms
- **Vine Navigation:** Use vines as rope swing points
- **Boulder Surfing:** Ride boulders to new areas

### Power-Up Variants
- **Blaze Echo:** Split-second duplicate projectile
- **Big Overflow:** Momentary size increase beyond 1.5x
- **Diamond Fractal:** Multiply reflections

### Cosmetic Skills
- **Trail Customization:** Change particle colors per skill
- **Sound Theme:** Select audio style (chiptune vs orchestral)
- **Character Cosmetics:** Unlock Lil Blunt outfit variations

---

## Balance Metrics

| Tier | Skill | Power | Skill Ceiling | Unlock Time |
|------|-------|-------|---------------|------------|
| 1 | Sprint Walk | Low | Low | 0m |
| 1 | High Jump | Low | Low | 0m |
| 1 | Wall Slide | Medium | Medium | 0m |
| 2 | Blaze Dash | Medium | Medium | 15m |
| 2 | Big Smash | Medium | Low | 15m |
| 2 | Diamond Reflection | High | High | 15m |
| 3 | Air Dash | Medium | High | 35m |
| 3 | Double Jump | Medium | Medium | 35m |
| 3 | Power Combo | High | Medium | 35m |
| 4 | Perfect Dodge | Very High | Very High | 95m |
| 4 | Momentum Banking | High | Very High | 95m |
| 4 | Void Protocol | High | Low | 95m |

---

## Testing Checklist

- [ ] Each skill works independently
- [ ] Skills interact correctly (no conflicts)
- [ ] Unlock conditions trigger properly
- [ ] Visual/audio feedback is clear
- [ ] Performance stable with all skills active
- [ ] Difficulty curve feels natural
- [ ] Skill unlocks happen at logical story points

---

*Skills system designed for Lil Blunt v0.2 prototype*  
*Last updated: May 2026*
