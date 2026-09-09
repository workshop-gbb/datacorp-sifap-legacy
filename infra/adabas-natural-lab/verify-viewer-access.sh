#!/usr/bin/env bash
set -euo pipefail

# Sonda somente rotas anônimas. Perfis autenticados são cobertos no browser E2E.
base_url="${SIFAP_LAB_URL:-https://sifap-lab-438k30.eastus2.cloudapp.azure.com}"
if [[ ! "$base_url" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
  printf 'ERROR: SIFAP_LAB_URL must be an HTTPS origin without credentials or a path.\n' >&2
  exit 2
fi
command -v curl >/dev/null || { printf 'ERROR: curl is required.\n' >&2; exit 2; }

failures=0

check_status() {
  local audience="$1" route="$2" expected="$3" actual
  actual="$(curl -q --proto '=https' --silent --show-error \
    --connect-timeout 5 --max-time 15 --output /dev/null \
    --write-out '%{http_code}' "$base_url$route")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL %s %s: expected HTTP %s, received %s\n' "$audience" "$route" "$expected" "$actual" >&2
    failures=$((failures + 1))
  else
    printf 'PASS %s %s: HTTP %s\n' "$audience" "$route" "$actual"
  fi
}

# REQ-112 (SIFAP Modern): verificar os dois ambientes publicados sem alterar dados.
check_status anonymous /healthz 200
check_status anonymous / 200
check_status anonymous /terminal/ 303
check_status anonymous /admin/ 303
check_status anonymous /auth/check 303

if ((failures > 0)); then
  printf 'ERROR: %s viewer access check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf 'Anonymous HTTP boundaries passed. Authenticated roles are covered by the browser suite.\n'
