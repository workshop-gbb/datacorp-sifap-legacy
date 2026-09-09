import { readFileSync, writeFileSync } from "node:fs";
import { render } from "./messages.mjs";
const template = readFileSync(new URL("./landing.html", import.meta.url), "utf8");
writeFileSync(new URL("../../payload-static/www/index.html", import.meta.url), render(template, "pt-BR"));
