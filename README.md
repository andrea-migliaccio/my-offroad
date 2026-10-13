# Super Off-Road — Godot 4.7 remake (enhanced)

Single-screen 3/4-view off-road truck racing in the style of the 1989 Leland
arcade, here at 960x540 with a PC-style front end: main menu, options, key
remapping, lives instead of coin-op credits and an auto-saved career.

## Play
Open the folder in Godot 4.7 and press F5, or:

    Godot_v4.7.1-stable_win64.exe --path .

The window opens at the largest whole-number scale that fits your screen; F11
(or Options > Display) switches to fullscreen (exact 2x on a 1080p monitor).

| Action | Default keys | Joypad |
|---|---|---|
| Steer | Left / Right (A / D) | D-pad / left stick |
| Gas | Up (W) | A / right trigger |
| Reverse | Down (S) | D-pad down |
| Nitro | Space (X) | B / X |
| Pause menu | Esc or P | Start |
| Fullscreen | F11 | |

Driving keys can be remapped in Options > Controls. Menus work with arrows +
Enter or with the mouse.

## Builds and releases
GitHub Actions (`.github/workflows/release.yml`) exports Windows, Linux and Web builds with Godot 4.7.1:
- push a tag starting with `v` (e.g. `git tag v2.0-enhanced && git push origin v2.0-enhanced`) to create a
  GitHub Release with `SuperOffRoad-<tag>-windows.zip`, `-linux.tar.gz` and `-web.zip`, and to publish the
  Web build on GitHub Pages;
- or run it by hand from the Actions tab ("Build & Release" > Run workflow): builds as artifacts + Pages.

GitHub Pages must be enabled once: Settings > Pages > Source: "GitHub Actions" (needs a public repo or a paid
plan). Then Settings > Environments > github-pages > deployment branches and tags: allow `enhanced` and tags `v*`.

Local export: install the 4.7.1 export templates in the editor, then
`Godot_..._console.exe --headless --path . --export-release "Windows Desktop" build/windows/SuperOffRoad.exe`
(presets: "Windows Desktop", "Linux", "Web").

## Two versions
- `enhanced` (this branch): 960x540, PC menus, 16 tracks.
- `main` (tag `v1.0-arcade`): the original 320x240 arcade-style version.

Switch with `tools\switch_version.bat main` / `tools\switch_version.bat enhanced` (add `play` to start the game).
Close Godot first. The script also reimports the assets: Godot's import cache (`.godot/`) is not in git, and
without a reimport the other branch's sprites are used (trucks drawn twice, giant flagman).
If you switch with plain `git switch`, run `Godot_..._console.exe --headless --path . --import` afterwards,
or open the project in the editor once before pressing Play.

## Rules
- 4 trucks, 3-5 laps (Options). The race ends when the first truck completes the last lap; everyone else is ranked by where they are, like the arcade.
- Prize money: $150K / $100K / $50K / $0. Money bags and nitro cans appear on the track and are worth more on later laps.
- Speed Shop between races: Nitro ($10K each), Tires, Shocks, Acceleration, Top Speed (6 levels each).
- You start with $100K and 3 lives. Finishing 4th costs a life; with no lives left it's game over and the hall of fame. Short of cash, the shop trades a life for $200K (never the last one).
- 16 tracks: Huevos Grande, Fandango, Big Dukes, Blaster, Sidewinder, Cliff Hanger, Hurricane Gulch, Wipeout and the Track-Pak set (Redoubt-About, Rio Trio, Leapin' Lizards, Shortcut, Boulder Hill, Pig Bog, Cutoff Pass, Volcano Valley), first forward, then reversed. CPU trucks get upgraded every race; grey Ivan adapts to how well you drive. Difficulty (Easy/Normal/Hard) shifts CPU skill.
- The career is saved automatically after every race and when leaving the shop (Main menu > Continue Season).

Saved files live in Godot's user folder (`%APPDATA%\Godot\app_userdata\Super Off-Road\`):
`settings.cfg`, `career.cfg`, `hall_of_fame.cfg`.

## Project layout
- `autoload/` — `GameState` (season, lives, upgrades, settings, career save, hall of fame), `Audio` (Music/SFX buses)
- `scripts/track/track.gd` — tracks from `assets/tracks.json`: distance/height/surface fields and the 3/4 heightfield background, loaded from the bake in `assets/tracks/baked/`
- `scripts/truck/` — truck physics, player input, CPU driver
- `scripts/race/` — race manager, pickups
- `scripts/ui/` — theme, HUD, menu screens, pause overlay; `scripts/main.gd` — screen flow
- `tools/` — asset generators (Blender truck renders, pixel art, track preview, bake); see `tools/README.md`
- `tests/` — headless checks

After editing `assets/tracks.json` run `tools\bake_tracks.bat` (a track whose
bake is missing or outdated is built live at load time, with a warning).
When exporting, add `*.bin` to the export filter so the baked fields are included.

## Tests

    Godot_..._console.exe --headless --path . res://tests/sim_race.tscn
    Godot_..._console.exe --headless --path . res://tests/career_test.tscn

`sim_race` runs a CPU-only race on all 32 track configurations and fails if a race
doesn't finish or a truck leaves the track (`SIM_TRACK=3,4` limits it to some tracks).
`career_test` checks save/load, lives, the life-for-cash trade and game over
(your own save and hall of fame are backed up and restored).
`res://tests/debug_stuck.tscn` reports spots where CPU trucks stop making progress.

Debug flags (after `--`): `--screen=menu|options|name|shop|race|awards|gameover|hof`,
`--race-index=N`, `--shot=out.png --shot-time=5`, `--pause`.
