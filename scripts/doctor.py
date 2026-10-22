#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check the local toolchain before building or publishing."""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TYPST = ROOT / ".tools" / "typst"

REQUIRED_FONTS = ("New Computer Modern", "Noto Serif CJK SC", "Noto Sans CJK SC")
OPTIONAL_BINARIES = {"pdfinfo": "poppler-utils", "pdftotext": "poppler-utils", "pdftoppm": "poppler-utils"}


def main() -> int:
    failures = 0

    if TYPST.exists():
        version = subprocess.run([str(TYPST), "--version"], capture_output=True, text=True).stdout.strip()
        print(f"  ✓ typst              {version}")
    else:
        failures += 1
        print("  ✗ typst              missing; run `just bootstrap`")

    vendor = ROOT / "toolchain" / "vendor" / "preview"
    for package in ("cetz", "oxifmt"):
        if (vendor / package).is_dir():
            print(f"  ✓ package {package:<10} vendored")
        else:
            failures += 1
            print(f"  ✗ package {package:<10} missing under toolchain/vendor/preview")

    if TYPST.exists():
        fonts = subprocess.run([str(TYPST), "fonts"], capture_output=True, text=True).stdout
        for font in REQUIRED_FONTS:
            if font in fonts:
                print(f"  ✓ font {font:<19} available")
            else:
                failures += 1
                print(f"  ✗ font {font:<19} missing; install fonts-noto-cjk (CJK)")

    for binary, package in OPTIONAL_BINARIES.items():
        if shutil.which(binary):
            print(f"  ✓ {binary:<19} available")
        else:
            print(f"  ! {binary:<19} missing; install {package} for page counts and covers")

    print()
    if failures:
        print("toolchain is incomplete", file=sys.stderr)
        return 1
    print("toolchain ready")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
