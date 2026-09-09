import { money, date, period } from "../i18n.mjs";
import { maskCpf } from "./model.mjs";

export const COLUMNS = 80;
export const ROWS = 24;
export const PAGE_SIZE = 8;

export function ascii(value) {
  return String(value).normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\x20-\x7E]/g, " ").toUpperCase();
}

export function pad(value, width) {
  const text = ascii(value);
  return text.length >= width ? text.slice(0, width) : text + " ".repeat(width - text.length);
}

export function lpad(value, width) {
  const text = ascii(value);
  return text.length >= width ? text.slice(-width) : " ".repeat(width - text.length) + text;
}

export function spread(left, middle, right, width = COLUMNS) {
  const start = ascii(left);
  const end = ascii(right);
  const center = ascii(middle);
  const slot = Math.max(0, width - start.length - end.length);
  const offset = Math.max(0, Math.floor((slot - center.length) / 2));
  return pad(start + " ".repeat(offset) + center, width - end.length) + end;
}

const rule = character => character.repeat(COLUMNS);
const indent = (text, columns = 3) => " ".repeat(columns) + ascii(text);
const sentence = (text, index = 0) => `${ascii(text).split(". ")[index] || ""}.`.replace(/\.\.$/, ".");
// Terminais listavam números sem símbolo; a moeda vai no cabeçalho da coluna.
const amount = (locale, cents) => new Intl.NumberFormat(locale, {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
}).format(cents / 100);
const currency = (label, locale) => `${ascii(label)} ${ascii(money(locale, 0).replace(/[\d.,\s]/g, ""))}`;

function clock(now) {
  const stamp = value => String(value).padStart(2, "0");
  return {
    date: `${stamp(now.getDate())}/${stamp(now.getMonth() + 1)}/${now.getFullYear()}`,
    time: `${stamp(now.getHours())}:${stamp(now.getMinutes())}:${stamp(now.getSeconds())}`,
  };
}

function table(headers, widths, records, cells) {
  const border = `  +${widths.map(width => "-".repeat(width + 2)).join("+")}+`;
  const row = values => `  | ${values.map((value, index) =>
    typeof value === "number" ? lpad(value, widths[index]) : pad(value, widths[index])).join(" | ")} |`;
  return [border, row(headers), border, ...records.map(record => row(cells(record))), border];
}

function paged(model, rows) {
  const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  model.state.page = Math.min(Math.max(model.state.page, 0), pages - 1);
  const current = model.state.page;
  return {
    slice: rows.slice(current * PAGE_SIZE, (current + 1) * PAGE_SIZE),
    footer: `${lpad(rows.length, 5)} REG   PAG ${current + 1}/${pages}`,
  };
}

const programLabel = (t, code) => `${code} ${t(`program.${code}`)}`;

function body(model, t, locale) {
  const state = model.state;
  const lines = [];

  if (state.screen === "welcome") {
    lines.push("",
      indent("SIFAP - SISTEMA DE FISCALIZACAO E ADMINISTRACAO DE PAGAMENTOS", 8), "",
      indent(sentence(t("demo.welcomeCopy"))), "",
      indent(`${pad(t("demo.query"), 26)}: ${lpad(model.data.beneficiaries.length, 5)}`, 8),
      indent(`${pad(t("demo.programs"), 26)}: ${lpad(model.data.programs.length, 5)}`, 8),
      indent(`${pad(t("demo.payments"), 26)}: ${lpad(model.data.payments.length, 5)}`, 8),
      indent(`${pad(t("demo.audit"), 26)}: ${lpad(model.data.audits.length, 5)}`, 8),
      "", indent(sentence(t("demo.welcomeNote"))), "",
      indent(`>>> ${t("demo.start")}: START + ENTER`));
  } else if (state.screen === "menu") {
    lines.push("", indent("SIFAP - SISTEMA DE FISCALIZACAO E ADMINISTRACAO DE PAGAMENTOS", 8), "");
    for (const [option, key, locked] of [
      ["1", "query"], ["2", "history"], ["3", "programs"], ["4", "payments"],
      ["5", "report"], ["6", "maintenance", true], ["7", "batch", true], ["8", "audit"],
    ]) lines.push(indent(`${option}  -  ${pad(t(`demo.${key}`), 44)}${locked ? `[${t("demo.locked")}]` : ""}`, 8));
    lines.push("", indent(`9  -  ${t("demo.logout")}`, 8));
  } else if (state.screen === "query") {
    const kind = state.searchKind;
    lines.push("", indent(sentence(t("demo.queryCopy"))), "",
      indent(`${pad(t("demo.searchType"), 20)}: ${kind === "CPF" ? "[C] CPF    ( ) NIS" : "( ) CPF    [N] NIS"}`, 6),
      indent(`${pad(kind, 20)}: ___________     (11 DIG)`, 6), "",
      indent(`${t("demo.examples")}:`, 6));
    for (const record of model.samples()) {
      lines.push(indent(`${record[kind.toLowerCase()]}   ${pad(record.name, 30)} ${t(`beneficiaryStatus.${record.status}`)}`, 6));
    }
    lines.push("", indent(">>> C / N / 11 DIG + ENTER"));
  } else if (state.screen === "beneficiary") {
    const record = model.selected();
    lines.push("", indent(t("demo.detail")), indent("-".repeat(44)),
      indent(`${pad("CPF", 15)}: ${maskCpf(record.cpf)}        NIS: ${record.nis}`, 5),
      indent(`${pad(t("demo.name"), 15)}: ${record.name}`, 5),
      indent(`${pad(t("demo.birth"), 15)}: ${date(locale, record.birthDate)}`, 5),
      indent(`${pad(t("demo.city"), 15)}: ${record.city} / ${record.uf}    ${t("demo.region")}: ${record.region}`, 5),
      indent(`${pad(t("demo.program"), 15)}: ${programLabel(t, record.program)}`, 5),
      indent(`${pad(t("demo.status"), 15)}: ${t(`beneficiaryStatus.${record.status}`)}`, 5),
      indent(`${pad(t("demo.registered"), 15)}: ${date(locale, record.registeredAt)}`, 5),
      indent(`${pad(t("demo.dependents"), 15)}: ${record.dependents}`, 5),
      indent(`${pad(t("demo.income"), 15)}: ${money(locale, record.familyIncomeCents)}`, 5),
      "", indent(`>>> PF5 ${t("demo.history")}   PF6 ${t("demo.query")}`));
  } else if (state.screen === "history") {
    const record = model.selected();
    const view = paged(model, model.rows());
    lines.push("", indent(`NIS: ${record.nis}   ${pad(record.name, 34)} ${programLabel(t, record.program)}`), "",
      ...table([t("demo.period"), currency(t("demo.gross"), locale), currency(t("demo.discount"), locale), currency(t("demo.net"), locale), "STS", t("demo.type")],
        [9, 12, 11, 12, 3, 9], view.slice,
        row => [period(locale, row.period), amount(locale, row.grossCents), amount(locale, row.discountCents),
          amount(locale, row.netCents), row.status, t(`paymentType.${row.type}`)]),
      "", indent(`${view.footer}   PF6 ${t("demo.query")}   PF8 ${t("demo.detail")}`));
  } else if (state.screen === "programs") {
    lines.push("", indent(sentence(t("demo.selectOption"))), "");
    model.data.programs.forEach((record, index) => {
      const count = model.data.beneficiaries.filter(row => row.program === record.code).length;
      lines.push(indent(`${index + 1}  -  ${pad(programLabel(t, record.code), 46)}${lpad(count, 5)} REG`, 8));
    });
    lines.push("", indent(`9  -  ${t("demo.all")}`, 8));
  } else if (state.screen === "list") {
    const view = paged(model, model.rows());
    lines.push("", indent(`${t("demo.program")}: ${state.program === "ALL" ? t("demo.all") : programLabel(t, state.program)}`), "",
      ...table(["NIS", t("demo.name"), "UF", t("demo.program"), t("demo.status")],
        [11, 28, 2, 4, 10], view.slice,
        row => [row.nis, row.name, row.uf, row.program, t(`beneficiaryStatus.${row.status}`)]),
      "", indent(`${view.footer}   PF7/PF8 PAG   11 DIG = ${t("demo.open")}`));
  } else if (state.screen === "payments") {
    const view = paged(model, model.rows());
    lines.push("", indent(`${t("demo.period")}: ${period(locale, state.period)}    ${t("demo.program")}: ${state.program === "ALL" ? t("demo.all") : state.program}`), "",
      ...table([t("demo.period"), "NIS", t("demo.name"), currency(t("demo.net"), locale), "STS"],
        [9, 11, 23, 12, 3], view.slice,
        row => [period(locale, row.period), model.byCpf.get(row.cpf).nis, model.byCpf.get(row.cpf).name,
          amount(locale, row.netCents), row.status]),
      "", indent(`${view.footer}   PER=1..${model.data.periods.length}  PROG=COD/ALL  PF7/PF8`));
  } else if (state.screen === "report") {
    const rows = model.report();
    const total = rows.reduce((sum, row) => ({
      code: "TOTAL", count: sum.count + row.count, grossCents: sum.grossCents + row.grossCents,
      discountCents: sum.discountCents + row.discountCents, netCents: sum.netCents + row.netCents,
    }), { code: "TOTAL", count: 0, grossCents: 0, discountCents: 0, netCents: 0 });
    lines.push("", indent(`${t("demo.period")}: ${period(locale, state.period)}`), "",
      ...table([t("demo.program"), t("demo.records"), currency(t("demo.gross"), locale), currency(t("demo.discount"), locale), currency(t("demo.net"), locale)],
        [21, 6, 12, 11, 12], [...rows, total],
        row => [row.code === "TOTAL" ? t("demo.total") : programLabel(t, row.code), row.count,
          amount(locale, row.grossCents), amount(locale, row.discountCents), amount(locale, row.netCents)]),
      "", indent(`PER=1..${model.data.periods.length}   ${sentence(t("demo.reportNote"))}`));
  } else if (state.screen === "audit") {
    const view = paged(model, model.rows());
    lines.push("", indent(sentence(t("demo.auditNote"))), "",
      ...table([t("demo.event"), t("demo.date"), t("demo.module"), t("demo.action"), t("demo.entity")],
        [15, 13, 9, 11, 11], view.slice,
        row => [row.id, date(locale, row.date), row.module, t(`auditAction.${row.action}`), t(`entity.${row.entity}`)]),
      "", indent(`${view.footer}   PF7/PF8 PAG`));
  } else if (state.screen === "blocked") {
    lines.push("", "", indent(`*** ${t("demo.blocked")} ***`, 18), "",
      indent(sentence(t("demo.blockedCopy"))), indent(sentence(t("demo.blockedCopy"), 1)),
      "", indent(`>>> PF12 ${t("demo.menu")}`));
  } else if (state.screen === "help") {
    lines.push("", indent(sentence(t("demo.helpIntro"))), "");
    for (const [command, key] of [
      ["BENEF CPF=00097539740", "helpQuery"], ["PAG NIS=81977930374", "helpHistory"],
      ["LIST", "helpList"], ["PER=1   PROG=BPC1", "payments"], ["MENU / PF12", "helpMenu"],
      ["BACK / PF3", "helpBack"], ["GUIDE / PF2", "helpGuide"], ["LOGOFF", "helpExit"],
    ]) lines.push(indent(`${pad(command, 25)}${t(`demo.${key}`)}`, 5));
    lines.push("", indent(sentence(t("demo.helpKeyboard"))));
  } else if (state.screen === "loggedOut") {
    lines.push("", "", indent(`*** ${t("demo.ended")} ***`, 16), "",
      indent(sentence(t("demo.endedCopy"))), "", indent(">>> START + ENTER", 16));
  }
  return lines;
}

const PROGRAMS = {
  welcome: "SIFAP000", menu: "MENU0001", query: "CBENF010", beneficiary: "CBENF020",
  history: "CPAGT010", programs: "LBENF030", list: "LBENF031", payments: "LPAGT040",
  report: "RGER0050", audit: "CAUDT080", blocked: "SEGUR900", help: "HELP0001", loggedOut: "LOGOFF01",
};
const LEVELS = {
  welcome: "-----", menu: "00001", query: "00010", beneficiary: "00011", history: "00021",
  programs: "00030", list: "00031", payments: "00040", report: "00050", audit: "00080",
  blocked: "00090", help: "99999", loggedOut: "-----",
};

export function screenTitle(model, t) {
  const keys = {
    welcome: "welcome", menu: "menu", query: model.state.queryFor === "history" ? "history" : "query",
    beneficiary: "detail", history: "history", programs: "programs", list: "programs",
    payments: "payments", report: "report", audit: "audit", blocked: "blocked",
    help: "help", loggedOut: "ended",
  };
  return t(`demo.${keys[model.state.screen]}`);
}

export function promptLabel(model) {
  if (model.state.screen === "query") return `${model.state.searchKind} ===>`;
  if (["menu", "programs"].includes(model.state.screen)) return "OPCAO ===>";
  return "COMANDO ===>";
}

export function pfKeys(model, t) {
  const keys = [["PF1", t("demo.help")], ["PF2", t("demo.guide")], ["PF3", t("demo.previous")]];
  if (model.state.screen === "beneficiary") keys.push(["PF5", t("demo.history")], ["PF6", t("demo.query")]);
  else if (model.state.screen === "history") keys.push(["PF6", t("demo.query")], ["PF8", t("demo.detail")]);
  else if (["list", "payments", "audit"].includes(model.state.screen)) {
    keys.push(["PF7", t("demo.previous")], ["PF8", t("demo.next")]);
  }
  keys.push(["PF12", t("demo.menu")]);
  return keys;
}

export function statusLine(model, t) {
  if (model.state.message) return `*** ${t(`error.${model.state.message}`)}`;
  if (model.state.screen === "blocked") return `*** ${t("demo.blocked")}`;
  if (model.state.screen === "beneficiary") return t("demo.recordFound");
  if (["welcome", "loggedOut", "help"].includes(model.state.screen)) return t("demo.simulated");
  if (["list", "payments", "audit", "history"].includes(model.state.screen) && !model.rows().length) {
    return t("demo.empty");
  }
  return t("demo.selectOption");
}

export function composeScreen(model, t, locale, now = new Date()) {
  const screen = model.state.screen;
  const stamp = clock(now);
  const lines = [
    spread(`HORA: ${stamp.time}`, `SIFAP - ${screenTitle(model, t)}`, `DATA: ${stamp.date}`),
    spread("", t("demo.badge"), ""),
    spread(`PROGRAMA: ${PROGRAMS[screen]}`, "", `NIVEL: ${LEVELS[screen]}`),
    spread(`USUARIO : ${screen === "welcome" ? "----------" : "DEMO-LOCAL"}`, "", "BIBLIOTECA: SIFAPPRD"),
    rule("="),
  ];
  const available = ROWS - lines.length - 2;
  lines.push(...body(model, t, locale).slice(0, available));
  while (lines.length < ROWS - 2) lines.push("");
  lines.push(rule("="));
  lines.push(` ${statusLine(model, t)}`);
  return lines.map(line => pad(line, COLUMNS));
}
