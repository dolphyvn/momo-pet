"""Swift emitter: turns the part tables into generated `Path` constants.

Output contract (04 section 8.4, binding):
  - rig parts live in the `MomoRig` namespace, room in `MomoRoom`, props in
    `MomoProps` (the bundled-data names `momo.room.base` / `momo.room.pom`
    map onto the `Room.base` / `Room.pom` groups);
  - one file per layer group: `MomoRig+<Group>.swift`;
  - every generated file opens with the GENERATED header naming the
    generating command and the source of truth;
  - geometry is colorless (R4): no colors, no hex, shapes only.

Determinism: float text comes from geometry.fmt() (3 fixed decimals), part
order is the list order in parts.py, and nothing else influences the bytes.
"""

import os

import geometry as g
import parts as pmod

GENERATE_COMMAND = "python3 Tools/character-pipeline/generate.py"

HEADER_TEMPLATE = """\
//
//  {filename}
//  MomoCharacter
//
//  GENERATED FILE - DO NOT EDIT.
//  Regenerate with: {command}
//  (run from the repository root; output must reproduce this file
//  byte-identically - pinned by MomoPipelineReproducibilityTests)
//
//  Source of truth: Tools/character-pipeline/parts.py
//  Normative geometry: docs/design/04-character-system.md §2.1-2.2 (1000×1000
//  normalized grid, y-down, ground y = 1000), ADR-001 (Direction C).
//  Colorless geometry (R4): tokens are applied at render time (§8.4).
//

import SwiftUI

"""

DOC_LINE = "/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.\n"


def _pt(point):
    return "CGPoint(x: %s, y: %s)" % (g.fmt(point[0]), g.fmt(point[1]))


def _subpath_lines(subpath, indent):
    lines = []
    for seg in subpath:
        pad = " " * indent
        if seg[0] == "M":
            lines.append("%sp.move(to: %s)" % (pad, _pt(seg[1])))
        elif seg[0] == "L":
            lines.append("%sp.addLine(to: %s)" % (pad, _pt(seg[1])))
        elif seg[0] == "Q":
            lines.append("%sp.addQuadCurve(" % pad)
            lines.append("%s    to: %s," % (pad, _pt(seg[2])))
            lines.append("%s    control: %s)" % (pad, _pt(seg[1])))
        elif seg[0] == "C":
            lines.append("%sp.addCurve(" % pad)
            lines.append("%s    to: %s," % (pad, _pt(seg[3])))
            lines.append("%s    control1: %s," % (pad, _pt(seg[1])))
            lines.append("%s    control2: %s)" % (pad, _pt(seg[2])))
        elif seg[0] == "Z":
            lines.append("%sp.closeSubpath()" % pad)
    return lines


def _part_block(part):
    lines = [
        "",
        "    /// **%s** - %s group." % (part["name"], part["group"]),
        "    /// Channels: %s." % part["channels"],
        "    /// %s" % part["doc"],
        "    public static let %s: Path = Path { p in" % part["name"],
    ]
    for sp in part["subpaths"]:
        lines.extend(_subpath_lines(sp, indent=8))
    lines.append("    }")
    return lines


def _file_doc(filename, namespace, parts):
    if namespace == "MomoRig":
        groups = ", ".join(sorted({p["group"] for p in parts}))
        return (
            "/// The Direction-C rig's %s layer group(s) (04 §2.2).\n"
            "///\n"
            "/// The full rig's part accounting: 04 §2.2 counts 17 parts\n"
            "/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C\n"
            "/// delta adds the two hind feet. The mouth slot ships its three\n"
            "/// pre-built poses as separate constants (R1: crossfaded, never\n"
            "/// re-tessellated).\n" % groups
        )
    if namespace == "MomoRoom":
        return (
            "/// The static room scene (04 §8.5: charming, non-interactive),\n"
            "/// grouped per the §8.4 bundled-data names: the `Room.base`\n"
            "/// constants implement `momo.room.base`, the `Room.pom`\n"
            "/// constants implement `momo.room.pom` (the pom as static\n"
            "/// decor).\n"
        )
    return (
        "/// The four interaction-scoped props (04 §2.2 props row, §8.5):\n"
        "/// food, blanket, and the two sparkles. Sparkles are\n"
        "/// moment-scoped by consumers; placement transforms belong to the\n"
        "/// consuming surfaces.\n"
    )


def emit_file(filename, namespace, parts):
    out = [HEADER_TEMPLATE.format(filename=filename, command=GENERATE_COMMAND)]
    out.append(_file_doc(filename, namespace, parts))
    out.append(DOC_LINE)
    out.append("extension %s {\n" % namespace)
    for part in parts:
        out.extend(_part_block(part))
    out.append("}\n")
    return "\n".join(out)


def generate_sources():
    """Returns [(relative_swift_filename, file_contents)] in emission order."""
    files = []
    for filename, namespace, parts in pmod.parts_by_file():
        files.append((filename, emit_file(filename, namespace, parts)))
    return files


def write_sources(target_dir):
    written = []
    for filename, contents in generate_sources():
        path = os.path.join(target_dir, filename)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(contents)
        written.append(path)
    return written
