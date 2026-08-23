#!/usr/bin/env python3
"""Fail if an icon-only control ships without an accessibility label.

VoiceOver reaches a ``Button { Image(systemName: "plus") }`` with nothing to
announce: an SF Symbol carries no label of its own, so the control is reported
as a bare button. The same button with a ``Text`` beside it is fine, because the
text becomes the combined label — which is why this only flags controls whose
label view is icons all the way down.

Scoping is by brace span, not line proximity. An earlier proximity check got
both answers wrong on real files: it missed a label 14 lines up and it credited
a control with an unrelated modifier from the view above it.

Run locally with ``python3 scripts/check_accessibility.py``; exits non-zero and
lists offenders, so the fix is always "label it, or say why it needs none".
"""
import re
import subprocess
import sys
from pathlib import Path

# Views only. Networking and model files have no controls to label.
SOURCE_GLOBS = ["Hutch/**/*.swift", "Shared/*.swift", "HutchWidgetExtension/*.swift"]

CONTROL = re.compile(r"\b(Button|NavigationLink|Menu)\b")
ACCESSIBILITY = re.compile(r"accessibility(Label|Hidden|Hint|Value|AddTraits)")
# A visible text view inside the control's label supplies the announcement.
TEXTUAL = re.compile(r"\bText\(|\bLabel\(|Pill\(")

# How far back a control opener may sit, and how long its body may run. Both are
# generous for SwiftUI; a control longer than this is worth splitting anyway.
LOOKBACK = 25
MAX_BODY = 80


def enclosing_control(lines: list[str], index: int) -> tuple[int, int] | None:
    """Brace span of the nearest control whose body contains ``index``.

    Returns the span including the trailing modifier chain, since
    ``.accessibilityLabel`` attaches there rather than inside the label closure.
    """
    for start in range(index, max(-1, index - LOOKBACK), -1):
        if not CONTROL.search(lines[start]):
            continue
        depth = 0
        opened = False
        end = None
        for j in range(start, min(len(lines), start + MAX_BODY)):
            depth += lines[j].count("{") - lines[j].count("}")
            if "{" in lines[j]:
                opened = True
            if opened and depth <= 0:
                end = j
                break
        if end is None or end < index:
            continue
        after = end + 1
        while after < len(lines) and re.match(r"\s*\.\w+", lines[after]):
            after += 1
        return start, after
    return None


def offenders() -> list[tuple[str, int, str]]:
    files = subprocess.run(
        ["git", "ls-files", *SOURCE_GLOBS],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()

    found = []
    for path in files:
        lines = Path(path).read_text().splitlines()
        for i, line in enumerate(lines):
            if "Image(systemName:" not in line:
                continue
            span = enclosing_control(lines, i)
            if span is None:
                continue  # a decorative image, not a control's label
            body = "\n".join(lines[span[0] : span[1]])
            if ACCESSIBILITY.search(body) or TEXTUAL.search(body):
                continue
            found.append((path, i + 1, line.strip()))
    return found


def main() -> int:
    found = offenders()
    if not found:
        print("No unlabelled icon-only controls.")
        return 0

    print(f"{len(found)} icon-only control(s) reach VoiceOver with no label:\n")
    for path, line, source in found:
        print(f"  {path}:{line}")
        print(f"      {source}")
    print(
        "\nAdd .accessibilityLabel(\"...\") to the control, or .accessibilityHidden(true)"
        "\nif something else already announces it."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
