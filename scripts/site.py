#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Render the Niubook reading site into dist/site.

The site is deliberately static: an index, one page per book, the PDF itself,
and a generated cover image. No JavaScript is required to read.
"""

from __future__ import annotations

import html
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))

from catalog import build_catalog, dump  # noqa: E402

SITE = ROOT / "site"
DIST = ROOT / "dist" / "site"
REPO_URL = "https://github.com/niuverse/niubook"
BASE_URL = os.environ.get("SITE_URL", "https://niuverse.github.io/niubook").rstrip("/")

READER_JS = """<script>
  document.querySelectorAll(".reader-shell").forEach(function (shell) {
    var button = shell.querySelector("[data-reader]");
    if (!button) return;
    button.addEventListener("click", function () {
      var frame = document.createElement("iframe");
      frame.src = shell.dataset.pdf;
      frame.title = shell.dataset.title || "PDF";
      frame.setAttribute("loading", "eager");
      shell.replaceChildren(frame);
    });
  });
</script>"""



def esc(value: object) -> str:
    return html.escape(str(value), quote=True)


def money(size: int) -> str:
    return f"{size / 1_000_000:.1f} MB"


def page(
    *,
    title: str,
    description: str,
    body: str,
    root: str,
    canonical: str,
    extra_head: str = "",
) -> str:
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<title>{esc(title)}</title>
<meta name="description" content="{esc(description)}">
<link rel="canonical" href="{esc(canonical)}">
<link rel="icon" href="{root}/assets/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="{root}/assets/style.css">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Niubook">
<meta property="og:title" content="{esc(title)}">
<meta property="og:description" content="{esc(description)}">
<meta property="og:url" content="{esc(canonical)}">
{extra_head}</head>
<body>
<a class="skip" href="#main">跳到正文</a>
<header class="masthead wrap">
  <a class="wordmark" href="{root}/">NIUBOOK</a>
  <nav aria-label="主导航">
    <a href="{root}/">书目</a>
    <a href="{REPO_URL}" rel="noopener">GitHub</a>
  </nav>
</header>
{body}
<footer class="wrap">
  <div class="footer-inner">
    <span>Niubook · 2026</span>
    <span>AI 生成 · 人工统稿</span>
    <span>内容 CC BY-NC-SA 4.0 · 代码 MIT</span>
    <a href="{REPO_URL}/blob/main/NOTICE" rel="noopener">权利声明</a>
  </div>
</footer>
</body>
</html>
"""


def render_index(catalog: dict) -> str:
    books = catalog["books"]
    rows = []
    for book in books:
        index = f"{book['order']:02d}"
        stats = book["stats"]
        meta_bits = [str(book["year"]), f"{stats['pages']} 页"]
        if stats["references"]:
            meta_bits.append(f"{stats['references']} 文献")
        rows.append(
            f"""      <li>
        <a class="book-row" href="books/{esc(book['slug'])}/">
          <span class="row-index">{index}</span>
          <span class="row-body">
            <span class="row-title">{esc(book['title'])}</span>
            <span class="row-sub">{esc(book['subtitle'])}</span>
          </span>
          <span class="row-meta">{esc(' · '.join(meta_bits))}</span>
          <span class="row-arrow" aria-hidden="true">→</span>
        </a>
      </li>"""
        )

    body = f"""<main id="main" class="wrap">
  <section class="catalogue" id="books">
    <div class="section-head">
      <h1>书目</h1>
      <span class="count">{len(books):02d} / {len(books):02d}</span>
    </div>
    <ol class="book-list">
{chr(10).join(rows)}
    </ol>
  </section>
</main>"""

    return page(
        title="Niubook — 书目",
        description="Niubook 书库：AI 生成书稿，Typst 源码，PDF 下载。",
        body=body,
        root=".",
        canonical=f"{BASE_URL}/",
    )


def render_book(book: dict, pdf_bytes: int, has_cover: bool) -> str:
    slug = book["slug"]
    stats = book["stats"]
    root = "../.."
    canonical = f"{BASE_URL}/books/{slug}/"

    chapters = "\n".join(
        f'        <li><span class="toc-num">{chapter["number"]:02d}</span>'
        f'<span class="toc-title">{esc(chapter["title"])}</span></li>'
        for chapter in book["chapters"]
    )
    appendix = "\n".join(
        f'        <li><span class="toc-num"></span>'
        f'<span class="toc-title">附录 {esc(entry["number"])}　{esc(entry["title"])}</span></li>'
        for entry in book["appendix"]
    )

    facts = [
        ("作者", book["author"]),
        ("篇幅", f"{stats['pages']} 页 · {len(book['chapters'])} 章"),
        ("文献", f"{stats['references']} 条"),
        ("版次", f"{book['edition']} · v{book['version']}"),
        ("许可", book["license"]["spdx"]),
        ("知识截点", book["knowledge_cutoff"]),
    ]
    facts_html = "\n".join(
        f"        <div><dt>{esc(label)}</dt><dd>{esc(value)}</dd></div>"
        for label, value in facts
    )

    cover_html = (
        f"""      <figure class="cover">
        <img src="cover.jpg" alt="《{esc(book['title'])}》封面" width="827" height="1169">
        <figcaption>{esc(book['edition'])} · {stats['pages']} 页</figcaption>
      </figure>"""
        if has_cover
        else ""
    )

    jsonld = {
        "@context": "https://schema.org",
        "@type": "Book",
        "name": book["title"],
        "alternateName": book["title_en"],
        "author": {"@type": "Organization", "name": book["author"]},
        "inLanguage": book["language"],
        "numberOfPages": stats["pages"],
        "bookEdition": book["edition"],
        "license": book["license"]["url"],
        "url": canonical,
        "description": book["abstract"],
    }

    body = f"""<main id="main" class="wrap">
  <nav class="crumbs" aria-label="面包屑">
    <a href="{root}/">书目</a><span aria-hidden="true">/</span><span>{book['order']:02d}</span>
  </nav>

  <header class="book-header">
    <p class="eyebrow">Book {book['order']:02d} · {esc(book['edition'])} · v{esc(book['version'])}</p>
    <h1>{esc(book['title'])}</h1>
    <p class="book-subtitle">{esc(book['subtitle'])}</p>
    <p class="book-title-en">{esc(book['title_en'])}</p>
    <p class="tag">AI 生成初稿 · 人工统稿</p>
    <div class="actions">
      <a class="btn primary" href="{slug}.pdf" download>下载 PDF<span>{money(pdf_bytes)}</span></a>
      <a class="btn" href="{slug}.pdf" target="_blank" rel="noopener">在线阅读</a>
    </div>
  </header>

  <section class="book-overview">
{cover_html}
    <div class="overview-text">
      <h2 class="label">摘要</h2>
      <p>{esc(book['abstract'])}</p>
      <dl class="facts">
{facts_html}
      </dl>
    </div>
  </section>

  <section class="toc">
    <h2 class="label">目录</h2>
    <ol>
        <li><span class="toc-num">—</span><span class="toc-title">前言</span></li>
{chapters}
{appendix}
    </ol>
  </section>

  <section class="reader">
    <h2 class="label">在线阅读</h2>
    <div class="reader-shell" data-pdf="{slug}.pdf#view=FitH" data-title="《{esc(book['title'])}》PDF">
      <div class="reader-placeholder">
        <p class="reader-meta">PDF · {stats['pages']} 页 · {money(pdf_bytes)}</p>
        <div class="actions">
          <button class="btn primary" type="button" data-reader>在页面内阅读</button>
          <a class="btn" href="{slug}.pdf" target="_blank" rel="noopener">新标签页打开</a>
        </div>
      </div>
    </div>
  </section>

  <section class="provenance">
    <h2 class="label">版本与溯源</h2>
    <p>初稿 {esc(book['provenance']['generator'])} · 人工统稿 · {stats['unverified']} 条文献待核验。</p>
    <ul class="links">
      <li><a href="{REPO_URL}/blob/main/books/{slug}/PROVENANCE.md" rel="noopener">溯源记录</a></li>
      <li><a href="{REPO_URL}/blob/main/books/{slug}/REVIEW.md" rel="noopener">审校台账</a></li>
      <li><a href="{REPO_URL}/tree/main/books/{slug}" rel="noopener">Typst 源码</a></li>
      <li><a href="{REPO_URL}/blob/main/LICENSE" rel="noopener">许可全文</a></li>
    </ul>
  </section>
</main>
{READER_JS}
<script type="application/ld+json">{json.dumps(jsonld, ensure_ascii=False)}</script>"""

    extra_head = (
        f'<meta property="og:type" content="book">\n'
        f'<meta property="og:image" content="{BASE_URL}/books/{slug}/cover.jpg">\n'
        f'<meta name="author" content="{esc(book["author"])}">\n'
        f'<link rel="alternate" type="application/pdf" href="{slug}.pdf">\n'
    )

    return page(
        title=f"{book['title']} — Niubook",
        description=book["abstract"][:140],
        body=body,
        root=root,
        canonical=canonical,
        extra_head=extra_head,
    )


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


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> int:
    catalog = build_catalog()
    if not catalog["books"]:
        print("no books to publish", file=sys.stderr)
        return 1

    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir(parents=True)
    shutil.copytree(SITE / "assets", DIST / "assets")

    write(DIST / "index.html", render_index(catalog))

    for book in catalog["books"]:
        slug = book["slug"]
        pdf = ROOT / "dist" / "books" / slug / f"{slug}.pdf"
        if not pdf.exists():
            print(f"missing {pdf.relative_to(ROOT)}; run `just build {slug}` first", file=sys.stderr)
            return 1
        out = DIST / "books" / slug
        out.mkdir(parents=True)
        shutil.copy2(pdf, out / f"{slug}.pdf")
        cover = make_cover(pdf, out / "cover.jpg")
        write(out / "index.html", render_book(book, pdf.stat().st_size, cover))
        print(f"  site · /books/{slug}/ ({money(pdf.stat().st_size)})")

    write(
        DIST / "robots.txt",
        f"User-agent: *\nAllow: /\nSitemap: {BASE_URL}/sitemap.xml\n",
    )
    urls = [f"{BASE_URL}/"] + [f"{BASE_URL}/books/{b['slug']}/" for b in catalog["books"]]
    sitemap = "\n".join(f"  <url><loc>{esc(url)}</loc></url>" for url in urls)
    write(
        DIST / "sitemap.xml",
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        f"{sitemap}\n</urlset>\n",
    )
    write(
        DIST / "books.json",
        dump(catalog),
    )
    write(
        DIST / "404.html",
        page(
            title="页面不存在 — Niubook",
            description="未找到该页面。",
            body='<main id="main" class="wrap notfound"><p class="eyebrow">404</p>'
                 '<h1>这一页不在书里。</h1><p><a href="./">返回书库</a></p></main>',
            root=".",
            canonical=f"{BASE_URL}/404.html",
        ),
    )

    print(f"site written to {DIST.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
