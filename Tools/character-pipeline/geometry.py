"""Geometry core for the Momo character pipeline.

Pure math + shape builders over the 1000x1000 normalized design grid
(04-character-system section 2.1): y grows downward, x = 500 is the spine,
y = 1000 is the ground contact line.

Every shape is a list of subpaths; a subpath is a list of segments and a
segment is one of:
    ("M", (x, y))                       move
    ("L", (x, y))                       line
    ("Q", (cx, cy), (x, y))             quad curve
    ("C", (c1x, c1y), (c2x, c2y), (x, y))  cubic curve
    ("Z",)                              close subpath

All builders are pure functions of their arguments: the pipeline output is
byte-identical across runs (no randomness, no dict-order dependence, no wall
clock). The ONLY consumer-visible float surface is the formatter `fmt()`,
which fixes three decimals and normalizes negative zero.
"""

import math

GRID = 1000.0
KAPPA = 0.5522847498307936  # circle constant for cubic-arc approximation

# 04 section 2.1 reference landmarks (Direction C values). The pipeline's
# verify step and the Swift pins measure the exported geometry against these.
LANDMARKS = {
    "ground_y": 1000.0,
    "body_center": (500.0, 640.0),
    "body_radius": 300.0,
    "head_center": (500.0, 400.0),
    "eye_left": (430.0, 390.0),
    "eye_right": (570.0, 390.0),
    "eye_radius": 52.0,
    "ear_root_left": (440.0, 250.0),
    "ear_root_right": (560.0, 250.0),
    "tail_anchor": (720.0, 800.0),
}


def fmt(value):
    """Deterministic 3-decimal fixed-point formatting (no exponent, no -0)."""
    text = "%.3f" % (value + 0.0)
    if text == "-0.000":
        text = "0.000"
    return text


def _rot(px, py, cx, cy, sin_t, cos_t):
    dx, dy = px - cx, py - cy
    return (cx + dx * cos_t - dy * sin_t, cy + dx * sin_t + dy * cos_t)


def ellipse_subpath(cx, cy, rx, ry, rot_deg=0.0):
    """A full ellipse as four cubic arcs, optionally rotated about its center.

    Starts at the ellipse's 3-o'clock point and sweeps clockwise on screen
    (y-down space). With rot_deg = -10 the major axis tilts counterclockwise
    on screen (the Direction-C left ear posture).
    """
    sin_t = math.sin(math.radians(rot_deg))
    cos_t = math.cos(math.radians(rot_deg))

    def rp(px, py):
        return _rot(px, py, cx, cy, sin_t, cos_t)

    pts = [
        rp(cx + rx, cy),                      # 3 o'clock
        rp(cx + rx, cy + ry * KAPPA),         # handle
        rp(cx + rx * KAPPA, cy + ry),         # handle
        rp(cx, cy + ry),                      # 6 o'clock
        rp(cx - rx * KAPPA, cy + ry),         # handle
        rp(cx - rx, cy + ry * KAPPA),         # handle
        rp(cx - rx, cy),                      # 9 o'clock
        rp(cx - rx, cy - ry * KAPPA),         # handle
        rp(cx - rx * KAPPA, cy - ry),         # handle
        rp(cx, cy - ry),                      # 12 o'clock
        rp(cx + rx * KAPPA, cy - ry),         # handle
        rp(cx + rx, cy - ry * KAPPA),         # handle
    ]
    return [
        ("M", pts[0]),
        ("C", pts[1], pts[2], pts[3]),
        ("C", pts[4], pts[5], pts[6]),
        ("C", pts[7], pts[8], pts[9]),
        ("C", pts[10], pts[11], pts[0]),
        ("Z",),
    ]


def _seg_end(seg, current):
    if seg[0] in ("M", "L"):
        return seg[1]
    if seg[0] == "Q":
        return seg[2]
    if seg[0] == "C":
        return seg[3]
    return current  # "Z"


def mirrored(subpath, axis_x=500.0):
    """Mirror a subpath across a vertical axis, traversed BACKWARDS.

    Appending `mirrored(right_half)` after `right_half` continues the same
    contour: the mirror starts where the original ended and returns to the
    original's start point. Each segment is emitted as its reverse (curve
    controls swap order) with every point mirrored across the axis.
    """
    def mx(pt):
        return (2.0 * axis_x - pt[0], pt[1])

    starts = []
    current = None
    for seg in subpath:
        starts.append(current)
        current = _seg_end(seg, current)

    out = []
    for seg, seg_start in zip(reversed(subpath), reversed(starts)):
        if seg[0] == "M":
            continue  # the last reversed segment already lands here (mirrored)
        if seg[0] == "L":
            out.append(("L", mx(seg_start)))
        elif seg[0] == "Q":
            out.append(("Q", mx(seg[1]), mx(seg_start)))
        elif seg[0] == "C":
            out.append(("C", mx(seg[2]), mx(seg[1]), mx(seg_start)))
    return out


def reversed_subpath(subpath):
    """The same closed contour traversed in the OPPOSITE winding direction.

    Every emitted subpath must own its start: the reversal opens with an
    explicit move at the original start point and ends with a single close
    (no reliance on CoreGraphics current-point carryover). Each surviving
    segment is emitted as its reverse - line endpoints swap, a quad keeps its
    control, cubic controls swap order.

    Used to counter-wind shapes INSIDE a compound: overlapping subpaths that
    share one winding fill as a union under the nonzero rule, while an
    opposite-wound subpath punches a hole (the room window opening).
    """
    if not subpath or subpath[0][0] != "M":
        raise ValueError("reversed_subpath expects a subpath starting with M")
    starts = []
    current = None
    for seg in subpath:
        starts.append(current)
        current = _seg_end(seg, current)

    out = [("M", subpath[0][1])]
    for seg, seg_start in zip(reversed(subpath), reversed(starts)):
        if seg[0] in ("M", "Z"):
            continue  # the explicit move above / the single close below
        if seg[0] == "L":
            out.append(("L", seg_start))
        elif seg[0] == "Q":
            out.append(("Q", seg[1], seg_start))
        else:  # "C"
            out.append(("C", seg[2], seg[1], seg_start))
    out.append(("Z",))
    return out


def pear_body_subpath():
    """Direction-C pear body: rounded lower bulge tapering to the neck.

    Hand-tuned symmetric cubic chain anchored on the section 2.1 landmarks
    (bottom-center on the spine, neck tucked under the head outline).
    """
    right = [
        ("M", (500.0, 940.0)),
        ("C", (640.0, 940.0), (752.0, 882.0), (764.0, 800.0)),
        ("C", (776.0, 718.0), (760.0, 610.0), (712.0, 548.0)),
        ("C", (668.0, 490.0), (610.0, 448.0), (500.0, 428.0)),
    ]
    return right + mirrored(right) + [("Z",)]


def head_subpath():
    """Round head with full cheeks (ADR-001: round cheeks, no muzzle)."""
    right = [
        ("M", (500.0, 590.0)),
        ("C", (628.0, 588.0), (694.0, 520.0), (694.0, 412.0)),
        ("C", (694.0, 308.0), (626.0, 226.0), (500.0, 224.0)),
    ]
    return right + mirrored(right) + [("Z",)]


def upper_half_ellipse_subpath(cx, cy, rx, ry):
    """Upper half of an ellipse (y-down): left rim over the top to right rim,
    closed along the chord. The pre-built eye-lid shape (R1: crossfaded /
    scaled, never re-tessellated)."""
    k = KAPPA
    return [
        ("M", (cx - rx, cy)),
        ("C", (cx - rx, cy - ry * k), (cx - rx * k, cy - ry), (cx, cy - ry)),
        ("C", (cx + rx * k, cy - ry), (cx + rx, cy - ry * k), (cx + rx, cy)),
        ("Z",),
    ]


def lower_half_ellipse_subpath(cx, cy, rx, ry):
    """Lower half of an ellipse (y-down): left rim under the bottom to right
    rim, closed along the chord. The food-bowl body."""
    k = KAPPA
    return [
        ("M", (cx - rx, cy)),
        ("C", (cx - rx, cy + ry * k), (cx - rx * k, cy + ry), (cx, cy + ry)),
        ("C", (cx + rx * k, cy + ry), (cx + rx, cy + ry * k), (cx + rx, cy)),
        ("Z",),
    ]


def rounded_rect_subpath(x, y, w, h, r, rot_deg=0.0, ccw=False):
    """Rounded rectangle (optionally rotated about its center).

    ccw=True reverses the winding (explicit move, single trailing close) so
    the shape can punch a hole in an enclosing nonzero-filled path (used for
    the room window opening).
    """
    r = min(r, w / 2.0, h / 2.0)
    k = KAPPA
    cx, cy = x + w / 2.0, y + h / 2.0
    sin_t = math.sin(math.radians(rot_deg))
    cos_t = math.cos(math.radians(rot_deg))

    def rp(pt):
        return _rot(pt[0], pt[1], cx, cy, sin_t, cos_t)

    kr = k * r
    segs_cw = [
        ("M", rp((x + r, y))),
        ("L", rp((x + w - r, y))),
        ("C", rp((x + w - r + kr, y)), rp((x + w, y + r - kr)), rp((x + w, y + r))),
        ("L", rp((x + w, y + h - r))),
        ("C", rp((x + w, y + h - r + kr)), rp((x + w - r + kr, y + h)), rp((x + w - r, y + h))),
        ("L", rp((x + r, y + h))),
        ("C", rp((x + r - kr, y + h)), rp((x, y + h - r + kr)), rp((x, y + h - r))),
        ("L", rp((x, y + r))),
        ("C", rp((x, y + r - kr)), rp((x + r - kr, y)), rp((x + r, y))),
        ("Z",),
    ]
    if not ccw:
        return segs_cw
    return reversed_subpath(segs_cw)


def sparkle_subpath(cx, cy, s):
    """Four-point sparkle (concave star) as four quad curves pulled toward
    the center. Celebration/moment-scoped prop (section 2.2 props row)."""
    d = 0.14 * s
    return [
        ("M", (cx, cy - s)),
        ("Q", (cx + d, cy - d), (cx + s, cy)),
        ("Q", (cx + d, cy + d), (cx, cy + s)),
        ("Q", (cx - d, cy + d), (cx - s, cy)),
        ("Q", (cx - d, cy - d), (cx, cy - s)),
        ("Z",),
    ]


def crescent_subpath(x_left, x_right, y_base, bow, thickness):
    """A thin fillable crescent (the mouth poses: a 2-4 px curve at stage
    size). bow > 0 arcs the outer edge downward (smile), bow < 0 upward."""
    cx = (x_left + x_right) / 2.0
    inner_bow = bow - thickness if bow > 0 else bow + thickness
    return [
        ("M", (x_left, y_base)),
        ("Q", (cx, y_base + bow), (x_right, y_base)),
        ("Q", (cx, y_base + inner_bow), (x_left, y_base)),
        ("Z",),
    ]


# ---------------------------------------------------------------------------
# Measurement helpers (pipeline-side self-verification; the Swift pins
# re-measure the emitted Path constants independently - double entry).
# ---------------------------------------------------------------------------

def flatten_subpath(subpath, steps=32):
    """Polyline approximation of one subpath (cubics/quads sampled)."""
    points = []
    current = None
    for seg in subpath:
        if seg[0] == "M":
            current = seg[1]
            points.append(current)
        elif seg[0] == "L":
            current = seg[1]
            points.append(current)
        elif seg[0] == "Q":
            c, to = seg[1], seg[2]
            for i in range(1, steps + 1):
                t = i / steps
                mt = 1.0 - t
                points.append((
                    mt * mt * current[0] + 2 * mt * t * c[0] + t * t * to[0],
                    mt * mt * current[1] + 2 * mt * t * c[1] + t * t * to[1],
                ))
            current = to
        elif seg[0] == "C":
            c1, c2, to = seg[1], seg[2], seg[3]
            for i in range(1, steps + 1):
                t = i / steps
                mt = 1.0 - t
                points.append((
                    mt ** 3 * current[0] + 3 * mt * mt * t * c1[0]
                    + 3 * mt * t * t * c2[0] + t ** 3 * to[0],
                    mt ** 3 * current[1] + 3 * mt * mt * t * c1[1]
                    + 3 * mt * t * t * c2[1] + t ** 3 * to[1],
                ))
            current = to
        elif seg[0] == "Z":
            pass
    return points


def flatten(subpaths, steps=32):
    pts = []
    for sp in subpaths:
        pts.extend(flatten_subpath(sp, steps))
    return pts


def bbox(subpaths, steps=32):
    pts = flatten(subpaths, steps)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return (min(xs), min(ys), max(xs), max(ys))


def width_at_y(subpaths, y, steps=32):
    """Total x-extent of the shape's outline crossings at horizontal line y."""
    xs = []
    for sp in subpaths:
        pts = flatten_subpath(sp, steps)
        for a, b in zip(pts, pts[1:] + pts[:1]):
            if (a[1] <= y <= b[1]) or (b[1] <= y <= a[1]):
                if a[1] == b[1]:
                    xs.extend([a[0], b[0]])
                else:
                    t = (y - a[1]) / (b[1] - a[1])
                    xs.append(a[0] + t * (b[0] - a[0]))
    if not xs:
        return 0.0
    return max(xs) - min(xs)


def point_in_polygon(pt, polygon):
    """Ray-casting containment on a sampled polygon."""
    x, y = pt
    inside = False
    n = len(polygon)
    for i in range(n):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            x_cross = x1 + (y - y1) / (y2 - y1) * (x2 - x1)
            if x_cross > x:
                inside = not inside
    return inside


def signed_area(polygon):
    """Shoelace signed area of a sampled closed polygon. Sign = winding
    direction: under the y-down screen convention the builders here emit
    negative areas for the head/body/half-ellipse chains and the opposite
    sign for a plain `ellipse_subpath` (the reason compounds must reverse
    their ellipse members before filling as one union)."""
    total = 0.0
    n = len(polygon)
    for i in range(n):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % n]
        total += x1 * y2 - x2 * y1
    return total / 2.0


def winding_number(pt, polygon):
    """Signed winding number of a sampled closed polygon around `pt`."""
    x, y = pt
    wn = 0
    n = len(polygon)
    for i in range(n):
        x1, y1 = polygon[i]
        x2, y2 = polygon[(i + 1) % n]
        side = (x2 - x1) * (y - y1) - (x - x1) * (y2 - y1)
        if y1 <= y:
            if y2 > y and side > 0:
                wn += 1
        elif y2 <= y and side < 0:
            wn -= 1
    return wn


def filled_contains(subpaths, pt, steps=48):
    """Nonzero-fill containment for a COMPOUND of subpaths - the rule the
    rendered Path uses. Unlike `contains` (ray parity, single outline),
    overlapping same-winding subpaths count up: the point is inside when the
    winding numbers sum to anything but zero. This is what proves an
    overlap seam (ear/head, foot/body, mound/bowl) is filled rather than
    cancelled to a hole by mixed winding."""
    return sum(
        winding_number(pt, flatten_subpath(sp, steps)) for sp in subpaths
    ) != 0


def contains(outer_subpaths, inner_points, steps=48):
    """True when every inner point lies inside (or within eps of) the outer
    shape. Used for the belly-in-body and mouth-in-head containment checks."""
    polygon = flatten_subpath(outer_subpaths[0], steps)
    eps = 2.0
    for pt in inner_points:
        if point_in_polygon(pt, polygon):
            continue
        near = any(
            (px - pt[0]) ** 2 + (py - pt[1]) ** 2 <= eps * eps
            for px, py in polygon
        )
        if not near:
            return False
    return True
