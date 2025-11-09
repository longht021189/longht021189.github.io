#!/usr/bin/env python3

"""Generate tech-collection.json with a listing of tech-collection files."""

from __future__ import annotations

import json
import sys
from datetime import datetime, UTC
from pathlib import Path


def build_listing(target_dir: Path, base_dir: Path) -> list[str]:
    """Return a sorted list of file paths (posix style) under target_dir."""
    files: list[str] = []
    for path in target_dir.rglob("*"):
        if path.is_file():
            files.append(path.relative_to(base_dir).as_posix())
    files.sort()
    return files


def main() -> int:
    root = Path(".").resolve()
    tech_collection = root / "tech-collection"
    output_file = root / "tech-collection.json"

    if not tech_collection.is_dir():
        print("tech-collection directory not found", file=sys.stderr)
        return 1

    listing = build_listing(tech_collection, root)
    generated_at = datetime.now(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")
    payload = {"generatedAt": generated_at, "files": listing}

    output_file.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
