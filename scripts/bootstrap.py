#!/usr/bin/env python3
"""Download and verify the pinned Typst binary into .tools/typst.

The version and checksum live in toolchain/versions.toml. Builds never
download Typst packages: CeTZ and friends are vendored under toolchain/vendor.
"""

from __future__ import annotations

import hashlib
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSIONS = ROOT / "toolchain" / "versions.toml"
DEST = ROOT / ".tools" / "typst"


def load_config() -> dict:
    with VERSIONS.open("rb") as fh:
        return tomllib.load(fh)


def current_version() -> str | None:
    if not DEST.exists():
        return None
    try:
        out = subprocess.run(
            [str(DEST), "--version"], capture_output=True, text=True, timeout=10
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    parts = out.split()
    return parts[1] if len(parts) >= 2 else None


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    print(f"  downloading {url}", flush=True)
    if shutil.which("curl"):
        subprocess.run(
            [
                "curl", "--fail", "--location", "--silent", "--show-error",
                "--retry", "3", "--connect-timeout", "20",
                "--output", str(target), url,
            ],
            check=True,
        )
        return

    import urllib.request

    with urllib.request.urlopen(url, timeout=120) as response, target.open("wb") as fh:
        shutil.copyfileobj(response, fh)


def install(cfg: dict, force: bool = False, archive_path: Path | None = None) -> None:
    typst = cfg["typst"]
    version = typst["version"]
    have = current_version()
    if have == version and not force:
        print(f"typst {version} already installed at {DEST.relative_to(ROOT)}")
        return
    if have:
        print(f"replacing typst {have} with {version}")

    key = f"{platform.system().lower()}-{platform.machine().lower()}"
    platforms = typst.get("platforms", {})
    if key not in platforms:
        raise SystemExit(
            f"no pinned Typst build for platform {key!r}; "
            f"available: {', '.join(sorted(platforms))}"
        )
    spec = platforms[key]
    url = spec["url"].format(version=version)
    expected = spec["sha256"]
    archive_root = spec["archive_root"]
    if not expected:
        raise SystemExit(
            f"no sha256 pinned for {key} in toolchain/versions.toml; "
            "add the checksum before bootstrapping on this platform"
        )

    DEST.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        archive = tmp / "typst.tar.xz"
        if archive_path is not None:
            print(f"  using local archive {archive_path}", flush=True)
            shutil.copyfile(archive_path, archive)
        else:
            download(url, archive)
        actual = sha256(archive)
        if actual != expected:
            raise SystemExit(
                f"checksum mismatch for {url}\n  expected {expected}\n  actual   {actual}"
            )
        with tarfile.open(archive, "r:xz") as tar:
            member = tar.getmember(f"{archive_root}/typst")
            extracted = tar.extractfile(member)
            if extracted is None:
                raise SystemExit("archive does not contain the typst binary")
            tmp_bin = tmp / "typst-bin"
            tmp_bin.write_bytes(extracted.read())
            tmp_bin.chmod(0o755)
        os.replace(tmp_bin, DEST)

    print(f"installed typst {version} -> {DEST.relative_to(ROOT)}")


def main(argv: list[str]) -> int:
    cfg = load_config()
    archive_path = None
    if "--from" in argv:
        index = argv.index("--from")
        try:
            archive_path = Path(argv[index + 1]).expanduser().resolve()
        except IndexError:
            print("--from requires a path", file=sys.stderr)
            return 2
    if "--check" in argv:
        version = cfg["typst"]["version"]
        have = current_version()
        if have == version:
            print(f"typst {version} ready")
            return 0
        print(f"typst {version} missing (found {have or 'none'})", file=sys.stderr)
        return 1
    install(cfg, force="--force" in argv, archive_path=archive_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
