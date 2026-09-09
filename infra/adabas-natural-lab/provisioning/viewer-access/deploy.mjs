import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync, rmSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, isAbsolute } from "node:path";

const [tag, directory] = process.argv.slice(2);
const subscription = process.env.AZURE_SUBSCRIPTION_ID;
if (!tag || !directory || !isAbsolute(directory) ||
    !/^[a-f0-9-]{36}$/i.test(subscription ?? ""))
  throw new Error("Provide the release tag, absolute private artifact directory and AZURE_SUBSCRIPTION_ID.");
const repository = "workshop-gbb/datacorp-sifap-legacy";
function command(program, args) {
  const result = spawnSync(program, args, { encoding:"utf8", maxBuffer:1024*1024 });
  if (result.status !== 0) throw new Error(`${program} failed; no protected output printed.`);
  return result.stdout.trim();
}
const token = command("gh", ["auth","token","--hostname","github.com"]);
const headers = new Headers({ Accept:"application/vnd.github+json" });
headers.set("Authorization", ["Bearer", token].join(" "));
const response = await fetch(`https://api.github.com/repos/${repository}/releases/tags/${encodeURIComponent(tag)}`,
  { headers, redirect:"error", signal:AbortSignal.timeout(20000) });
if (!response.ok) throw new Error(`Release lookup failed (${response.status}).`);
const release = await response.json();
async function asset(name) {
  const entry = release.assets.find(item => item.name === name);
  if (!entry) throw new Error("Release artifact missing.");
  const requestHeaders = new Headers(headers);
  requestHeaders.set("Accept", "application/octet-stream");
  const result = await fetch(`https://api.github.com/repos/${repository}/releases/assets/${entry.id}`,
    { headers:requestHeaders, redirect:"manual", signal:AbortSignal.timeout(20000) });
  const value = result.headers.get("Location");
  if (result.status !== 302 || !value) throw new Error("Scoped download URL missing.");
  const url = new URL(value);
  if (url.protocol !== "https:" || url.hostname !== "release-assets.githubusercontent.com")
    throw new Error("Artifact download origin is not trusted.");
  const local = readFileSync(resolve(directory,name));
  if (local.length !== entry.size) throw new Error("Artifact size mismatch.");
  return { url:value, hash:createHash("sha256").update(local).digest("hex") };
}
const runtime = await asset("runtime-final.tar.gz");
const body = {
  location:"eastus2",
  properties:{
    source:{ script:readFileSync(new URL("./deploy-release.sh", import.meta.url),"utf8") },
    timeoutInSeconds:900, asyncExecution:false,
    parameters:[
      { name:"SIFAP_RUNTIME_SHA", value:runtime.hash },
    ],
    protectedParameters:[
      { name:"SIFAP_RUNTIME_URL", value:runtime.url },
    ],
  },
};
const path = resolve(directory,"protected-legacy-release.json");
writeFileSync(path,JSON.stringify(body),{mode:0o600,flag:"wx"});
try {
  command("az", ["rest","--method","put","--url",
    `https://management.azure.com/subscriptions/${subscription}/resourceGroups/sifap-lab-rg-eus2/providers/Microsoft.Compute/virtualMachines/sifap-lab-vm-eus2/runCommands/deploy-direct-viewer?api-version=2024-07-01`,
    "--body",`@${path}`,"--output","none"]);
  console.log("Legacy viewer release submitted. Verify instanceView exitCode and runtime probes.");
} finally { rmSync(path); }
