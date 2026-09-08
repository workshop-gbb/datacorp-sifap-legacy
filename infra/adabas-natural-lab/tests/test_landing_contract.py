"""Protect the static landing without starting Natural or changing the lab."""

from __future__ import annotations

import hashlib
from html.parser import HTMLParser
import os
from pathlib import Path
import re
import subprocess
import tarfile
from urllib.parse import urljoin, urlsplit

import pytest

from conftest import LAB

WWW = LAB / "payload-static" / "www"
ENTRY_URL = "https://sifap-lab-438k30.eastus2.cloudapp.azure.com/login?locale=pt-BR"


class LandingDocument(HTMLParser):
    def __init__(self, source: str) -> None:
        super().__init__(convert_charrefs=True)
        self.elements: list[tuple[str, dict[str, str | None]]] = []
        self.links: list[tuple[dict[str, str | None], list[str]]] = []
        self.current_link: list[str] | None = None
        self.text: list[str] = []
        self.feed(source)

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        attributes = dict(attrs)
        self.elements.append((tag, attributes))
        if tag == "a":
            self.current_link = []
            self.links.append((attributes, self.current_link))

    def handle_endtag(self, tag: str) -> None:
        if tag == "a":
            self.current_link = None

    def handle_data(self, data: str) -> None:
        self.text.append(data)
        if self.current_link is not None:
            self.current_link.append(data)

    def attributes(self, tag: str) -> list[dict[str, str | None]]:
        return [attributes for name, attributes in self.elements if name == tag]


@pytest.fixture
def document() -> LandingDocument:
    return LandingDocument((WWW / "index.html").read_text(encoding="utf-8"))


def test_should_present_sifap_in_portuguese_with_accessible_page_structure(
    document: LandingDocument,
) -> None:
    assert document.attributes("html")[0]["lang"] == "pt-BR"
    assert len(document.attributes("h1")) == 1
    assert len(document.attributes("main")) == 1
    assert document.attributes("main")[0].get("id") == "main"
    assert document.attributes("main")[0].get("tabindex") == "-1"
    assert any(
        meta.get("name") == "viewport"
        and "width=device-width" in (meta.get("content") or "")
        for meta in document.attributes("meta")
    )
    assert any(
        meta.get("name") == "description" and meta.get("content")
        for meta in document.attributes("meta")
    )
    text = " ".join(document.text)
    assert "Sistema de Fiscalização e Administração de Pagamentos" in text
    assert "Natural" in text
    assert "Adabas" in text


def test_should_open_the_azure_session_entry_without_javascript(
    document: LandingDocument,
) -> None:
    actions = [
        attrs
        for attrs, text in document.links
        if "Acessar SIFAP legado" in " ".join(" ".join(text).split())
    ]

    assert len(actions) >= 2, "Both the hero and closing section need real access links."
    for action in actions:
        assert action["href"] == ENTRY_URL
        assert action.get("target") == "_self"
        assert action.get("referrerpolicy") == "no-referrer"
        assert "onclick" not in action


def test_should_resolve_skip_and_section_links(
    document: LandingDocument,
) -> None:
    ids = [
        attrs["id"] for _, attrs in document.elements if attrs.get("id") is not None
    ]
    hrefs = [attrs.get("href", "") for attrs in document.attributes("a")]

    assert len(ids) == len(set(ids)), "Page landmarks must have unique IDs."
    assert "#main" in hrefs
    assert {"main", "sobre", "acesso"}.issubset(ids)
    for href in hrefs:
        assert href
        if href.startswith("#"):
            assert href[1:] in ids, f"Broken section link: {href}"


def test_should_keep_authentication_and_operations_out_of_the_public_site(
    document: LandingDocument,
) -> None:
    hrefs = {attrs.get("href") for attrs in document.attributes("a")}

    assert not document.attributes("form"), "Do not introduce a second login flow."
    assert not document.attributes("input")
    assert not document.attributes("script"), "The public site must not fetch private status."
    assert not document.attributes("iframe")
    assert "/app/" not in hrefs, "The placeholder is not the deployed modern product."
    assert all(
        not any(path in (href or "") for path in ("/admin", "/status.html", "/healthz"))
        for href in hrefs
    )
    external = {href for href in hrefs if urlsplit(href).netloc}
    assert external == {ENTRY_URL}
    assert all(urlsplit(href).path != "/terminal/" for href in external)
    text = " ".join(document.text)
    assert "Sem senha" in text
    assert "credenciais" not in text.lower()


def test_should_ship_all_runtime_assets_inside_the_existing_payload(
    document: LandingDocument,
) -> None:
    assets = []
    for tag, attrs in document.elements:
        if tag in ("script", "img", "source"):
            assets.append(attrs.get("src"))
        if tag == "link" and attrs.get("rel") in ("stylesheet", "icon", "preload"):
            assets.append(attrs.get("href"))
        assert not any(name.startswith("on") for name in attrs)
        assert "style" not in attrs

    assert "./landing.css" in assets
    for asset in assets:
        assert asset, "Runtime assets must not be empty or inline."
        parsed = urlsplit(asset)
        assert not parsed.scheme and not parsed.netloc, f"External asset: {asset}"
        assert not parsed.path.startswith("/"), f"Asset escapes the Pages base path: {asset}"
        local_file = (WWW / parsed.path.lstrip("/")).resolve()
        assert local_file.is_relative_to(WWW.resolve())
        assert local_file.is_file(), f"Missing payload asset: {asset}"
    assert not document.attributes("style")


def test_should_use_local_fonts_and_respect_reduced_motion() -> None:
    css = (WWW / "landing.css").read_text(encoding="utf-8")

    assert "prefers-reduced-motion" in css
    assert ":focus-visible" in css
    for url in re.findall(r"url\(\s*['\"]?([^'\"\s)]+)", css):
        parsed = urlsplit(url)
        assert not parsed.scheme and not parsed.netloc, f"External CSS asset: {url}"
        assert not parsed.path.startswith("/"), f"Font escapes the Pages base path: {url}"
        font = (WWW / parsed.path.lstrip("/")).resolve()
        assert font.is_relative_to(WWW.resolve())
        assert font.is_file(), f"Missing CSS asset: {url}"
    assert not re.search(r"@import\s", css), "The lab must not depend on a font CDN."


@pytest.mark.parametrize(
    "base",
    ["https://workshop-gbb.github.io/datacorp-sifap-legacy/", "http://localhost:4388/"],
)
def test_should_resolve_home_assets_and_azure_login_from_each_host(
    document: LandingDocument, base: str,
) -> None:
    for tag, attrs in document.elements:
        if tag == "a" and attrs.get("href") == "./":
            assert urljoin(base, attrs["href"]) == base
        if tag == "a" and attrs.get("href") == ENTRY_URL:
            assert urljoin(base, attrs["href"]) == ENTRY_URL
        if tag == "link":
            assert urljoin(base, attrs["href"]).startswith(base)


@pytest.mark.parametrize(
    "script_name",
    ["deploy-local.sh", "install-payload-from-github.sh"],
)
def test_should_include_the_landing_in_both_payload_delivery_paths(
    script_name: str,
) -> None:
    script = (LAB / script_name).read_text(encoding="utf-8")

    assert 'payload-static/."' in script
    assert '"www/"' in script


def test_should_package_every_web_asset_with_a_matching_checksum(
    tmp_path: Path,
) -> None:
    destination = tmp_path / "sifap-payload.tar.gz"
    environment = {
        key: value for key, value in os.environ.items() if not key.startswith("SIFAP_")
    }
    environment["SIFAP_PAYLOAD_ARCHIVE"] = str(destination)
    result = subprocess.run(
        ["bash", str(LAB / "deploy-local.sh"), "package"],
        env=environment,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    with tarfile.open(destination, "r:gz") as archive:
        members = {
            member.name.removeprefix("./"): member
            for member in archive.getmembers()
            if member.isfile()
        }
        manifest_file = archive.extractfile(members["manifest.sha256"])
        assert manifest_file is not None
        checksums = {
            path: digest
            for digest, path in (
                line.split("  ", 1)
                for line in manifest_file.read().decode("utf-8").splitlines()
            )
        }
        for asset in WWW.rglob("*"):
            if not asset.is_file():
                continue
            name = "www/" + asset.relative_to(WWW).as_posix()
            assert name in members, f"Asset missing from delivered payload: {name}"
            packaged_file = archive.extractfile(members[name])
            assert packaged_file is not None
            content = packaged_file.read()
            assert content == asset.read_bytes(), f"Stale packaged asset: {name}"
            assert checksums[name] == hashlib.sha256(content).hexdigest()


def test_should_preserve_the_authenticated_caddy_terminal_boundary() -> None:
    source = (LAB / "cloud-init.yaml").read_text(encoding="utf-8")
    caddy = source.split("- path: /opt/sifap/Caddyfile", 1)[1].split(
        "- path: /opt/sifap/docker-compose.yml", 1
    )[0]

    assert "@protected not path /healthz /healthz/*" in caddy
    assert "basic_auth @protected" in caddy
    assert "handle /terminal*" in caddy
    assert "root * /srv" in caddy
    assert "file_server" in caddy
