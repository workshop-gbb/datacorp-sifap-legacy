import assert from "node:assert/strict";
const base = process.env.SIFAP_TEST_ORIGIN ?? "http://127.0.0.1:4389";
const admin = process.env.TEST_ADMIN_PASSWORD;
const viewer = process.env.TEST_VIEWER_PASSWORD;
if (!admin || !viewer) throw new Error("Provide TEST_ADMIN_PASSWORD and TEST_VIEWER_PASSWORD.");

const check = (path, init = {}) => fetch(base + path, { redirect: "manual", ...init });
const login = (role, user, password) => check("/auth/login", {
  method: "POST",
  headers: { Origin: base, "Content-Type": "application/x-www-form-urlencoded" },
  body: `locale=en&role=${role}&username=${user}&password=${encodeURIComponent(password)}`,
});

assert.equal((await check("/")).status, 200);
assert.equal((await check("/terminal/")).status, 303, "anonymous terminal must redirect to sign-in");
assert.equal((await check("/terminal")).status, 303, "bare terminal must redirect to sign-in");
assert.equal((await check("/admin/")).status, 303, "anonymous admin must redirect to sign-in");
assert.equal((await login("VIEWER", "viewer", "wrong")).status, 401);

const viewerLogin = await login("VIEWER", "viewer", viewer);
assert.equal(viewerLogin.status, 303);
const viewerCookie = viewerLogin.headers.get("set-cookie").split(";")[0];
const asViewer = { headers: { Cookie: viewerCookie } };
const forged = { headers: { Cookie: viewerCookie, "X-Sifap-Role": "ADMIN" } };
assert.equal(await (await check("/terminal/", asViewer)).text(), "restricted-viewer");
assert.equal(await (await check("/terminal/", forged)).text(), "restricted-viewer", "a forged role header must be stripped");
assert.equal((await check("/admin/", asViewer)).status, 403);
assert.equal((await check("/admin", forged)).status, 403);

const adminLogin = await login("ADMIN", "admin", admin);
const asAdmin = { headers: { Cookie: adminLogin.headers.get("set-cookie").split(";")[0] } };
assert.equal(await (await check("/terminal/", asAdmin)).text(), "operator-terminal");
assert.equal(await (await check("/admin/", asAdmin)).text(), "operator-admin");

const logout = await check("/auth/logout", {
  method: "POST",
  headers: { Origin: base, Cookie: viewerCookie, "Content-Type": "application/x-www-form-urlencoded" },
  body: "locale=en",
});
assert.equal(logout.status, 303);
assert.equal((await check("/terminal/", asViewer)).status, 303);
console.log("Gateway: credential sign-in, role routing, forged-header denial, admin console and logout all passed.");
