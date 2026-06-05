#!/usr/bin/env python3
"""Remove spaces before '(' in Vala method calls and definitions.

Preserves control-flow keywords (if, for, while, …) and attribute syntax ([CCode (…)]).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Words that keep a space before '(' (control flow / operators, not callees).
KEEP_SPACE_KEYWORDS = frozenset(
    {
        "if",
        "for",
        "while",
        "switch",
        "case",
        "catch",
        "foreach",
        "lock",
        "try",
        "else",
        "do",
        "return",
        "new",
        "typeof",
        "sizeof",
        "assert",
        "throw",
        "yield",
        "as",
        "is",
        "in",
        "using",
        "with",
        "delegate",
    }
)

# identifier or qualified name immediately followed by space and '('
CALLEE_RE = re.compile(r"(?<![\[])([A-Za-z_][A-Za-z0-9_.]*)\s+\(")


def fix_line(line: str) -> str:
    def repl(match: re.Match[str]) -> str:
        name = match.group(1)
        if name in KEEP_SPACE_KEYWORDS:
            return match.group(0)
        return f"{name}("

    return CALLEE_RE.sub(repl, line)


def fix_text(text: str) -> str:
    if not text:
        return text
    fixed = "\n".join(fix_line(line) for line in text.splitlines())
    if text.endswith(("\n", "\r\n")):
        fixed += "\n"
    return fixed


def iter_vala_files(root: Path) -> list[Path]:
    skip_dirs = {"build", "build-win", ".git", "node_modules", "mingw-libs"}
    files: list[Path] = []
    for path in root.rglob("*.vala"):
        if any(part in skip_dirs for part in path.parts):
            continue
        files.append(path)
    return sorted(files)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "root",
        nargs="?",
        default=Path(__file__).resolve().parent.parent,
        type=Path,
        help="Repository root (default: parent of scripts/)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report files that would change without writing",
    )
    args = parser.parse_args()
    root: Path = args.root.resolve()

    changed_files: list[Path] = []
    for path in iter_vala_files(root):
        original = path.read_text(encoding="utf-8")
        fixed = fix_text(original)
        if fixed == original:
            continue
        changed_files.append(path)
        if not args.check:
            path.write_text(fixed, encoding="utf-8")

    if args.check:
        if not changed_files:
            print("OK: all .vala files match paren spacing style")
            return 0
        print(f"{len(changed_files)} file(s) need paren spacing fixes:")
        for path in changed_files:
            print(f"  {path.relative_to(root)}")
        return 1

    print(f"fixed paren spacing in {len(changed_files)} file(s)")
    for path in changed_files:
        print(f"  {path.relative_to(root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
