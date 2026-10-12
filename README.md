# puffin-platformer
SNES-style 2D platformer starring a puffin (Godot 4, web)

## Milestone 1: core movement prototype

Godot **4.7.2-stable** (GDScript, GL Compatibility renderer). Base resolution 256x224, viewport stretch, integer scaling, nearest filtering, 2D pixel snapping.

### Run locally
- **Editor:** open `project.godot` in Godot 4.x and press F5.
- **Web build:** Project > Export > Web (threads off, so it works on GitHub Pages with no COOP/COEP headers), or headless:
  `godot --headless --export-release Web build/web/index.html`
  then `cd build/web && python3 -m http.server 8080` and open http://localhost:8080. `build/` is git-ignored.

### Controls
| Action | Keyboard | Gamepad |
|---|---|---|
| Move | Arrows / A,D | D-pad / left stick |
| Jump | Z / Space / Up / W | A (bottom) |
| Run | X / Shift | X or B |
| Respawn | R | Start |

### Layout
`scenes/main.tscn` (entry), `scripts/level.gd` (ASCII gray-box level, falling out respawns you), `scripts/player.gd` (puffin controller, `Power` enum is the hook for the fish power-ups), `scripts/follow_camera.gd`, `scripts/puffin_sprite.gd` (original 16x16 placeholder art made in code), `scripts/input_setup.gd` (input map). `art/`, `audio/` are reserved.

### Tuning (exported on `Puffin`, px and seconds)
walk_speed 90, run_speed 150, ground_accel 420, ground_decel 520, skid_decel 900, air_accel 300, air_decel 120, jump_velocity -330, run_jump_bonus -25, gravity_rise 820, gravity_fall 1300, jump_cut_multiplier 0.45, max_fall_speed 300, coyote_time 0.09, jump_buffer_time 0.11. Camera: look_ahead 40, smoothing 7.
