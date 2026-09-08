import { test } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { readFileSync } from "node:fs";
import { createViewerServer } from "../server.mjs";
import { createSessionStore, cookieId } from "../session-store.mjs";
import { messages, render } from "../messages.mjs";

test("REQ-117 REQ-119: opaque sessions expire, rotate, and cannot be forged", () => {
  let time = 1000;
  const store = createSessionStore({ now: () => time, ttlMs: 1000, limit: 2 });
  const first = store.create();
  assert.equal(store.valid(first), true);
  assert.equal(store.valid("forged"), false);
  const next = store.create(first);
  assert.equal(store.valid(first), false);
  assert.equal(store.valid(next), true);
  store.create();
  assert.equal(store.create(), null);
  store.remove(next);
  assert.equal(store.valid(next), false);
  time = 2000;
  assert.notEqual(store.create(), null);
  assert.equal(cookieId("sifap_viewer=a; sifap_viewer=b"), undefined);
});

test("REQ-116: three complete translations and escaped rendering", () => {
  const template = readFileSync(new URL("../landing.html", import.meta.url), "utf8");
  const keys = Object.keys(messages.en).sort();
  for (const locale of ["en", "es", "pt-BR"]) {
    assert.deepEqual(Object.keys(messages[locale]).sort(), keys);
    const html = render(template, locale);
    assert.ok(html.includes(`<html lang="${locale}">`));
    assert.ok(!html.includes("{{"));
    assert.ok(html.includes('action="/auth/viewer"'));
    assert.ok(!html.includes('type="password"'));
    assert.ok(!html.includes("demo-viewer-password"));
    assert.equal((html.match(/<h1 /g) ?? []).length, 1);
  }
  assert.throws(() => render("{{missing}}", "en"), /Missing landing message/);
});

test("REQ-117 REQ-118 REQ-119: one-click requires same-origin POST and only issues viewer access", async t => {
  const origin = "https://legacy.test";
  let clock = Date.now();
  const store = createSessionStore({ now: () => clock });
  const server = createViewerServer({ origin, store });
  server.listen(0, "127.0.0.1"); await once(server, "listening");
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (path, body, extra = {}) => fetch(base + path, { method: "POST", redirect: "manual",
    headers: { Origin: origin, "Content-Type": "application/x-www-form-urlencoded", ...extra }, body });
  for (const locale of ["en", "es", "pt-BR"]) {
    const page = await fetch(`${base}/${locale}/`);
    assert.equal(page.status, 200);
    assert.ok((await page.text()).includes(`<html lang="${locale}">`));
    assert.equal(page.headers.get("set-cookie"), null);
  }
  assert.equal((await fetch(`${base}/auth/viewer`, { redirect:"manual" })).status, 404);
  assert.equal((await post("/auth/viewer", "locale=en", { Origin: "https://evil.test" })).status, 403);
  assert.equal((await post("/auth/viewer", "locale=en&role=ADMIN")).status, 400);
  assert.equal((await post("/auth/viewer?role=ADMIN", "locale=en")).status, 400);
  const login = await post("/auth/viewer", "locale=en");
  assert.equal(login.status, 303);
  assert.equal(login.headers.get("location"), "/viewer?locale=en");
  const setCookie = login.headers.get("set-cookie");
  for (const attr of ["HttpOnly","Secure","SameSite=Strict","Max-Age=3600"]) assert.ok(setCookie.includes(attr));
  const cookie = setCookie.split(";")[0];
  const session = await fetch(`${base}/viewer?locale=en`, { headers: { Cookie: cookie } });
  assert.equal(session.status, 200);
  assert.ok((await session.text()).includes('iframe src="/terminal/"'));
  assert.equal((await fetch(`${base}/auth/check`, { headers: { Cookie: cookie } })).status, 204);
  const logout = await post("/auth/logout", "locale=en", { Cookie: cookie });
  assert.equal(logout.status, 303);
  assert.ok(logout.headers.get("set-cookie").includes("Max-Age=0"));
  assert.equal((await fetch(`${base}/auth/check`, { headers: { Cookie: cookie }, redirect:"manual" })).status, 303);
  assert.equal((await fetch(`${base}/viewer`, { headers: { Cookie:"sifap_viewer=forged" }, redirect:"manual" })).status, 303);
  const other = await post("/auth/viewer", "locale=en");
  clock += 3600001;
  assert.equal((await fetch(`${base}/auth/check`, { headers: { Cookie: other.headers.get("set-cookie").split(";")[0] }, redirect:"manual" })).status, 303);
});

test("REQ-118: production origins cannot disable TLS or contain credentials", () => {
  assert.throws(() => createViewerServer({ origin:"http://public.test" }));
  assert.throws(() => createViewerServer({ origin:"https://user:secret@public.test" }));
  assert.throws(() => createViewerServer({ origin:"https://public.test", secure:false }));
});
