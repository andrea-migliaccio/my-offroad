# Tools

Everything here is optional: the generated files are already in `assets/`.

| Script | What it does |
|---|---|
| `render_trucks.bat` | Runs Blender **headless** (no window, no MCP) to render the truck at 32 headings x 3 pitches, then converts the renders into pixel-art sheets `assets/sprites/truck_{red,yellow,blue,gray}.png`. |
| `blender/render_trucks.py` | The Blender script: builds the low-poly pickup, camera and lights from scratch. Tweak sizes/colours here. |
| `compose_trucks.py` | Downscales renders to 24x24, recolours the magenta body per team, limits the palette, adds the dark outline. |
| `gen_pixel_art.py` | Money bag, nitro can, flagman, trophy, shop icons, nitro flame, game icon (ASCII-art maps). |
| `preview_tracks.py` | Draws all layouts from `assets/tracks.json` and checks spacing between track sections. |
| `fetch_assets.sh` | Re-downloads the CC0/OFL sound, music and font packs into `_downloads/`. |

Requirements: Blender 5.x (path set in `render_trucks.bat`), Python 3 with Pillow (`pip install pillow`).

## Editing tracks
Tracks live in `assets/tracks.json`: a closed list of centerline control points
(320x240 screen pixels, Catmull-Rom smoothed), `start_t` (where the start line
is, as a fraction of the lap) and `features` (`jump`, `hill`, `bumps`, `mud`,
`water`) placed by lap fraction `t`. Run `python tools/preview_tracks.py` to check
the layout, then `godot --headless --path . -s tests/render_tracks.gd` to render
the real backgrounds into `_render/`.
