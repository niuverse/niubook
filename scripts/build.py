#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compile every book (or one book) with the pinned Typst toolchain."""

from __future__ import annotations

import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPST = ROOT / ".tools" / "typst"


def book_dirs() -> list[Path]:
    return [
        path for path in sorted((ROOT / "books").iterdir())
        if path.is_dir() and not path.name.startswith("_") and (path / "book.toml").exists()
    ]


def build(book_dir: Path) -> Path:
    with (book_dir / "book.toml").open("rb") as fh:
        book = tomllib.load(fh)["book"]
    slug = book["slug"]
    output = ROOT / "dist" / "books" / slug / f"{slug}.pdf"
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(TYPST), "compile", "--root", str(ROOT),
            "--package-path", str(ROOT / "toolchain" / "vendor"),
            str(book_dir / "main.typ"), str(output),
        ],
        check=True, cwd=ROOT,
    )
    return output


def main(argv: list[str]) -> int:
    if not TYPST.exists():
        print("typst is not installed; run `just bootstrap`", file=sys.stderr)
        return 1

    targets = book_dirs()
    if "--book" in argv:
        slug = argv[argv.index("--book") + 1]
        targets = [path for path in targets if path.name == slug]
        if not targets:
            print(f"unknown book {slug!r}", file=sys.stderr)
            return 1

    for book_dir in targets:
        output = build(book_dir)
        print(f"  built {output.relative_to(ROOT)} ({output.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
