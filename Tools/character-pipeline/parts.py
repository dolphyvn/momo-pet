"""The Direction-C "Round Rabbit" rig, variants, room and props.

THIS FILE IS THE GEOMETRY SOURCE OF TRUTH. The generated Swift Path constants
and the evidence renders are projections of the part tables below; re-running
the pipeline reproduces them byte-identically. A future human vector-tool pass
replaces these parametric definitions WITHOUT touching any consumer of the
generated constants (04 section 8.2 authoring posture).

Normative sources:
  - 04-character-system section 2.1 (1000x1000 grid + Direction-C landmarks)
  - 04-character-system section 2.2 (the rig model, layer groups, R1-R4)
  - ADR-001 (ear >= 12% of body width at base with rounded tips; per-ear
    rotation channels as separate parts; puff tail; hind feet visible at
    rest; glyph merges ears below ~32 pt; no bounce-loops anywhere)
  - 04 section 8.4 (naming law), 8.5 (Phase-1 manifest)

Part accounting (the reviewer's re-derivation should land here):
  section 2.2 counting basis = body(1) + belly(1) + head(1) + ears(2)
  + tail(1) + eyes(6) + mouth counted once as a 3-pose slot(1) + cheeks(2)
  + front paws(2) = 17 parts. ADR-001's Direction-C delta adds the two hind
  feet as static body-group anatomy -> 19 counted parts. The full rig emits
  21 Path constants because the mouth slot ships its 3 pre-built poses.
"""

import math

import geometry as g

# ---------------------------------------------------------------------------
# Shared geometry parameters (single-sourced; emitters and verifiers read
# these, never their own copies).
# ---------------------------------------------------------------------------

BODY = {
    "width": 536.0,          # measured max body width (bbox 232..768)
    "base_width_rule": 0.12, # ADR-001: ear base >= 12% of body width
}
HEAD_CENTER = (500.0, 407.0)
EYE_RADIUS_X = 50.0         # landmark eye radius ~52 (pinned 40..64)
EYE_RADIUS_Y = 56.0
EYE_LID_LIFT = 30.0         # rest pose: lid sits above the pupil line, so it
                            # trims only the eye's top arc (calm, not sleepy);
                            # blink/aperture scales it down over the base (R1)
EAR_HALF_WIDTH = 58.0       # ear shaft width (the mid-shaft maximum); the
                            # ADR-001 base rule is measured as the at-base
                            # chord at the ear-root landmark line instead
                            # (verify_geometry), never from this constant
EAR_HALF_LENGTH = 110.0     # ear total length 220 ~ 60% of head height
EAR_TILT_DEG = 10.0         # calm perked posture, tips leaning outward
BELLY = {"cx": 500.0, "cy": 764.0, "rx": 186.0, "ry": 150.0}  # clears the feet
TAIL = {"cx": 778.0, "cy": 796.0, "rx": 52.0, "ry": 56.0}     # exposed puff
FOOT = {"cx_left": 370.0, "cx_right": 630.0, "cy": 962.0,
        "rx": 68.0, "ry": 38.0}   # bottom edge lands on y = 1000
PAW = {"cx_left": 447.0, "cx_right": 553.0, "cy": 894.0,
       "rx": 44.0, "ry": 28.0}    # resting ON the belly's lower front


def _ear(rot_sign):
    """One ear: a thick rotated oval rooted on the section 2.1 ear-root
    landmark, tip capped by the ellipse itself (ADR-001 rounded tips).
    rot_sign -1 = left ear (tips lean outward-left), +1 = right."""
    root = g.LANDMARKS["ear_root_left"] if rot_sign < 0 else g.LANDMARKS["ear_root_right"]
    sin_t = math.sin(math.radians(EAR_TILT_DEG))
    cos_t = math.cos(math.radians(EAR_TILT_DEG))
    # Center sits up the ear axis from the root; overlap keeps the base inside
    # the head outline (R2: one continuous creature - nothing floats).
    overlap = 18.0
    cx = root[0] + rot_sign * sin_t * (EAR_HALF_LENGTH - overlap)
    cy = root[1] - cos_t * (EAR_HALF_LENGTH - overlap)
    return g.ellipse_subpath(cx, cy, EAR_HALF_WIDTH, EAR_HALF_LENGTH,
                             rot_deg=rot_sign * EAR_TILT_DEG)


# ---------------------------------------------------------------------------
# Part tables. Each part: name, group, channels doc, doc, subpaths.
# ---------------------------------------------------------------------------

def _part(name, group, channels, doc, subpaths):
    return {
        "name": name,
        "group": group,
        "channels": channels,
        "doc": doc,
        "subpaths": subpaths,
    }


def full_rig_parts():
    """The full iPhone rig: all section 2.2 parts + ADR-001 hind feet."""
    eye_l = g.LANDMARKS["eye_left"]
    eye_r = g.LANDMARKS["eye_right"]
    return [
        _part(
            "body", "Body",
            "scaleY/X (breath, squash), rotation (lean/rock), position (hop, settle)",
            "Pear body (ADR-001). Bottom-center anchor on the spine; ground "
            "contact is carried by the hind feet, not the body outline.",
            [g.pear_body_subpath()],
        ),
        _part(
            "bellyPatch", "Body",
            "static; rides the Body transform",
            "Belly patch - the lower-front lighter zone (IV-5: never a state "
            "channel).",
            [g.ellipse_subpath(BELLY["cx"], BELLY["cy"], BELLY["rx"], BELLY["ry"])],
        ),
        _part(
            "hindFootLeft", "Body",
            "static; rides the Body transform",
            "Hind foot, visible at rest (ADR-001 Direction-C delta). Bottom "
            "edge lands exactly on the ground line y = 1000.",
            [g.ellipse_subpath(FOOT["cx_left"], FOOT["cy"], FOOT["rx"], FOOT["ry"])],
        ),
        _part(
            "hindFootRight", "Body",
            "static; rides the Body transform",
            "Hind foot, visible at rest (ADR-001 Direction-C delta). Bottom "
            "edge lands exactly on the ground line y = 1000.",
            [g.ellipse_subpath(FOOT["cx_right"], FOOT["cy"], FOOT["rx"], FOOT["ry"])],
        ),
        _part(
            "head", "Head",
            "rotation (tilt +/-6 deg), position (bob, lean-in), scaleY (settle squash)",
            "Round head with full cheeks (ADR-001); overlaps the body so the "
            "creature reads as one continuous form (R2).",
            [g.head_subpath()],
        ),
        _part(
            "earLeft", "Ears",
            "rotation (-25..+25 deg), scaleY (twitch)",
            "Left ear - thick short-to-medium oval, rounded tip, calm perked "
            "posture. Separate part: per-ear rotation is an expression "
            "channel (ADR-001).",
            [_ear(-1)],
        ),
        _part(
            "earRight", "Ears",
            "rotation (-25..+25 deg), scaleY (twitch)",
            "Right ear - mirror of the left. Separate part: asymmetry "
            "(one-up-one-down) is a deliberate expression state (ADR-001).",
            [_ear(+1)],
        ),
        _part(
            "tail", "Tail",
            "rotation (metronome +/-10 deg), scaleY (flick)",
            "Puff tail anchored near the section 2.1 tail anchor, peeking "
            "past the body's right edge (ADR-001 puff tail).",
            [g.ellipse_subpath(TAIL["cx"], TAIL["cy"], TAIL["rx"], TAIL["ry"])],
        ),
        _part(
            "eyeLeftBase", "Eyes",
            "static base; the eye group carries lid scaleY + pupil offset",
            "Left eye base (the iris oval, section 2.1 eye landmark).",
            [g.ellipse_subpath(eye_l[0], eye_l[1], EYE_RADIUS_X, EYE_RADIUS_Y)],
        ),
        _part(
            "eyeLeftPupil", "Eyes",
            "pupil offset (gaze, clamped to 30% of eye radius - section 2.4)",
            "Left pupil at its neutral, centered pose; gaze offsets apply as "
            "render-time transforms (R1).",
            [g.ellipse_subpath(eye_l[0], eye_l[1], 23.0, 25.0)],
        ),
        _part(
            "eyeLeftLid", "Eyes",
            "lid scaleY (blink/aperture), anchored at the eye's top",
            "Left lid - the pre-built upper-lid half-oval; at rest it "
            "sits above the pupil line and trims only the eye's top arc "
            "(calm aperture). Blink and aperture scale it over the base, "
            "never re-tessellate (R1).",
            [g.upper_half_ellipse_subpath(eye_l[0], eye_l[1] - EYE_LID_LIFT, EYE_RADIUS_X + 2.0, EYE_RADIUS_Y)],
        ),
        _part(
            "eyeRightBase", "Eyes",
            "static base; the eye group carries lid scaleY + pupil offset",
            "Right eye base (the iris oval, section 2.1 eye landmark).",
            [g.ellipse_subpath(eye_r[0], eye_r[1], EYE_RADIUS_X, EYE_RADIUS_Y)],
        ),
        _part(
            "eyeRightPupil", "Eyes",
            "pupil offset (gaze, clamped to 30% of eye radius - section 2.4)",
            "Right pupil at its neutral, centered pose; gaze offsets apply "
            "as render-time transforms (R1).",
            [g.ellipse_subpath(eye_r[0], eye_r[1], 23.0, 25.0)],
        ),
        _part(
            "eyeRightLid", "Eyes",
            "lid scaleY (blink/aperture), anchored at the eye's top",
            "Right lid - the pre-built upper-lid half-oval, resting above "
            "the pupil line like the left.",
            [g.upper_half_ellipse_subpath(eye_r[0], eye_r[1] - EYE_LID_LIFT, EYE_RADIUS_X + 2.0, EYE_RADIUS_Y)],
        ),
        _part(
            "mouthNeutral", "FaceDetails",
            "opacity/swap (pre-built pose shapes - never re-tessellated, R1)",
            "Neutral mouth: a subtle small crescent (the resting face reads "
            "calm; section 1.3 keeps the mouth for eating/refusal).",
            [g.crescent_subpath(490.0, 510.0, 465.0, bow=9.0, thickness=4.0)],
        ),
        _part(
            "mouthEat", "FaceDetails",
            "opacity/swap (pre-built pose shapes - never re-tessellated, R1)",
            "Eating mouth: a small open oval (nibbling pose).",
            [g.ellipse_subpath(500.0, 471.0, 13.0, 9.0)],
        ),
        _part(
            "mouthRefuse", "FaceDetails",
            "opacity/swap (pre-built pose shapes - never re-tessellated, R1)",
            "Refusing mouth: a gentle downturned crescent (the warm refusal "
            "register - never a sad face, INV-6).",
            [g.crescent_subpath(490.0, 510.0, 469.0, bow=-8.0, thickness=4.0)],
        ),
        _part(
            "cheekLeft", "FaceDetails",
            "opacity (celebration-only - section 2.2 face-details row)",
            "Left cheek accent, celebration moments only (INV-5: never a "
            "state channel).",
            [g.ellipse_subpath(398.0, 450.0, 32.0, 22.0)],
        ),
        _part(
            "cheekRight", "FaceDetails",
            "opacity (celebration-only - section 2.2 face-details row)",
            "Right cheek accent, celebration moments only (INV-5).",
            [g.ellipse_subpath(602.0, 450.0, 32.0, 22.0)],
        ),
        _part(
            "pawLeft", "FrontPaws",
            "position/rotation (peek, pat, refuse-raise)",
            "Left front paw resting on the belly's lower front, clear of "
            "the hind feet at rest.",
            [g.ellipse_subpath(PAW["cx_left"], PAW["cy"], PAW["rx"], PAW["ry"])],
        ),
        _part(
            "pawRight", "FrontPaws",
            "position/rotation (peek, pat, refuse-raise)",
            "Right front paw resting on the belly's lower front, clear of "
            "the hind feet at rest.",
            [g.ellipse_subpath(PAW["cx_right"], PAW["cy"], PAW["rx"], PAW["ry"])],
        ),
    ]


def lod_glance_parts():
    """LOD-glance variant (Watch foreground, section 8.5): the reduced layer
    set - no pupil-tracking split (one eye shape per eye, no lids), paws
    simplified into one merged, non-animated pair shape. Ears stay separate
    parts (the per-ear channel is core expression, not a detail)."""
    eye_l = g.LANDMARKS["eye_left"]
    eye_r = g.LANDMARKS["eye_right"]
    return [
        _part(
            "lodBody", "LODGlance", "static LOD layer",
            "LOD-glance body - same pear as the full rig (shared builders).",
            [g.pear_body_subpath()],
        ),
        _part(
            "lodBellyPatch", "LODGlance", "static LOD layer",
            "LOD-glance belly patch.",
            [g.ellipse_subpath(BELLY["cx"], BELLY["cy"], BELLY["rx"], BELLY["ry"])],
        ),
        _part(
            "lodHead", "LODGlance", "static LOD layer",
            "LOD-glance head.",
            [g.head_subpath()],
        ),
        _part(
            "lodEarLeft", "LODGlance",
            "rotation per ear retained (expression channel)",
            "LOD-glance left ear - ears stay separate at Watch stage size "
            "(60-80 pt keeps the thickness rule legible, ADR-001).",
            [_ear(-1)],
        ),
        _part(
            "lodEarRight", "LODGlance",
            "rotation per ear retained (expression channel)",
            "LOD-glance right ear.",
            [_ear(+1)],
        ),
        _part(
            "lodTail", "LODGlance", "rotation (metronome) retained",
            "LOD-glance puff tail.",
            [g.ellipse_subpath(TAIL["cx"], TAIL["cy"], TAIL["rx"], TAIL["ry"])],
        ),
        _part(
            "lodHindFootLeft", "LODGlance", "static LOD layer",
            "LOD-glance hind foot (ADR-001 rest posture).",
            [g.ellipse_subpath(FOOT["cx_left"], FOOT["cy"], FOOT["rx"], FOOT["ry"])],
        ),
        _part(
            "lodHindFootRight", "LODGlance", "static LOD layer",
            "LOD-glance hind foot (ADR-001 rest posture).",
            [g.ellipse_subpath(FOOT["cx_right"], FOOT["cy"], FOOT["rx"], FOOT["ry"])],
        ),
        _part(
            "lodEyeLeft", "LODGlance", "static LOD layer",
            "LOD-glance left eye - a single shape: the pupil-tracking split "
            "is removed below the iPhone tier (section 8.5).",
            [g.ellipse_subpath(eye_l[0], eye_l[1], EYE_RADIUS_X, EYE_RADIUS_Y)],
        ),
        _part(
            "lodEyeRight", "LODGlance", "static LOD layer",
            "LOD-glance right eye - single shape, no pupil split.",
            [g.ellipse_subpath(eye_r[0], eye_r[1], EYE_RADIUS_X, EYE_RADIUS_Y)],
        ),
        _part(
            "lodPawPair", "LODGlance", "static LOD layer",
            "Simplified paws: one merged, non-animated pair shape (section "
            "8.5 'simplified paws') - two subpaths in a single Path.",
            [
                g.ellipse_subpath(PAW["cx_left"], PAW["cy"], PAW["rx"], PAW["ry"]),
                g.ellipse_subpath(PAW["cx_right"], PAW["cy"], PAW["rx"], PAW["ry"]),
            ],
        ),
    ]


def glyph_parts():
    """Glyph variant (complication/AOD, section 8.5 + ADR-001): the
    silhouette-preserving simplification. The ears are MERGED into the
    outline: the silhouette is one compound Path whose overlapping subpaths
    fill as a single union (ears can no longer rotate - that is the merge).
    Pear silhouette landmarks are retained (ground contact, ear bumps)."""
    head = g.head_subpath()
    body = g.pear_body_subpath()
    # Winding discipline for the compound union: the head/body chains sweep
    # opposite to a plain ellipse_subpath, so every overlapping ellipse member
    # (ears, hind feet) is reversed to match. Under the nonzero fill rule,
    # mixed winding would cancel the ear-head and foot-body overlaps to
    # literal holes in the merged silhouette (verified_geometry's compound
    # fill check pins the seams as filled).
    ear_l = g.reversed_subpath(_ear(-1))
    ear_r = g.reversed_subpath(_ear(+1))
    foot_l = g.reversed_subpath(
        g.ellipse_subpath(FOOT["cx_left"], FOOT["cy"], FOOT["rx"], FOOT["ry"]))
    foot_r = g.reversed_subpath(
        g.ellipse_subpath(FOOT["cx_right"], FOOT["cy"], FOOT["rx"], FOOT["ry"]))
    return [
        _part(
            "glyphSilhouette", "Glyph", "static; fills as one union (nonzero)",
            "Glyph silhouette: head + pear body + both ears + both hind feet "
            "as one compound Path. Ears are merged into the outline (ADR-001 "
            "below ~32 pt) while the pear silhouette and ground contact are "
            "retained.",
            [head, body, ear_l, ear_r, foot_l, foot_r],
        ),
        _part(
            "glyphEyeLeft", "Glyph", "static; opacity-carrying dot",
            "Glyph left eye - a simple dot that keeps the face legible at "
            "24-32 pt.",
            [g.ellipse_subpath(432.0, 386.0, 40.0, 44.0)],
        ),
        _part(
            "glyphEyeRight", "Glyph", "static; opacity-carrying dot",
            "Glyph right eye.",
            [g.ellipse_subpath(568.0, 386.0, 40.0, 44.0)],
        ),
    ]


def room_parts():
    """The static room (section 8.5: charming, non-interactive). Two bundled
    groups per the section 8.4 data names: `momo.room.base` (floor, rug,
    window) and `momo.room.pom` (string + puff of the hanging pom decor)."""
    return [
        _part(
            "floor", "Room.base", "static room decor",
            "Room floor band; top corners rounded, full-bleed to the grid "
            "edges.",
            [g.rounded_rect_subpath(0.0, 880.0, 1000.0, 120.0, 48.0)],
        ),
        _part(
            "rug", "Room.base", "static room decor",
            "Round rug under the pet's ground contact.",
            [g.ellipse_subpath(500.0, 942.0, 330.0, 58.0)],
        ),
        _part(
            "window", "Room.base", "static room decor",
            "Round-cornered window: outer frame, counter-wound opening (a "
            "hole under the nonzero fill rule), and the cross bars drawn "
            "over the opening - one compound Path.",
            [
                g.rounded_rect_subpath(120.0, 110.0, 260.0, 260.0, 30.0),
                g.rounded_rect_subpath(146.0, 136.0, 208.0, 208.0, 20.0, ccw=True),
                g.rounded_rect_subpath(236.0, 122.0, 28.0, 236.0, 4.0),
                g.rounded_rect_subpath(122.0, 226.0, 256.0, 28.0, 4.0),
            ],
        ),
        _part(
            "pomString", "Room.pom", "static room decor",
            "Hanging cord of the pom-pom decor, from the ceiling line.",
            [g.rounded_rect_subpath(816.0, 0.0, 8.0, 118.0, 4.0)],
        ),
        _part(
            "pomPuff", "Room.pom", "static room decor",
            "The pom-pom itself: a cluster of overlapping circles filling as "
            "one puff (nonzero rule).",
            [
                g.ellipse_subpath(820.0, 148.0, 36.0, 36.0),
                g.ellipse_subpath(786.0, 126.0, 24.0, 24.0),
                g.ellipse_subpath(854.0, 126.0, 24.0, 24.0),
                g.ellipse_subpath(790.0, 170.0, 24.0, 24.0),
                g.ellipse_subpath(850.0, 170.0, 24.0, 24.0),
            ],
        ),
    ]


def prop_parts():
    """The four interaction-scoped props (section 2.2 props row): food,
    blanket, and the two moment-scoped sparkles."""
    return [
        _part(
            "food", "Props",
            "position/rotation/opacity (interaction-scoped)",
            "Food bowl: body + full mound + two kibble dots as one compound "
            "Path, resting on the room floor left of the pet.",
            [
                # Same winding discipline as the glyph compound: the
                # half-ellipse bowl body sweeps opposite to ellipse_subpath,
                # so the overlapping mound (and the disjoint kibbles, for
                # table uniformity) is reversed to match - mixed winding
                # would cancel the mound-bowl overlap band to a hole.
                g.lower_half_ellipse_subpath(240.0, 946.0, 62.0, 42.0),
                g.reversed_subpath(g.ellipse_subpath(240.0, 942.0, 38.0, 15.0)),
                g.reversed_subpath(g.ellipse_subpath(224.0, 926.0, 8.0, 7.0)),
                g.reversed_subpath(g.ellipse_subpath(256.0, 922.0, 8.0, 7.0)),
            ],
        ),
        _part(
            "blanket", "Props",
            "position/rotation/opacity (interaction-scoped)",
            "Folded blanket: body + fold-edge strip, right of the pet.",
            [
                g.rounded_rect_subpath(686.0, 890.0, 230.0, 100.0, 34.0, rot_deg=5.0),
                g.rounded_rect_subpath(686.0, 912.0, 230.0, 22.0, 11.0, rot_deg=5.0),
            ],
        ),
        _part(
            "sparkleA", "Props",
            "opacity (moment-scoped - celebration)",
            "Celebration sparkle A (larger of the pair).",
            [g.sparkle_subpath(230.0, 250.0, 95.0)],
        ),
        _part(
            "sparkleB", "Props",
            "opacity (moment-scoped - celebration)",
            "Celebration sparkle B.",
            [g.sparkle_subpath(712.0, 320.0, 62.0)],
        ),
    ]


ALL_PARTS = (
    full_rig_parts() + lod_glance_parts() + glyph_parts()
    + room_parts() + prop_parts()
)


def parts_by_file():
    """Emission order, grouped exactly as the generated Swift files."""
    return [
        ("MomoRig+Body.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "Body"]),
        ("MomoRig+Head.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "Head"]),
        ("MomoRig+Ears.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "Ears"]),
        ("MomoRig+Tail.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "Tail"]),
        ("MomoRig+Eyes.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "Eyes"]),
        ("MomoRig+FaceDetails.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "FaceDetails"]),
        ("MomoRig+FrontPaws.swift", "MomoRig",
             [p for p in full_rig_parts() if p["group"] == "FrontPaws"]),
        ("MomoRig+LODGlance.swift", "MomoRig", lod_glance_parts()),
        ("MomoRig+Glyph.swift", "MomoRig", glyph_parts()),
        ("MomoRoom.swift", "MomoRoom", room_parts()),
        ("MomoProps.swift", "MomoProps", prop_parts()),
    ]
