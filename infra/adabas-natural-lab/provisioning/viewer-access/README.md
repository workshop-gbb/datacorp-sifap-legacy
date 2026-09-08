# Public retro landing and one-click viewer

This opt-in workshop gateway implements REQ-116 through REQ-119 from the modern
repository. Any visitor can intentionally start a **read-only synthetic-data**
session. This is not identity verification and is not suitable for real personal
or production financial data.

The retro landing reuses the existing editorial SIFAP design and licensed local
fonts. The original draft worktree was preserved. English, Spanish and Brazilian
Portuguese render on the server, including with browser JavaScript disabled.

## Authorization boundary

- `POST /auth/viewer` creates a cryptographically random opaque session.
- The browser receives only an HttpOnly, Secure, SameSite=Strict cookie.
- Sessions are stored server-side, expire after one hour and are capacity-limited.
- `GET` never logs a visitor in. Session creation/logout require the exact
  configured Origin and reject role/identity/redirect parameters.
- Caddy forwards guest terminal traffic only to `ttyd-viewer`, already pinned
  to `VIEWBENF;FIN`. The gateway has no Docker socket, database connection or
  operator credentials. WebSocket streams are limited to one hour.
- Adabas administration still requires the operator's Basic Auth credentials.
  Guest and old credential-based viewers are explicitly denied.
- Credential-based operator terminal access is preserved independently.
- Logout invalidates the opaque session and removes the cookie. Navigating away
  from the viewer page closes its terminal iframe.

## Runtime

`compose.viewer.yaml` extends the existing lab Compose definition, without
changing its database or Natural containers. `install.sh` verifies Caddy's config
before enabling it, preserves the previous config for rollback, and recreates
only Caddy plus the new session gateway. Its restart policy survives VM restarts.
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
including the actual Natural viewer terminal. It no longer requires a shared
viewer password to run the ordinary classroom journeys.
