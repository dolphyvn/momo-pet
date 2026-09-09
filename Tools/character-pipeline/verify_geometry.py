"""Pipeline-side geometry verification (the generator fails loudly before
writing anything if the authored geometry violates the contract).

These are the SAME tolerances the Swift pins in MomoCharacterTests enforce
against the emitted Path constants - deliberate double entry: Python
measures the parametric source, Swift re-measures the committed constants,
and the two must agree.

Checks (normative sources in brackets):
  - section 2.1 landmark anchors within tolerance
  - ADR-001 ear rule: at-base width (the chord at the ear-root landmark
    line) >= 12% of body width, from measured numbers
  - ADR-001 rounded tips (ear width profile near the tip)
  - ADR-001 hind feet visible at rest, ground contact at y = 1000
  - pear silhouette (base-to-waist taper), R2 head/body overlap
  - glyph merge: no separate ear paths, ear bumps present above the head,
    ground contact retained
  - compound fill: overlapping compound subpaths share one winding (nonzero
    union, no cancellation holes) and pinned seam points are inside the
    filled compound
  - LOD-glance: no pupil/lid split, simplified paws
  - normalized-grid-only: every coordinate within [0, 1000]
"""

import geometry as g

TOL = {
    "body_center": 60.0,     # vs landmark (500, 640)
    "body_radius": 60.0,     # vs landmark r ~ 300
    "head_center": 40.0,     # vs landmark (500, 400)
    "eye_center": 20.0,      # vs landmarks (430, 390) / (570, 390)
    "eye_radius": 12.0,      # vs landmark r ~ 52
    "ear_root": 30.0,        # ear root inside the ear shape's inflated bbox
    "tail_anchor": 30.0,     # tail anchor near the puff
    "ground": 1.0,           # ground contact exact to a unit
}

GRID_LO, GRID_HI = 0.0, 1000.0
GRID_EPS = 0.01


def _bbox(part):
    return g.bbox(part["subpaths"])


def _fails(part_name, message, failures):
    failures.append("%s: %s" % (part_name, message))


def check_grid(parts):
    """Every coordinate of every part stays on the normalized grid."""
    failures = []
    for part in parts:
        for sp in part["subpaths"]:
            for seg in sp:
                pts = [s for s in seg[1:] if isinstance(s, tuple)]
                for (x, y) in pts:
                    if not (GRID_LO - GRID_EPS <= x <= GRID_HI + GRID_EPS
                            and GRID_LO - GRID_EPS <= y <= GRID_HI + GRID_EPS):
                        _fails(part["name"],
                               "coordinate (%.3f, %.3f) off the 1000x1000 grid"
                               % (x, y), failures)
    return failures


def check_full_rig(parts):
    failures = {}
    by_name = {p["name"]: p for p in parts}
    body = by_name["body"]
    head = by_name["head"]

    body_box = _bbox(body)
    body_cx = (body_box[0] + body_box[2]) / 2.0
    body_cy = (body_box[1] + body_box[3]) / 2.0
    body_w = body_box[2] - body_box[0]
    body_r = max(body_w, body_box[3] - body_box[1]) / 2.0
    lm = g.LANDMARKS

    if abs(body_cx - lm["body_center"][0]) > TOL["body_center"] \
            or abs(body_cy - lm["body_center"][1]) > TOL["body_center"]:
        _fails("body", "center (%.1f, %.1f) off landmark %s (tol %s)"
               % (body_cx, body_cy, lm["body_center"], TOL["body_center"]),
               failures.setdefault("landmarks", []))
    if abs(body_r - lm["body_radius"]) > TOL["body_radius"]:
        _fails("body", "radius %.1f off landmark %s (tol %s)"
               % (body_r, lm["body_radius"], TOL["body_radius"]),
               failures.setdefault("landmarks", []))

    # Pear silhouette: the base must taper - width at hip > width at waist.
    hip = g.width_at_y(body["subpaths"], 780.0)
    waist = g.width_at_y(body["subpaths"], 470.0)
    if hip < 1.25 * waist:
        _fails("body", "pear taper missing: hip %.1f vs waist %.1f"
               % (hip, waist), failures.setdefault("pear", []))

    head_box = _bbox(head)
    head_cx = (head_box[0] + head_box[2]) / 2.0
    head_cy = (head_box[1] + head_box[3]) / 2.0
    if abs(head_cx - lm["head_center"][0]) > TOL["head_center"] \
            or abs(head_cy - lm["head_center"][1]) > TOL["head_center"]:
        _fails("head", "center (%.1f, %.1f) off landmark %s"
               % (head_cx, head_cy, lm["head_center"], TOL["head_center"]),
               failures.setdefault("landmarks", []))

    # R2: head overlaps the body (one continuous creature).
    overlap = min(head_box[3], body_box[3]) - max(head_box[1], body_box[1])
    if overlap < 40.0:
        _fails("head", "head/body overlap %.1f < 40 (R2 continuity)" % overlap,
               failures.setdefault("continuity", []))

    # Eyes.
    for side, key in (("Left", "eye_left"), ("Right", "eye_right")):
        base = by_name["eye%sBase" % side]
        box = _bbox(base)
        cx, cy = (box[0] + box[2]) / 2.0, (box[1] + box[3]) / 2.0
        rx = (box[2] - box[0]) / 2.0
        want = lm[key]
        if abs(cx - want[0]) > TOL["eye_center"] or abs(cy - want[1]) > TOL["eye_center"]:
            _fails(base["name"], "center (%.1f, %.1f) off landmark %s"
                   % (cx, cy, want), failures.setdefault("landmarks", []))
        if abs(rx - lm["eye_radius"]) > TOL["eye_radius"]:
            _fails(base["name"], "radius %.1f off landmark %s"
                   % (rx, lm["eye_radius"]), failures.setdefault("landmarks", []))

    # Ears: root anchor, thickness rule, rounded tips, per-ear separation.
    for side, sign in (("Left", "ear_root_left"), ("Right", "ear_root_right")):
        ear = by_name["ear%s" % side]
        box = _bbox(ear)
        root = lm[sign]
        inflated = (box[0] - TOL["ear_root"], box[1] - TOL["ear_root"],
                    box[2] + TOL["ear_root"], box[3] + TOL["ear_root"])
        if not (inflated[0] <= root[0] <= inflated[2]
                and inflated[1] <= root[1] <= inflated[3]):
            _fails(ear["name"], "ear root %s outside the ear (tol %s)"
                   % (root, TOL["ear_root"]), failures.setdefault("ear_rule", []))

        # ADR-001 ear rule: the AT-BASE width - the chord across the ear at
        # the ear-root landmark line - not the bounding-box width, which on
        # these tilted ears is the mid-shaft maximum and overstates the base
        # (a thin, strongly tilted ear passes a bbox pin while violating the
        # rule).
        at_base_width = g.width_at_y(ear["subpaths"], root[1])
        ratio = at_base_width / body_w
        if at_base_width <= 0.0:
            _fails(ear["name"],
                   "does not cross the ear-root line y=%.0f - at-base width "
                   "unmeasurable" % root[1],
                   failures.setdefault("ear_rule", []))
        elif ratio < BODY_RULE_MIN:
            _fails(ear["name"],
                   "at-base width %.2f at the root line y=%.0f = %.2f%% of "
                   "body width %.2f < %.1f%%"
                   % (at_base_width, root[1], ratio * 100.0, body_w,
                      BODY_RULE_MIN * 100.0),
                   failures.setdefault("ear_rule", []))

        # Rounded tips: width measured down the ear must taper SLOWLY near
        # the tip (a pointed tip collapses to ~0 well before the top).
        # Reference = the ear's max (bounding-box) width: the tip profile is
        # a shape property of the shaft, independent of the at-base rule.
        tip_y = box[1]
        h = box[3] - box[1]
        max_width = box[2] - box[0]
        for frac, min_keep in ((0.10, 0.50), (0.06, 0.30)):
            w = g.width_at_y(ear["subpaths"], tip_y + frac * h)
            if w < min_keep * max_width:
                _fails(ear["name"],
                       "tip not rounded: width %.1f at %.0f%% from tip "
                       "(< %.0f%% of max width %.1f)"
                       % (w, frac * 100, min_keep * 100, max_width),
                       failures.setdefault("ear_rule", []))

    # Tail anchor.
    tail_box = _bbox(by_name["tail"])
    anchor = lm["tail_anchor"]
    if not (tail_box[0] - TOL["tail_anchor"] <= anchor[0] <= tail_box[2] + TOL["tail_anchor"]
            and tail_box[1] - TOL["tail_anchor"] <= anchor[1] <= tail_box[3] + TOL["tail_anchor"]):
        _fails("tail", "anchor %s outside the puff (tol %s)"
               % (anchor, TOL["tail_anchor"]), failures.setdefault("landmarks", []))

    # Hind feet: visible at rest, ground contact exact, connected to the body.
    ground = lm["ground_y"]
    for name in ("hindFootLeft", "hindFootRight"):
        box = _bbox(by_name[name])
        if abs(box[3] - ground) > TOL["ground"]:
            _fails(name, "bottom %.1f not on the ground line %.1f"
                   % (box[3], ground), failures.setdefault("ground", []))
        if box[1] > body_box[3] - 10.0:
            # Feet must overlap the body by >= 10 units: visible at rest
            # (ADR-001) yet connected - nothing floats (R2).
            _fails(name, "floats below the body (top %.1f vs body bottom %.1f)"
                   % (box[1], body_box[3]), failures.setdefault("ground", []))

    # Face details stay on the head.
    for name in ("mouthNeutral", "mouthEat", "mouthRefuse",
                 "cheekLeft", "cheekRight"):
        box = _bbox(by_name[name])
        if not (head_box[0] <= box[0] and box[2] <= head_box[2]
                and head_box[1] <= box[1] and box[3] <= head_box[3]):
            _fails(name, "escapes the head outline", failures.setdefault("face", []))

    # Belly patch containment.
    belly = by_name["bellyPatch"]
    pts = g.flatten(belly["subpaths"], steps=24)
    if not g.contains(body["subpaths"], pts):
        _fails("bellyPatch", "escapes the body outline",
               failures.setdefault("belly", []))

    return failures


BODY_RULE_MIN = 0.12


# ---------------------------------------------------------------------------
# Compound fill discipline (nonzero rule): overlapping subpaths of one
# compound must share ONE winding so their overlap fills as a union; an
# opposite-wound member cancels the overlap to a literal hole. The room
# window is the ONE intentional exception - its counter-wound opening is the
# hole mechanism.
# ---------------------------------------------------------------------------

HOLE_COMPOUNDS = ("window",)

# Overlap-seam points pinned as FILLED, computed from the committed geometry
# (2026-09-09 fix round): each lies strictly inside BOTH overlapping subpaths
# (verified stable across flatten resolutions 16..512; the tightest - the
# foot/body bands - keeps ~0.8 units of margin to either outline). Under the
# pre-fix mixed winding each of these summed to winding 0, i.e. a hole.
FILL_SEAM_POINTS = {
    "glyphSilhouette": [
        ((455.0, 245.0), "left ear/head overlap lens"),
        ((545.0, 245.0), "right ear/head overlap lens"),
        ((396.0, 927.65), "left hind-foot/body overlap band"),
        ((604.0, 927.65), "right hind-foot/body overlap band"),
    ],
    "food": [
        ((240.0, 952.0), "mound/bowl overlap band"),
    ],
}


def check_compound_fill(parts):
    """Two gates over every multi-subpath constant:
    - winding uniformity: all subpaths share one winding sign, except the
      named hole compounds (a degenerate zero-area subpath is ignored);
    - seam points: the pinned overlap-seam points are inside the filled
      compound (nonzero winding sum)."""
    failures = {}
    for part in parts:
        subpaths = part["subpaths"]
        if len(subpaths) < 2:
            continue
        areas = [g.signed_area(g.flatten_subpath(sp)) for sp in subpaths]
        if part["name"] not in HOLE_COMPOUNDS:
            nonzero = [a for a in areas if abs(a) > 1.0]
            mixed = nonzero and not (all(a < 0 for a in nonzero)
                                     or all(a > 0 for a in nonzero))
            if mixed:
                _fails(part["name"],
                       "compound subpaths wind inconsistently (signed areas "
                       "%s) - nonzero fill cancels overlaps to holes"
                       % ", ".join("%.0f" % a for a in areas),
                       failures.setdefault("compound_fill", []))
        for pt, label in FILL_SEAM_POINTS.get(part["name"], []):
            if not g.filled_contains(subpaths, pt):
                _fails(part["name"],
                       "seam point (%.2f, %.2f) (%s) is NOT inside the "
                       "filled compound - cancellation hole"
                       % (pt[0], pt[1], label),
                       failures.setdefault("compound_fill", []))
    return failures


def check_variants(all_parts):
    failures = {}
    by_name = {p["name"]: p for p in all_parts}

    # Glyph: ears merged - no separate ear parts; the silhouette still shows
    # the ear bumps above the head and keeps ground contact.
    glyph_names = [n for n in by_name if n.startswith("glyph")]
    if any("ear" in n.lower() for n in glyph_names):
        _fails("glyph", "glyph set carries a separate ear part: %s"
               % glyph_names, failures.setdefault("glyph", []))
    sil = by_name["glyphSilhouette"]
    sil_box = _bbox(sil)
    head_box = _bbox(by_name["head"])
    above_head = max(head_box[1] - 100.0, 10.0)
    extent = g.width_at_y(sil["subpaths"], above_head)
    if extent < 160.0:
        _fails("glyphSilhouette",
               "no merged ear bumps: extent %.1f above the head top" % extent,
               failures.setdefault("glyph", []))
    if abs(sil_box[3] - g.LANDMARKS["ground_y"]) > TOL["ground"]:
        _fails("glyphSilhouette", "lost ground contact (bottom %.1f)"
               % sil_box[3], failures.setdefault("glyph", []))
    if len(sil["subpaths"]) != 6:
        _fails("glyphSilhouette", "expected 6 merged subpaths, got %d"
               % len(sil["subpaths"]), failures.setdefault("glyph", []))

    # LOD-glance: no pupil-tracking split, simplified paws.
    lod_names = sorted(n for n in by_name if n.startswith("lod"))
    for n in lod_names:
        if "pupil" in n.lower() or "lid" in n.lower():
            _fails(n, "LOD-glance must not split the eye (pupil/lid part)",
                   failures.setdefault("lod", []))
    paws = [n for n in lod_names if "paw" in n.lower()]
    if paws != ["lodPawPair"]:
        _fails("lod", "expected exactly one simplified paw part, got %s" % paws,
               failures.setdefault("lod", []))

    return failures


def run_all_checks():
    import parts as pmod
    everything = pmod.ALL_PARTS
    failures = {}
    failures.update(check_grid(everything))
    failures.update(check_full_rig(pmod.full_rig_parts()))
    failures.update(check_variants(everything))
    failures.update(check_compound_fill(everything))
    return failures


def report(by_name):
    """Measured geometry summary for --report (budgets are in generate.py)."""
    lines = []
    body_box = _bbox(by_name["body"])
    body_w = body_box[2] - body_box[0]
    lines.append("body bbox: (%.1f, %.1f) - (%.1f, %.1f)  width %.1f"
                 % (body_box[0], body_box[1], body_box[2], body_box[3], body_w))
    for side, key in (("Left", "ear_root_left"), ("Right", "ear_root_right")):
        ear = by_name["ear%s" % side]
        box = _bbox(ear)
        max_width = box[2] - box[0]
        root_y = g.LANDMARKS[key][1]
        at_base = g.width_at_y(ear["subpaths"], root_y)
        lines.append("ear%s bbox: (%.1f, %.1f) - (%.1f, %.1f)  max (bbox) "
                     "width %.1f; at-base width at the root line y=%.0f: "
                     "%.2f = %.2f%% of body width" %
                     (side, box[0], box[1], box[2], box[3], max_width,
                      root_y, at_base, at_base / body_w * 100.0))
    sil = by_name["glyphSilhouette"]
    box = _bbox(sil)
    lines.append("glyph silhouette bbox: (%.1f, %.1f) - (%.1f, %.1f)"
                 % (box[0], box[1], box[2], box[3]))
    return lines
