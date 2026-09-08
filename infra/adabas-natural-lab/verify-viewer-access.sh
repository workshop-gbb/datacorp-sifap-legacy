#!/usr/bin/env bash
set -euo pipefail

# A credencial fica na entrada padrao do curl, nunca em seus argumentos ou logs.
base_url="${SIFAP_LAB_URL:-https://sifap-lab-438k30.eastus2.cloudapp.azure.com}"
viewer_user="${SIFAP_VIEWER_USERNAME:-viewer}"

if [[ ! "$base_url" =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?$ ]]; then
  printf 'ERROR: SIFAP_LAB_URL must be an HTTPS origin without credentials or a path.\n' >&2
  exit 2
fi
if [[ ! "$viewer_user" =~ ^[a-zA-Z0-9._-]{2,32}$ ]]; then
  printf 'ERROR: SIFAP_VIEWER_USERNAME has an invalid format.\n' >&2
  exit 2
fi
if [[ -z "${SIFAP_VIEWER_PASSWORD:-}" ]]; then
  printf 'ERROR: set SIFAP_VIEWER_PASSWORD using the protected viewer credential.\n' >&2
  exit 2
fi

command -v curl >/dev/null || { printf 'ERROR: curl is required.\n' >&2; exit 2; }
command -v base64 >/dev/null || { printf 'ERROR: base64 is required.\n' >&2; exit 2; }

authorization="$(printf '%s:%s' "$viewer_user" "$SIFAP_VIEWER_PASSWORD" | base64 | tr -d '\r\n')"
unset SIFAP_VIEWER_PASSWORD
trap 'unset authorization' EXIT
failures=0

check_status() {
  local audience="$1" route="$2" expected="$3" actual
  if [[ "$audience" == viewer ]]; then
    actual="$(printf 'header = "Authorization: Basic %s"\n' "$authorization" |
      curl -q --config - --proto '=https' --silent --show-error \
        --connect-timeout 5 --max-time 15 --output /dev/null \
        --write-out '%{http_code}' "$base_url$route")"
  else
    actual="$(curl -q --proto '=https' --silent --show-error \
      --connect-timeout 5 --max-time 15 --output /dev/null \
      --write-out '%{http_code}' "$base_url$route")"
  fi
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
check_status anonymous /admin/ 401
check_status viewer / 200
check_status viewer /terminal/ 200
check_status viewer /admin 403
check_status viewer /admin/ 403

if ((failures > 0)); then
  printf 'ERROR: %s viewer access check(s) failed.\n' "$failures" >&2
  exit 1
fi
printf 'Viewer HTTP boundaries passed. This does not certify every Natural business workflow.\n'
