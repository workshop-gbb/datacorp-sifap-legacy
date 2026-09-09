# Workshop sign-in accounts

> [!CAUTION]
> **PRIVATE — FACILITATORS ONLY.** This repository operates the live lab. Share
> these accounts only with immersion participants, and only through an approved
> channel. Never paste a password into an issue, pull request, commit message,
> chat transcript, screenshot or application log.

Both SIFAP environments require a **username, a password and an access type**
chosen from a selector on the sign-in screen. Roles are enforced on the server:
the selector cannot grant a permission the account does not hold, and a viewer
credential is rejected when the administrator role is requested.

| Access type | Username | Legacy (Natural / Adabas) | Modern (Java / Next.js) |
|---|---|---|---|
| **Administrator** | `admin` | Operator Natural session and the Adabas console | Reads every screen, report and integration |
| **Viewer** | `viewer` | Pinned `VIEWBENF` query screen only; no console | Reads every screen, report and integration |

> [!IMPORTANT]
> The modern system currently exposes **no write or administrative operation to
> either role**, because the original benefit and document rules remain blocked
> by the open `CLAR` gates. The administrator role is meaningfully different in
> the legacy system today; in the modern system it is a distinct identity with
> the same read-only reach. Do not describe it to participants as production
> administrative access.

## Passwords

Passwords are **not stored in this repository**. Git history is permanent and is
copied to every clone, so a password committed here could not be revoked by
deleting the line. They live in the lab Key Vault and are read by the virtual
machine's managed identity at start-up.

Record the values you distribute in the facilitator's own protected notes, or
fill the table below **only in a local working copy that is never committed**:

| Access type | Username | Password |
|---|---|---|
| Administrator | `admin` | _(fill in locally — do not commit)_ |
| Viewer | `viewer` | _(fill in locally — do not commit)_ |

Read the current legacy passwords from the lab:

```bash
az vm run-command invoke -g sifap-lab-rg-eus2 -n sifap-lab-vm-eus2 \
  --command-id RunShellScript \
  --scripts '/opt/sifap/read-secret.sh demo-basic-auth-password' \
  --query 'value[0].message' -o tsv
```

Replace `demo-basic-auth-password` with `demo-viewer-password` for the other
account. The sign-in gateway derives hashes from those existing Key Vault
secrets during deployment; plaintext is never placed in its environment file.

The modern passwords live in its private Key Vault runtime JSON. The operator
can read only the two account values through a protected Azure Run Command. Do
not print the database password, signing secret or password hashes.

## Rotating a password

1. Choose a new password of at least 12 characters.
2. Derive its hash without putting the password in shell history:

   ```bash
   printf '%s\n' "$NEW_PASSWORD" | node \
     infra/adabas-natural-lab/provisioning/viewer-access/hash-password.mjs
   ```

   The legacy gateway stores an **scrypt** hash; the modern API stores a
   **bcrypt** hash produced by its own image utility. Neither stores plaintext.
3. Store the new password and hash in Key Vault, then restart the sign-in
   gateway and the modern API so they read the new configuration.
4. Update the facilitator's protected notes. Do not commit the new value.

## What the accounts protect

- Sessions expire after one hour and are invalidated by **Sign out**.
- The legacy session cookie is `HttpOnly`, `Secure` and `SameSite=Strict`; the
  browser never receives a password or an account hash.
- Signing in requires a same-origin `POST`. A `GET` never creates a session.
- Repeated failures are rate-limited per source address.
- A forged `X-Sifap-Role` header is stripped before the session is validated, so
  a viewer cannot reach the operator terminal or the Adabas console.
- The modern API issues a signed token carrying only the granted role and still
  denies every business mutation.

## Related documentation

- [Sign-in gateway](../infra/adabas-natural-lab/provisioning/viewer-access/README.md)
- [Modern viewer operations](https://github.com/workshop-gbb/datacorp-sifap-modern/blob/main/docs/operations/viewer.md)
