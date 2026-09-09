import { createServer } from "node:http";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createSessionStore, cookieId } from "./session-store.mjs";
import { loadAccounts, authenticate } from "./credentials.mjs";
import { messages, localeOf, render, escapeHtml } from "./messages.mjs";

const template = readFileSync(new URL("./landing.html", import.meta.url), "utf8");

export function createViewerServer({
  origin, secure = true, store = createSessionStore(), accounts = loadAccounts(), now = Date.now,
} = {}) {
  if (typeof origin !== "string" || !origin)
    throw new Error("SIFAP_ORIGIN is required.");
  const expected = new URL(origin);
  const localTest = expected.protocol === "http:" && ["127.0.0.1", "localhost"].includes(expected.hostname);
  if (expected.origin !== origin || (expected.protocol !== "https:" && !localTest))
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
    const role = store.role(id);
    const send = (status, body = "", extra = {}) => { res.writeHead(status, { ...headers, ...extra }); res.end(body); };
    const redirect = (location, extra = {}) => send(303, "", { Location: location, ...extra });
    const cookie = (value, age) =>
      `sifap_viewer=${value}; Path=/; HttpOnly; SameSite=Strict; Max-Age=${age}${secure ? "; Secure" : ""}`;
    const failure = (status, key, extra = {}) => {
      const d = messages[locale];
      send(status, `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><link rel="stylesheet" href="/landing.css"><title>${d.errorTitle}</title></head><body><main class="container access-error"><h1>${d.errorTitle}</h1><p role="alert">${d[key]}</p><a class="button button-primary" href="/${locale}/#acesso">${d.retry}</a></main></body></html>`, extra);
    };

    if (req.method === "GET" && url.pathname === "/internal/health") return send(200, "ok");
    if (req.method === "GET" && (url.pathname === "/auth/check" || url.pathname === "/auth/check-admin")) {
      if (!role) return redirect(`/${locale}/?session=expired#acesso`);
      if (url.pathname === "/auth/check-admin" && role !== "ADMIN") return failure(403, "adminOnly");
      return send(204, "", { "X-Sifap-Role": role });
    }
    if (req.method === "GET" && url.pathname === "/viewer") {
      if (!role) return redirect(`/${locale}/?session=expired#acesso`);
      const d = messages[locale];
      const label = role === "ADMIN" ? d.adminRole : d.viewerRole;
      const admin = role === "ADMIN"
        ? `<a class="button button-secondary" href="/admin/">${d.admin}</a>` : "";
      return send(200, `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>SIFAP — ${d.session}</title><link rel="stylesheet" href="/landing.css"></head><body class="viewer-workspace"><header class="viewer-bar"><a class="brand" href="/${locale}/">SIFAP<span class="brand-dot">.</span></a><span class="viewer-label">${escapeHtml(label)}</span><div class="viewer-actions">${admin}<form method="post" action="/auth/logout"><input type="hidden" name="locale" value="${locale}"><button class="button button-secondary" type="submit">${d.logout}</button></form></div></header><main><h1>${d.session}</h1><p>${role === "ADMIN" ? d.adminTerminalHelp : d.terminalHelp}</p><iframe src="/terminal/" title="SIFAP Natural" allow="clipboard-read; clipboard-write"></iframe></main></body></html>`);
    }
    if (req.method === "GET" &&
      ["/", "/index.html", "/en", "/en/", "/es", "/es/", "/pt-BR", "/pt-BR/", "/login"].includes(url.pathname)) {
      return send(200, render(template, locale, { failed: url.searchParams.get("session") === "invalid" }));
    }
    if (req.method === "POST" && ["/auth/login", "/auth/logout"].includes(url.pathname)) {
      if (req.headers.origin !== origin ||
        (req.headers["sec-fetch-site"] && req.headers["sec-fetch-site"] !== "same-origin"))
        return failure(403, "forbidden");
      if (!String(req.headers["content-type"] ?? "").startsWith("application/x-www-form-urlencoded"))
        return failure(415, "forbidden");
      let body = "";
      try {
        for await (const chunk of req) {
          body += chunk.toString("utf8");
          if (body.length > 1024) { failure(413, "forbidden"); req.resume(); return; }
        }
      } catch (error) {
        if (error.code === "ECONNRESET") { res.destroy(); return; }
        throw error;
      }
      const form = new URLSearchParams(body);
      const allowed = url.pathname === "/auth/logout"
        ? new Set(["locale"]) : new Set(["locale", "username", "password"]);
      if ([...form.keys()].some(key => !allowed.has(key)) || form.getAll("locale").length !== 1 ||
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
      const item = attempts.get(source) ?? { count: 0, until: time + 300000 };
      if (item.count >= 20 || attempts.size >= 1024) return failure(429, "rateLimited");
      attempts.set(source, { count: item.count + 1, until: item.until });
      if (form.getAll("username").length !== 1 || form.getAll("password").length !== 1)
        return failure(400, "forbidden");
      const granted = authenticate(accounts, form.get("username"), form.get("password"));
      if (!granted) return failure(401, "invalidCredentials");
      const session = store.create(granted, id);
      if (!session) return failure(503, "capacity");
      attempts.delete(source);
      return redirect(`/viewer?locale=${locale}`, { "Set-Cookie": cookie(session, 3600) });
    }
    return send(404, escapeHtml(messages[locale].forbidden));
  };

  return createServer({ maxHeaderSize: 8192, requestTimeout: 15000, headersTimeout: 15000 }, (req, res) => {
    handle(req, res).catch(error => {
      // Failures stay explicit; no session, credential or account data is logged.
      console.error("Viewer request failed:", error.name);
      if (!res.headersSent) {
        res.writeHead(503, { "Content-Type": "text/plain; charset=utf-8", "Cache-Control": "no-store" });
        res.end("Viewer service unavailable. Please retry.");
      } else res.destroy();
    });
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createViewerServer({
    origin: process.env.SIFAP_ORIGIN,
    secure: process.env.SIFAP_COOKIE_SECURE !== "false",
  });
  server.listen(Number(process.env.PORT ?? 8082), "0.0.0.0",
    () => console.log("SIFAP legacy sign-in gateway ready."));
}
