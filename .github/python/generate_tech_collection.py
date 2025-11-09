#!/usr/bin/env python3

"""Generate tech-collection.json with a listing of tech-collection files."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def load_existing_listing(output_file: Path) -> list[str]:
    """Return existing listing from tech-collection.json if available."""
    if not output_file.exists():
        return []

    try:
        data = json.loads(output_file.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []

    files = data.get("files")
    if not isinstance(files, list):
        return []

    return [str(entry) for entry in files]


def build_listing(target_dir: Path, base_dir: Path) -> list[str]:
    """Return a sorted list of file paths (posix style) under target_dir."""
    files: list[str] = []
    for path in target_dir.rglob("*"):
        if path.is_file():
            files.append(path.relative_to(base_dir).as_posix())
    files.sort()
    return files


def merge_listings(existing: list[str], current: list[str]) -> list[str]:
    """Keep previous order for existing files, add new files at the top."""
    current_set = set(current)
    preserved_existing = [item for item in existing if item in current_set]

    preserved_set = set(preserved_existing)
    new_files = sorted(file for file in current if file not in preserved_set)

    return new_files + preserved_existing


def main() -> int:
    root = Path(".").resolve()
    tech_collection = root / "tech-collection"
    output_file = root / "tech-collection.json"

    if not tech_collection.is_dir():
        print("tech-collection directory not found", file=sys.stderr)
        return 1

    listing = build_listing(tech_collection, root)
    existing_listing = load_existing_listing(output_file)
    final_listing = merge_listings(existing_listing, listing)
    generated_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    payload = {"generatedAt": generated_at, "files": final_listing}

    output_file.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
