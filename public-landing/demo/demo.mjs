import { locale, t } from "../site.mjs";
import { DemoModel } from "./model.mjs";
import { composeScreen, promptLabel, pfKeys, screenTitle, COLUMNS, ROWS } from "./terminal.mjs";

const screen = document.getElementById("screen");
const prompt = document.getElementById("prompt-label");
const commandInput = document.getElementById("command");
const keysBar = document.getElementById("pf-keys");
const announcer = document.getElementById("screen-announcer");
const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");
let model;
let historyIndex = 0;
let loadFailed = false;
let booting = false;

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

// A grade de 80x24 precisa preencher o tubo: medimos a largura real do caractere
// na fonte carregada e derivamos o corpo do texto do espaço disponível.
const viewport = document.querySelector(".crt-viewport");
let cellRatio = 0.6;
let lineRatio = 1.44;

function measureCell() {
  const probe = document.createElement("span");
  probe.setAttribute("aria-hidden", "true");
  probe.style.cssText = "position:absolute;visibility:hidden;white-space:pre;font-size:100px;letter-spacing:0;line-height:1.44";
  probe.style.fontFamily = getComputedStyle(screen).fontFamily;
  probe.textContent = "M".repeat(80);
  document.body.append(probe);
  const box = probe.getBoundingClientRect();
  if (box.width > 0) cellRatio = box.width / 80 / 100;
  if (box.height > 0) lineRatio = box.height / 100;
  probe.remove();
}

function fitScreen() {
  const box = viewport.getBoundingClientRect();
  if (box.width < 10 || box.height < 10) return;
  // A altura decide o corpo do texto; a largura restante vira passo de caractere,
  // como no cel de 3270, para que as 80 colunas ocupem o tubo inteiro.
  const byHeight = box.height / (ROWS * lineRatio);
  const byWidth = box.width / (COLUMNS * cellRatio);
  const size = Math.max(5, Math.min(byHeight, byWidth));
  const spacing = Math.max(0, Math.min(size * 0.5, (box.width - COLUMNS * size * cellRatio) / COLUMNS));
  screen.style.fontSize = `${size}px`;
  screen.style.letterSpacing = `${spacing}px`;
  document.documentElement.style.setProperty("--chrome-font", `${Math.min(16, Math.max(9, size * 0.8))}px`);
  document.documentElement.style.setProperty("--chrome-small", `${Math.min(12, Math.max(8, size * 0.58))}px`);
}

async function prepareFit() {
  if (document.fonts?.ready) {
    try { await document.fonts.ready; } catch { /* fonte opcional */ }
  }
  measureCell();
  fitScreen();
}

new ResizeObserver(fitScreen).observe(viewport);
addEventListener("orientationchange", () => setTimeout(fitScreen, 120));

// Navegadores só permitem tela cheia a partir de um gesto: tentamos na abertura e,
// se for recusado, entramos na primeira interação real da pessoa.
function requestFullScreen({ silent = false } = {}) {
  if (document.fullscreenElement) return Promise.resolve(true);
  const request = document.documentElement.requestFullscreen?.({ navigationUI: "hide" });
  if (!request) return Promise.resolve(false);
  return request.then(() => true).catch(() => {
    if (!silent) announcer.textContent = t("demo.fullscreenUnavailable");
    return false;
  });
}

function armAutomaticFullScreen() {
  const enter = () => { requestFullScreen({ silent: true }); };
  addEventListener("pointerdown", enter, { once: true });
  addEventListener("keydown", enter, { once: true });
}

function renderKeys() {
  keysBar.replaceChildren();
  for (const [key, label] of pfKeys(model, t)) {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.command = key;
    const code = document.createElement("kbd");
    code.textContent = key;
    button.append(code, document.createTextNode(label));
    keysBar.append(button);
  }
}

function render({ announce = true } = {}) {
  screen.textContent = composeScreen(model, t, locale()).join("\n");
  prompt.textContent = promptLabel(model);
  renderKeys();
  document.getElementById("command-form").hidden = false;
  fitScreen();
  commandInput.setAttribute("aria-label", `${promptLabel(model)} ${t("demo.command")}`);
  const guideStep = model.state.guideStep;
  document.getElementById("guide-panel").hidden = guideStep < 0;
  if (guideStep >= 0) {
    document.getElementById("guide-progress").textContent = t("demo.guideStep", { current: guideStep + 1, total: model.guideLength });
    document.getElementById("guide-copy").textContent = t(`demo.guide${guideStep}`);
    document.getElementById("guide-prev").disabled = guideStep === 0;
    document.getElementById("guide-next").textContent = t(guideStep === model.guideLength - 1 ? "demo.finish" : "demo.next");
  }
  if (announce) {
    announcer.textContent = `${screenTitle(model, t)}. ${model.state.message ? t(`error.${model.state.message}`) : ""}`;
  }
}

function run(command) {
  if (!model || booting) return;
  model.command(command);
  commandInput.value = "";
  historyIndex = model.history.length;
  render();
}

async function boot() {
  booting = true;
  const banner = [
    "",
    "   DATACORP - SIFAP - AMBIENTE DE DEMONSTRACAO LOCAL",
    "",
    "   CONECTANDO ADABAS CE 7.4.0   DBID=12 ................. [SIMULADO]",
    "   NATURAL CE 9.3.3   LIBRARY: SIFAPPRD ................. [SIMULADO]",
    "   TERMINAL T0001   80X24   VERDE FOSFORO ............... [PRONTO]",
    "",
    `   ${t("demo.simulated")}`,
  ];
  if (reduceMotion.matches) {
    screen.textContent = banner.join("\n");
    await sleep(200);
  } else {
    for (let index = 0; index < banner.length; index++) {
      screen.textContent = banner.slice(0, index + 1).join("\n");
      await sleep(index === 0 ? 60 : 190);
    }
    await sleep(420);
  }
  booting = false;
  render({ announce: false });
}

document.addEventListener("click", event => {
  if (!model || !(event.target instanceof Element)) return;
  const target = event.target.closest("button");
  if (!target || target.disabled) return;
  if (target.dataset.command) { run(target.dataset.command); commandInput.focus(); return; }
  if (target.id === "reset") { model.reset(); historyIndex = 0; commandInput.value = ""; render(); }
  else if (target.id === "fullscreen") {
    if (document.fullscreenElement) document.exitFullscreen();
    else requestFullScreen();
  }
  else if (target.id === "guide") { model.guide(0); render(); }
  else if (target.id === "guide-stop") { model.state.guideStep = -1; render({ announce: false }); }
  else if (target.id === "guide-prev") { model.guide(model.state.guideStep - 1); render(); }
  else if (target.id === "guide-next") {
    if (model.state.guideStep === model.guideLength - 1) run("MENU");
    else { model.guide(model.state.guideStep + 1); render(); }
  }
});

document.getElementById("command-form").addEventListener("submit", event => {
  event.preventDefault();
  run(commandInput.value);
});

commandInput.addEventListener("keydown", event => {
  if (!model || !["ArrowUp", "ArrowDown"].includes(event.key)) return;
  event.preventDefault();
  historyIndex = Math.max(0, Math.min(model.history.length, historyIndex + (event.key === "ArrowUp" ? -1 : 1)));
  commandInput.value = model.history[historyIndex] || "";
});

document.addEventListener("keydown", event => {
  if (!model || event.repeat || event.altKey || event.metaKey || event.ctrlKey) return;
  if (["F1", "F2", "F3", "F7", "F8"].includes(event.key)) {
    event.preventDefault();
    run(`P${event.key}`);
  }
});

document.getElementById("terminal").addEventListener("click", event => {
  if (!event.target.closest("button")) commandInput.focus();
});

function showLoadError() {
  const container = document.getElementById("load-state");
  const message = document.createElement("p");
  message.textContent = t("demo.loadError");
  const reload = document.createElement("button");
  reload.type = "button";
  reload.className = "button button-secondary";
  reload.textContent = t("demo.reload");
  reload.addEventListener("click", () => location.reload());
  container.replaceChildren(message, reload);
  container.setAttribute("role", "alert");
  container.hidden = false;
  document.getElementById("command-form").hidden = true;
}

document.addEventListener("sifap:locale", () => {
  if (model && !booting) render({ announce: false });
  else if (loadFailed) showLoadError();
});

try {
  const response = await fetch(new URL("./data.json", import.meta.url), { credentials: "omit" });
  if (!response.ok) throw new Error(`Demo dataset HTTP ${response.status}`);
  model = new DemoModel(await response.json());
  document.getElementById("load-state").hidden = true;
  document.getElementById("guide").disabled = false;
  document.getElementById("reset").disabled = false;
  await prepareFit();
  armAutomaticFullScreen();
  await boot();
  commandInput.focus({ preventScroll: true });
} catch (error) {
  console.error("Simulation dataset could not load:", error.name);
  loadFailed = true;
  showLoadError();
}
