# Super Off-Road — Godot 4.7 remake

Single-screen 3/4-view off-road truck racing in the style of the 1989 Leland arcade.

## Play
Open the folder in Godot 4.7 and press F5, or:

    Godot_v4.7.1-stable_win64.exe --path .

| Action | Keys | Joypad |
|---|---|---|
| Steer | Left / Right (or A / D) | D-pad / left stick |
| Gas | Up, Z or W | A / right trigger |
| Reverse | Down or S | D-pad down |
| Nitro | X or Space | B / X |
| Start / confirm | Enter | Start |
| Pause | Esc or P | Back |
| Fullscreen | F11 | |

## Rules (as in the arcade)
- 4 trucks, 4 laps. The race ends when the first truck completes lap 4; everyone else is ranked by where they are.
- Prize money: $150K / $100K / $50K / $0. Money bags and nitro cans appear on the track and are worth more on later laps.
- Speed Shop between races: Nitro ($10K each), Tires, Shocks, Acceleration, Top Speed (6 levels each).
- You start with $100K and 3 credits. Finishing 4th costs a credit. Short of cash, the shop cashes in a credit for $200K.
- 8 tracks (Huevos Grande, Fandango, Big Dukes, Blaster, Sidewinder, Cliff Hanger, Hurricane Gulch, Wipeout), first forward, then reversed. CPU trucks get upgraded every race; grey Ivan adapts to how well you drive.

## Project layout
- `autoload/` — `GameState` (season, money, upgrades, hall of fame), `Audio`
- `scripts/track/track.gd` — builds a track from `assets/tracks.json`: distance/height/surface fields and the 3/4 heightfield background
- `scripts/truck/` — truck physics, player input, CPU driver
- `scripts/race/` — race manager, pickups
- `scripts/ui/` — HUD and menu screens; `scripts/main.gd` — screen flow
- `tools/` — asset generators (Blender truck renders, pixel art, track preview); see `tools/README.md`
- `tests/` — headless checks

## Tests

    Godot_..._console.exe --headless --path . res://tests/sim_race.tscn

Runs a CPU-only race on all 16 track configurations and fails if a race doesn't finish or a truck leaves the track.
`res://tests/debug_stuck.tscn` reports spots where CPU trucks stop making progress (useful when editing tracks).

Debug flags (after `--`): `--screen=race|demo|shop|awards|title`, `--race-index=N`, `--shot=out.png --shot-time=5`.
