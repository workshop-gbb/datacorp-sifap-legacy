"""Protect the static landing without starting Natural or changing the lab."""

from __future__ import annotations

from html.parser import HTMLParser
import re
from urllib.parse import urljoin, urlsplit

import pytest

from conftest import ROOT

PUBLIC_SITE = ROOT / "public-landing"
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
    return LandingDocument((PUBLIC_SITE / "index.html").read_text(encoding="utf-8"))


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
        assert action.get("target") == "_blank"
        assert "noopener" in (action.get("rel") or "")
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
    assert document.attributes("script") == [{"type": "module", "src": "./site.mjs"}]
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
    assert "sem senha" in text.lower()
    assert "credenciais" not in text.lower()


def test_should_ship_all_assets_inside_the_public_landing(
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
        local_file = (PUBLIC_SITE / parsed.path.lstrip("/")).resolve()
        assert local_file.is_relative_to(PUBLIC_SITE.resolve())
        assert local_file.is_file(), f"Missing payload asset: {asset}"
    assert not document.attributes("style")


def test_should_use_local_fonts_and_respect_reduced_motion() -> None:
    css = (PUBLIC_SITE / "landing.css").read_text(encoding="utf-8")

    assert "prefers-reduced-motion" in css
    assert ":focus-visible" in css
    for url in re.findall(r"url\(\s*['\"]?([^'\"\s)]+)", css):
        parsed = urlsplit(url)
        assert not parsed.scheme and not parsed.netloc, f"External CSS asset: {url}"
        assert not parsed.path.startswith("/"), f"Font escapes the Pages base path: {url}"
        font = (PUBLIC_SITE / parsed.path.lstrip("/")).resolve()
        assert font.is_relative_to(PUBLIC_SITE.resolve())
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


def test_should_link_the_complete_simulation_and_offer_all_site_languages(
    document: LandingDocument,
) -> None:
    locales = {
        attrs["data-locale"]: attrs["href"]
        for attrs in document.attributes("a") if "data-locale" in attrs
    }
    assert locales == {
        "pt-BR": "?lang=pt-BR", "en": "?lang=en", "es": "?lang=es",
    }
    demo_links = [
        attrs["href"] for attrs in document.attributes("a") if "data-demo-link" in attrs
    ]
    assert len(demo_links) >= 3
    assert set(demo_links) == {"./demo/?lang=pt-BR"}
    assert (PUBLIC_SITE / "demo/index.html").is_file()
    for attrs in document.attributes("a"):
        if attrs.get("href", "").startswith(("#", "?")) or "data-home-link" in attrs:
            continue
        assert attrs.get("target") == "_blank", attrs.get("href")
        assert "noopener" in (attrs.get("rel") or ""), attrs.get("href")


def test_should_open_the_simulation_full_screen_without_site_chrome():
    demo = (PUBLIC_SITE / "demo/index.html").read_text(encoding="utf-8")
    document = LandingDocument(demo)
    body = next(attrs for tag, attrs in document.elements if tag == "body")

    assert body.get("data-page") == "demo"
    assert "demo-body" in (body.get("class") or "")
    assert not document.attributes("header")
    assert not document.attributes("footer")
    assert any(attrs.get("id") == "screen" for attrs in document.attributes("pre"))
    assert any(attrs.get("id") == "fullscreen" for attrs in document.attributes("button"))
    assert "./landing.css" not in demo and "../landing.css" not in demo
    css = (PUBLIC_SITE / "demo/demo.css").read_text(encoding="utf-8")
    assert "100dvh" in css
    assert ":fullscreen" in css
    assert "[hidden]" in css, "Hidden panels must not survive display:flex rules."
    assert "prefers-reduced-motion" in css
    script = (PUBLIC_SITE / "demo/demo.mjs").read_text(encoding="utf-8")
    assert "requestFullscreen" in script
    assert "armAutomaticFullScreen" in script, "Full screen must be armed for the first gesture."
    assert "ResizeObserver" in script, "The 80x24 grid must refit when the window changes."
    for attrs in document.attributes("a"):
        if attrs.get("href", "").startswith(("#", "?")):
            continue
        assert attrs.get("target") == "_blank"
        assert "noopener" in (attrs.get("rel") or "")


def test_should_translate_nested_demo_assets_without_including_remote_runtime():
    document = LandingDocument((PUBLIC_SITE / "demo/index.html").read_text(encoding="utf-8"))
    assert len(document.attributes("h1")) == 1
    for tag, attrs in document.elements:
        assert not any(name.startswith("on") for name in attrs)
        if tag in ("script", "link"):
            asset = attrs.get("src") or attrs.get("href")
            target = (PUBLIC_SITE / "demo" / asset).resolve()
            assert target.is_relative_to(PUBLIC_SITE.resolve())
            assert target.is_file()
    assert not document.attributes("iframe")
    assert not any(attrs.get("type") == "password" for attrs in document.attributes("input"))
    assert any(meta.get("http-equiv") == "Content-Security-Policy" and "connect-src 'self'" in meta["content"] for meta in document.attributes("meta"))
