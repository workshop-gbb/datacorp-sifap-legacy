#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TFVARS="$SCRIPT_DIR/terraform.tfvars"
PLAN_FILE="$SCRIPT_DIR/lab.tfplan"
STATE_FILE="$SCRIPT_DIR/terraform.tfstate"
BACKUP_DIR="${SIFAP_STATE_BACKUP_DIR:-$REPO_ROOT/.local-state-backups/adabas-natural-lab}"
ENABLE_DDM_WORKSTATION="${SIFAP_ENABLE_DDM_WORKSTATION:-true}"
SSH_OPTIONS=(-o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o StrictHostKeyChecking=accept-new)

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

usage() {
  cat <<'USAGE'
Usage: ./deploy-local.sh <package|plan|apply|upload|status|destroy>

Environment:
  SIFAP_ENABLE_DDM_WORKSTATION=true|false  Include the temporary NaturalONE VM (default: true)
  SIFAP_TERRAFORM_EXTRA_ARGS="-replace=..." Non-secret Terraform plan flags
  SIFAP_CONFIRM_DESTROY=DESTROY            Required for destroy
  SIFAP_STATE_BACKUP_DIR=<path>            Encrypted/private state backup location
  SIFAP_PAYLOAD_ARCHIVE=<path>             Destination used by package
USAGE
}

backup_state() {
  [ -f "$STATE_FILE" ] || return 0
  mkdir -p "$BACKUP_DIR"
  chmod 0700 "$BACKUP_DIR"
  local destination
  destination="$BACKUP_DIR/terraform.tfstate.$(date -u +%Y%m%dT%H%M%SZ)"
  (umask 077; cp "$STATE_FILE" "$destination")
  printf 'State backup: %s\n' "$destination"
}

run_preflight() {
  [ -f "$TFVARS" ] || fail "Missing $TFVARS. Copy terraform.tfvars.example and set owner and allowed_source_cidrs."
  require_command curl
  local current_ip
  current_ip="$(curl -fsS --max-time 15 https://api.ipify.org)" \
    || fail "Could not determine the facilitator public IP."
  python3 - "$TFVARS" "$current_ip" <<'PY' \
    || fail "The current public IP is not covered by allowed_source_cidrs in terraform.tfvars."
import ipaddress
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"allowed_source_cidrs\s*=\s*\[(.*?)\]", text, re.DOTALL)
if not match:
    raise SystemExit(1)
networks = [
    ipaddress.ip_network(value, strict=False)
    for value in re.findall(r'["\']([^"\']+)["\']', match.group(1))
]
address = ipaddress.ip_address(sys.argv[2])
raise SystemExit(0 if any(address in network for network in networks) else 1)
PY
  printf 'Facilitator CIDR: current public IP is allowed\n'
  TF_VAR_enable_ddm_workstation="$ENABLE_DDM_WORKSTATION" "$SCRIPT_DIR/preflight-local.sh"
}

audit_plan() {
  terraform -chdir="$SCRIPT_DIR" show -json "$PLAN_FILE" | python3 "$SCRIPT_DIR/audit-plan.py"
}

build_payload() {
  local work_dir="$1"
  local stage="$work_dir/stage"
  local corpus_root="$REPO_ROOT/01-archaeology/legacy-sifap"
  mkdir -p "$stage/corpus" "$stage/provisioning" "$stage/www"
  [ -d "$corpus_root/natural-programs" ] || fail "Missing legacy Natural corpus: $corpus_root/natural-programs"
  [ -d "$corpus_root/adabas-ddms" ] || fail "Missing DDM corpus: $corpus_root/adabas-ddms"

  cp -a "$corpus_root/natural-programs" "$stage/corpus/"
  cp -a "$corpus_root/adabas-ddms" "$stage/corpus/"
  cp -a "$SCRIPT_DIR/payload-static/." "$stage/"
  tar -C "$SCRIPT_DIR/provisioning" \
    --exclude='./work' --exclude='./ngd-work' --exclude='./ddm-work' --exclude='./__pycache__' \
    -cf - . | tar -C "$stage/provisioning" -xf -

  python3 - "$stage" <<'PY'
import hashlib
import pathlib
import sys

stage = pathlib.Path(sys.argv[1])
entries = []
for path in sorted(stage.rglob("*")):
    if not path.is_file() or path.name == "manifest.sha256":
        continue
    relative = path.relative_to(stage).as_posix()
    if not relative.startswith(("corpus/", "provisioning/", "www/")):
        raise SystemExit(f"unexpected payload path: {relative}")
    entries.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {relative}\n")
(stage / "manifest.sha256").write_text("".join(entries), encoding="utf-8")
print(f"Payload manifest: {len(entries)} files")
PY
  tar -C "$stage" -czf "$work_dir/sifap-payload.tar.gz" .
}

wait_for_ssh() {
  local target="$1" attempt
  for attempt in $(seq 1 60); do
    if ssh "${SSH_OPTIONS[@]}" "$target" true 2>/dev/null; then
      printf 'SSH ready after %s attempt(s)\n' "$attempt"
      return 0
    fi
    sleep 10
  done
  fail "SSH did not become ready within 10 minutes: $target"
}

upload_payload() {
  [ -f "$STATE_FILE" ] || fail "Terraform state is missing; run apply first."
  local work_dir target archive
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir:-}"' EXIT
  build_payload "$work_dir"
  archive="$work_dir/sifap-payload.tar.gz"
  target="$(terraform -chdir="$SCRIPT_DIR" output -raw admin_username)@$(terraform -chdir="$SCRIPT_DIR" output -raw demo_fqdn)"

  wait_for_ssh "$target"
  ssh "${SSH_OPTIONS[@]}" "$target" 'sudo cloud-init status --wait >/dev/null'
  scp "${SSH_OPTIONS[@]}" "$archive" "$target:/tmp/sifap-payload.tar.gz"
  ssh "${SSH_OPTIONS[@]}" "$target" '
    set -eu
    sudo rm -rf /opt/sifap/payload
    sudo mkdir -p /opt/sifap/payload
    sudo tar -xzf /tmp/sifap-payload.tar.gz -C /opt/sifap/payload
    sudo rm -f /tmp/sifap-payload.tar.gz
    sudo /opt/sifap/fetch-payload.sh
    sudo systemctl restart sifap-provisioning
  '
  rm -rf "$work_dir"
  trap - EXIT
  printf 'Payload installed and provisioning restarted on %s\n' "$target"
}

package_payload() {
  local work_dir destination
  work_dir="$(mktemp -d)"
  trap 'rm -rf "${work_dir:-}"' EXIT
  destination="${SIFAP_PAYLOAD_ARCHIVE:-$SCRIPT_DIR/sifap-payload.tar.gz}"
  build_payload "$work_dir"
  mkdir -p "$(dirname "$destination")"
  mv "$work_dir/sifap-payload.tar.gz" "$destination"
  rm -rf "$work_dir"
  trap - EXIT
  printf 'Payload archive: %s\n' "$destination"
}

plan() {
  run_preflight
  local args=("-var=enable_ddm_workstation=${ENABLE_DDM_WORKSTATION}")
  local extra_args=()
  if [ -n "${SIFAP_TERRAFORM_EXTRA_ARGS:-}" ]; then
    read -r -a extra_args <<< "$SIFAP_TERRAFORM_EXTRA_ARGS"
    args+=("${extra_args[@]}")
  fi
  terraform -chdir="$SCRIPT_DIR" plan "${args[@]}" -out="$PLAN_FILE"
  audit_plan
  printf 'Saved plan: %s\n' "$PLAN_FILE"
}

apply() {
  plan
  terraform -chdir="$SCRIPT_DIR" apply -auto-approve "$PLAN_FILE"
  rm -f "$PLAN_FILE"
  backup_state
  upload_payload
  terraform -chdir="$SCRIPT_DIR" output
}

status() {
  [ -f "$STATE_FILE" ] || fail "Terraform state is missing."
  local target
  target="$(terraform -chdir="$SCRIPT_DIR" output -raw admin_username)@$(terraform -chdir="$SCRIPT_DIR" output -raw demo_fqdn)"
  ssh "${SSH_OPTIONS[@]}" "$target" '
    printf "%s\n" "=== cloud-init ==="
    sudo cloud-init status
    printf "%s\n" "=== provisioning ==="
    sudo systemctl status sifap-provisioning --no-pager || true
    printf "%s\n" "=== markers ==="
    sudo ls -l /opt/sifap/READY /opt/sifap/PAYLOAD-OK /opt/sifap/state/DDMS-READY /opt/sifap/PROVISIONED 2>/dev/null || true
  '
}

destroy() {
  [ "${SIFAP_CONFIRM_DESTROY:-}" = "DESTROY" ] || fail "Set SIFAP_CONFIRM_DESTROY=DESTROY to confirm teardown."
  [ -f "$STATE_FILE" ] || fail "Terraform state is missing; refusing a blind destroy."
  backup_state
  cp "$SCRIPT_DIR/teardown.tf.disabled" "$SCRIPT_DIR/override.tf"
  trap 'rm -f "$SCRIPT_DIR/override.tf"' EXIT
  local args=("-var=enable_ddm_workstation=${ENABLE_DDM_WORKSTATION}")
  terraform -chdir="$SCRIPT_DIR" destroy -auto-approve "${args[@]}"
  rm -f "$SCRIPT_DIR/override.tf"
  az keyvault list-deleted --query "[?starts_with(name, 'sifaplab')].{name:name,location:properties.location}" -o tsv \
    | while read -r vault location; do
        [ -n "$vault" ] || continue
        az keyvault purge --name "$vault" --location "$location" || true
      done
  backup_state
}

main() {
  case "${1:-}" in
    package)
      require_command python3
      require_command tar
      package_payload
      ;;
    plan)
      require_command az
      require_command python3
      require_command terraform
      plan
      ;;
    apply)
      require_command az
      require_command python3
      require_command scp
      require_command ssh
      require_command tar
      require_command terraform
      apply
      ;;
    upload)
      require_command python3
      require_command scp
      require_command ssh
      require_command tar
      require_command terraform
      upload_payload
      ;;
    status)
      require_command ssh
      require_command terraform
      status
      ;;
    destroy)
      require_command az
      require_command terraform
      destroy
      ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"