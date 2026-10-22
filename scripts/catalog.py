#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the machine-readable catalogue of every book in the repository."""

from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BOOKS = ROOT / "books"
CATALOG = ROOT / "catalog" / "books.json"

CHAPTER_RE = re.compile(r"^= (.+)$", re.MULTILINE)
APPENDIX_RE = re.compile(r"#heading\(numbering: none\)\[附录\s*([A-Z])\s*[　 ]\s*(.+?)\]")


def _read_toml(path: Path) -> dict:
    with path.open("rb") as fh:
        return tomllib.load(fh)


def _chapters(book_dir: Path) -> tuple[list[dict], list[dict]]:
    chapters = []
    for path in sorted((book_dir / "chapters").glob("ch*.typ")):
        match = CHAPTER_RE.search(path.read_text(encoding="utf-8"))
        if not match:
            continue
        number = int(re.sub(r"\D", "", path.stem) or 0)
        chapters.append({"number": number, "title": match.group(1).strip(), "file": path.name})

    appendix = []
    appendix_path = book_dir / "chapters" / "appendix.typ"
    if appendix_path.exists():
        for letter, title in APPENDIX_RE.findall(appendix_path.read_text(encoding="utf-8")):
            appendix.append({"number": letter, "title": title.strip(), "file": "appendix.typ"})
    return chapters, appendix


def book_entry(book_dir: Path) -> dict:
    data = _read_toml(book_dir / "book.toml")
    book = data["book"]
    stats = data.get("stats", {})
    license_ = data.get("license", {})
    provenance = data.get("provenance", {})
    chapters, appendix = _chapters(book_dir)
    slug = book["slug"]

    return {
        "slug": slug,
        "order": book.get("order", 0),
        "title": book["title"],
        "subtitle": book.get("subtitle", ""),
        "title_en": book.get("title_en", ""),
        "author": book.get("author", ""),
        "series": book.get("series", "Niubook"),
        "language": book.get("language", "zh-CN"),
        "year": book.get("year", 0),
        "edition": book.get("edition", ""),
        "version": book.get("version", "0.0.0"),
        "status": book.get("status", "draft"),
        "knowledge_cutoff": book.get("knowledge_cutoff", ""),
        "tags": book.get("tags", []),
        "abstract": book.get("abstract", ""),
        "license": {
            "spdx": license_.get("spdx", ""),
            "name": license_.get("name", ""),
            "url": license_.get("url", ""),
        },
        "stats": {
            "pages": stats.get("pages", 0),
            "chapters": stats.get("chapters", len(chapters)),
            "sections": stats.get("sections", 0),
            "references": stats.get("references", 0),
            "unverified": stats.get("unverified", 0),
        },
        "chapters": chapters,
        "appendix": appendix,
        "paths": {
            "source": f"books/{slug}",
            "pdf": f"books/{slug}/{slug}.pdf",
        },
        "provenance": {
            "generator": provenance.get("generator", ""),
            "imported_at": provenance.get("imported_at", ""),
        },
    }


def build_catalog() -> dict:
    books = []
    for book_dir in sorted(BOOKS.iterdir()):
        if not book_dir.is_dir() or book_dir.name.startswith("_"):
            continue
        if not (book_dir / "book.toml").exists():
            continue
        books.append(book_entry(book_dir))
    books.sort(key=lambda item: (item["order"], item["slug"]))
    return {"schema": 1, "series": "Niubook", "books": books}


def dump(catalog: dict) -> str:
    return json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"


def write() -> Path:
    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(dump(build_catalog()), encoding="utf-8")
    return CATALOG


def main(argv: list[str]) -> int:
    rendered = dump(build_catalog())
    if "--check" in argv:
        if not CATALOG.exists():
            print(f"missing {CATALOG.relative_to(ROOT)}; run `just catalog`", file=sys.stderr)
            return 1
        if CATALOG.read_text(encoding="utf-8") != rendered:
            print(
                f"{CATALOG.relative_to(ROOT)} is out of date; run `just catalog`",
                file=sys.stderr,
            )
            return 1
        print(f"ok {CATALOG.relative_to(ROOT)}")
        return 0
    path = write()
    print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
