#!/usr/bin/env python3
"""Download and verify the pinned Typst and mdBook binaries into .tools/.

Versions and checksums live in toolchain/versions.toml. Builds never
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
TOOLS = ("typst", "mdbook")


def load_config() -> dict:
    with VERSIONS.open("rb") as fh:
        return tomllib.load(fh)


def binary(name: str) -> Path:
    return ROOT / ".tools" / name


def current_version(name: str) -> str | None:
    path = binary(name)
    if not path.exists():
        return None
    try:
        out = subprocess.run(
            [str(path), "--version"], capture_output=True, text=True, timeout=10
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return None
    parts = out.split()
    return parts[1].lstrip("v") if len(parts) >= 2 else None


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


def install(
    name: str,
    cfg: dict,
    *,
    force: bool = False,
    archive_path: Path | None = None,
) -> None:
    version = cfg["version"]
    have = current_version(name)
    if have == version and not force:
        print(f"{name} {version} already installed at {binary(name).relative_to(ROOT)}")
        return
    if have:
        print(f"replacing {name} {have} with {version}")

    key = f"{platform.system().lower()}-{platform.machine().lower()}"
    platforms = cfg.get("platforms", {})
    if key not in platforms:
        raise SystemExit(
            f"no pinned {name} build for platform {key!r}; "
            f"available: {', '.join(sorted(platforms))}"
        )
    spec = platforms[key]
    url = spec["url"].format(version=version)
    expected = spec["sha256"]
    archive_root = spec.get("archive_root", "")
    member = f"{archive_root}/{name}" if archive_root else name
    if not expected:
        raise SystemExit(
            f"no sha256 pinned for {name} on {key} in toolchain/versions.toml"
        )

    binary(name).parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        archive = tmp / "package.tar.gz"
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
        with tarfile.open(archive, "r:*") as tar:
            try:
                extracted = tar.extractfile(member)
            except KeyError:
                raise SystemExit(f"{member} not found in {url}") from None
            if extracted is None:
                raise SystemExit(f"{member} is not a regular file in {url}")
            tmp_bin = tmp / f"{name}-bin"
            tmp_bin.write_bytes(extracted.read())
            tmp_bin.chmod(0o755)
        os.replace(tmp_bin, binary(name))

    print(f"installed {name} {version} -> {binary(name).relative_to(ROOT)}")


def main(argv: list[str]) -> int:
    cfg = load_config()
    from_path = None
    if "--from" in argv:
        index = argv.index("--from")
        try:
            from_path = Path(argv[index + 1]).expanduser().resolve()
        except IndexError:
            print("--from requires a path", file=sys.stderr)
            return 2

    if "--check" in argv:
        failures = 0
        for name in TOOLS:
            version = cfg[name]["version"]
            have = current_version(name)
            if have == version:
                print(f"{name} {version} ready")
            else:
                failures += 1
                print(f"{name} {version} missing (found {have or 'none'})", file=sys.stderr)
        return 1 if failures else 0

    force = "--force" in argv
    targets = [arg for arg in argv if arg in TOOLS] or list(TOOLS)
    for name in targets:
        install(
            name,
            cfg[name],
            force=force,
            archive_path=from_path if (len(targets) == 1 or name == "typst") else None,
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
