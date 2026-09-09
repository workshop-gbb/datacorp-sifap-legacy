import { createInterface } from "node:readline";
import { hashPassword } from "./credentials.mjs";

// Reads one password from standard input so it never appears in shell history,
// process arguments or this repository. Prints only the derived hash.
const input = createInterface({ input: process.stdin, terminal: false });
const [password] = await input[Symbol.asyncIterator]().next().then((entry) => [entry.value]);
input.close();
if (typeof password !== "string") throw new Error("Provide the password on standard input.");
process.stdout.write(`${hashPassword(password.replace(/\r$/, ""))}\n`);
