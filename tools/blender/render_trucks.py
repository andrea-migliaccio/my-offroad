"""Render the off-road pickup truck from 32 headings x 3 pitches.

Run headless (no Blender UI needed):
  blender --background --factory-startup --python tools/blender/render_trucks.py -- --out <dir>

Outputs <dir>/frame_p{pitch}_h{heading}.png at RENDER_SIZE px. The body is
painted pure magenta so tools/compose_trucks.py can recolor it per team.
Heading 0 faces screen-right, headings advance clockwise on screen (Godot y-down).
"""
import bpy
import math
import os
import sys

HEADINGS = 32
PITCHES = [0.0, 14.0, -14.0]  # flat, nose up, nose down (degrees)
RENDER_SIZE = 96
CAM_ELEVATION = 55.0  # degrees above horizon

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_dir = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(os.getcwd(), "_render")
out_dir = os.path.abspath(out_dir)
os.makedirs(out_dir, exist_ok=True)

# --- clean scene -----------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    return m


M_BODY = mat("body", (1.0, 0.0, 1.0))
M_DARK = mat("chassis", (0.10, 0.10, 0.11))
M_TIRE = mat("tire", (0.05, 0.05, 0.05))
M_RIM = mat("rim", (0.75, 0.75, 0.72))
M_GLASS = mat("glass", (0.30, 0.45, 0.60))
M_LIGHT = mat("light", (1.0, 0.95, 0.6))
M_BAR = mat("bar", (0.85, 0.85, 0.85))

root = bpy.data.objects.new("truck", None)
scene.collection.objects.link(root)


def box(name, size, loc, material):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.data.materials.append(material)
    o.parent = root
    return o


def wheel(loc):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.62, depth=0.5, location=loc,
                                        rotation=(math.radians(90), 0, 0))
    t = bpy.context.active_object
    t.data.materials.append(M_TIRE)
    t.parent = root
    side = 1 if loc[1] > 0 else -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.3, depth=0.05,
                                        location=(loc[0], loc[1] + side * 0.26, loc[2]),
                                        rotation=(math.radians(90), 0, 0))
    r = bpy.context.active_object
    r.data.materials.append(M_RIM)
    r.parent = root


# Truck faces +X. Units ~ 1 = 1/4 truck length.
box("chassis", (3.6, 1.5, 0.35), (0, 0, 0.75), M_DARK)
box("bed", (1.5, 1.7, 0.45), (-0.95, 0, 1.15), M_BODY)
box("hood", (1.3, 1.7, 0.45), (1.2, 0, 1.15), M_BODY)
box("cab", (1.0, 1.55, 0.75), (0.15, 0, 1.6), M_BODY)
box("windshield", (0.08, 1.4, 0.55), (0.66, 0, 1.6), M_GLASS)
box("roof", (1.05, 1.6, 0.08), (0.15, 0, 2.0), M_BODY)
box("rollbar", (0.12, 1.6, 0.12), (-0.6, 0, 1.75), M_BAR)
box("bumper", (0.18, 1.8, 0.25), (1.9, 0, 0.9), M_BAR)
box("lightL", (0.06, 0.3, 0.15), (1.86, 0.55, 1.2), M_LIGHT)
box("lightR", (0.06, 0.3, 0.15), (1.86, -0.55, 1.2), M_LIGHT)
for x in (1.15, -1.15):
    for y in (0.95, -0.95):
        wheel((x, y, 0.55))

# Rotate around the truck centre at wheel height so pitching looks natural.
for o in list(root.children):
    o.location.z -= 0.55
root.location.z = 0.55

# --- camera & render -------------------------------------------------------
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 5.0
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
el = math.radians(CAM_ELEVATION)
dist = 30.0
cam.location = (0, -dist * math.cos(el), dist * math.sin(el) + 0.6)
cam.rotation_euler = (math.radians(90) - el, 0, 0)
scene.camera = cam

scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = RENDER_SIZE
scene.render.resolution_y = RENDER_SIZE
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.display.render_aa = "OFF"
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "MATERIAL"
shading.show_object_outline = False
shading.show_cavity = False
shading.show_shadows = False
try:
    scene.view_settings.view_transform = "Standard"
except Exception:
    pass

for pi, pitch in enumerate(PITCHES):
    for h in range(HEADINGS):
        ang = h * 2.0 * math.pi / HEADINGS
        # Godot y-down clockwise heading -> Blender counter-clockwise negative.
        root.rotation_euler = (0.0, math.radians(-pitch), -ang)
        scene.render.filepath = os.path.join(out_dir, "frame_p%d_h%02d.png" % (pi, h))
        bpy.ops.render.render(write_still=True)

print("RENDER_DONE", out_dir)
