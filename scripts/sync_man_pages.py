#!/usr/bin/env python3
"""Regenerate the bundled sr.ht man page catalog from man.sr.ht.

Fetches the man.sr.ht landing page, extracts the per-service "User Manual"
links, and writes them to ``Hutch/Resources/man-pages.json``. The scheduled
GitHub workflow that runs this opens a pull request whenever the result differs
from the committed copy, so the in-app list stays in sync with upstream without
hand edits.

Run locally with ``python3 scripts/sync_man_pages.py``; exits non-zero (without
writing) if upstream markup changed enough that too few pages were found, so a
bad scrape can never wipe the bundled list.
"""
import json
import re
import sys
import urllib.request
from pathlib import Path

INDEX_URL = "https://man.sr.ht/"
OUTPUT = Path(__file__).resolve().parent.parent / "Hutch" / "Resources" / "man-pages.json"
# The suite has ~12 service manuals; a scrape returning far fewer means the page
# structure changed and we should fail loudly rather than commit a gutted list.
MINIMUM_EXPECTED = 8


def fetch(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "hutch-man-page-sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def build_catalog(html: str) -> list[dict[str, str]]:
    """Extract official man-page links, deduplicated and sorted by title."""
    entries: dict[str, str] = {}
    for href in re.findall(r'href="([^"]+)"', html):
        service = re.fullmatch(r"/([a-z0-9][a-z0-9.-]*\.sr\.ht)/?", href)
        if service:
            title = service.group(1)
            entries[title] = f"https://man.sr.ht/{title}/"
        elif re.fullmatch(r"sr\.ht/?", href):
            entries["sr.ht"] = "https://man.sr.ht/sr.ht/"
        elif re.fullmatch(r"https://srht\.site/?", href):
            entries["srht.site"] = "https://srht.site/"
    return [{"title": title, "url": entries[title]} for title in sorted(entries)]


def main() -> int:
    catalog = build_catalog(fetch(INDEX_URL))
    if len(catalog) < MINIMUM_EXPECTED:
        print(
            f"Refusing to write catalog with only {len(catalog)} entries; "
            "man.sr.ht markup may have changed.",
            file=sys.stderr,
        )
        return 1
    OUTPUT.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    print(f"Wrote {len(catalog)} man page(s) to {OUTPUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
