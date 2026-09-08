import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const [kind, modernRepository] = process.argv.slice(2);
const subscription = process.env.AZURE_SUBSCRIPTION_ID;
if (!subscription || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subscription)) {
  throw new Error("Set AZURE_SUBSCRIPTION_ID explicitly before installing validators.");
}
if (!["legacy", "modern"].includes(kind) || (kind === "modern" && !modernRepository)) {
  throw new Error("Usage: node install-validator.mjs legacy|modern [modern-repository-path]");
}
const target = kind === "legacy"
  ? {
      group: "sifap-lab-rg-eus2", vm: "sifap-lab-vm-eus2",
      source: fileURLToPath(new URL("../adabas-natural-lab/provisioning/verify-startup.sh", import.meta.url)),
      destination: "/opt/sifap/provisioning/verify-startup.sh",
    }
  : {
      group: "sifap-modern-rg-eus2", vm: "sifap-modern-vm",
      source: resolve(modernRepository, "infra/runtime/verify-startup.sh"),
      destination: "/opt/sifap-modern/infra/runtime/verify-startup.sh",
    };
const content = readFileSync(target.source);
const hash = createHash("sha256").update(content).digest("hex");
const script = [
  "set -eu",
  `printf '%s' '${content.toString("base64")}' | base64 -d > '${target.destination}'`,
  `chmod 0755 '${target.destination}'`,
  `printf '%s\\n' '${hash}  ${target.destination}' | sha256sum -c -`,
  `timeout 600 bash '${target.destination}' --check-only`,
].join("\n");
const result = spawnSync("az", [
  "vm", "run-command", "invoke", "--subscription", subscription,
  "--resource-group", target.group, "--name", target.vm, "--command-id", "RunShellScript",
  "--scripts", script, "--query", "value[].message", "--output", "json",
], { encoding: "utf8", maxBuffer: 1024 * 1024, timeout: 720000 });
if (result.status !== 0) throw new Error(`Validator installation failed for ${kind}: ${result.stderr}`);
const messages = JSON.parse(result.stdout).join("\n");
if (!messages.includes("SIFAP_STARTUP_VALIDATION=OK")) {
  throw new Error(`Readiness did not pass for ${kind}: ${messages}`);
}
console.log(`${kind}: validator installed, checksum verified, application and database ready.`);
