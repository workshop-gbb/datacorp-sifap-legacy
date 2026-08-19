#!/usr/bin/env python3
"""Reject plan shapes that conflict with the corporate tenant's private-network policy."""

from __future__ import annotations

import json
import sys
from collections.abc import Iterator
from typing import Any


def resources(module: dict[str, Any]) -> Iterator[dict[str, Any]]:
    yield from module.get("resources", [])
    for child in module.get("child_modules", []):
        yield from resources(child)


def main() -> int:
    plan = json.load(sys.stdin)
    planned = list(
        resources(plan.get("planned_values", {}).get("root_module", {})))
    forbidden = [
        resource["address"]
        for resource in planned
        if resource["type"].startswith("azurerm_storage_")
        or resource["type"] in {"azurerm_role_assignment", "azurerm_key_vault_secret"}
    ]
    if forbidden:
        print(
            "Plan contains resources incompatible with the tenant's private-network policy:\n"
            + "\n".join(f"- {address}" for address in forbidden),
            file=sys.stderr,
        )
        return 1

    by_address = {resource["address"]: resource for resource in planned}
    vault = by_address.get("azurerm_key_vault.lab")
    if not vault or vault.get("values", {}).get("public_network_access_enabled") is not False:
        print("Plan does not prove that Key Vault public network access is disabled.", file=sys.stderr)
        return 1
    if "azurerm_private_endpoint.key_vault" not in by_address:
        print("Plan does not contain the Key Vault private endpoint.", file=sys.stderr)
        return 1

    print("Plan policy audit: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
