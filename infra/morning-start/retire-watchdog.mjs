import { spawnSync } from "node:child_process";
const subscription = process.env.AZURE_SUBSCRIPTION_ID;
if (!subscription || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(subscription)) {
  throw new Error("Set AZURE_SUBSCRIPTION_ID explicitly before changing schedules.");
}
const base = `https://management.azure.com/subscriptions/${subscription}/resourceGroups/sifap-lab-rg-eus2/providers/Microsoft.Automation/automationAccounts/sifap-lab-aa-watchdog-eus2`;
function az(args) {
  const result = spawnSync("az", args, { encoding: "utf8", maxBuffer: 1024 * 1024 });
  if (result.status !== 0) throw new Error(`Azure operation failed: ${result.stderr}`);
  return result.stdout.trim();
}
const schedules = JSON.parse(az(["rest", "--method", "get", "--url", `${base}/schedules?api-version=2023-11-01`])).value;
const morning = schedules.find(schedule => schedule.name === "sifap-morning-0700");
if (!morning?.properties.isEnabled || morning.properties.frequency !== "Day" ||
    morning.properties.timeZone !== "America/Sao_Paulo") {
  throw new Error("The replacement daily schedule is not enabled and verified.");
}
for (const schedule of schedules) {
  if (!/^(vm-watchdog-(poll-\d{2}|leg-\d)|vm-daily-start-0700-brt)$/.test(schedule.name)) continue;
  if (!schedule.properties.isEnabled) continue;
  az(["rest", "--method", "patch", "--url", `${base}/schedules/${schedule.name}?api-version=2023-11-01`,
    "--body", JSON.stringify({ properties: { isEnabled: false } }), "--output", "none"]);
  console.log(`Disabled obsolete watchdog schedule: ${schedule.name}`);
}
console.log("Only the replacement morning schedule is retained for SIFAP startup. MCAPS resources were not changed.");
