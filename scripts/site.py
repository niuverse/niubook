#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate mdBook sources for the Niubook catalogue and build the site.

The catalogue and per-book pages are generated from catalog/books.json so the
site cannot drift from book.toml. mdBook supplies navigation, search, print
and the 404 page; the PDFs remain the canonical reading format.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from catalog import build_catalog  # noqa: E402

SITE = ROOT / "site"
SRC = ROOT / "dist" / "mdbook-src"
DIST = ROOT / "dist" / "site"
REPO_URL = "https://github.com/niuverse/niubook"


def mdbook_bin() -> str:
    local = ROOT / ".tools" / "mdbook"
    if local.exists():
        return str(local)
    found = shutil.which("mdbook")
    if found:
        return found
    raise SystemExit("mdbook is not installed; run `just bootstrap`")


def money(size: int) -> str:
    return f"{size / 1_000_000:.1f} MB"


def make_cover(pdf: Path, target: Path) -> bool:
    if not shutil.which("pdftoppm"):
        print("warning: pdftoppm not found; skipping cover generation", file=sys.stderr)
        return False
    subprocess.run(
        [
            "pdftoppm", "-f", "1", "-l", "1", "-r", "150", "-jpeg",
            "-jpegopt", "quality=90", "-singlefile", str(pdf), str(target.with_suffix("")),
        ],
        check=True,
    )
    return target.exists()


def write_summary(catalog: dict) -> str:
    lines = ["# Summary", "", "[书库](index.md)", ""]
    for book in catalog["books"]:
        lines.append(f"- [{book['title']}](books/{book['slug']}.md)")
    lines.append("")
    return "\n".join(lines)


def render_index(catalog: dict) -> str:
    rows = []
    for book in catalog["books"]:
        stats = book["stats"]
        rows.append(
            f"- [{book['title']}](books/{book['slug']}.md) — {book['subtitle']}"
            f"（{book['edition']} · {stats['pages']} 页 · {stats['references']} 文献）"
        )

    return f"""# 书目

{chr(10).join(rows)}

---

内容 CC BY-NC-SA 4.0 · 代码 MIT · AI 生成 · 人工统稿 · [权利声明]({REPO_URL}/blob/main/NOTICE)
"""


def render_book(book: dict, pdf_bytes: int, has_cover: bool) -> str:
    slug = book["slug"]
    stats = book["stats"]
    cover = (
        f'<p style="text-align:center"><img src="{slug}.jpg" '
        f'alt="《{book["title"]}》封面" width="260" style="border:1px solid #cfcfcf"></p>\n\n'
        if has_cover
        else ""
    )
    toc = "\n".join(
        f"{chapter['number']}. {chapter['title']}" for chapter in book["chapters"]
    )
    appendix = "\n".join(
        f"- 附录 {entry['number']}　{entry['title']}" for entry in book["appendix"]
    )

    return f"""# {book['title']}

**{book['subtitle']}**

*{book['title_en']}*

[下载 PDF]({slug}.pdf) · [Typst 源码]({REPO_URL}/tree/main/books/{slug}) · [溯源]({REPO_URL}/blob/main/books/{slug}/PROVENANCE.md) · [审校]({REPO_URL}/blob/main/books/{slug}/REVIEW.md)

作者：{book['author']} ｜ 版次：{book['edition']} ｜ {stats['pages']} 页 ｜ {stats['references']} 文献 ｜ {book['license']['spdx']}

{cover}## 摘要

{book['abstract']}

## 目录

{toc}

{appendix}

## 阅读

[打开 PDF]({slug}.pdf) · {stats['pages']} 页 · {money(pdf_bytes)}

## 版本与溯源

初稿 {book['provenance']['generator']} · 人工统稿 · {stats['unverified']} 条文献待核验。
"""


def main() -> int:
    catalog = build_catalog()
    if not catalog["books"]:
        print("no books to publish", file=sys.stderr)
        return 1

    mdbook = mdbook_bin()
    if SRC.exists():
        shutil.rmtree(SRC)
    if DIST.exists():
        shutil.rmtree(DIST)
    (SRC / "src").mkdir(parents=True)
    shutil.copy2(SITE / "book.toml", SRC / "book.toml")

    (SRC / "src" / "SUMMARY.md").write_text(write_summary(catalog), encoding="utf-8")
    (SRC / "src" / "index.md").write_text(render_index(catalog), encoding="utf-8")

    for book in catalog["books"]:
        slug = book["slug"]
        pdf = ROOT / "dist" / "books" / slug / f"{slug}.pdf"
        if not pdf.exists():
            print(f"missing {pdf.relative_to(ROOT)}; run `just build {slug}` first", file=sys.stderr)
            return 1
        out = SRC / "src" / "books"
        out.mkdir(parents=True, exist_ok=True)
        shutil.copy2(pdf, out / f"{slug}.pdf")
        cover = make_cover(pdf, out / f"{slug}.jpg")
        (out / f"{slug}.md").write_text(
            render_book(book, pdf.stat().st_size, cover), encoding="utf-8"
        )
        print(f"  mdbook · /books/{slug}.html ({money(pdf.stat().st_size)})")

    subprocess.run(
        [mdbook, "build", str(SRC), "-d", str(DIST)],
        check=True, cwd=ROOT,
    )
    print(f"site written to {DIST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
