import { test } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { readFileSync } from "node:fs";
import { createViewerServer } from "../server.mjs";
import { createSessionStore, cookieId } from "../session-store.mjs";
import { hashPassword, verifyPassword, loadAccounts, authenticate } from "../credentials.mjs";
import { messages, render } from "../messages.mjs";

const ADMIN_PASSWORD = "local-test-admin-passphrase";
const VIEWER_PASSWORD = "local-test-viewer-passphrase";
const accounts = new Map([
  ["ADMIN", { username: "admin", hash: hashPassword(ADMIN_PASSWORD) }],
  ["VIEWER", { username: "viewer", hash: hashPassword(VIEWER_PASSWORD) }],
]);

test("REQ-121: passwords are stored as verifiable scrypt hashes only", () => {
  const hash = hashPassword(VIEWER_PASSWORD);
  assert.match(hash, /^scrypt\$32768\$8\$1\$/);
  assert.ok(!hash.includes(VIEWER_PASSWORD));
  assert.equal(verifyPassword(VIEWER_PASSWORD, hash), true);
  assert.equal(verifyPassword(VIEWER_PASSWORD + "x", hash), false);
  assert.equal(verifyPassword("", hash), false);
  assert.equal(verifyPassword(VIEWER_PASSWORD, "plaintext"), false);
  assert.notEqual(hash, hashPassword(VIEWER_PASSWORD));
  assert.throws(() => hashPassword("short"));
});

test("REQ-121: configuration rejects missing or malformed accounts", () => {
  const valid = hashPassword(ADMIN_PASSWORD);
  assert.throws(() => loadAccounts({}), /at least one workshop account/i);
  assert.throws(() => loadAccounts({ SIFAP_ADMIN_USERNAME: "bad user", SIFAP_ADMIN_PASSWORD_HASH: valid }), /invalid format/);
  assert.throws(() => loadAccounts({ SIFAP_ADMIN_USERNAME: "admin", SIFAP_ADMIN_PASSWORD_HASH: ADMIN_PASSWORD }), /scrypt hash/);
  const loaded = loadAccounts({ SIFAP_VIEWER_USERNAME: "viewer", SIFAP_VIEWER_PASSWORD_HASH: valid });
  assert.deepEqual([...loaded.keys()], ["VIEWER"]);
});

test("REQ-122: the requested role must match its own account", () => {
  assert.equal(authenticate(accounts, "admin", ADMIN_PASSWORD), "ADMIN");
  assert.equal(authenticate(accounts, "viewer", VIEWER_PASSWORD), "VIEWER");
  assert.equal(authenticate(accounts, "admin", VIEWER_PASSWORD), null);
  assert.equal(authenticate(accounts, "viewer", ADMIN_PASSWORD), null);
});

test("REQ-122: sessions carry a role, expire and cannot be forged", () => {
  let time = 1000;
  const store = createSessionStore({ now: () => time, ttlMs: 1000, limit: 2 });
  const admin = store.create("ADMIN");
  assert.equal(store.role(admin), "ADMIN");
  assert.equal(store.role("forged"), null);
  const rotated = store.create("VIEWER", admin);
  assert.equal(store.role(admin), null);
  assert.equal(store.role(rotated), "VIEWER");
  store.create("VIEWER");
  assert.equal(store.create("VIEWER"), null);
  time = 3000;
  assert.equal(store.role(rotated), null);
  assert.equal(cookieId("sifap_viewer=a; sifap_viewer=b"), undefined);
});

test("REQ-121: the sign-in form is translated and exposes no credential", () => {
  const template = readFileSync(new URL("../landing.html", import.meta.url), "utf8");
  const keys = Object.keys(messages.en).sort();
  for (const locale of ["en", "es", "pt-BR"]) {
    assert.deepEqual(Object.keys(messages[locale]).sort(), keys);
    const html = render(template, locale);
    assert.ok(html.includes(`<html lang="${locale}">`));
    assert.ok(!html.includes("{{"));
    assert.ok(html.includes('action="/auth/login"'));
    assert.ok(!html.includes('name="role"') && html.includes('type="password"'));
    assert.ok(!html.includes("/auth/viewer"));
    assert.equal((html.match(/<h1 /g) ?? []).length, 1);
    assert.ok(render(template, locale, { failed: true }).includes(messages[locale].invalidCredentials));
  }
});

test("REQ-121 REQ-122 REQ-123: sign-in enforces credentials, role and logout", async t => {
  const origin = "https://legacy.test";
  let clock = Date.now();
  const store = createSessionStore({ now: () => clock });
  const server = createViewerServer({ origin, store, accounts, now: () => clock });
  server.listen(0, "127.0.0.1"); await once(server, "listening");
  t.after(() => server.close());
  const base = `http://127.0.0.1:${server.address().port}`;
  const post = (path, body, extra = {}) => fetch(base + path, {
    method: "POST", redirect: "manual",
    headers: { Origin: origin, "Content-Type": "application/x-www-form-urlencoded", ...extra }, body,
  });
  const credentials = (user, password) =>
    `locale=en&username=${user}&password=${encodeURIComponent(password)}`;

  assert.equal((await fetch(`${base}/en/`)).status, 200);
  assert.equal((await fetch(`${base}/auth/login`, { redirect: "manual" })).status, 404);
  assert.equal((await post("/auth/login", credentials("viewer", VIEWER_PASSWORD),
    { Origin: "https://evil.test" })).status, 403);
  assert.equal((await post("/auth/login", credentials("viewer", "wrong"))).status, 401);
  assert.equal((await post("/auth/login", `${credentials("admin", ADMIN_PASSWORD)}&extra=1`)).status, 400);

  const viewer = await post("/auth/login", credentials("viewer", VIEWER_PASSWORD));
  assert.equal(viewer.status, 303);
  assert.equal(viewer.headers.get("location"), "/viewer?locale=en");
  const viewerCookie = viewer.headers.get("set-cookie");
  for (const attribute of ["HttpOnly", "Secure", "SameSite=Strict", "Max-Age=3600"])
    assert.ok(viewerCookie.includes(attribute));
  const viewerSession = { Cookie: viewerCookie.split(";")[0] };
  const check = await fetch(`${base}/auth/check`, { headers: viewerSession });
  assert.equal(check.status, 204);
  assert.equal(check.headers.get("x-sifap-role"), "VIEWER");
  assert.equal((await fetch(`${base}/auth/check-admin`, { headers: viewerSession, redirect: "manual" })).status, 403);
  const page = await fetch(`${base}/viewer`, { headers: viewerSession });
  assert.ok((await page.text()).includes('iframe src="/terminal/"'));

  const admin = await post("/auth/login", credentials("admin", ADMIN_PASSWORD));
  const adminSession = { Cookie: admin.headers.get("set-cookie").split(";")[0] };
  const adminCheck = await fetch(`${base}/auth/check-admin`, { headers: adminSession });
  assert.equal(adminCheck.status, 204);
  assert.equal(adminCheck.headers.get("x-sifap-role"), "ADMIN");
  assert.ok((await (await fetch(`${base}/viewer`, { headers: adminSession })).text()).includes('href="/admin/"'));

  const logout = await post("/auth/logout", "locale=en", adminSession);
  assert.equal(logout.status, 303);
  assert.ok(logout.headers.get("set-cookie").includes("Max-Age=0"));
  assert.equal((await fetch(`${base}/auth/check`, { headers: adminSession, redirect: "manual" })).status, 303);

  for (let attempt = 0; attempt < 20; attempt++)
    await post("/auth/login", credentials("viewer", "wrong"));
  assert.equal((await post("/auth/login", credentials("viewer", VIEWER_PASSWORD))).status, 429);
  clock += 300001;
  assert.equal((await post("/auth/login", credentials("viewer", VIEWER_PASSWORD))).status, 303);
});

test("REQ-123: production origins cannot disable TLS or embed credentials", () => {
  assert.throws(() => createViewerServer({ origin: "", accounts }), /SIFAP_ORIGIN is required/);
  assert.throws(() => createViewerServer({ origin: "http://public.test", accounts }));
  assert.throws(() => createViewerServer({ origin: "https://user:secret@public.test", accounts }));
  assert.throws(() => createViewerServer({ origin: "https://public.test", secure: false, accounts }));
});
