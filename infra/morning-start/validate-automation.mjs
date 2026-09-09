import { spawnSync } from "node:child_process";
import { randomUUID } from "node:crypto";

const subscription = process.env.AZURE_SUBSCRIPTION_ID;
if (!subscription || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subscription)) {
  throw new Error("Set AZURE_SUBSCRIPTION_ID explicitly before validating the environment.");
}
const base = `https://management.azure.com/subscriptions/${subscription}/resourceGroups/sifap-lab-rg-eus2/providers/Microsoft.Automation/automationAccounts/sifap-lab-aa-watchdog-eus2`;
function az(args) {
  const result = spawnSync("az", args, { encoding: "utf8", maxBuffer: 1024 * 1024 });
  if (result.status !== 0) throw new Error(`Azure operation failed: ${result.stderr}`);
  return result.stdout.trim();
}
const targets = [
  { name: "sifap-lab-vm-eus2", resourceGroup: "sifap-lab-rg-eus2", kind: "legacy", origin: "https://sifap-lab-438k30.eastus2.cloudapp.azure.com" },
  { name: "sifap-modern-vm", resourceGroup: "sifap-modern-rg-eus2", kind: "modern", origin: "https://sifap-modern-fiepi9.eastus2.cloudapp.azure.com" },
];
const job = randomUUID();
az(["rest", "--method", "put", "--url", `${base}/jobs/${job}?api-version=2023-11-01`,
  "--body", JSON.stringify({ properties: {
    runbook: { name: "Start-SifapWorkshopMorning" },
    parameters: { SubscriptionId: subscription, TargetsBase64: Buffer.from(JSON.stringify(targets)).toString("base64"), Mode: "ValidateOnly" },
  } }), "--output", "none"]);
console.log(`Validation job: ${job}`);
const deadline = Date.now() + 30 * 60 * 1000;
while (Date.now() < deadline) {
  await new Promise(resolve => setTimeout(resolve, 15000));
  const status = az(["rest", "--method", "get", "--url", `${base}/jobs/${job}?api-version=2023-11-01`,
    "--query", "properties.status", "--output", "tsv"]);
  console.log(`Job status: ${status}`);
  if (status === "Completed") {
    const output = az(["rest", "--method", "get", "--url", `${base}/jobs/${job}/output?api-version=2023-11-01`, "--output", "json"]);
    if (!output.includes("SIFAP_MORNING_VALIDATION=OK")) throw new Error("Job completed without the readiness success marker.");
    console.log("Both application/database validators and public HTTPS probes passed.");
    process.exit(0);
  }
  if (["Failed", "Stopped", "Suspended", "Blocked"].includes(status)) {
    throw new Error(`Morning validation failed; inspect Azure job ${job}.`);
  }
}
throw new Error("Morning validation did not finish within its deadline.");
