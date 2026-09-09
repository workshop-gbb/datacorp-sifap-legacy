# Public retro landing and role-based sign-in

This workshop gateway implements REQ-116 and REQ-121 through REQ-124 from the
modern repository. The landing is public, but both terminal roles require a
username and password. The server derives the role from the account.

The retro landing reuses the existing editorial SIFAP design and licensed local
fonts. The original draft worktree was preserved. English, Spanish and Brazilian
Portuguese render on the server, including with browser JavaScript disabled.

## Authorization boundary

- `POST /auth/login` verifies a scrypt hash and creates a random opaque session.
- The browser receives only an HttpOnly, Secure, SameSite=Strict cookie.
- Sessions are stored server-side, expire after one hour and are capacity-limited.
- `GET` never logs a visitor in. Login/logout require the configured Origin.
- The account determines the role. Client-supplied role headers are stripped by
  Caddy, so a VIEWER credential cannot reach administrator resources.
- Caddy sends VIEWER only to `ttyd-viewer`, pinned to `VIEWBENF;FIN`, and sends
  ADMIN to the operator Natural terminal. Only ADMIN reaches `/admin/`.
- The gateway has no Docker socket, database connection or plaintext passwords.
- WebSocket streams and application sessions are limited to one hour.
- Logout invalidates the opaque session and removes the cookie. Navigating away
  from the viewer page closes its terminal iframe.
- The viewer session driver reaps its Natural process when the browser
  disconnects, avoiding buffer-pool exhaustion from orphan sessions.

## Runtime

`compose.viewer.yaml` extends the existing lab Compose definition, without
changing its database or Natural containers. `install.sh` verifies Caddy's config
before enabling it, requires a root-owned mode-600 account file, preserves the
previous config for rollback, and recreates only Caddy, the sign-in gateway and
the restricted ttyd process. Its restart policy survives VM restarts.
The daily startup validator checks the extra gateway when the opt-in marker is
present. Do not run Terraform to replace the VM for this UI change.

## Tests

```bash
npm run build
npm test
node build-landing.mjs
```

No npm packages are needed. The pinned Node 24 runtime is shared with the modern
frontend. `test/compose.yaml` runs the actual Caddy config with distinct fake
viewer/operator upstreams; `test/gateway-check.mjs` verifies routing, denied admin
access, forged role headers, logout and compatibility.

The modern repository's Playwright suite also exercises this deployed origin,
including both roles and the actual Natural viewer terminal.
