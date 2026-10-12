"""Layout check for assets/tracks.json: draws every track and reports clearance.

  python tools/preview_tracks.py [out.png] [--format]

Mirrors the centerline processing of scripts/track/track.gd (Catmull-Rom,
resample, smoothing, fit). --format rewrites tracks.json in the compact style.
"""
import json
import math
import sys
from PIL import Image, ImageDraw

W, H = 960, 540
HW = 36
BANK = 9
MIN_GAP = 2 * (HW + BANK)  # banks may touch, never overlap
DS = 4.0
FIT = (60, 122, 900, 478)
TRACKS = "assets/tracks.json"


def catmull(points, steps=32):
    n = len(points)
    out = []
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                   + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    return out


def resample(poly, ds=DS):
    n = len(poly)
    seglens = [math.dist(poly[i], poly[(i + 1) % n]) for i in range(n)]
    total = sum(seglens)
    count = round(total / ds)
    step = total / count
    out = []
    seg, seg_start = 0, 0.0
    for k in range(count):
        target = k * step
        while seg_start + seglens[seg] < target and seg < n - 1:
            seg_start += seglens[seg]
            seg += 1
        u = 0 if seglens[seg] <= 0 else (target - seg_start) / seglens[seg]
        a, b = poly[seg], poly[(seg + 1) % n]
        out.append((a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u))
    return out


def smooth(pts):
    m = len(pts)
    for _ in range(3):
        pts = [(sum(pts[(i + k) % m][0] for k in range(-4, 5)) / 9, sum(pts[(i + k) % m][1] for k in range(-4, 5)) / 9)
               for i in range(m)]
    return pts


def fit(pts):
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    lo = (min(xs), min(ys))
    hi = (max(xs), max(ys))

    def rm(v, a, b, c, d):
        return c + (v - a) * (d - c) / (b - a)
    out = []
    for p in pts:
        x, y = p
        if lo[0] < FIT[0] or hi[0] > FIT[2]:
            x = rm(p[0], lo[0], hi[0], max(lo[0], FIT[0]), min(hi[0], FIT[2]))
        if lo[1] < FIT[1] or hi[1] > FIT[3]:
            y = rm(p[1], lo[1], hi[1], max(lo[1], FIT[1]), min(hi[1], FIT[3]))
        out.append((x, y))
    return out


def centerline(points):
    return fit(resample(smooth(resample(catmull(points)))))


def save_compact(data):
    lines = ["{", ' "_doc": %s,' % json.dumps(data["_doc"]), ' "tracks": [']
    for ti, t in enumerate(data["tracks"]):
        lines.append("  {")
        keys = [k for k in t.keys()]
        parts = []
        for k in keys:
            v = t[k]
            if k in ("points",):
                parts.append('   "%s": %s' % (k, json.dumps(v, separators=(",", ":"))))
            elif k in ("features", "props"):
                inner = ",\n".join("    " + json.dumps(f) for f in v)
                parts.append('   "%s": [\n%s\n   ]' % (k, inner) if v else '   "%s": []' % k)
            else:
                parts.append('   "%s": %s' % (k, json.dumps(v)))
        lines.append(",\n".join(parts))
        lines.append("  }" + ("," if ti < len(data["tracks"]) - 1 else ""))
    lines += [" ]", "}"]
    open(TRACKS, "w").write("\n".join(lines) + "\n")


def main():
    data = json.load(open(TRACKS))
    if "--format" in sys.argv:
        save_compact(data)
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cols = 4
    rows = (len(data["tracks"]) + cols - 1) // cols
    tw, th = W // 2, H // 2
    sheet = Image.new("RGB", (tw * cols, th * rows), (0, 0, 0))
    all_ok = True
    for ti, tr in enumerate(data["tracks"]):
        s = centerline(tr["points"])
        n = len(s)
        worst = 1e9
        worst_at = None
        skip = int(220 / DS)
        for i in range(0, n, 2):
            for j in range(i + skip, n, 2):
                dd = min(abs(i - j), n - abs(i - j))
                if dd > skip:
                    d = math.dist(s[i], s[j])
                    if d < worst:
                        worst, worst_at = d, s[i]
        min_r = 1e9
        for i in range(n):
            a, b, c = s[i - 6], s[i], s[(i + 6) % n]
            ab, bc, ca = math.dist(a, b), math.dist(b, c), math.dist(c, a)
            area = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2
            if area > 1e-6:
                min_r = min(min_r, ab * bc * ca / (4 * area))
        ok = worst >= MIN_GAP and min_r > HW * 0.45
        all_ok &= ok
        wa = "(%d,%d)" % worst_at if worst_at else ""
        print(f"{'OK ' if ok else 'BAD'} {tr['name']:16s} len={n * DS:6.0f} gap={worst:5.1f}{wa:>11s} minR={min_r:5.1f}")
        im = Image.new("RGB", (W, H), (54, 38, 24))
        d = ImageDraw.Draw(im)
        d.rectangle((0, 0, W, 67), fill=(60, 60, 70))
        for pr in tr.get("props", []):
            if pr["type"] == "lake":
                d.ellipse((pr["x"] - pr["rx"], pr["y"] - pr["ry"], pr["x"] + pr["rx"], pr["y"] + pr["ry"]), fill=(40, 88, 168))
            elif pr["type"] in ("rock", "volcano"):
                d.ellipse((pr["x"] - pr["r"], pr["y"] - pr["r"], pr["x"] + pr["r"], pr["y"] + pr["r"]), fill=(146, 114, 86))
        for p in s:
            r = HW + BANK
            d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=(220, 190, 90))
        for p in s:
            d.ellipse((p[0] - HW, p[1] - HW, p[0] + HW, p[1] + HW), fill=(176, 112, 56))
        cmap = {"jump": (255, 255, 255), "hill": (255, 200, 0), "bumps": (200, 80, 200), "mud": (60, 30, 10), "water": (40, 90, 200)}
        for f in tr["features"]:
            c = int(f["t"] * n) % n
            half = int(f.get("len", 72) / DS / 2)
            for k in range(c - half, c + half):
                p = s[k % n]
                d.ellipse((p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8), fill=cmap[f["type"]])
        st = s[int(tr["start_t"] * n) % n]
        nxt = s[(int(tr["start_t"] * n) + 10) % n]
        d.ellipse((st[0] - 6, st[1] - 6, st[0] + 6, st[1] + 6), fill=(0, 255, 0))
        d.line((st[0], st[1], nxt[0], nxt[1]), fill=(255, 0, 0), width=4)
        if not ok and worst_at:
            d.ellipse((worst_at[0] - 12, worst_at[1] - 12, worst_at[0] + 12, worst_at[1] + 12), outline=(255, 0, 0), width=3)
        for i, p in enumerate(tr["points"]):
            d.text((p[0] + 3, p[1] - 10), str(i), fill=(255, 255, 255))
        d.text((8, 8), tr["name"], fill=(255, 255, 255))
        sheet.paste(im.resize((tw, th)), ((ti % cols) * tw, (ti // cols) * th))
    sheet.save(args[0] if args else "_render/tracks_preview.png")
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
