# TheGame

## Effects manager

Instance `scenes/Effects.tscn` as a child of the world node that contains the
platforms. Keep it at `(0, 0)`. Bind a visual child of the player, not the
physics body:

```gdscript
@onready var effects: EffectsManager = $Effects

func _ready() -> void:
	effects.bind_character($Player/Sprite2D)
```

After adding each platform to the world, connect it to the manager:

```gdscript
var platform: Platform = platform_scene.instantiate() as Platform
platform.kind = chosen_kind
platform.position = spawn_position
world.add_child(platform)
effects.connect_platform(platform)
```

Call `effects.clear_all()` when restarting a run. Other scripts can request
effects with `effects.trigger(&"sparkle", world_position)`,
`effects.trigger(&"confetti", world_position)`, `effects.trigger(&"pulse")`,
or `effects.trigger(&"flip")`.

The manager maps platform landings to cosmetic effects, limits active particles
to 400, and ignores repeated landing events from the same platform for 50 ms.
Effects do not change player velocity or collision. The visual child should have
its pivot centered for a centered flip.

| Platform kind | Effects |
| --- | --- |
| Normal or moving | Sparkle burst and character color pulse |
| Crumble | Sparkle burst and pixel emoji; shatter shards when it breaks |
| Rainbow | Sparkle burst, 40 confetti particles, color pulse, and flip |
| Glitch | Sparkle burst, pixel emoji, and cyan-tinted pulse |
| Meme | Sparkle burst, pixel emoji, and flip |

`platform_landed` handles the landing effects. The manager ignores the
`rainbow`, `glitch`, `meme`, and `crumble_start` special-effect signals to avoid
duplicating them; `crumble_break` triggers the shatter effect.

The manager pools particles and caps the active count at 400. Landing and
platform-side checks prevent duplicate effects. New pulse or flip tweens replace
the previous tween, character color is restored, and destroyed platforms have
their connection and cooldown records cleared.

## Signal architecture

| Signal | Emitted by | Emitted when | Listeners |
| --- | --- | --- | --- |
| `platform_landed(platform_type, landing_position)` | `Platform` | Once per new landing contact, before the bounce | `EffectsManager`; optional score or stats listeners |
| `platform_destroyed(platform)` | `Platform` | Once when `despawn()` removes it after a crumble break | `EffectsManager`; the generator should also remove it from its list |
| `special_effect_triggered(effect_type, effect_position)` | `Platform` | Rainbow, glitch, meme, crumble start, or crumble break | `EffectsManager` handles only `crumble_break`; landing effects cover the other events |
| `steering_modifier_requested(multiplier, duration)` | `Platform` | On a glitch landing | Informational; the player already receives this through `PlayerAdapter` |

`EffectsManager` has no signals of its own. Other scripts request effects with
`trigger(effect_type, world_pos)`.

Player integration uses direct `PlayerAdapter` method calls rather than signals:

| Adapter call | Player method |
| --- | --- |
| `PlayerAdapter.notify_landing` | `on_platform_landed(platform_type, landing_position)` (optional) |
| `PlayerAdapter.apply_default_bounce` | `apply_default_bounce()` |
| `PlayerAdapter.apply_boosted_bounce` | `apply_boosted_bounce(velocity_y)` |
| `PlayerAdapter.apply_steering_modifier` | `apply_steering_modifier(multiplier, duration)` |

A landing is handled in this order: the platform emits `platform_landed`,
notifies the player, applies the bounce, applies kind-specific extras, then
emits any `special_effect_triggered` event. Platforms do not reference the
effects manager or directly read the player's movement state.

Connect platform destruction from the generator as well as connecting effects:

```gdscript
p.platform_destroyed.connect(_on_platform_destroyed)
effects.connect_platform(p)

func _on_platform_destroyed(platform: Platform) -> void:
	active_platforms.erase(platform)
```

Each platform type is handled in `Platform._handle_landing()`. Add a matching
case to `EffectsManager` if a new type needs visual effects.

## Error handling and testing

| Safeguard | Behavior |
| --- | --- |
| Null and freed nodes | `PlayerAdapter` skips invalid targets; `EffectsManager` validates character, platform, particle, and container references |
| Landing validation | Only bodies in the `player` group with downward velocity count as landings; the sensor mask is layer 1 |
| Deferred removal | `despawn()` disables collision and monitoring deferred, emits once, then queues deletion |
| Crumble cleanup | The one-shot timer starts once; the break tween calls `despawn()` |
| Duplicate landings | Platforms track player instance IDs until sensor exit; effects also apply a 50 ms per-platform cooldown |
| Repeated destruction | `_destroyed` and queued-deletion checks prevent duplicate destroy signals |
| Temporary effects | Steering requests replace and restart the timer; visual tweens are killed before replacement |
| Delta-time updates | Moving platforms, steering timeouts, and particles use `delta` |

The meme popup is added to `get_tree().current_scene`; it disappears if that
scene changes while the popup is visible. Crumble platforms continue to bounce
the player during the 0.15-second delay before breaking.

### Automated tests

Run the test scene with F6 in the editor or use
`godot --headless --path . --scene res://tests/platform_tests.tscn`. The tests
call platform handlers directly, so they do not require physics simulation. In
headless mode, the script exits with code 1 if any test fails.

### Manual checks

1. Compare bounce height and horizontal speed with effects enabled and disabled.
2. Land repeatedly for 30 seconds; the number of `Particle` nodes should level off.
3. Call `effects.clear_all()` during an effect; particles should stop and the
   character's color and rotation should be restored.
4. Free a crumble platform during its break animation and check the Output panel
   for errors.
5. If a "player is missing method" warning appears, implement that method on the
   player script.
