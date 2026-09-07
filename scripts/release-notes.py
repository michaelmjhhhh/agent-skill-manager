#!/usr/bin/env python3
"""Extract the exact tagged version's changelog section. Fail on missing notes."""
import re
import sys
from pathlib import Path


def extract_notes(changelog: str, version: str) -> str:
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Version must be X.Y.Z")
    headings = list(re.finditer(r"^## \[([^\]]+)\]\s*$", changelog, re.MULTILINE))
    matches = [i for i, heading in enumerate(headings) if heading[1] == version]
    if len(matches) != 1:
        raise ValueError(f"CHANGELOG.md must have exactly one ## [{version}] section")
    index = matches[0]
    start = headings[index].end()
    end = headings[index + 1].start() if index + 1 < len(headings) else len(changelog)
    section = changelog[start:end]
    section = re.split(r"^\[[^\]]+\]:", section, maxsplit=1, flags=re.MULTILINE)[0].strip()
    if not re.search(r"^- \S", section, re.MULTILINE):
        raise ValueError(f"The {version} section must include at least one change")
    return f"## Changes in {version}\n\n{section}\n"


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("Usage: python3 scripts/release-notes.py X.Y.Z")
        source = Path(__file__).resolve().parent.parent / "CHANGELOG.md"
        print(extract_notes(source.read_text(encoding="utf-8"), sys.argv[1]), end="")
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
