#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPECTED_SUBSCRIPTION_ID="${SIFAP_AZURE_SUBSCRIPTION_ID:-${ARM_SUBSCRIPTION_ID:-bf39c110-94c5-4bfa-959d-216b1f971d81}}"
LOCATION="${SIFAP_AZURE_LOCATION:-eastus2}"
ENABLE_DDM_WORKSTATION="${TF_VAR_enable_ddm_workstation:-true}"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

variable_default() {
  local variable_name="$1"
  awk -v variable_name="$variable_name" '
    $0 ~ "^variable \\\"" variable_name "\\\"" { in_block=1 }
    in_block && $1 == "default" {
      gsub(/"/, "", $3)
      print $3
      exit
    }
  ' "$SCRIPT_DIR/variables.tf"
}

check_provider_registrations() {
  local provider registration_state
  local providers=(
    Microsoft.Compute
    Microsoft.Consumption
    Microsoft.DevTestLab
    Microsoft.Insights
    Microsoft.KeyVault
    Microsoft.Network
    Microsoft.OperationalInsights
    Microsoft.Resources
  )
  for provider in "${providers[@]}"; do
    registration_state="$(az provider show --namespace "$provider" --query registrationState -o tsv 2>/dev/null || true)"
    [ "$registration_state" = "Registered" ] || fail "Resource provider ${provider} is ${registration_state:-not registered}."
    printf '%s: %s\n' "$provider" "$registration_state"
  done
}

check_deployer_role() {
  local assignee roles_json
  assignee="${ARM_CLIENT_ID:-$(az account show --query user.name -o tsv)}"
  roles_json="$(az role assignment list \
    --assignee "$assignee" \
    --include-inherited \
    --scope "/subscriptions/${EXPECTED_SUBSCRIPTION_ID}" \
    --query '[].roleDefinitionName' -o json 2>/dev/null || true)"
  [ -n "$roles_json" ] || fail "Could not read role assignments for ${assignee}."
  python3 - "$roles_json" <<'PY' || fail "The deployer needs Owner or Contributor on the target subscription."
import json
import sys

roles = set(json.loads(sys.argv[1] or "[]"))
sys.exit(0 if {"Owner", "Contributor"} & roles else 1)
PY
  printf 'Deployer RBAC: Contributor-or-higher\n'
}

check_vm_capacity() {
  local vm_size workstation_size workstation_image_version size sku_json sku_details usage_json
  local requirements_file
  vm_size="$(variable_default vm_size)"
  [ -n "$vm_size" ] || fail "Could not derive vm_size from variables.tf."
  local vm_sizes=("$vm_size")

  if [ "$ENABLE_DDM_WORKSTATION" = "true" ]; then
    workstation_size="$(variable_default ddm_workstation_size)"
    workstation_image_version="$(variable_default ddm_workstation_image_version)"
    [ -n "$workstation_size" ] || fail "Could not derive ddm_workstation_size from variables.tf."
    [ -n "$workstation_image_version" ] || fail "Could not derive ddm_workstation_image_version from variables.tf."
    vm_sizes+=("$workstation_size")
    az vm image show --location "$LOCATION" \
      --urn "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:${workstation_image_version}" \
      --query urn -o tsv >/dev/null \
      || fail "Pinned Windows image ${workstation_image_version} is unavailable in ${LOCATION}."
    printf 'Windows image: %s\n' "$workstation_image_version"
  fi

  requirements_file="$(mktemp)"
  trap 'rm -f "${requirements_file:-}"; trap - RETURN' RETURN
  for size in "${vm_sizes[@]}"; do
    sku_json="$(az vm list-skus --location "$LOCATION" --resource-type virtualMachines \
      --size "$size" --all \
      --query "[?name=='${size}'].{name:name,family:family,capabilities:capabilities,restrictions:restrictions}" \
      -o json)" || fail "Failed while reading SKU restrictions for ${size} in ${LOCATION}."
    sku_details="$(python3 - "$size" "$sku_json" <<'PY'
import json
import sys

vm_size = sys.argv[1]
skus = json.loads(sys.argv[2] or "[]")
if not skus:
    print(f"VM SKU {vm_size} is not offered in the target region.", file=sys.stderr)
    sys.exit(1)
sku = skus[0]
restrictions = sku.get("restrictions") or []
if restrictions:
    print(f"VM SKU {vm_size} is restricted: {json.dumps(restrictions)}", file=sys.stderr)
    sys.exit(1)
vcpus = next(c.get("value") for c in sku.get("capabilities", []) if c.get("name") == "vCPUs")
print(sku["family"], vcpus)
PY
    )" || fail "VM SKU ${size} is not usable in ${LOCATION}."
    printf '%s\n' "$sku_details" >> "$requirements_file"
    printf 'VM size %s: %s vCPU(s), quota family %s\n' "$size" "${sku_details##* }" "${sku_details% *}"
  done

  usage_json="$(az vm list-usage --location "$LOCATION" -o json)"
  python3 - "$requirements_file" "$usage_json" "$LOCATION" <<'PY' || fail "Insufficient VM quota."
import collections
import json
import pathlib
import sys

requirements = collections.Counter()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    family, vcpus = line.split()
    requirements[family.casefold()] += int(vcpus)

usage = {item["name"]["value"].casefold(): item for item in json.loads(sys.argv[2])}
location = sys.argv[3]
for family, required in sorted(requirements.items()):
    row = usage.get(family)
    if row is None:
        print(f"Quota family {family} was not returned for {location}.", file=sys.stderr)
        sys.exit(1)
    available = int(row["limit"]) - int(row["currentValue"])
    print(f"{row['name']['value']} quota: used={row['currentValue']}, limit={row['limit']}, available={available}, required={required}")
    if available < required:
        sys.exit(1)
PY
}

main() {
  require_command az
  require_command python3
  require_command terraform

  local actual_subscription state
  actual_subscription="$(az account show --query id -o tsv 2>/dev/null || true)"
  state="$(az account show --query state -o tsv 2>/dev/null || true)"
  [ "$actual_subscription" = "$EXPECTED_SUBSCRIPTION_ID" ] \
    || fail "Azure CLI targets ${actual_subscription:-nothing}; expected ${EXPECTED_SUBSCRIPTION_ID}."
  [ "$state" = "Enabled" ] || fail "Target subscription state is ${state:-unknown}."
  printf 'Subscription: %s (%s)\n' "$actual_subscription" "$state"

  check_provider_registrations
  check_deployer_role
  check_vm_capacity

  terraform -chdir="$SCRIPT_DIR" fmt -check
  terraform -chdir="$SCRIPT_DIR" init -lockfile=readonly -input=false >/dev/null
  terraform -chdir="$SCRIPT_DIR" validate >/dev/null
  printf 'Terraform: fmt and validate passed\n'
  printf 'PREFLIGHT RESULT: PASS\n'
}

main "$@"