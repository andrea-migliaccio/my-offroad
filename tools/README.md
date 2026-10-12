# Tools

Everything here is optional: the generated files are already in `assets/`.

| Script | What it does |
|---|---|
| `render_trucks.bat` | Runs Blender **headless** (no window, no MCP) to render the truck at 64 headings x 3 pitches, then converts the renders into pixel-art sheets `assets/sprites/truck_{red,yellow,blue,gray}.png` (40x40 frames). |
| `blender/render_trucks.py` | The Blender script: builds the low-poly pickup, camera and lights from scratch. Tweak sizes/colours here (`ortho_scale` sets how big the truck is in its frame). |
| `compose_trucks.py` | Downscales renders to 40x40, recolours the magenta body per team (6 tones), limits the palette, adds the dark outline. |
| `gen_pixel_art.py` | Money bag, nitro can, flagman, trophy, shop icons, nitro flame, game icon: ASCII-art maps enlarged with Scale2x/Scale3x. |
| `preview_tracks.py` | Draws all layouts from `assets/tracks.json` and checks spacing between track sections and corner radii. `--format` rewrites the JSON in the compact style. |
| `bake_tracks.bat` | Rebuilds `assets/tracks/baked/` (fields + background per track) with Godot headless. Pass ids to bake only some tracks. |
| `fetch_assets.sh` | Re-downloads the CC0/OFL sound, music and font packs into `_downloads/`. |

Requirements: Blender 5.x (path set in `render_trucks.bat`), Godot 4.7 console
executable (path set in `bake_tracks.bat`), Python 3 with Pillow (`pip install pillow`).

## Editing tracks
Tracks live in `assets/tracks.json` (960x540 screen pixels):
- `points`: closed list of centerline control points (Catmull-Rom smoothed, then fitted inside x 60-900, y 122-478);
- `start_t`: where the start line is, as a fraction of the lap;
- `features`: `jump`, `hill`, `bumps` (`len`, `h` in pixels), `mud`, `water` (`len`), placed by lap fraction `t`;
- `props` (optional, infield decoration only): `lake {x,y,rx,ry}`, `rock {x,y,r,h,mesa?}`, `volcano {x,y,r,h}`, `tires {}` (scattered tyre stacks, the default when a track has no props).

Workflow: `python tools/preview_tracks.py` (layout check, writes `_render/tracks_preview.png`),
then `tools\bake_tracks.bat <id>`, then run `tests/sim_race.tscn` with `SIM_TRACK=<id>` to make sure
CPU trucks can lap it.
