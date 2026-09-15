import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DemoModel, validateDataset, maskCpf } from "../../../public-landing/demo/model.mjs";
import { composeScreen, promptLabel, pfKeys, ascii, pad, spread, COLUMNS, ROWS } from "../../../public-landing/demo/terminal.mjs";
import { messages, translate, normalizeLocale, money, date, period, periodShort } from "../../../public-landing/i18n.mjs";

const fixture = JSON.parse(readFileSync(new URL("../../../public-landing/demo/data.json", import.meta.url)));
const first = fixture.beneficiaries[0];
const t = key => translate("pt-BR", key);
const clock = new Date("2026-09-09T02:15:30Z");

test("all site and demo translations have identical keys and no empty values", () => {
  const keys = Object.keys(messages["pt-BR"]).sort();
  for (const locale of ["pt-BR", "en", "es"]) {
    assert.deepEqual(Object.keys(messages[locale]).sort(), keys);
    assert.ok(Object.values(messages[locale]).every(value => typeof value === "string" && value.trim()));
    for (const key of keys) assert.equal(typeof translate(locale, key), "string");
  }
  assert.equal(normalizeLocale("pt"), "pt-BR");
  assert.equal(normalizeLocale("en"), "en");
  assert.equal(normalizeLocale("es"), "es");
  assert.equal(normalizeLocale("https://evil.invalid"), "pt-BR");
  assert.throws(() => translate("en", "missing.key"), /Missing translation/);
  assert.notEqual(money("en", 123456), money("pt-BR", 123456));
  assert.match(money("es", 123456), /1234,56|1\.234,56/);
  assert.notEqual(date("en", "2018-03-14"), date("pt-BR", "2018-03-14"));
  assert.notEqual(period("en", "2018-01"), period("es", "2018-01"));
  for (const language of ["pt-BR", "en", "es"]) {
    assert.match(periodShort(language, "2018-01"), /^\d{2}\/2018$/);
  }
});

test("dataset validation refuses live, malformed or inconsistent fixtures", () => {
  validateDataset(fixture);
  assert.throws(() => validateDataset({ ...fixture, synthetic: false }));
  assert.throws(() => validateDataset({ ...fixture, schemaVersion: 100 }));
  const malformed = structuredClone(fixture);
  malformed.payments[0].netCents = "broken";
  assert.throws(() => validateDataset(malformed));
  const duplicate = structuredClone(fixture);
  duplicate.beneficiaries[1].cpf = first.cpf;
  assert.throws(() => validateDataset(duplicate));
});

test("CPF and NIS queries preserve leading zeros and resolve the same record", () => {
  const model = new DemoModel(fixture);
  model.command(`BENEF CPF=${first.cpf}`);
  assert.equal(model.state.screen, "beneficiary");
  assert.equal(model.selected().cpf, first.cpf);
  model.command(`PAG NIS=${first.nis}`);
  assert.equal(model.state.screen, "history");
  assert.equal(model.selected().cpf, first.cpf);
  assert.equal(model.rows().length, 4);
  model.command("BENEF CPF=<script>");
  assert.equal(model.state.message, "invalidId");
  model.command("BENEF NIS=99999999999");
  assert.equal(model.state.message, "notFound");
  assert.equal(maskCpf(first.cpf), "000.***.***-**");
});

test("all menu options work and monthly payments are payments, not beneficiaries", () => {
  const model = new DemoModel(fixture);
  model.command("START");
  for (const [option, screen] of [
    ["1", "query"], ["2", "query"], ["3", "programs"], ["4", "payments"],
    ["5", "report"], ["6", "blocked"], ["7", "blocked"], ["8", "audit"],
  ]) {
    model.command("MENU");
    model.command(option);
    assert.equal(model.state.screen, screen);
  }
  model.command("MENU"); model.command("4");
  assert.equal(model.rows().length, 500);
  assert.ok(model.rows().every(row => Number.isSafeInteger(row.netCents)));
  model.command("9");
  assert.equal(model.state.screen, "loggedOut");
  model.command("START");
  assert.equal(model.state.screen, "menu");
});

test("program, period, pagination and report totals derive from the displayed snapshot", () => {
  const model = new DemoModel(fixture);
  model.command("START"); model.command("3"); model.command("BPC1");
  assert.equal(model.state.screen, "list");
  assert.ok(model.rows().every(row => row.program === "BPC1"));
  model.command("LIST");
  assert.equal(model.rows().length, 500);
  model.command("MENU"); model.command("5");
  model.setPeriod("2017-12");
  const rows = model.report();
  const expected = fixture.payments.filter(row => row.period === "2017-12");
  assert.equal(rows.reduce((sum, row) => sum + row.count, 0), expected.length);
  assert.equal(rows.reduce((sum, row) => sum + row.netCents, 0), expected.reduce((sum, row) => sum + row.netCents, 0));
  model.setPeriod("2099-01");
  assert.equal(model.state.message, "invalidPeriod");
  assert.equal(model.state.period, "2017-12");
});

test("read-only actions, errors, reset and help do not mutate fixtures", () => {
  const original = JSON.stringify(fixture);
  const model = new DemoModel(fixture);
  model.command("START"); model.command("6");
  assert.equal(model.state.screen, "blocked");
  model.command("HELP");
  assert.equal(model.state.screen, "help");
  model.command("PF3");
  assert.equal(model.state.screen, "blocked");
  model.command("MENU"); model.command("<img src=x>");
  assert.equal(model.state.message, "invalidCommand");
  model.reset();
  assert.equal(model.state.screen, "welcome");
  assert.equal(model.history.length, 0);
  assert.equal(JSON.stringify(fixture), original);
});

test("every screen renders an exact 80x24 character grid with terminal chrome", () => {
  const model = new DemoModel(fixture);
  const seen = new Set();
  for (let step = 0; step < model.guideLength; step++) {
    model.guide(step);
    const lines = composeScreen(model, t, "pt-BR", clock);
    assert.equal(lines.length, ROWS);
    assert.ok(lines.every(line => line.length === COLUMNS), model.state.screen);
    assert.ok(lines.every(line => /^[\x20-\x7E]*$/.test(line)), model.state.screen);
    assert.match(lines[0], /^HORA: \d\d:\d\d:\d\d/);
    assert.match(lines[0], /SIFAP - /);
    assert.match(lines[0], /DATA: \d\d\/\d\d\/\d{4}\s*$/);
    assert.match(lines[2], /^PROGRAMA: [A-Z0-9]{8}.*NIVEL: [\d-]{5}\s*$/);
    assert.match(lines[3], /BIBLIOTECA: SIFAPPRD\s*$/);
    assert.equal(lines[4], "=".repeat(COLUMNS));
    assert.equal(lines[ROWS - 2], "=".repeat(COLUMNS));
    assert.ok(lines[ROWS - 1].trim().length > 0);
    assert.match(promptLabel(model), /===>$/);
    assert.ok(pfKeys(model, t).some(([key]) => key === "PF12"));
    seen.add(model.state.screen);
  }
  assert.equal(seen.size, model.guideLength);
});

test("terminal text is uppercase ASCII and its data stays legible in every language", () => {
  assert.equal(ascii("Situação · Relatório"), "SITUACAO   RELATORIO");
  assert.equal(pad("abc", 5), "ABC  ");
  assert.equal(spread("A", "B", "C").length, COLUMNS);
  const model = new DemoModel(fixture);
  model.command(`BENEF CPF=${first.cpf}`);
  const screens = ["pt-BR", "en", "es"].map(language => composeScreen(model, t, language, clock).join("\n"));
  for (const text of screens) {
    assert.ok(text.includes(maskCpf(first.cpf)));
    assert.ok(text.includes(ascii(first.name)));
    assert.ok(text.includes(first.nis));
  }
  const localized = ["pt-BR", "en", "es"].map(language =>
    composeScreen(model, key => translate(language, key), language, clock).join("\n"));
  assert.equal(new Set(localized).size, 3);
});

test("terminal tables show complete amounts and blocked screens warn on the status line", () => {
  const model = new DemoModel(fixture);
  model.command("START"); model.command("5");
  const report = composeScreen(model, t, "pt-BR", clock).join("\n");
  const totals = report.split("\n").find(line => line.includes("TOTAL"));
  assert.match(totals, /\d{1,3}(\.\d{3})*,\d{2}\s*\|/);
  assert.ok(!totals.includes(",3 "), totals);
  assert.match(report, /R\$/);
  model.command("MENU"); model.command("6");
  assert.match(composeScreen(model, t, "pt-BR", clock).at(-1), /\*\*\*/);
});

test("table columns never truncate periods, amounts or codes in any language", () => {
  const model = new DemoModel(fixture);
  model.command(`PAG CPF=${first.cpf}`);
  for (const language of ["pt-BR", "en", "es"]) {
    const rows = composeScreen(model, key => translate(language, key), language, clock)
      .filter(line => /\|\s*\d{2}\/\d{4}\s*\|/.test(line));
    assert.ok(rows.length > 0, language);
    for (const row of rows) {
      const cells = row.split("|").slice(1, -1).map(cell => cell.trim());
      assert.match(cells[0], /^\d{2}\/\d{4}$/, `${language}: ${row}`);
      for (const cell of cells.slice(1, 4)) assert.match(cell, /^[\d.,]+$/, `${language}: ${row}`);
      assert.ok(!row.includes("…"), row);
    }
  }
});

test("blocked, error and empty states stay visible on the status line", () => {
  const model = new DemoModel(fixture);
  model.command("START"); model.command("7");
  assert.match(composeScreen(model, t, "pt-BR", clock).join("\n"), /SEGUR900/);
  model.command("BENEF NIS=99999999999");
  assert.match(composeScreen(model, t, "pt-BR", clock)[ROWS - 1], /^ \*\*\* /);
});

test("period and program commands filter the payment screens", () => {
  const model = new DemoModel(fixture);
  model.command("START"); model.command("4");
  model.command("PER=2");
  assert.equal(model.state.period, fixture.periods[1]);
  model.command("PROG=BPC1");
  assert.equal(model.state.program, "BPC1");
  assert.ok(model.rows().every(row => model.byCpf.get(row.cpf).program === "BPC1"));
  model.command("PF8");
  assert.equal(model.state.page, 1);
  model.command("PF7");
  assert.equal(model.state.page, 0);
  model.command("PER=99");
  assert.equal(model.state.message, "invalidPeriod");
  model.command("PROG=ZZZZ");
  assert.equal(model.state.message, "invalidProgram");
});

test("guided tour covers the complete demo and is resettable", () => {
  const model = new DemoModel(fixture);
  const visited = new Set();
  for (let index = 0; index < model.guideLength; index++) {
    model.guide(index);
    visited.add(model.state.screen);
    assert.equal(model.state.guideStep, index);
  }
  for (const screen of ["menu", "query", "beneficiary", "history", "list", "payments", "report", "audit", "blocked", "help"]) {
    assert.ok(visited.has(screen), screen);
  }
  model.reset();
  assert.equal(model.state.guideStep, -1);
});
