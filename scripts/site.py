#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the Niubook site with Typst's native bundle exporter.

`site/build.typ` produces the catalogue, the full HTML book and the 404 page
from one stylesheet. PDFs and cover images are copied next to the HTML book so
the download and cover links stay relative.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from catalog import build_catalog, write as write_catalog  # noqa: E402

DIST = ROOT / "dist" / "site"
BUILD = ROOT / "site" / "build.typ"
STYLE = ROOT / "site" / "style.css"


def typst_bin() -> str:
    local = ROOT / ".tools" / "typst"
    if local.exists():
        return str(local)
    found = shutil.which("typst")
    if found:
        return found
    raise SystemExit("typst is not installed; run `just bootstrap`")


def money(size: int) -> str:
    return f"{size / 1_000_000:.1f} MB"


def make_cover(pdf: Path, target: Path) -> bool:
    if not shutil.which("pdftoppm"):
        print("warning: pdftoppm not found; cover image will be missing", file=sys.stderr)
        return False
    subprocess.run(
        [
            "pdftoppm", "-f", "1", "-l", "1", "-r", "150", "-jpeg",
            "-jpegopt", "quality=90", "-singlefile", str(pdf), str(target.with_suffix("")),
        ],
        check=True,
    )
    return target.exists()


def fix_html(path: Path) -> None:
    """Set the document language and move the stylesheet link into <head>."""
    text = path.read_text(encoding="utf-8")
    text = text.replace('lang="en"', 'lang="zh-CN"', 1)
    links = re.findall(r'<link rel="stylesheet" href="[^"]+">', text)
    for link in links:
        text = text.replace(link, "", 1)
    if links:
        text = text.replace("</head>", "".join(links) + "</head>", 1)
    if path.name == "404.html":
        text = text.replace('href="style.css"', 'href="/niubook/style.css"')
    path.write_text(text, encoding="utf-8")


def main() -> int:
    write_catalog()
    catalog = build_catalog()
    if not catalog["books"]:
        print("no books to publish", file=sys.stderr)
        return 1

    typst = typst_bin()
    if DIST.exists():
        shutil.rmtree(DIST)

    subprocess.run(
        [
            typst, "compile",
            "--root", str(ROOT),
            "--package-path", str(ROOT / "toolchain" / "vendor"),
            "--features", "bundle,html",
            "--format", "bundle",
            str(BUILD), str(DIST),
        ],
        check=True, cwd=ROOT,
    )

    out = DIST / "books"
    out.mkdir(parents=True, exist_ok=True)
    for book in catalog["books"]:
        slug = book["slug"]
        pdf = ROOT / "dist" / "books" / slug / f"{slug}.pdf"
        if not pdf.exists():
            print(f"missing {pdf.relative_to(ROOT)}; run `just build {slug}` first", file=sys.stderr)
            return 1
        shutil.copy2(pdf, out / f"{slug}.pdf")
        make_cover(pdf, out / f"{slug}.jpg")
        print(f"  html · /books/{slug}.html ({money(pdf.stat().st_size)})")

    for page in DIST.rglob("*.html"):
        fix_html(page)

    print(f"site written to {DIST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
