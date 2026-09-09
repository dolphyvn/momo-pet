#!/usr/bin/env python3
"""Momo character asset pipeline (TASK-025; 04 section 8.2, ADR-007).

Repo-local, deterministic, re-runnable generator for the Direction-C rig's
Swift `Path` constants and the evidence renders. The generated Swift sources
are COMMITTED; re-running this pipeline must reproduce them byte-identically
(pinned by MomoPipelineReproducibilityTests). Zero runtime dependencies: this
is a build-time repo tool, stdlib-only.

Usage (from the repository root):
  python3 Tools/character-pipeline/generate.py
        Writes the 11 generated Swift files into Sources/MomoCharacter/.
  --out-dir DIR       Write the Swift files into DIR instead.
  --evidence-dir DIR  Also write the SVG evidence canvases into DIR.
  --check             Regenerate into a temp dir and compare with the
                      committed output; exit 1 listing any drift.
  --verify-geometry   Run the geometry contract checks (landmarks, ADR-001
                      rules, variants) before writing; exit 1 on violation.
  --report            Print the measured geometry summary and source budgets.

Python 3.9+ (verified on this host's CLT python3 3.9.6 and homebrew 3.12.13 -
see Tools/character-pipeline/README.md, VERIFY-AT-BUILD record).
"""

import argparse
import filecmp
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import emit_swift
import parts as pmod
import render_svg
import verify_geometry

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_SWIFT_DIR = os.path.join(REPO_ROOT, "Sources", "MomoCharacter")
EVIDENCE_COMMIT_DIR = os.path.join(REPO_ROOT, "docs", "evidence", "character")

# 04 section 8.3 budget buckets (bytes of generated source; 1024-byte KB).
BUDGETS = {
    "rig": (300 * 1024, lambda name: name.startswith("MomoRig+")),
    "room_props": (250 * 1024,
                   lambda name: name in ("MomoRoom.swift", "MomoProps.swift")),
    "total": (1536 * 1024, lambda name: True),
}


def _by_name():
    return {p["name"]: p for p in pmod.ALL_PARTS}


def write_evidence(target_dir):
    os.makedirs(target_dir, exist_ok=True)
    written = []
    for filename, contents in render_svg.render_all(_by_name()).items():
        path = os.path.join(target_dir, filename)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(contents)
        written.append(path)
    return written


def verify_geometry_or_die():
    failures = verify_geometry.run_all_checks()
    if failures:
        print("GEOMETRY CONTRACT VIOLATIONS:", file=sys.stderr)
        for bucket, messages in failures.items():
            for message in messages:
                print("  [%s] %s" % (bucket, message), file=sys.stderr)
        sys.exit(1)


def print_report():
    by_name = _by_name()
    print("Measured geometry (pipeline-side):")
    for line in verify_geometry.report(by_name):
        print("  " + line)
    print("Generated-source budgets (04 section 8.3):")
    sizes = {name: len(contents.encode("utf-8"))
             for name, contents in emit_swift.generate_sources()}
    total = 0
    for bucket, (limit, match) in BUDGETS.items():
        if bucket == "total":
            continue
        subtotal = sum(size for name, size in sizes.items() if match(name))
        total += subtotal
        print("  %-11s %6d bytes / limit %6d  (%s)" %
              (bucket, subtotal, limit,
               ", ".join(sorted(n for n in sizes if match(n)))))
    print("  %-11s %6d bytes / limit %6d" % ("total", total, BUDGETS["total"][0]))
    evidence_bytes = sum(len(contents.encode("utf-8"))
                         for contents in render_svg.render_all(by_name).values())
    print("  evidence SVGs (not shipped code): %d bytes" % evidence_bytes)


def check_committed(swift_dir, evidence_dir):
    """Regenerate into a temp dir and byte-compare with the committed output."""
    swift_files = emit_swift.generate_sources()
    evidence_files = render_svg.render_all(_by_name())
    drifted = []
    with tempfile.TemporaryDirectory(prefix="momo-pipeline-check-") as tmp:
        tmp_swift = os.path.join(tmp, "swift")
        tmp_evidence = os.path.join(tmp, "evidence")
        os.makedirs(tmp_swift)
        os.makedirs(tmp_evidence)
        for name, contents in swift_files:
            with open(os.path.join(tmp_swift, name), "w", encoding="utf-8") as h:
                h.write(contents)
        for name, contents in evidence_files.items():
            with open(os.path.join(tmp_evidence, name), "w", encoding="utf-8") as h:
                h.write(contents)
        for name, _ in swift_files:
            committed = os.path.join(swift_dir, name)
            fresh = os.path.join(tmp_swift, name)
            if not os.path.exists(committed):
                drifted.append("missing committed Swift file: %s" % name)
            elif not filecmp.cmp(committed, fresh, shallow=False):
                drifted.append("drift: %s" % name)
        for name in evidence_files:
            committed = os.path.join(evidence_dir, name)
            fresh = os.path.join(tmp_evidence, name)
            if not os.path.exists(committed):
                drifted.append("missing committed evidence file: %s" % name)
            elif not filecmp.cmp(committed, fresh, shallow=False):
                drifted.append("drift: %s" % name)
    if drifted:
        print("PIPELINE OUTPUT DRIFT (re-run the pipeline and commit):", file=sys.stderr)
        for line in drifted:
            print("  " + line, file=sys.stderr)
        sys.exit(1)
    print("check OK: %d Swift files + %d evidence canvases reproduce "
          "byte-identically" % (len(swift_files), len(evidence_files)))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out-dir", default=DEFAULT_SWIFT_DIR)
    parser.add_argument("--evidence-dir", default=None)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--verify-geometry", action="store_true")
    parser.add_argument("--report", action="store_true")
    args = parser.parse_args()

    # Every mode verifies the geometry contract first: the pipeline must fail
    # loudly before writing anything if the authored geometry is off.
    verify_geometry_or_die()

    if args.report:
        print_report()
        return
    if args.check:
        evidence_dir = args.evidence_dir or EVIDENCE_COMMIT_DIR
        check_committed(args.out_dir, evidence_dir)
        return

    os.makedirs(args.out_dir, exist_ok=True)
    written = emit_swift.write_sources(args.out_dir)
    for path in written:
        print("wrote %s" % os.path.relpath(path, REPO_ROOT))
    if args.evidence_dir:
        for path in write_evidence(args.evidence_dir):
            print("wrote %s" % os.path.relpath(path, REPO_ROOT))


if __name__ == "__main__":
    main()
