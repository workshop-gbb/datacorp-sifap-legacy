# SIFAP legacy-to-modern demonstration

> [!CAUTION]
> **PRIVATE FACILITATOR RUNBOOK.** Do not copy credentials, operator screens or
> participant data into public material. Both environments use synthetic data.

This demonstration begins with the original Natural/Adabas system and then
repeats the same concepts in the modern Java/Next.js platform. It is designed to
show continuity of intent without claiming that the open financial clarification
gates have been resolved.

## Before the audience arrives

1. Confirm the daily 07:00 America/Sao_Paulo Automation job completed.
2. Open both health endpoints:
   - Legacy: <https://sifap-lab-438k30.eastus2.cloudapp.azure.com/healthz>
   - Modern: <https://sifap-modern-fiepi9.eastus2.cloudapp.azure.com/actuator/health>
3. Use the credentials documented in
   [WORKSHOP-ACCOUNTS.md](WORKSHOP-ACCOUNTS.md). The `admin` password is for the
   facilitator only. Participants receive only `viewer`.
4. Sign out of previous sessions. Do not leave an administrator session open in
   a shared browser.

## Part 1 — original SIFAP

Open <https://sifap-lab-438k30.eastus2.cloudapp.azure.com/pt-BR/>.

### Story

- Point out the shared design language: large editorial type, thin rules,
  restrained accent colors and the four-part SIFAP mark.
- Explain the retro treatment: black screen, green phosphor, monospaced type and
  a terminal illustration. The illustration is labelled non-interactive.
- Introduce the 29-year history, 24 Natural members and four Adabas DDMs.
- Emphasize that the landing is public, but the systems are not.

### Legacy viewer demonstration

1. Scroll to **Pronto para voltar à origem?**
2. Enter the `viewer` username and viewer password. There is no role dropdown;
   the account determines the permission.
3. Confirm the header displays `VIEWER · SOMENTE LEITURA`.
4. Wait for the real Natural screen:

   ```text
   SIFAP - BENEFICIARY QUERY
   SEARCH TYPE (C=CPF / N=NIS)
   ```

5. Explain that this session is pinned to `VIEWBENF;FIN`; it cannot reach the
   Natural command line, registration/batch programs or Adabas administration.
6. Click **Sair**. The server invalidates the session and closes the terminal.

Do not enter or narrate a real personal identifier. The workshop corpus is
synthetic, but screenshots should still avoid record-level values.

### Legacy administrator demonstration

Use this only when operator access is relevant:

1. Sign in using the private `admin` account.
2. Confirm the header displays `ADMINISTRADOR`.
3. Show that the operator Natural terminal is available.
4. Open **Console Adabas** only long enough to demonstrate the separate
   administrative boundary.
5. Do not create, update, delete, load or execute a payment batch.
6. Sign out immediately.

The server derives the role from the credentials. Supplying a forged role header
or using the viewer account can never reach the administrator routes.

## Part 2 — modern SIFAP

Open <https://sifap-modern-fiepi9.eastus2.cloudapp.azure.com/pt-BR>.

### Modern viewer demonstration

1. Select **Explorar a plataforma**.
2. Enter the `viewer` account. The form contains only username and password.
3. Show the read-only dashboard, payment trend, program distribution and
   geographic coverage.
4. Search for a synthetic participant, open program/payment details and return.
5. Open **Relatórios**, apply a filter and download CSV.
6. Open **Integrações** and explain:
   - Legacy is a real HTTPS liveness check, not full behavioral equivalence.
   - IBGE is real public geographic reference data.
7. Show EN, ES and PT-BR while preserving the current route.
8. Sign out and confirm protected routes return to login.

### Modern administrator demonstration

The private `admin` account is reserved for the facilitator. Sign in with that
username/password and point out the **Administrator** identity in the header.

The current modern increment intentionally exposes the same consultation
screens to ADMIN and VIEWER. It does **not** create an edit/payment capability:
those operations depend on open legacy clarification gates. The distinction is a
real authenticated role ready for future authorized administrative functions,
not a fake hidden button.

## Messages to reinforce

- Modernization starts by understanding the running original system.
- The interface changes; traceable business evidence remains.
- Authentication and authorization are enforced by the servers, not by labels.
- Viewer means consultation only.
- The admin credential is facilitator-only.
- Synthetic workshop data is not production benefit data.
- The daily 07:00 start validates both applications and databases while the
  MCAPS shutdown policy continues to turn machines off at night.

## If something fails

- A public landing problem: check Caddy and the sign-in gateway.
- A legacy terminal that shows **Press Enter to Reconnect**: run the versioned
  startup validator and inspect Natural buffer-pool users. The current
  restricted-session driver reaps the associated Natural process on disconnect.
- A modern login failure: verify both account hashes exist in the private
  `workshop-runtime` Key Vault secret and restart only the API/frontend service.
- Never fix a demo by publishing a password, disabling authorization, widening
  administration access or reloading the databases.
