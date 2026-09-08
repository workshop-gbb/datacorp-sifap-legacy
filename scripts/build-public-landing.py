"""Export only approved presentation assets, never the private lab payload."""

from __future__ import annotations

import argparse
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "infra" / "adabas-natural-lab" / "payload-static" / "www"
PUBLIC_FILES = (
    "index.html",
    "landing.css",
    "favicon.svg",
    "fonts/inter-latin-wght-normal.woff2",
    "fonts/jetbrains-mono-latin-wght-normal.woff2",
    "fonts/Inter-LICENSE.txt",
    "fonts/JetBrainsMono-LICENSE.txt",
)


def build(output: Path) -> None:
    output = output.resolve()
    if output.is_relative_to(ROOT):
        raise ValueError("The public export must be outside the private source checkout.")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise ValueError("The public export directory must be new or empty.")

    for name in PUBLIC_FILES:
        source = SOURCE / name
        if (
            not source.is_file()
            or source.is_symlink()
            or not source.resolve().is_relative_to(SOURCE)
        ):
            raise ValueError(f"Missing or unsafe public asset: {name}")

    output.mkdir(parents=True, exist_ok=True)
    for name in PUBLIC_FILES:
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE / name, destination)
    (output / ".nojekyll").touch()
    print(f"Exported {len(PUBLIC_FILES) + 1} public files to {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New or empty directory outside this checkout")
    arguments = parser.parse_args()
    try:
        build(arguments.output)
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
