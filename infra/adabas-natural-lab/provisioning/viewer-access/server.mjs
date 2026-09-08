import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createSessionStore, cookieId } from "./session-store.mjs";
import { messages, localeOf, render, escapeHtml } from "./messages.mjs";

const template = readFileSync(new URL("./landing.html", import.meta.url), "utf8");
export function createViewerServer({ origin, secure = true, store = createSessionStore(), now = Date.now } = {}) {
  const expected = new URL(origin);
  if (expected.origin !== origin || (expected.protocol !== "https:" &&
    !(expected.protocol === "http:" && ["127.0.0.1","localhost"].includes(expected.hostname))))
    throw new Error("SIFAP_ORIGIN must be an HTTPS origin or local test origin.");
  if (expected.protocol === "https:" && !secure) throw new Error("HTTPS sessions must use Secure cookies.");
  const attempts = new Map();
  const handle = async (req, res) => {
    const headers = {
      "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "same-origin", "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": "default-src 'self'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self' data:; connect-src 'self'; frame-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'self'",
    };
    const url = new URL(req.url, origin);
    let locale = localeOf(url.searchParams.get("locale") ?? url.pathname.split("/")[1]);
    const id = cookieId(req.headers.cookie);
    const send = (status, body = "", extra = {}) => { res.writeHead(status, { ...headers, ...extra }); res.end(body); };
    const redirect = (location, extra = {}) => send(303, "", { Location: location, ...extra });
    const cookie = (value, age) => `sifap_viewer=${value}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${age}${secure ? "; Secure" : ""}`;
    const failure = (status, key) => {
      const d = messages[locale];
      send(status, `<!doctype html><html lang="${locale}"><meta name="viewport" content="width=device-width"><link rel="stylesheet" href="/landing.css"><title>${d.errorTitle}</title><main class="container access-error"><h1>${d.errorTitle}</h1><p role="alert">${d[key]}</p><a class="button button-primary" href="/${locale}/">${d.retry}</a></main></html>`);
    };
    if (req.method === "GET" && url.pathname === "/internal/health") return send(200, "ok");
    if (req.method === "GET" && url.pathname === "/auth/check") {
      return store.valid(id) ? send(204) : redirect(`/${locale}/?session=expired`);
    }
    if (req.method === "GET" && url.pathname === "/viewer") {
      if (!store.valid(id)) return redirect(`/${locale}/?session=expired`);
      const d = messages[locale];
      return send(200, `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>SIFAP — ${d.session}</title><link rel="stylesheet" href="/landing.css"></head><body class="viewer-workspace"><header class="viewer-bar"><a class="brand" href="/${locale}/">SIFAP<span class="brand-dot">.</span></a><span class="viewer-label">${d.onlyRead}</span><form method="post" action="/auth/logout"><input type="hidden" name="locale" value="${locale}"><button class="button button-secondary" type="submit">${d.logout}</button></form></header><main><h1>${d.session}</h1><p>${d.terminalHelp}</p><iframe src="/terminal/" title="SIFAP Natural — VIEWBENF" allow="clipboard-read; clipboard-write"></iframe></main></body></html>`);
    }
    if (req.method === "GET" && ["/","/index.html","/en","/en/","/es","/es/","/pt-BR","/pt-BR/","/login"].includes(url.pathname)) {
      return send(200, render(template, locale));
    }
    if (req.method === "POST" && ["/auth/viewer","/auth/logout"].includes(url.pathname)) {
      if (req.headers.origin !== origin || (req.headers["sec-fetch-site"] && req.headers["sec-fetch-site"] !== "same-origin"))
        return failure(403, "forbidden");
      if (!String(req.headers["content-type"] ?? "").startsWith("application/x-www-form-urlencoded"))
        return failure(415, "forbidden");
      let body = "";
      try {
        for await (const chunk of req) {
          body += chunk.toString("utf8");
          if (body.length > 256) { failure(413, "forbidden"); req.resume(); return; }
        }
      } catch (error) {
        if (error.code === "ECONNRESET") { res.destroy(); return; }
        throw error;
      }
      const form = new URLSearchParams(body);
      if ([...form.keys()].some(key => key !== "locale") || form.getAll("locale").length !== 1 ||
          !Object.hasOwn(messages, form.get("locale")) || url.search)
        return failure(400, "forbidden");
      locale = form.get("locale");
      if (url.pathname === "/auth/logout") {
        store.remove(id);
        return redirect(`/${locale}/`, { "Set-Cookie": cookie("", 0) });
      }
      const time = now();
      for (const [key, item] of attempts) if (item.until <= time) attempts.delete(key);
      const source = req.socket.remoteAddress;
      const item = attempts.get(source) ?? { count: 0, until: time + 60000 };
      if (item.count >= 120 || attempts.size >= 1024) return failure(429, "capacity");
      attempts.set(source, { count: item.count + 1, until: item.until });
      const session = store.create(id);
      if (!session) return failure(503, "capacity");
      return redirect(`/viewer?locale=${locale}`, { "Set-Cookie": cookie(session, 3600) });
    }
    return send(404, escapeHtml(messages[locale].forbidden));
  };
  return createServer({ maxHeaderSize: 8192, requestTimeout: 10000, headersTimeout: 10000 }, (req, res) => {
    handle(req, res).catch(error => {
      // Limite HTTP: falhas inesperadas ficam explicitas, sem dados de sessao nos logs.
      console.error("Viewer request failed:", error.name);
      if (!res.headersSent) {
        res.writeHead(503, { "Content-Type": "text/plain; charset=utf-8", "Cache-Control":"no-store" });
        res.end("Viewer service unavailable. Please retry.");
      } else res.destroy();
    });
  });
}
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createViewerServer({ origin: process.env.SIFAP_ORIGIN,
    secure: process.env.SIFAP_COOKIE_SECURE !== "false" });
  server.listen(Number(process.env.PORT ?? 8082), "0.0.0.0", () => console.log("Legacy viewer session gateway ready."));
}
