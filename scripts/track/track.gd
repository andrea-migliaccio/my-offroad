class_name Track
extends RefCounted
## A single-screen track defined in assets/tracks.json.
##
## Ground coordinates are screen pixels (960x540). Every pixel stores the nearest
## centerline sample, height and surface, so physics and AI query plain arrays.
## The background is rendered as a heightfield seen from a 3/4 view: a pixel of
## height h is drawn h pixels higher, with darker front faces below raised areas.
##
## Fields and background are expensive at this resolution, so they are baked by
## tests/bake_tracks.gd into assets/tracks/baked/ (always in the forward
## direction). Reversing a track only remaps sample indices at load time.

enum Surface { NONE, DIRT, MUD, WATER, BANK, INFIELD, WALL, STANDS, TIRES, ROCK }

const W := 960
const H := 540
const DS := 4.0
const HALF_WIDTH := 36.0
const BANK_WIDTH := 9.0
const BANK_HEIGHT := 9.0
const INFIELD_HEIGHT := 4.0
const OUTER_WALL_HEIGHT := 14.0
const SIDE_WALL := 8
const STANDS_BOTTOM := 56
const FIELD_TOP := 74
const FIT_RECT := Rect2(60, 122, 840, 356)
const BAKE_DIR := "res://assets/tracks/baked/"
const BAKE_VERSION := 1

const PAL := {
	Surface.DIRT: [Color8(120, 72, 36), Color8(168, 104, 52), Color8(194, 128, 68), Color8(220, 162, 98)],
	Surface.MUD: [Color8(44, 28, 14), Color8(66, 44, 24), Color8(86, 58, 32), Color8(108, 74, 42)],
	Surface.WATER: [Color8(24, 56, 120), Color8(40, 88, 168), Color8(72, 128, 208), Color8(150, 190, 240)],
	Surface.BANK: [Color8(146, 106, 36), Color8(206, 166, 66), Color8(232, 198, 98), Color8(250, 226, 140)],
	Surface.INFIELD: [Color8(54, 38, 24), Color8(78, 56, 34), Color8(98, 72, 44), Color8(120, 90, 56)],
	Surface.TIRES: [Color8(14, 14, 16), Color8(34, 34, 38), Color8(58, 58, 64), Color8(96, 96, 104)],
	Surface.WALL: [Color8(80, 80, 88), Color8(124, 124, 132), Color8(156, 156, 164), Color8(188, 188, 196)],
	Surface.ROCK: [Color8(70, 52, 40), Color8(112, 84, 62), Color8(146, 114, 86), Color8(182, 150, 118)],
}
const BOARD_W := 120
const BOARD_COLORS := [Color8(200, 30, 30), Color8(240, 240, 240), Color8(30, 60, 200), Color8(240, 200, 20)]

static var _json_cache: Array = []

var id := 0
var name := ""
var reverse := false
var features: Array = []
var props: Array = []
var start_fwd := 0  # forward sample index of the start line
var _with_tires := true  # scatter tyre stacks (default when a track has no props)

# Forward-direction centerline (as in the JSON, not rotated).
var fwd_samples := PackedVector2Array()
var fwd_tangents := PackedVector2Array()
# Race-direction centerline: index 0 is the start line.
var samples := PackedVector2Array()
var tangents := PackedVector2Array()
var length := 0.0
var _remap := PackedInt32Array()  # forward index -> race index

# Per-pixel fields (forward indices).
var near_fwd := PackedInt32Array()
var height := PackedFloat32Array()
var surface := PackedByteArray()
# Build-time only.
var _dist := PackedFloat32Array()
var _lateral := PackedFloat32Array()

var background: Texture2D
var crowd_frames: Array[Texture2D] = []


static func track_count() -> int:
	return _load_json().size()


static func track_name(track_id: int) -> String:
	return _load_json()[track_id].name


static func _load_json() -> Array:
	if _json_cache.is_empty():
		var f := FileAccess.open("res://assets/tracks.json", FileAccess.READ)
		_json_cache = JSON.parse_string(f.get_as_text()).tracks
	return _json_cache


static func _def_hash(def: Dictionary) -> int:
	return hash(JSON.stringify(def)) ^ BAKE_VERSION


## Loads a track (baked data when available) oriented for racing.
static func build(track_id: int, is_reverse: bool) -> Track:
	var t := Track.new()
	var def: Dictionary = _load_json()[track_id]
	t.id = track_id
	t.name = def.name
	t.features = def.features
	t.props = def.get("props", [])
	t._build_centerline(def)
	if not t._load_bake(def):
		push_warning("Track '%s': no up-to-date bake, building live (slow). Run tools/bake_tracks.bat." % t.name)
		t._build_fields()
		t.background = ImageTexture.create_from_image(t._render())
	t._render_crowd()
	t._orient(is_reverse)
	return t


## Builds everything from scratch and writes the bake files. Used by the bake tool.
static func bake(track_id: int) -> void:
	var t := Track.new()
	var def: Dictionary = _load_json()[track_id]
	t.id = track_id
	t.name = def.name
	t.features = def.features
	t.props = def.get("props", [])
	t._build_centerline(def)
	t._build_fields()
	var img := t._render()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAKE_DIR))
	img.save_png(BAKE_DIR + "%02d.png" % track_id)
	var hq := PackedByteArray()
	hq.resize(t.height.size())
	for i in t.height.size():
		hq[i] = clampi(int(round(t.height[i] * 4.0)) + 64, 0, 255)
	var f := FileAccess.open_compressed(BAKE_DIR + "%02d.bin" % track_id, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	f.store_var({
		"hash": _def_hash(def),
		"near": t.near_fwd,
		"height": hq,
		"surface": t.surface,
	})
	f.close()


func _load_bake(def: Dictionary) -> bool:
	var bin := BAKE_DIR + "%02d.bin" % id
	var png := BAKE_DIR + "%02d.png" % id
	if not FileAccess.file_exists(bin) or not ResourceLoader.exists(png):
		return false
	var f := FileAccess.open_compressed(bin, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var data: Dictionary = f.get_var()
	f.close()
	if data.get("hash", 0) != _def_hash(def):
		return false
	near_fwd = data.near
	surface = data.surface
	var hq: PackedByteArray = data.height
	height.resize(hq.size())
	for i in hq.size():
		height[i] = (hq[i] - 64) * 0.25
	background = load(png)
	return true


# --- centerline -------------------------------------------------------------

func _build_centerline(def: Dictionary) -> void:
	var ctrl := PackedVector2Array()
	for p in def.points:
		ctrl.append(Vector2(p[0], p[1]))
	# Catmull-Rom through control points.
	var dense := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in 32:
			var t := s / 32.0
			var t2 := t * t
			var t3 := t2 * t
			dense.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	var pts := _resample(dense, DS)
	# Soften the sharpest corners a little.
	for pass_i in 3:
		var sm := PackedVector2Array()
		var m := pts.size()
		sm.resize(m)
		for i in m:
			var acc := Vector2.ZERO
			for k in range(-4, 5):
				acc += pts[(i + k + m) % m]
			sm[i] = acc / 9.0
		pts = sm
	fwd_samples = _fit(_resample(pts, DS))
	var m := fwd_samples.size()
	length = m * DS
	fwd_tangents.resize(m)
	for i in m:
		fwd_tangents[i] = (fwd_samples[(i + 1) % m] - fwd_samples[(i - 1 + m) % m]).normalized()
	start_fwd = int(def.start_t * m) % m


## Builds the race-direction arrays: index 0 on the start line, reversed if needed.
func _orient(is_reverse: bool) -> void:
	reverse = is_reverse
	var m := fwd_samples.size()
	samples.resize(m)
	tangents.resize(m)
	_remap.resize(m)
	for f in m:
		var i := (start_fwd - f + m) % m if is_reverse else (f - start_fwd + m) % m
		_remap[f] = i
		samples[i] = fwd_samples[f]
		tangents[i] = -fwd_tangents[f] if is_reverse else fwd_tangents[f]


## Shrinks the loop (per axis) if it does not fit inside FIT_RECT.
static func _fit(pts: PackedVector2Array) -> PackedVector2Array:
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var out := PackedVector2Array()
	for p in pts:
		var q := p
		if lo.x < FIT_RECT.position.x or hi.x > FIT_RECT.end.x:
			q.x = remap(p.x, lo.x, hi.x, maxf(lo.x, FIT_RECT.position.x), minf(hi.x, FIT_RECT.end.x))
		if lo.y < FIT_RECT.position.y or hi.y > FIT_RECT.end.y:
			q.y = remap(p.y, lo.y, hi.y, maxf(lo.y, FIT_RECT.position.y), minf(hi.y, FIT_RECT.end.y))
		out.append(q)
	return out


static func _resample(poly: PackedVector2Array, ds: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var total := 0.0
	var n := poly.size()
	for i in n:
		total += poly[i].distance_to(poly[(i + 1) % n])
	var count := int(round(total / ds))
	var step := total / count
	var seg := 0
	var seg_start := 0.0
	var seg_len := poly[0].distance_to(poly[1 % n])
	for k in count:
		var target := k * step
		while seg_start + seg_len < target and seg < n - 1:
			seg_start += seg_len
			seg += 1
			seg_len = poly[seg].distance_to(poly[(seg + 1) % n])
		var u := 0.0 if seg_len <= 0.0 else (target - seg_start) / seg_len
		out.append(poly[seg].lerp(poly[(seg + 1) % n], u))
	return out


# --- fields (build / bake only) ---------------------------------------------

func _build_fields() -> void:
	_with_tires = props.is_empty() or props.any(func(q): return q.type == "tires")
	var size := W * H
	near_fwd.resize(size)
	near_fwd.fill(-1)
	_dist.resize(size)
	_dist.fill(1e9)
	_lateral.resize(size)
	_lateral.fill(0.0)
	var r := HALF_WIDTH + BANK_WIDTH + 3.0
	var r2 := r * r
	var ri := int(ceil(r))
	var m := fwd_samples.size()
	for i in m:
		var p := fwd_samples[i]
		var nrm := Vector2(-fwd_tangents[i].y, fwd_tangents[i].x)
		var cx := int(p.x)
		var cy := int(p.y)
		for y in range(maxi(0, cy - ri), mini(H, cy + ri + 1)):
			var row := y * W
			var dy := y + 0.5 - p.y
			for x in range(maxi(0, cx - ri), mini(W, cx + ri + 1)):
				var dx := x + 0.5 - p.x
				var d2 := dx * dx + dy * dy
				if d2 < r2:
					var k := row + x
					var dl := sqrt(d2)
					if dl < _dist[k]:
						_dist[k] = dl
						near_fwd[k] = i
						_lateral[k] = dx * nrm.x + dy * nrm.y

	height.resize(size)
	surface.resize(size)
	for y in H:
		for x in W:
			var k := y * W + x
			var s := Surface.INFIELD
			var h := INFIELD_HEIGHT
			if y < STANDS_BOTTOM:
				s = Surface.STANDS
				h = 0.0
			elif y < FIELD_TOP:
				s = Surface.WALL
				h = 0.0
			elif x < SIDE_WALL or x >= W - SIDE_WALL or y >= H - SIDE_WALL:
				s = Surface.WALL
				h = OUTER_WALL_HEIGHT
			elif near_fwd[k] >= 0 and _dist[k] <= HALF_WIDTH + BANK_WIDTH:
				var i := near_fwd[k]
				var fs := i * DS
				if _dist[k] <= HALF_WIDTH:
					s = Surface.DIRT
					h = 0.0
					for f in features:
						var res := _feature(f, fs, _lateral[k])
						h += res.x
						if res.y > 0.0:
							s = Surface.MUD if f.type == "mud" else Surface.WATER
				else:
					s = Surface.BANK
					var base := 0.0
					for f in features:
						if f.type == "jump" or f.type == "hill":
							base += _feature(f, fs, 0.0).x
					h = BANK_HEIGHT + base * 0.6
			if s == Surface.INFIELD:
				var pr := _prop(x, y)
				if pr.y > 0.0:
					s = int(pr.y) as Surface
					h = INFIELD_HEIGHT + pr.x
			height[k] = h
			surface[k] = s


## Infield decoration at a pixel: Vector2(extra height, surface or 0).
func _prop(x: int, y: int) -> Vector2:
	var p := Vector2(x + 0.5, y + 0.5)
	for pr in props:
		if pr.type == "tires":
			continue
		var c := Vector2(pr.x, pr.y)
		match pr.type:
			"lake":
				var e := pow((p.x - c.x) / pr.rx, 2.0) + pow((p.y - c.y) / pr.ry, 2.0)
				if e < 1.0:
					return Vector2(-3.0 * (1.0 - e), Surface.WATER)
			"rock":
				var d := p.distance_to(c)
				var rad: float = pr.r
				if d < rad:
					# Steep-sided boulder / pillar with a rounded top.
					var u := d / rad
					if pr.get("mesa", false):
						# Flat-topped plateau with steep sides.
						return Vector2(pr.h * clampf((1.0 - u) * 3.0, 0.0, 1.0), Surface.ROCK)
					var bumpy := 1.0 + 0.08 * sin(atan2(p.y - c.y, p.x - c.x) * 5.0 + pr.x)
					return Vector2(pr.h * sqrt(maxf(0.0, 1.0 - u * u * u)) * bumpy, Surface.ROCK)
			"volcano":
				var d := p.distance_to(c)
				var rad: float = pr.r
				if d < rad:
					var u := d / rad
					var h: float = pr.h * (1.0 - u)
					if u < 0.18:
						h = pr.h * (1.0 - 0.18) - (0.18 - u) * pr.h * 1.5  # crater
					return Vector2(h, Surface.ROCK)
	if _with_tires:
		var stack := _tire_stack(x, y)
		if stack > 0.0:
			return Vector2(stack, Surface.TIRES)
	return Vector2.ZERO


## Decorative stacks of tyres scattered over the infield (height, 0 if none).
func _tire_stack(x: int, y: int) -> float:
	const CELL := 64
	var cx := x / CELL
	var cy := y / CELL
	var hsh := _hash(cx + 101, cy + 37)
	if hsh % 3 != 0:
		return 0.0
	var c := Vector2(cx * CELL + 14 + hsh % (CELL - 28), cy * CELL + 14 + (hsh >> 8) % (CELL - 28))
	var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
	if d > 8.5:
		return 0.0
	# Whole stack must sit well away from the track.
	for o in [Vector2(-14, -14), Vector2(14, -14), Vector2(-14, 14), Vector2(14, 14)]:
		var q: Vector2 = c + o
		if q.x < 14 or q.y < FIELD_TOP + 8 or q.x > W - 14 or q.y > H - 18:
			return 0.0
		var k := int(q.y) * W + int(q.x)
		if near_fwd[k] >= 0 and _dist[k] < HALF_WIDTH + BANK_WIDTH + 2.0:
			return 0.0
	return 9.0 + 3.5 * sqrt(maxf(0.0, 1.0 - d * d / 72.0))


## Returns Vector2(height, is_inside_area) of a feature at forward arc length fs.
func _feature(f: Dictionary, fs: float, lat: float) -> Vector2:
	var center: float = f.t * length
	var delta := fposmod(fs - center + length * 0.5, length) - length * 0.5
	var half: float = f.get("len", 72.0) * 0.5
	var u := delta / half
	if absf(u) >= 1.0:
		return Vector2.ZERO
	match f.type:
		"jump":
			return Vector2(f.h * (1.0 - absf(u)), 0.0)
		"hill":
			return Vector2(f.h * 0.5 * (1.0 + cos(PI * u)), 0.0)
		"bumps":
			var edge := clampf((1.0 - absf(u)) * 4.0, 0.0, 1.0)
			return Vector2(f.h * 0.5 * (1.0 - cos(TAU * delta / 24.0)) * edge, 0.0)
		"mud", "water":
			var e := u * u + pow(lat / (HALF_WIDTH * 0.85), 2.0)
			if e < 1.0:
				var depth := -3.5 if f.type == "water" else -1.5
				return Vector2(depth * (1.0 - e), 1.0)
	return Vector2.ZERO


# --- queries ----------------------------------------------------------------

static func _idx(p: Vector2) -> int:
	var x := clampi(int(p.x), 0, W - 1)
	var y := clampi(int(p.y), 0, H - 1)
	return y * W + x


func surface_at(p: Vector2) -> int:
	return surface[_idx(p)]


## Race-direction index of the nearest centerline sample, or -1 far from the track.
func nearest_sample(p: Vector2) -> int:
	var f := near_fwd[_idx(p)]
	return -1 if f < 0 else _remap[f]


func height_at(p: Vector2) -> float:
	var fx := clampf(p.x - 0.5, 0.0, W - 1.001)
	var fy := clampf(p.y - 0.5, 0.0, H - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var tx := fx - x0
	var ty := fy - y0
	var k := y0 * W + x0
	var a := lerpf(height[k], height[k + 1], tx)
	var b := lerpf(height[k + W], height[k + W + 1], tx)
	return lerpf(a, b, ty)


## Arc length from the start line of the nearest centerline sample, or -1 off track.
func progress_at(p: Vector2) -> float:
	var i := nearest_sample(p)
	return -1.0 if i < 0 else i * DS


func sample_at_s(s: float) -> Vector2:
	var m := samples.size()
	var f := fposmod(s, length) / DS
	var i := int(f) % m
	return samples[i].lerp(samples[(i + 1) % m], f - int(f))


func tangent_at_s(s: float) -> Vector2:
	var m := samples.size()
	return tangents[int(fposmod(s, length) / DS) % m]


## Pushes a point of radius r back inside the track. Returns [position, wall normal]
## with the normal pointing back into the track, or Vector2.ZERO if no correction.
func constrain(p: Vector2, r: float, hint_idx: int) -> Array:
	var i := nearest_sample(p)
	if i < 0:
		i = hint_idx
	if i < 0:
		return [p, Vector2.ZERO]
	# Refine nearest sample locally (handles positions outside the stamped band).
	var m := samples.size()
	var best := i
	var best_d := p.distance_squared_to(samples[i])
	for k in range(-6, 7):
		var j := (i + k + m) % m
		var dd := p.distance_squared_to(samples[j])
		if dd < best_d:
			best_d = dd
			best = j
	var c := samples[best]
	var d := sqrt(best_d)
	var limit := HALF_WIDTH - r
	if d <= limit:
		return [p, Vector2.ZERO]
	var n := (p - c) / maxf(d, 0.001)
	return [c + n * limit, -n]


# --- rendering (build / bake only) ------------------------------------------

static func _hash(x: int, y: int) -> int:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff


func _tone(k: int, x: int, y: int) -> int:
	var hx := height[k + 1] - height[k - 1] if x > 0 and x < W - 1 else 0.0
	var hy := height[k + W] - height[k - W] if y > 0 and y < H - 1 else 0.0
	var shade := (hx + hy) * 0.9
	var t := 1
	if shade > 0.35:
		t = 2
	if shade > 1.4:
		t = 3
	if shade < -0.35:
		t = 0
	return t


func _base_color(k: int, x: int, y: int) -> Color:
	var s := surface[k]
	var t := _tone(k, x, y)
	var noise := _hash(x, y) % 16
	var i := near_fwd[k]
	match s:
		Surface.DIRT:
			# Coarse clods (2x2) plus fine grain, so the dirt reads at 960x540.
			var clod := _hash(x / 2, y / 2) % 11
			if (noise == 0 or clod == 0) and t > 0:
				t -= 1
			elif (noise == 1 or clod == 1) and t < 3:
				t += 1
			var rel := wrapi(i - start_fwd, -fwd_samples.size() / 2, fwd_samples.size() / 2)
			if absi(rel) <= 1:
				var checker := (int((_lateral[k] + 48.0) / 6.0) + (1 if rel < 0 else 0)) % 2
				return Color8(240, 240, 240) if checker == 0 else Color8(24, 24, 24)
			return PAL[s][t]
		Surface.MUD:
			if noise < 2 or _hash(x / 3, y / 3) % 9 == 0:
				return PAL[s][mini(3, t + 1)]
			return PAL[s][t]
		Surface.WATER:
			var ripple := (x / 3 + y / 2 * 3 + _hash(x / 6, y / 3) % 4) % 9 == 0
			return PAL[s][3] if ripple and noise < 8 else PAL[s][mini(t + 1, 2)]
		Surface.BANK:
			# Hay bales: dark seam every 18px along the track and on the outer edge.
			var fs := i * DS
			var along := int(fs / 18.0)
			var seam := fmod(fs, 18.0) < 2.5 or _dist[k] > HALF_WIDTH + BANK_WIDTH - 1.5
			if seam:
				return PAL[s][0]
			# Straw texture.
			if noise < 3:
				t = maxi(0, t - 1)
			return PAL[s][clampi(t + (along % 2), 0, 3)]
		Surface.INFIELD:
			if noise < 2:
				t = maxi(0, t - 1)
			elif noise == 2:
				t = mini(3, t + 1)
			return PAL[s][t]
		Surface.TIRES:
			# Concentric rings read as stacked tyres.
			return PAL[s][clampi(t + (1 if int(height[k]) % 3 == 0 else 0), 0, 3)]
		Surface.ROCK:
			if noise < 3:
				t = maxi(0, t - 1)
			return PAL[s][t]
		Surface.WALL:
			if y >= STANDS_BOTTOM and y < FIELD_TOP:
				# Advertising boards along the back wall (sponsor names are drawn by Race).
				var board := (x / BOARD_W) % BOARD_COLORS.size()
				if y <= STANDS_BOTTOM + 1 or y >= FIELD_TOP - 2 or x % BOARD_W <= 1:
					return Color8(30, 30, 34)
				return BOARD_COLORS[board]
			return PAL[s][t]
	return Color.BLACK


## Renders the background with a byte buffer (much faster than set_pixel).
func _render() -> Image:
	var buf := PackedByteArray()
	buf.resize(W * H * 4)
	var stands := _stands_image(0)
	var sd := stands.get_data()
	for k in sd.size():
		buf[k] = sd[k]
	for k in range(sd.size(), buf.size(), 4):
		buf[k] = 16
		buf[k + 1] = 12
		buf[k + 2] = 10
		buf[k + 3] = 255
	for y in range(STANDS_BOTTOM, H):
		for x in W:
			var k := y * W + x
			var sy := y - int(round(height[k]))
			var top := _base_color(k, x, y)
			if sy >= STANDS_BOTTOM - 12:
				_put(buf, x, clampi(sy, 0, H - 1), top)
			# Front face down to where the next row (nearer to the viewer) starts.
			var next_h := height[k + W] if y < H - 1 else 0.0
			var face_bottom := (y + 1) - int(round(next_h))
			if face_bottom > sy + 1:
				var face_col := top.darkened(0.45)
				for fy in range(maxi(sy + 1, STANDS_BOTTOM), mini(face_bottom, H)):
					_put(buf, x, fy, face_col)
	return Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, buf)


static func _put(buf: PackedByteArray, x: int, y: int, c: Color) -> void:
	var o := (y * W + x) * 4
	buf[o] = c.r8
	buf[o + 1] = c.g8
	buf[o + 2] = c.b8
	buf[o + 3] = 255


func _render_crowd() -> void:
	crowd_frames.clear()
	for f in 2:
		crowd_frames.append(ImageTexture.create_from_image(_stands_image(f)))


## Grandstand rows with a pixel crowd. Frame 1 bobs some heads / raises arms.
static func _stands_image(frame: int) -> Image:
	var people := [Color8(230, 60, 50), Color8(240, 220, 60), Color8(60, 120, 230), Color8(240, 240, 240),
		Color8(80, 200, 90), Color8(240, 150, 60), Color8(200, 120, 200), Color8(40, 40, 50)]
	var skin := [Color8(232, 176, 128), Color8(196, 136, 92), Color8(120, 76, 48)]
	var hair := [Color8(40, 28, 20), Color8(90, 60, 30), Color8(220, 190, 110), Color8(20, 20, 20)]
	var img := Image.create(W, STANDS_BOTTOM, false, Image.FORMAT_RGBA8)
	const ROW := 9
	for y in STANDS_BOTTOM:
		var row := y / ROW
		var in_row := y % ROW
		for x in W:
			# Step: light top edge, then seat back, then shadow.
			var c := Color8(78, 78, 90) if in_row < 7 else (Color8(110, 110, 122) if in_row == 7 else Color8(40, 40, 48))
			if row == 0:
				c = Color8(30, 30, 40) if y % 3 == 0 else Color8(36, 36, 46)  # roof shade
			else:
				var seat := (x + row * 3) / 5
				var sx := (x + row * 3) % 5
				var hsh := _hash(seat, row)
				if hsh % 6 != 0 and sx < 4:
					var bob := 1 if (hsh % 3 == 0 and frame == 1) else 0
					var py := in_row + bob
					var arms_up: bool = frame == 1 and hsh % 9 == 0
					if py == 0 and sx >= 1 and sx <= 2:
						c = hair[(hsh >> 6) % hair.size()]
					elif py >= 1 and py <= 2 and sx >= 1 and sx <= 2:
						c = skin[hsh % 3]
					elif py >= 3 and py <= 6:
						c = people[(hsh >> 4) % people.size()]
					if arms_up and in_row <= 1 and (sx == 0 or sx == 3):
						c = skin[hsh % 3]
			img.set_pixel(x, y, c)
	return img
