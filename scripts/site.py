#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate mdBook sources for the Niubook catalogue and build the site.

The catalogue and per-book pages are generated from catalog/books.json so the
site cannot drift from book.toml. mdBook supplies navigation, search, print
and the 404 page; the PDFs remain the canonical reading format.
"""

from __future__ import annotations

import html
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
            f'<li><a href="books/{book["slug"]}.html">'
            f'<span class="book-index">{book["order"]:02d}</span>'
            f'<span class="book-body"><span class="book-title">{html.escape(book["title"])}</span>'
            f'<span class="book-subtitle">{html.escape(book["subtitle"])}</span></span>'
            f'<span class="book-meta">{book["edition"]} · {stats["pages"]} 页 · {stats["references"]} 文献</span>'
            f'</a></li>'
        )

    return f"""# 书目

<ul class="book-list">
{chr(10).join(rows)}
</ul>

---

内容 CC BY-NC-SA 4.0 · 代码 MIT · AI 生成 · 人工统稿 · [权利声明]({REPO_URL}/blob/main/NOTICE)
"""


def render_book(book: dict, pdf_bytes: int, has_cover: bool) -> str:
    slug = book["slug"]
    stats = book["stats"]
    cover = (
        f'<img class="book-cover" src="{slug}.jpg" alt="《{html.escape(book["title"])}》封面">\n\n'
        if has_cover
        else ""
    )
    toc = "\n".join(
        f'<li><span class="toc-num">{chapter["number"]:02d}</span>'
        f'<span>{html.escape(chapter["title"])}</span></li>'
        for chapter in book["chapters"]
    )
    appendix = "\n".join(
        f'<li><span class="toc-num"></span>'
        f'<span>附录 {html.escape(entry["number"])}　{html.escape(entry["title"])}</span></li>'
        for entry in book["appendix"]
    )

    return f"""# {book['title']}

<p class="book-subtitle">{html.escape(book['subtitle'])}</p>

<p class="book-title-en">{html.escape(book['title_en'])}</p>

[Typst 源码]({REPO_URL}/tree/main/books/{slug}) · [溯源]({REPO_URL}/blob/main/books/{slug}/PROVENANCE.md) · [审校]({REPO_URL}/blob/main/books/{slug}/REVIEW.md)

<dl class="book-meta-list">
<div><dt>作者</dt><dd>{html.escape(book['author'])}</dd></div>
<div><dt>版次</dt><dd>{html.escape(book['edition'])}</dd></div>
<div><dt>页数</dt><dd>{stats['pages']}</dd></div>
<div><dt>文献</dt><dd>{stats['references']}</dd></div>
<div><dt>许可</dt><dd>{html.escape(book['license']['spdx'])}</dd></div>
</dl>

{cover}## 摘要

{book['abstract']}

## 目录

<ol class="book-toc">
{toc}
</ol>

<ul class="book-appendix">
{appendix}
</ul>

## 阅读

<p class="pdf-actions"><a class="pdf-open" href="{slug}.pdf" target="_blank" rel="noopener">打开 PDF</a><span class="pdf-size">{stats['pages']} 页 · {money(pdf_bytes)}</span></p>

也可以[下载到本地]({slug}.pdf)。

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
    shutil.copytree(SITE / "theme", SRC / "theme")

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
        print(f"  mdbook · /books/{slug}/ ({money(pdf.stat().st_size)})")

    subprocess.run(
        [mdbook, "build", str(SRC), "-d", str(DIST)],
        check=True, cwd=ROOT,
    )
    print(f"site written to {DIST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
