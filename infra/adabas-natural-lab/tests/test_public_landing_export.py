"""Keep GitHub Pages publication separate from private runtime delivery."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import sys

import pytest

from conftest import ROOT

BUILDER = ROOT / "scripts" / "build-public-landing.py"
EXPECTED_FILES = {
    ".nojekyll",
    "index.html",
    "landing.css",
    "favicon.svg",
    "i18n.mjs",
    "site.mjs",
    "demo/index.html",
    "demo/demo.css",
    "demo/demo.mjs",
    "demo/model.mjs",
    "demo/terminal.mjs",
    "demo/data.json",
    "fonts/inter-latin-wght-normal.woff2",
    "fonts/jetbrains-mono-latin-wght-normal.woff2",
    "fonts/Inter-LICENSE.txt",
    "fonts/JetBrainsMono-LICENSE.txt",
}


@pytest.fixture
def builder():
    spec = importlib.util.spec_from_file_location("public_landing", BUILDER)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_should_export_exactly_the_approved_public_files(tmp_path: Path) -> None:
    destination = tmp_path / "public"
    result = subprocess.run(
        [sys.executable, str(BUILDER), str(destination)],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    actual = {
        path.relative_to(destination).as_posix()
        for path in destination.rglob("*")
        if path.is_file()
    }
    assert actual == EXPECTED_FILES
    for name in EXPECTED_FILES - {".nojekyll"}:
        source = ROOT / "public-landing" / name
        assert (destination / name).read_bytes() == source.read_bytes()
    assert (destination / ".nojekyll").read_bytes() == b""


def test_should_never_overwrite_an_existing_directory(builder, tmp_path: Path) -> None:
    existing = tmp_path / "keep.txt"
    existing.write_text("existing content", encoding="utf-8")

    with pytest.raises(ValueError, match="new or empty"):
        builder.build(tmp_path)

    assert existing.read_text(encoding="utf-8") == "existing content"
    assert list(tmp_path.iterdir()) == [existing]


def test_should_reject_output_inside_the_private_checkout(builder) -> None:
    with pytest.raises(ValueError, match="outside the private source checkout"):
        builder.build(ROOT / "accidental-public-export")

    assert not (ROOT / "accidental-public-export").exists()


def test_should_exclude_new_operational_files_by_default(
    builder, monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    source = tmp_path / "source"
    source.mkdir()
    for name in builder.PUBLIC_FILES:
        file = source / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text("public presentation asset", encoding="utf-8")
    (source / "status.html").write_text("private runtime details", encoding="utf-8")
    (source / ".env").write_text("NOT_FOR_PUBLICATION=fixture", encoding="utf-8")
    (source / "app").mkdir()
    (source / "app/index.html").write_text("private placeholder", encoding="utf-8")
    monkeypatch.setattr(builder, "SOURCE", source)
    output = tmp_path / "public"

    builder.build(output)

    assert {
        file.relative_to(output).as_posix()
        for file in output.rglob("*")
        if file.is_file()
    } == EXPECTED_FILES


def test_should_reject_symlinks_before_writing_any_output(
    builder, monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    source = tmp_path / "source"
    source.mkdir()
    private_file = tmp_path / "private.txt"
    private_file.write_text("private operation details", encoding="utf-8")
    (source / "index.html").symlink_to(private_file)
    monkeypatch.setattr(builder, "SOURCE", source)
    output = tmp_path / "public"

    with pytest.raises(ValueError, match="unsafe public asset"):
        builder.build(output)

    assert not output.exists()


def test_should_fail_explicitly_when_an_asset_is_missing(
    builder, monkeypatch: pytest.MonkeyPatch, tmp_path: Path,
) -> None:
    monkeypatch.setattr(builder, "SOURCE", tmp_path / "missing-source")
    output = tmp_path / "public"

    with pytest.raises(ValueError, match="Missing or unsafe public asset"):
        builder.build(output)

    assert not output.exists()
