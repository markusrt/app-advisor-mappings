#!/usr/bin/env python3
"""Generate site data and per-coordinate detail pages for the Jekyll site.

The script scans ``mappings/`` and ``mappings-optimized/`` and writes:

* ``docs/_data/coordinates.json`` – list consumed by ``docs/index.html`` to
  render the overview tiles.
* ``docs/coordinates/<id>.html`` – one Jekyll page per coordinate folder,
  rendered with the ``coordinate`` layout to provide detailed insight.

Run from the repository root::

    python3 scripts/generate-site-data.py

Optional environment variables:
    REPO_SLUG   ``owner/repo`` slug used when building GitHub blob/tree URLs
                (default ``markusrt/app-advisor-mappings``).
    REPO_BRANCH Branch name used for GitHub URLs (default ``main``).
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
MAPPINGS_DIR = REPO_ROOT / "mappings"
OPTIMIZED_DIR = REPO_ROOT / "mappings-optimized"
DOCS_DIR = REPO_ROOT / "docs"
DATA_DIR = DOCS_DIR / "_data"
COORDINATES_PAGES_DIR = DOCS_DIR / "coordinates"

REPO_SLUG = os.environ.get("REPO_SLUG", "markusrt/app-advisor-mappings")
REPO_BRANCH = os.environ.get("REPO_BRANCH", "main")
GITHUB_TREE_BASE = f"https://github.com/{REPO_SLUG}/tree/{REPO_BRANCH}"
GITHUB_BLOB_BASE = f"https://github.com/{REPO_SLUG}/blob/{REPO_BRANCH}"


def _parse_coordinate_id(folder_name: str) -> tuple[str, str]:
    """Split a ``groupId_artifactId`` folder name into its two parts."""
    if "_" not in folder_name:
        return folder_name, ""
    group_id, artifact_id = folder_name.split("_", 1)
    return group_id, artifact_id


def _load_json_files(folder: Path) -> list[dict[str, Any]]:
    """Load all ``*.json`` files from ``folder`` (sorted by name)."""
    files: list[dict[str, Any]] = []
    if not folder.is_dir():
        return files
    for json_path in sorted(folder.glob("*.json")):
        try:
            with json_path.open(encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            print(f"WARN: Could not read {json_path}: {exc}")
            continue
        files.append({"name": json_path.name, "data": data})
    return files


def _count_versions(files: list[dict[str, Any]]) -> int:
    return sum(len((f["data"] or {}).get("rewrite", {}) or {}) for f in files)


def _summarise_files(
    files: list[dict[str, Any]], folder_rel: str
) -> list[dict[str, Any]]:
    """Convert raw mapping files into a JSON-serialisable summary."""
    summary: list[dict[str, Any]] = []
    for entry in files:
        data = entry["data"] or {}
        rewrite = data.get("rewrite", {}) or {}
        versions: list[dict[str, Any]] = []
        for version, details in rewrite.items():
            details = details or {}
            requirements = details.get("requirements", {}) or {}
            next_rewrite = details.get("nextRewrite")
            next_version = None
            if isinstance(next_rewrite, dict):
                next_version = next_rewrite.get("version")
            generations = requirements.get("supportedGenerations", {}) or {}
            excluded = requirements.get("excludedArtifacts", []) or []
            recipes = details.get("recipes", []) or []
            versions.append(
                {
                    "version": version,
                    "nextVersion": next_version,
                    "supportedGenerations": generations,
                    "excludedArtifacts": excluded,
                    "recipeCount": len(recipes),
                }
            )
        summary.append(
            {
                "fileName": entry["name"],
                "githubUrl": f"{GITHUB_BLOB_BASE}/{folder_rel}/{entry['name']}",
                "slug": data.get("slug", ""),
                "coordinates": data.get("coordinates", []) or [],
                "repositoryUrl": data.get("repositoryUrl", "") or "",
                "versionCount": len(versions),
                "versions": versions,
            }
        )
    return summary


def _collect_coordinates() -> list[dict[str, Any]]:
    coordinates: list[dict[str, Any]] = []
    if not MAPPINGS_DIR.is_dir():
        return coordinates

    for folder in sorted(p for p in MAPPINGS_DIR.iterdir() if p.is_dir()):
        folder_name = folder.name
        group_id, artifact_id = _parse_coordinate_id(folder_name)

        mappings_files = _load_json_files(folder)
        optimized_folder = OPTIMIZED_DIR / folder_name
        optimized_files = _load_json_files(optimized_folder)

        if not mappings_files and not optimized_files:
            # Folder exists but contains no JSON yet – skip.
            continue

        coordinates.append(
            {
                "id": folder_name,
                "groupId": group_id,
                "artifactId": artifact_id,
                "mavenUrl": (
                    f"https://central.sonatype.com/artifact/{group_id}/{artifact_id}"
                    if artifact_id
                    else ""
                ),
                "mappingsGithubUrl": f"{GITHUB_TREE_BASE}/mappings/{folder_name}",
                "optimizedGithubUrl": (
                    f"{GITHUB_TREE_BASE}/mappings-optimized/{folder_name}"
                    if optimized_folder.is_dir()
                    else ""
                ),
                "mappingsCount": _count_versions(mappings_files),
                "optimizedCount": _count_versions(optimized_files),
                "mappingFileCount": len(mappings_files),
                "optimizedFileCount": len(optimized_files),
                "hasOptimized": optimized_folder.is_dir() and bool(optimized_files),
                "mappings": _summarise_files(
                    mappings_files, f"mappings/{folder_name}"
                ),
                "optimized": _summarise_files(
                    optimized_files, f"mappings-optimized/{folder_name}"
                ),
            }
        )
    return coordinates


def _write_data(coordinates: list[dict[str, Any]]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    out_path = DATA_DIR / "coordinates.json"
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(coordinates, fh, indent=2, sort_keys=False)
        fh.write("\n")
    print(f"Wrote {out_path} ({len(coordinates)} coordinates)")


def _write_detail_pages(coordinates: list[dict[str, Any]]) -> None:
    if COORDINATES_PAGES_DIR.exists():
        for existing in COORDINATES_PAGES_DIR.glob("*.html"):
            existing.unlink()
    COORDINATES_PAGES_DIR.mkdir(parents=True, exist_ok=True)

    for coord in coordinates:
        page_path = COORDINATES_PAGES_DIR / f"{coord['id']}.html"
        title = f"{coord['groupId']}:{coord['artifactId']}".strip(":")
        front_matter = (
            "---\n"
            f"layout: coordinate\n"
            f"title: \"{title}\"\n"
            f"coordinate_id: \"{coord['id']}\"\n"
            f"permalink: /coordinates/{coord['id']}/\n"
            "---\n"
        )
        page_path.write_text(front_matter, encoding="utf-8")
    print(
        f"Wrote {len(coordinates)} detail pages to "
        f"{COORDINATES_PAGES_DIR.relative_to(REPO_ROOT)}"
    )


def main() -> None:
    coordinates = _collect_coordinates()
    _write_data(coordinates)
    _write_detail_pages(coordinates)


if __name__ == "__main__":
    main()
