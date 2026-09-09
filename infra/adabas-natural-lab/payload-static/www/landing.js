"use strict";
const locale = document.documentElement.lang;
document.querySelector(`.locale-switch a[hreflang="${locale}"]`)?.setAttribute("aria-current", "true");
const refresh = document.getElementById("refresh-status");
const status = document.getElementById("status");
if (refresh && status) {
  refresh.addEventListener("click", async () => {
    refresh.disabled = true;
    status.setAttribute("aria-busy", "true");
    status.textContent = status.dataset.loading;
    try {
      const response = await fetch("/healthz", { cache: "no-store", signal: AbortSignal.timeout(10000) });
      status.textContent = response.ok ? status.dataset.online : status.dataset.offline;
    } catch (error) {
      if (!(error instanceof TypeError) && !(error instanceof DOMException)) throw error;
      status.textContent = status.dataset.offline;
    } finally {
      refresh.disabled = false;
      status.setAttribute("aria-busy", "false");
    }
  });
}
