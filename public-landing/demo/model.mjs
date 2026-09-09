const screens = ["welcome", "menu", "query", "beneficiary", "history", "programs", "list", "payments", "report", "audit", "help", "blocked", "loggedOut"];
const integer = value => Number.isSafeInteger(value) && value >= 0;
const identifier = value => typeof value === "string" && /^\d{11}$/.test(value);

export function validateDataset(data) {
  const require = (condition, message) => {
    if (!condition) throw new TypeError(`Invalid simulation dataset: ${message}`);
  };
  require(data?.schemaVersion === 1 && data.synthetic === true, "synthetic snapshot required");
  for (const key of ["programs", "beneficiaries", "payments", "audits", "periods"]) {
    require(Array.isArray(data[key]) && data[key].length > 0, key);
  }
  require(/^\d{4}-\d{2}-\d{2}$/.test(data.snapshotDate), "snapshot date");
  require(data.versions?.natural === "9.3.3" && data.versions?.adabas === "7.4.0" && data.versions?.dbid === 12, "runtime references");
  const programs = new Set(data.programs.map(row => row.code));
  require(programs.size === data.programs.length, "duplicate programs");
  require([...programs].every(code => ["PBF1", "BPC1", "PETI", "AUX1", "GASF", "IDOS"].includes(code)), "program codes");
  const cpfs = new Set();
  const nises = new Set();
  for (const row of data.beneficiaries) {
    require(identifier(row.cpf) && identifier(row.nis) && !cpfs.has(row.cpf) && !nises.has(row.nis), "beneficiary identity");
    require(programs.has(row.program) && ["A", "S", "C", "I", "D"].includes(row.status), "beneficiary codes");
    require(integer(row.familyIncomeCents) && integer(row.dependents), "beneficiary numbers");
    for (const key of ["name", "city", "uf", "region"]) require(typeof row[key] === "string", key);
    for (const key of ["birthDate", "registeredAt"]) require(/^\d{4}-\d{2}-\d{2}$/.test(row[key]), key);
    cpfs.add(row.cpf); nises.add(row.nis);
  }
  const periods = new Set(data.periods);
  require(periods.size === data.periods.length && [...periods].every(value => /^\d{4}-(0[1-9]|1[0-2])$/.test(value)), "periods");
  const paymentIds = new Set();
  for (const row of data.payments) {
    require(cpfs.has(row.cpf) && periods.has(row.period), "payment relationship");
    require(typeof row.id === "string" && !paymentIds.has(row.id), "payment ID");
    require(integer(row.grossCents) && integer(row.discountCents) && integer(row.netCents), "payment amounts");
    require(["P", "G", "E", "C", "D", "X", "R"].includes(row.status) && ["N", "R", "A", "C"].includes(row.type), "payment codes");
    paymentIds.add(row.id);
  }
  for (const row of data.audits) {
    require(typeof row.id === "string" && typeof row.module === "string" && /^\d{4}-\d{2}-\d{2}$/.test(row.date), "audit structure");
    require(["IN", "AL", "BT", "ER", "CO"].includes(row.action) && ["BENF", "PGTO"].includes(row.entity), "audit codes");
  }
}

export function maskCpf(cpf) {
  if (!identifier(cpf)) throw new TypeError("Invalid CPF.");
  return cpf.startsWith("0") ? `${cpf.slice(0, 3)}.***.***-**` : `***.***.${cpf.slice(6, 9)}-${cpf.slice(9)}`;
}

export class DemoModel {
  constructor(data) {
    validateDataset(data);
    this.data = data;
    this.byCpf = new Map(data.beneficiaries.map(row => [row.cpf, row]));
    this.byNis = new Map(data.beneficiaries.map(row => [row.nis, row]));
    this.guideLength = 10;
    this.reset();
  }

  reset() {
    this.state = {
      screen: "welcome", selectedCpf: null, searchKind: "CPF", queryFor: "beneficiary",
      program: "ALL", period: this.data.periods[0], page: 0, message: null, guideStep: -1,
    };
    this.history = [];
    this.backstack = [];
  }

  navigate(screen) {
    if (!screens.includes(screen)) throw new Error("Unknown simulation screen.");
    if (screen !== this.state.screen) {
      this.backstack.push(this.state.screen);
      this.backstack = this.backstack.slice(-20);
    }
    this.state.screen = screen;
    this.state.page = 0;
    this.state.message = null;
  }

  back() {
    if (this.state.screen === "menu") return this.navigate("loggedOut");
    this.state.screen = this.backstack.pop() || "menu";
    this.state.message = null;
    this.state.page = 0;
  }

  lookup(raw, kind = "CPF", target = "beneficiary") {
    const value = raw.trim().replace(/[.\s-]/g, "");
    this.state.searchKind = kind;
    if (!identifier(value)) {
      this.state.message = "invalidId";
      return;
    }
    const record = (kind === "CPF" ? this.byCpf : this.byNis).get(value);
    if (!record) {
      this.state.message = "notFound";
      return;
    }
    this.state.selectedCpf = record.cpf;
    this.navigate(target);
  }

  selected() {
    return this.byCpf.get(this.state.selectedCpf) || null;
  }

  samples() {
    return [
      this.data.beneficiaries[0],
      this.data.beneficiaries.find(row => row.status === "A" && !row.cpf.startsWith("0")),
      this.data.beneficiaries.find(row => row.status === "S"),
    ].filter(Boolean);
  }

  turnPage(delta) {
    const total = this.state.screen === "history" ? this.rows().length : this.rows().length;
    const pages = Math.max(1, Math.ceil(total / 8));
    this.state.page = Math.min(Math.max(this.state.page + delta, 0), pages - 1);
  }

  setPeriod(value) {
    if (!this.data.periods.includes(value)) {
      this.state.message = "invalidPeriod";
      return;
    }
    this.state.period = value;
    this.state.page = 0;
    this.state.message = null;
  }

  setProgram(value) {
    if (value !== "ALL" && !this.data.programs.some(row => row.code === value)) {
      this.state.message = "invalidProgram";
      return;
    }
    this.state.program = value;
    this.state.page = 0;
    this.state.message = null;
  }

  rows() {
    const { screen, period, program, selectedCpf } = this.state;
    const matches = cpf => program === "ALL" || this.byCpf.get(cpf).program === program;
    if (screen === "history") {
      return this.data.payments.filter(row => row.cpf === selectedCpf)
        .toSorted((a, b) => b.period.localeCompare(a.period) || a.id.localeCompare(b.id)).slice(0, 12);
    }
    if (screen === "payments") {
      return this.data.payments.filter(row => row.period === period && matches(row.cpf));
    }
    if (screen === "audit") return this.data.audits.toSorted((a, b) => b.date.localeCompare(a.date));
    if (screen === "list") return this.data.beneficiaries.filter(row => program === "ALL" || row.program === program);
    return [];
  }

  report() {
    return this.data.programs
      .filter(row => this.state.program === "ALL" || row.code === this.state.program)
      .map(({ code }) => {
        const payments = this.data.payments.filter(row => row.period === this.state.period && this.byCpf.get(row.cpf).program === code);
        return payments.reduce((total, row) => ({
          code, count: total.count + 1, grossCents: total.grossCents + row.grossCents,
          discountCents: total.discountCents + row.discountCents, netCents: total.netCents + row.netCents,
        }), { code, count: 0, grossCents: 0, discountCents: 0, netCents: 0 });
      });
  }

  command(raw) {
    const cmd = raw.trim().toUpperCase();
    this.state.message = null;
    this.state.guideStep = -1;
    if (!cmd || cmd.length > 100) {
      this.state.message = "invalidCommand";
      return;
    }
    this.history.push(cmd);
    this.history = this.history.slice(-30);
    if (["RESET", "REINICIAR"].includes(cmd)) return this.reset();
    if (["START", "INICIAR"].includes(cmd)) return this.navigate("menu");
    if (["HELP", "AJUDA", "AYUDA", "?", "PF1"].includes(cmd)) return this.navigate("help");
    if (["GUIDE", "GUIA", "GUÍA", "PF2"].includes(cmd)) return this.guide(0);
    if (["LOGOFF", "LOGOUT", "SAIR", "SALIR", "EXIT"].includes(cmd)) return this.navigate("loggedOut");
    if (["PF3", "BACK", "VOLTAR", "VOLVER"].includes(cmd)) return this.back();
    if (["MENU", "MENÚ", "PF12"].includes(cmd)) return this.navigate("menu");
    const query = /^(BENEF|PAG)\s+(CPF|NIS)=(.*)$/.exec(cmd);
    if (query) return this.lookup(query[3], query[2], query[1] === "PAG" ? "history" : "beneficiary");
    const periodChoice = /^PER=(\d{1,2})$/.exec(cmd);
    if (periodChoice) return this.setPeriod(this.data.periods[Number(periodChoice[1]) - 1] ?? "");
    const programChoice = /^PROG=([A-Z0-9]{1,4})$/.exec(cmd);
    if (programChoice) return this.setProgram(programChoice[1]);
    if (cmd === "LIST") { this.setProgram("ALL"); return this.navigate("list"); }
    if (cmd === "9" && this.state.screen !== "programs") return this.navigate("loggedOut");
    if (["welcome", "loggedOut"].includes(this.state.screen)) {
      this.state.message = "startFirst";
      return;
    }
    if (this.state.screen === "menu") {
      if (["1", "2"].includes(cmd)) {
        this.state.queryFor = cmd === "1" ? "beneficiary" : "history";
        return this.navigate("query");
      }
      const choices = { "3": "programs", "4": "payments", "5": "report", "6": "blocked", "7": "blocked", "8": "audit" };
      if (choices[cmd]) return this.navigate(choices[cmd]);
    } else if (this.state.screen === "query") {
      if (cmd === "C" || cmd === "N") { this.state.searchKind = cmd === "C" ? "CPF" : "NIS"; return; }
      return this.lookup(cmd, this.state.searchKind, this.state.queryFor);
    } else if (this.state.screen === "programs") {
      const code = cmd === "9" || cmd === "ALL" ? "ALL" : this.data.programs[Number(cmd) - 1]?.code || cmd;
      this.setProgram(code);
      if (!this.state.message) this.navigate("list");
      return;
    } else if (["beneficiary", "history"].includes(this.state.screen)) {
      if (cmd === "PF5" && this.selected()) return this.navigate("history");
      if (cmd === "PF8" && this.selected()) return this.navigate("beneficiary");
      if (cmd === "PF6") return this.navigate("query");
      if (cmd === "PF7" && this.state.screen === "history") return this.turnPage(-1);
    } else if (["list", "payments", "audit"].includes(this.state.screen)) {
      if (cmd === "PF7") return this.turnPage(-1);
      if (cmd === "PF8") return this.turnPage(1);
      if (this.state.screen === "list" && identifier(cmd)) return this.lookup(cmd, "NIS");
    }
    this.state.message = "invalidCommand";
  }

  guide(index) {
    if (!Number.isInteger(index) || index < 0 || index >= this.guideLength) throw new RangeError("Invalid guide step.");
    this.state.selectedCpf = this.data.beneficiaries[0].cpf;
    this.state.program = "ALL";
    this.state.period = this.data.periods[0];
    this.navigate(["menu", "query", "beneficiary", "history", "list", "payments", "report", "audit", "blocked", "help"][index]);
    this.state.guideStep = index;
  }
}
