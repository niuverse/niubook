#!/usr/bin/env python3
"""Validate references.bib: balanced braces, key and title present per entry.

Usage: python3 validate_bib.py [path-to-references.bib]
Prints total entries, UNVERIFIED count, first 20 keys; exits nonzero on errors.
"""
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "references.bib"
text = open(path, encoding="utf-8").read()

# Split off comment lines; map UNVERIFIED markers to the entry that follows them.
entries = []          # (type, key, body, unverified)
pending_unv = False
i, n = 0, len(text)
while i < n:
    line_end = text.find("\n", i)
    if line_end == -1:
        line_end = n
    line = text[i:line_end]
    stripped = line.strip()
    if stripped.startswith("%"):
        if stripped.startswith("% UNVERIFIED"):
            pending_unv = True
        i = line_end + 1
        continue
    m = re.match(r"\s*@([A-Za-z]+)\s*\{", text[i:])
    if m:
        start = i
        j = i + m.end() - 1
        depth, k = 0, j
        while k < n:
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        if depth != 0:
            print(f"FATAL: unbalanced braces for entry starting at offset {start}")
            sys.exit(1)
        body = text[start:k + 1]
        km = re.match(r"\s*@([A-Za-z]+)\s*\{\s*([^,\s]+)", body)
        entries.append((km.group(1), km.group(2), body, pending_unv))
        pending_unv = False
        i = k + 1
    else:
        i = line_end + 1

errors = []
for etype, key, body, unv in entries:
    if body.count("{") != body.count("}"):
        errors.append(f"{key}: unbalanced braces")
    if not key:
        errors.append("entry with empty key")
    if not re.search(r"(?im)^\s*title\s*=", body):
        errors.append(f"{key}: missing title")

keys = [k for _, k, _, _ in entries]
if len(keys) != len(set(keys)):
    dup = [k for k in set(keys) if keys.count(k) > 1]
    errors.append(f"duplicate keys: {dup}")

n_unv = sum(1 for *_, unv in entries if unv)
print(f"file           : {path}")
print(f"total entries  : {len(entries)}")
print(f"UNVERIFIED     : {n_unv}")
print(f"first 20 keys  : {keys[:20]}")
if errors:
    print(f"ERRORS ({len(errors)}):")
    for e in errors:
        print("  -", e)
    sys.exit(1)
print("all checks passed: braces balanced, every entry has key + title, keys unique")
