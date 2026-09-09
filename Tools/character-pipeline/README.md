# Character asset pipeline (TASK-025)

Repo-local, deterministic, re-runnable generator for the Direction-C
"Round Rabbit" rig: it emits the Swift `Path` constants consumed by
EPIC-006 renderers, plus visual evidence renders. The generated Swift
sources are COMMITTED to `Sources/MomoCharacter/`; re-running the
pipeline reproduces them byte-identically (pinned by
`MomoPipelineReproducibilityTests`).

Zero runtime dependencies (ADR-007): this is a build-time repo tool,
Python stdlib only. The shipped rig is colorless (R4) — colors are
token slots applied at render time in TASK-026+; every tone in the
evidence renders is a placeholder.

## Layout

| File | Role |
|---|---|
| `geometry.py` | Grid constants, landmarks, path builders (ellipses, pear, crescents, rounded rects, sparkles), measurement helpers |
| `parts.py` | THE GEOMETRY SOURCE OF TRUTH: part tables for the full rig, LOD-glance, glyph, room and props |
| `verify_geometry.py` | Pipeline-side contract checks (landmarks, ADR-001 ear rule, variants, grid). Same tolerances the Swift tests pin |
| `emit_swift.py` | Swift emitter — GENERATED headers, `MomoRig.<part>` naming law, doc comments |
| `render_svg.py` | SVG evidence canvases (diffable projections of the parametric source) |
| `generate.py` | CLI entry point |
| `render_evidence.swift` | macOS host tool: compiles together with the GENERATED sources and rasterizes the committed constants to PNG (the evidence projects the shipped bytes, not just the source) |

## Usage (from the repository root)

```bash
# Regenerate the 11 Swift files into Sources/MomoCharacter/ (runs the
# geometry contract checks first; exits 1 on any violation)
python3 Tools/character-pipeline/generate.py

# Also write the 4 SVG evidence canvases
python3 Tools/character-pipeline/generate.py --evidence-dir docs/evidence/character

# Verify committed output reproduces byte-identically (CI-shaped check)
python3 Tools/character-pipeline/generate.py --check

# Print measured geometry + source-byte budgets
python3 Tools/character-pipeline/generate.py --report
```

Raster evidence (macOS build host, same host role as `swift test`):

```bash
swiftc Tools/character-pipeline/render_evidence.swift \
    Sources/MomoCharacter/MomoRig.swift \
    Sources/MomoCharacter/MomoRig+*.swift \
    Sources/MomoCharacter/MomoRoom.swift Sources/MomoCharacter/MomoProps.swift \
    -o /tmp/momo-render-evidence
/tmp/momo-render-evidence --out docs/evidence/character
```

## Evidence

`docs/evidence/character/` carries the committed visual evidence:
`rig-full.svg` / `rig-full.png` (the 21-constant rig), `rig-lod-glance.svg`,
`rig-glyph.svg` / `rig-glyph.png` (glyph + small-size legibility), and
`room-scene.svg` / `room-scene.png` (room + props composed with the rig).
The SVGs are byte-pinned by the reproducibility test; the PNGs are raster
evidence from `render_evidence.swift` (byte-deterministic on the verified
host below — two consecutive runs compared identical — but not pinned by
tests because the raster encoder is a host facility, not part of the
contract).

## Tooling record (VERIFY-AT-BUILD, per task contract)

Verified on the build host before relying on any of the above
(macOS 26.x, Xcode 26 / swiftc 6.3.3, Darwin 25.5.0, verified
2026-09-08/09 during TASK-025):

- `python3` → 3.12.13 (homebrew PATH) AND `/usr/bin/python3` → 3.9.6
  (CLT); the pipeline is stdlib-only 3.9+ and runs under both. The Swift
  reproducibility test resolves `python3` from `PATH` like a developer
  would.
- `swiftc` 6.3.3 compiles the generated sources standalone
  (`render_evidence.swift` build doubles as that check).
- Baseline reproduced on this host before changes: `swift test` →
  515 tests / 54 suites passed at fdb5cb5.

Re-verify on any new host before trusting evidence or `--check`.

## Generated-source budgets (04 §8.3)

Measured at authoring time (see `--report` for current numbers):
rig ≈ 49.9 KB / 300 KB, room + props ≈ 20.6 KB / 250 KB, total
≈ 70.4 KB / 1.5 MB — all far under budget, pinned by
`MomoArtBudgetTests` at the §8.3 limits.
