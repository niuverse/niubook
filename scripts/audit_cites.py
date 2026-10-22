#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Verify bibliography entries against arXiv and Crossref.

This is a review aid, not a build gate: it needs network access and the
metadata it checks is often incomplete. Results are written to
`reports/citations.md` for humans to act on.
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
import time
import tomllib
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARXIV_API = "https://export.arxiv.org/api/query?id_list="
CROSSREF_API = "https://api.crossref.org/works/"
ARXIV_RE = re.compile(r"arXiv:\s*(\d{4}\.\d{4,5})", re.IGNORECASE)
ENTRY_RE = re.compile(r"^@(\w+)\{\s*([^,\s]+)\s*,", re.MULTILINE)
ATOM = {"a": "http://www.w3.org/2005/Atom"}


def parse_entries(text: str) -> list[dict]:
    """Return [{type, key, fields, unverified}] using brace matching."""
    entries = []
    index = 0
    pending_unverified = False
    while index < len(text):
        line_end = text.find("\n", index)
        if line_end == -1:
            line_end = len(text)
        line = text[index:line_end].strip()
        if line.startswith("%"):
            if line.startswith("% UNVERIFIED"):
                pending_unverified = True
            index = line_end + 1
            continue
        match = ENTRY_RE.match(text, index)
        if not match:
            index = line_end + 1
            continue

        depth = 1
        entry_end = match.end()
        while entry_end < len(text) and depth:
            if text[entry_end] == "{":
                depth += 1
            elif text[entry_end] == "}":
                depth -= 1
            entry_end += 1

        body = text[match.start():entry_end]
        fields = {}
        for field_match in re.finditer(r"(\w+)\s*=\s*\{", body):
            field_start = field_match.end()
            field_depth = 1
            field_cursor = field_start
            while field_cursor < len(body) and field_depth:
                if body[field_cursor] == "{":
                    field_depth += 1
                elif body[field_cursor] == "}":
                    field_depth -= 1
                field_cursor += 1
            fields[field_match.group(1).lower()] = " ".join(body[field_start:field_cursor - 1].split())

        entries.append(
            {
                "type": match.group(1),
                "key": match.group(2),
                "body": body,
                "fields": fields,
                "unverified": pending_unverified,
            }
        )
        pending_unverified = False
        index = entry_end + 1
    return entries


def normalize(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^0-9a-z\u4e00-\u9fff]+", " ", value)
    return " ".join(value.split())


def similar(left: str, right: str) -> float:
    return difflib.SequenceMatcher(None, normalize(left), normalize(right)).ratio()


def fetch(url: str, timeout: int = 30) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "niubook-cite-audit/1.0"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read()


def check_arxiv(arxiv_id: str) -> tuple[str, str]:
    payload = fetch(ARXIV_API + urllib.parse.quote(arxiv_id))
    root = ET.fromstring(payload)
    entry = root.find("a:entry", ATOM)
    if entry is None:
        return "missing", "arXiv 无此条目"
    title = " ".join((entry.findtext("a:title", default="", namespaces=ATOM)).split())
    return "ok", title


def check_crossref(doi: str) -> tuple[str, str]:
    payload = fetch(CROSSREF_API + urllib.parse.quote(doi))
    import json

    data = json.loads(payload)
    title = " ".join((data.get("message", {}).get("title") or [""])[0].split())
    return "ok", title


def audit_entry(entry: dict) -> dict:
    fields = entry["fields"]
    haystack = " ".join(str(value) for value in fields.values())
    title = fields.get("title", "")
    result = {"key": entry["key"], "status": "skipped", "detail": "", "title": title}

    arxiv = ARXIV_RE.search(haystack)
    doi = fields.get("doi", "")
    try:
        if arxiv:
            status, remote = check_arxiv(arxiv.group(1))
            score = similar(title, remote) if status == "ok" else 0.0
            result["detail"] = f"arXiv:{arxiv.group(1)} · {remote}"
            result["status"] = "ok" if score >= 0.75 else "mismatch"
            result["score"] = round(score, 2)
            time.sleep(3)
        elif doi:
            status, remote = check_crossref(doi)
            score = similar(title, remote) if status == "ok" else 0.0
            result["detail"] = f"DOI:{doi} · {remote}"
            result["status"] = "ok" if score >= 0.75 else "mismatch"
            result["score"] = round(score, 2)
            time.sleep(1)
        else:
            result["detail"] = "无 arXiv ID / DOI，需人工核"
    except Exception as error:  # noqa: BLE001 - network failures are data here
        result["status"] = "error"
        result["detail"] = f"{type(error).__name__}: {error}"
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("book_dir", nargs="?", default="books/embodied-rsi")
    parser.add_argument("--limit", type=int, default=0, help="only check N entries")
    parser.add_argument("--only-unverified", action="store_true")
    parser.add_argument("--only-flagged", action="store_true", help="deprecated alias")
    args = parser.parse_args()

    book_dir = Path(args.book_dir)
    if not book_dir.is_absolute():
        book_dir = (ROOT / book_dir).resolve()
    with (book_dir / "book.toml").open("rb") as fh:
        book = tomllib.load(fh)["book"]

    entries = parse_entries((book_dir / "references.bib").read_text(encoding="utf-8"))
    if args.only_unverified or args.only_flagged:
        entries = [entry for entry in entries if entry["unverified"]]
    if args.limit:
        entries = entries[: args.limit]

    print(f"checking {len(entries)} entries for {book['slug']} …")
    results = []
    for position, entry in enumerate(entries, start=1):
        result = audit_entry(entry)
        results.append(result)
        print(f"  [{position:>2}/{len(entries)}] {result['status']:<8} {result['key']}")

    report = ROOT / "reports" / "citations.md"
    report.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"# 文献核验报告 — {book['title']}",
        "",
        f"- 生成时间：{time.strftime('%Y-%m-%d %H:%M:%S')}",
        f"- 条目数：{len(results)}",
        "",
        "| 状态 | key | 相似度 | 说明 |",
        "| --- | --- | ---: | --- |",
    ]
    for result in results:
        score = result.get("score", "")
        detail = result["detail"].replace("|", "\\|")
        lines.append(f"| {result['status']} | `{result['key']}` | {score} | {detail} |")
    report.write_text("\n".join(lines) + "\n", encoding="utf-8")

    counts: dict[str, int] = {}
    for result in results:
        counts[result["status"]] = counts.get(result["status"], 0) + 1
    print("summary:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print(f"report: {report.relative_to(ROOT)}")
    return 0 if counts.get("mismatch", 0) == 0 and counts.get("error", 0) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
