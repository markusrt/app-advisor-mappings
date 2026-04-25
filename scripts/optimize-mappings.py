#!/usr/bin/env python3
"""Build an optimized copy of the ``mappings/`` directory.

The script performs the following steps:

1. Recreate the ``mappings-optimized/`` directory (cleaning any previous
   contents) at the repository root.
2. Copy every ``*.json`` file from ``mappings/`` (recursively) into the
   matching location below ``mappings-optimized/``. Other files (notably
   ``*.log`` files produced by the advisor CLI) are intentionally skipped.
3. For every copied mapping JSON, collapse consecutive versions that share
   identical ``requirements`` so only the latest version of each run is
   kept. The ``nextRewrite`` of the previous kept version is updated so the
   chain still references a kept version.

Run from the repository root:

    python3 scripts/optimize-mappings.py

Optional environment variables:
    MAPPINGS_DIR            Source directory (default ``mappings``).
    MAPPINGS_OPTIMIZED_DIR  Destination directory
                            (default ``mappings-optimized``).
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path
from typing import Iterable


def version_sort_key(version: str) -> tuple:
    """Return a tuple suitable for sorting version strings like ``1.10.x``.

    Numeric components are compared as integers; ``x`` (or any non-numeric
    component) sorts after every concrete number so that ``1.10.x`` comes
    after ``1.10.0`` but its ordering relative to other ``*.x`` patterns is
    still deterministic.
    """

    parts: list[tuple[int, int | str]] = []
    for component in version.split("."):
        try:
            parts.append((0, int(component)))
        except ValueError:
            # Non-numeric components (e.g. "x") sort after numeric ones.
            parts.append((1, component))
    return tuple(parts)


def optimize_rewrite(rewrite: dict) -> dict:
    """Collapse consecutive versions sharing identical ``requirements``.

    The newest version of every run is kept and the ``nextRewrite`` of the
    preceding kept version is rewritten to reference the newly kept version
    (preserving its ``project`` field). The ``nextRewrite`` of the final
    kept version is left untouched.
    """

    if not rewrite:
        return rewrite

    versions = sorted(rewrite.keys(), key=version_sort_key)

    # Walk versions in order and collect indices of versions to keep: keep a
    # version when it is the last in the list, or when the next version has
    # different requirements.
    kept: list[str] = []
    for index, version in enumerate(versions):
        is_last = index == len(versions) - 1
        if is_last or rewrite[version].get("requirements") != rewrite[
            versions[index + 1]
        ].get("requirements"):
            kept.append(version)

    new_rewrite: dict = {}
    for index, version in enumerate(kept):
        entry = json.loads(json.dumps(rewrite[version]))  # deep copy
        if index < len(kept) - 1:
            next_version = kept[index + 1]
            existing_next = rewrite[version].get("nextRewrite") or {}
            project = existing_next.get("project") if isinstance(
                existing_next, dict
            ) else None
            entry["nextRewrite"] = {"version": next_version, "project": project}
        # For the final kept version we leave the original ``nextRewrite``
        # value alone (it should already be ``null`` in well-formed inputs).
        new_rewrite[version] = entry

    return new_rewrite


def optimize_mapping(data: dict) -> dict:
    """Return a new mapping dict with an optimized ``rewrite`` section."""

    if not isinstance(data, dict) or "rewrite" not in data:
        return data

    optimized = dict(data)
    optimized["rewrite"] = optimize_rewrite(data.get("rewrite") or {})
    return optimized


def iter_json_files(source: Path) -> Iterable[Path]:
    for path in sorted(source.rglob("*.json")):
        if path.is_file():
            yield path


def reset_directory(target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    target.mkdir(parents=True)


def process(source: Path, destination: Path) -> int:
    if not source.is_dir():
        print(f"error: source directory {source} does not exist", file=sys.stderr)
        return 1

    reset_directory(destination)

    count = 0
    for src_file in iter_json_files(source):
        relative = src_file.relative_to(source)
        dst_file = destination / relative
        dst_file.parent.mkdir(parents=True, exist_ok=True)

        with src_file.open("r", encoding="utf-8") as fh:
            data = json.load(fh)

        optimized = optimize_mapping(data)

        with dst_file.open("w", encoding="utf-8") as fh:
            json.dump(optimized, fh, indent=2)
            fh.write("\n")

        count += 1

    print(f"Optimized {count} mapping file(s) into {destination}/")
    return 0


def main() -> int:
    source = Path(os.environ.get("MAPPINGS_DIR", "mappings"))
    destination = Path(
        os.environ.get("MAPPINGS_OPTIMIZED_DIR", "mappings-optimized")
    )
    return process(source, destination)


if __name__ == "__main__":
    raise SystemExit(main())
