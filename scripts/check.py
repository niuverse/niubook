#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Niubook quality gates.

Each book must pass G0–G5 before it can be built or released:

  G0 metadata      book.toml is complete and self-consistent
  G1 structure     chapters are contiguous, imported once, correctly shaped
  G2 build         pinned Typst compiles the book with zero warnings
  G3 bibliography  entries are valid, citations resolve, flags do not grow
  G4 hygiene       no placeholders, no duplicate labels
  G5 provenance    source hash and review ledger are present and in sync

The series-level catalogue is checked separately as G6.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from gen_meta import render_meta  # noqa: E402

TYPST = ROOT / ".tools" / "typst"
BIB_VALIDATOR = ROOT / "toolchain" / "python" / "validate_bib.py"

REQUIRED_BOOK_FIELDS = (
    "slug", "order", "title", "author", "series", "language",
    "version", "edition", "status", "abstract",
)
ALLOWED_STATUS = {"draft", "review", "stable", "archived"}
PLACEHOLDER_RE = re.compile(r"\b(?:TODO|FIXME|TBD)\b|XXX|待补|待编写|待填")
LABEL_RE = re.compile(r"<([A-Za-z][\w-]*):([\w.-]+)>")
CITE_RE = re.compile(r"@([A-Za-z][A-Za-z0-9:_-]*)")
RAW_FENCE_RE = re.compile(r"```.*?```", re.DOTALL)
RAW_INLINE_RE = re.compile(r"`[^`\n]*`")
CHAPTER_NUMBER_RE = re.compile(r"^ch(\d+)\.typ$")
CHAPTER_TITLE_RE = re.compile(r"^= (.+)$", re.MULTILINE)
SECTION_RE = re.compile(r"^== (.+)$", re.MULTILINE)


class GateError(Exception):
    pass


def _read_toml(path: Path) -> dict:
    with path.open("rb") as fh:
        return tomllib.load(fh)


def _typ_files(book_dir: Path) -> list[Path]:
    return sorted((book_dir / "chapters").glob("*.typ")) + [book_dir / "main.typ"]


def _prose(body: str) -> str:
    """Drop raw/code blocks so decorators like @dataclass are not read as citations."""
    return RAW_INLINE_RE.sub("", RAW_FENCE_RE.sub("", body))


# ---------------------------------------------------------------- G0 metadata
def gate_metadata(book_dir: Path, data: dict) -> str:
    book = data.get("book", {})
    missing = [field for field in REQUIRED_BOOK_FIELDS if not book.get(field)]
    if missing:
        raise GateError(f"book.toml missing fields: {', '.join(missing)}")
    if book["slug"] != book_dir.name:
        raise GateError(f"slug {book['slug']!r} does not match directory {book_dir.name!r}")
    if book["status"] not in ALLOWED_STATUS:
        raise GateError(f"status {book['status']!r} not in {sorted(ALLOWED_STATUS)}")
    if not isinstance(book.get("order"), int) or book["order"] < 1:
        raise GateError("book.order must be a positive integer")
    if not data.get("license", {}).get("spdx"):
        raise GateError("license.spdx is required")
    if not data.get("stats", {}).get("pages"):
        raise GateError("stats.pages is required (used as the pagination baseline)")
    return f"v{book['version']} · {book['status']} · {data['license']['spdx']}"


# --------------------------------------------------------------- G1 structure
def gate_structure(book_dir: Path, data: dict) -> str:
    chapters_dir = book_dir / "chapters"
    if not chapters_dir.is_dir():
        raise GateError("chapters/ directory is missing")

    chapter_files = sorted(chapters_dir.glob("ch*.typ"))
    numbers = []
    for path in chapter_files:
        match = CHAPTER_NUMBER_RE.match(path.name)
        if not match:
            raise GateError(f"chapter filename {path.name!r} must look like chNN.typ")
        numbers.append(int(match.group(1)))

    expected = list(range(1, len(numbers) + 1))
    if numbers != expected:
        raise GateError(f"chapter numbering is not contiguous: found {numbers}")

    declared = data.get("stats", {}).get("chapters")
    if declared and declared != len(numbers):
        raise GateError(f"book.toml declares {declared} chapters, found {len(numbers)}")

    main = (book_dir / "main.typ").read_text(encoding="utf-8")
    for name in ("preface.typ", "appendix.typ"):
        if not (chapters_dir / name).exists():
            raise GateError(f"chapters/{name} is missing")
        if main.count(f'"chapters/{name}"') != 1:
            raise GateError(f'main.typ must include "chapters/{name}" exactly once')

    for path in [chapters_dir / "preface.typ", chapters_dir / "appendix.typ", *chapter_files]:
        body = path.read_text(encoding="utf-8")
        lines = [line.strip() for line in body.splitlines() if line.strip()]
        if not any(line.startswith('#import "../template.typ"') for line in lines[:3]):
            raise GateError(f"{path.name} must import ../template.typ on its first lines")

    for path in chapter_files:
        body = path.read_text(encoding="utf-8")
        if len(CHAPTER_TITLE_RE.findall(body)) != 1:
            raise GateError(f"{path.name} must contain exactly one level-1 heading")
        if main.count(f'"chapters/{path.name}"') != 1:
            raise GateError(f"main.typ must include chapters/{path.name} exactly once")

    extra_includes = set(re.findall(r'"chapters/([^"]+)"', main)) - {
        "preface.typ", "appendix.typ", *[p.name for p in chapter_files]
    }
    if extra_includes:
        raise GateError(f"main.typ includes unknown chapters: {sorted(extra_includes)}")

    sections = sum(len(SECTION_RE.findall(path.read_text(encoding="utf-8"))) for path in chapter_files)
    declared_sections = data.get("stats", {}).get("sections")
    if declared_sections and sections != declared_sections:
        raise GateError(f"book.toml declares {declared_sections} sections, found {sections}")
    return f"{len(chapter_files)} chapters · {sections} sections"


# ------------------------------------------------------------------- G2 build
def gate_build(book_dir: Path, data: dict, *, build: bool = True) -> str:
    if not build:
        return "skipped"
    if not TYPST.exists():
        raise GateError("typst is not installed; run `just bootstrap`")

    main = book_dir / "main.typ"
    started = time.time()
    with tempfile.TemporaryDirectory() as tmp:
        pdf = Path(tmp) / "book.pdf"
        result = subprocess.run(
            [
                str(TYPST), "compile", "--root", str(ROOT),
                "--package-path", str(ROOT / "toolchain" / "vendor"),
                str(main), str(pdf),
            ],
            capture_output=True, text=True, cwd=ROOT,
        )
        elapsed = time.time() - started
        if result.returncode != 0:
            raise GateError(f"compilation failed\n{result.stderr.strip()}")
        if result.stderr.strip():
            raise GateError(f"compilation emitted warnings\n{result.stderr.strip()}")
        if not pdf.exists():
            raise GateError("compilation produced no PDF")

        pages = None
        if shutil.which("pdfinfo"):
            info = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True)
            match = re.search(r"^Pages:\s+(\d+)", info.stdout, re.MULTILINE)
            if match:
                pages = int(match.group(1))

    declared = data.get("stats", {}).get("pages")
    if pages is not None and declared and pages != declared:
        raise GateError(f"pagination baseline moved: {pages} pages, expected {declared}")
    page_text = f"{pages} pages" if pages is not None else "pages unknown"
    return f"{page_text} · {elapsed:.1f}s · 0 warnings"


# -------------------------------------------------------------- G3 bibliography
def gate_bibliography(book_dir: Path, data: dict) -> str:
    bib = book_dir / "references.bib"
    if not bib.exists():
        raise GateError("references.bib is missing")

    result = subprocess.run(
        [sys.executable, str(BIB_VALIDATOR), str(bib)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise GateError(f"bibliography is malformed\n{result.stdout.strip()}")

    entries = int(re.search(r"total entries\s*:\s*(\d+)", result.stdout).group(1))
    unverified = int(re.search(r"UNVERIFIED\s*:\s*(\d+)", result.stdout).group(1))
    keys = set(re.findall(r"^@\w+\{\s*([^,\s]+)\s*,", bib.read_text(encoding="utf-8"), re.MULTILINE))

    body = _prose("\n".join(path.read_text(encoding="utf-8") for path in _typ_files(book_dir)))
    labels = {f"{kind}:{name}" for kind, name in LABEL_RE.findall(body)}
    cited_raw = set(CITE_RE.findall(body))
    cited = cited_raw - labels - {"preview"}

    undefined = sorted(cited - keys)
    if undefined:
        raise GateError(f"citations without a bibliography entry: {', '.join(undefined[:8])}")

    unused = sorted(keys - cited)
    stats = data.get("stats", {})
    if unverified > data.get("quality", {}).get("max_unverified", 0):
        raise GateError(
            f"{unverified} unverified references exceed the allowed budget "
            f"({data['quality']['max_unverified']})"
        )
    if stats.get("references") and entries != stats["references"]:
        raise GateError(f"book.toml declares {stats['references']} references, found {entries}")
    if stats.get("unverified") and unverified != stats["unverified"]:
        raise GateError(f"book.toml declares {stats['unverified']} flagged references, found {unverified}")
    if unused:
        return f"{entries} entries · {unverified} flagged · {len(unused)} uncited"

    return f"{entries} entries · {unverified} flagged · 0 undefined"


# ----------------------------------------------------------------- G4 hygiene
def gate_hygiene(book_dir: Path, data: dict) -> str:
    placeholders = []
    labels: list[str] = []
    canvas = 0
    canvas_ok = 0

    for path in _typ_files(book_dir):
        body = path.read_text(encoding="utf-8")
        for match in PLACEHOLDER_RE.finditer(body):
            line = body[: match.start()].count("\n") + 1
            placeholders.append(f"{path.relative_to(book_dir)}:{line} {match.group(0)}")
        labels.extend(f"{kind}:{name}" for kind, name in LABEL_RE.findall(body))
        canvas += body.count("cetz.canvas(")
        canvas_ok += body.count("cetz.canvas(length: 1cm")

    if placeholders:
        raise GateError("placeholder text found:\n" + "\n".join(f"  {p}" for p in placeholders[:10]))

    duplicates = sorted({label for label in labels if labels.count(label) > 1})
    if duplicates:
        raise GateError(f"duplicate labels: {', '.join(duplicates)}")

    return f"no placeholders · {len(labels)} labels · {canvas} canvases"


# -------------------------------------------------------------- G5 provenance
def gate_provenance(book_dir: Path, data: dict) -> str:
    provenance = book_dir / "PROVENANCE.md"
    review = book_dir / "REVIEW.md"
    if not provenance.exists():
        raise GateError("PROVENANCE.md is missing")
    if not review.exists():
        raise GateError("REVIEW.md is missing")

    text = provenance.read_text(encoding="utf-8")
    origin = data.get("provenance", {}).get("origin_sha256", "")
    if not re.fullmatch(r"[0-9a-f]{64}", origin):
        raise GateError("provenance.origin_sha256 must be a 64-character hex digest")
    if origin not in text:
        raise GateError("PROVENANCE.md does not record provenance.origin_sha256")

    meta_path = book_dir / "_meta.typ"
    if not meta_path.exists():
        raise GateError("_meta.typ is missing; run `just meta`")
    if meta_path.read_text(encoding="utf-8") != render_meta(book_dir):
        raise GateError("_meta.typ is out of date; run `just meta`")

    return f"source {origin[:12]}… · metadata in sync"


GATES = (
    ("G0 metadata", gate_metadata),
    ("G1 structure", gate_structure),
    ("G2 build", gate_build),
    ("G3 bibliography", gate_bibliography),
    ("G4 hygiene", gate_hygiene),
    ("G5 provenance", gate_provenance),
)


def check_book(book_dir: Path, *, build: bool) -> bool:
    data = _read_toml(book_dir / "book.toml")
    book = data["book"]
    print(f"\n{book['slug']}  ({book.get('title', '')})")
    failures = 0

    for label, gate in GATES:
        try:
            if gate is gate_build:
                detail = gate(book_dir, data, build=build)
            else:
                detail = gate(book_dir, data)
            print(f"  ✓ {label:<16} {detail}")
        except GateError as error:
            failures += 1
            print(f"  ✗ {label:<16} FAIL")
            for line in str(error).splitlines():
                print(f"      {line}")
        except Exception as error:  # noqa: BLE001 - surface unexpected gate crashes
            failures += 1
            print(f"  ✗ {label:<16} ERROR {error}")
    return failures == 0


def check_catalog() -> bool:
    from catalog import build_catalog, dump  # noqa: PLC0415

    target = ROOT / "catalog" / "books.json"
    print("\ncatalog")
    if not target.exists():
        print("  ✗ G6 catalogue     FAIL\n      catalog/books.json is missing; run `just catalog`")
        return False
    if target.read_text(encoding="utf-8") != dump(build_catalog()):
        print("  ✗ G6 catalogue     FAIL\n      catalog/books.json is out of date; run `just catalog`")
        return False
    print("  ✓ G6 catalogue     catalog/books.json in sync")
    return True


def main(argv: list[str]) -> int:
    build = "--no-build" not in argv
    args = [arg for arg in argv if not arg.startswith("--")]

    if "--all" in argv or not args:
        book_dirs = [
            path for path in sorted((ROOT / "books").iterdir())
            if path.is_dir() and not path.name.startswith("_") and (path / "book.toml").exists()
        ]
        if not book_dirs:
            print("no books found", file=sys.stderr)
            return 1
        ok = True
        for book_dir in book_dirs:
            ok = check_book(book_dir, build=build) and ok
        ok = check_catalog() and ok
    else:
        book_dir = Path(args[0])
        if not book_dir.is_absolute():
            book_dir = (ROOT / book_dir).resolve()
        if not (book_dir / "book.toml").exists():
            print(f"{book_dir} is not a book (no book.toml)", file=sys.stderr)
            return 1
        ok = check_book(book_dir, build=build)

    print()
    if ok:
        print("all gates passed")
        return 0
    print("gates failed", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
