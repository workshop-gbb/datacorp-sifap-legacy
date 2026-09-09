import { normalizeLocale, translate } from "./i18n.mjs";

const pageKind = document.body.dataset.page === "demo" ? "demo" : "site";
let currentLocale = normalizeLocale(new URL(location.href).searchParams.get("lang") ?? new URL(location.href).searchParams.get("locale"));
export const locale = () => currentLocale;
export const t = (key, params) => translate(currentLocale, key, params);

export function applyLocale(value) {
  currentLocale = normalizeLocale(value);
  document.documentElement.lang = currentLocale;
  document.title = t(`${pageKind}.title`);
  for (const element of document.querySelectorAll("[data-i18n]")) {
    element.textContent = t(element.dataset.i18n);
  }
  for (const attribute of ["aria-label", "placeholder", "title", "content"]) {
    for (const element of document.querySelectorAll(`[data-i18n-${attribute}]`)) {
      element.setAttribute(attribute, t(element.getAttribute(`data-i18n-${attribute}`)));
    }
  }
  const url = new URL(location.href);
  url.searchParams.delete("locale");
  url.searchParams.set("lang", currentLocale);
  history.replaceState(null, "", url);
  for (const link of document.querySelectorAll("[data-locale]")) {
    const next = new URL(url);
    next.searchParams.set("lang", link.dataset.locale);
    link.href = next.href;
    if (link.dataset.locale === currentLocale) link.setAttribute("aria-current", "page");
    else link.removeAttribute("aria-current");
  }
  for (const link of document.querySelectorAll("[data-home-link]")) {
    link.href = `${pageKind === "demo" ? "../" : "./"}?lang=${currentLocale}`;
  }
  for (const link of document.querySelectorAll("[data-demo-link]")) {
    link.href = `${pageKind === "demo" ? "./" : "./demo/"}?lang=${currentLocale}`;
  }
  for (const link of document.querySelectorAll("[data-real-link]")) {
    link.href = `https://sifap-lab-438k30.eastus2.cloudapp.azure.com/login?locale=${currentLocale}`;
  }
  // Todo link de destino abre em nova aba; o seletor de idioma continua na mesma.
  for (const link of document.querySelectorAll("a[href]:not([data-locale])")) {
    if (link.getAttribute("href").startsWith("#")) continue;
    link.target = "_blank";
    link.rel = link.href.startsWith(location.origin) ? "noopener" : "noopener noreferrer";
  }
  document.dispatchEvent(new CustomEvent("sifap:locale", { detail: currentLocale }));
}

document.addEventListener("click", event => {
  const link = event.target.closest("a[data-locale]");
  if (!link || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  event.preventDefault();
  applyLocale(link.dataset.locale);
});

window.addEventListener("popstate", () => applyLocale(new URL(location.href).searchParams.get("lang")));
applyLocale(currentLocale);
