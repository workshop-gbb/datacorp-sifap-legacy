import { scryptSync, randomBytes, timingSafeEqual } from "node:crypto";

// Node core scrypt keeps the gateway dependency-free. Parameters follow the
// OWASP minimum for interactive logins (N=2^15, r=8, p=1).
const COST = 32768;
const BLOCK = 8;
const PARALLEL = 1;
const KEY_LENGTH = 32;
const FORMAT = /^scrypt\$(\d+)\$(\d+)\$(\d+)\$([A-Za-z0-9+/=]{16,})\$([A-Za-z0-9+/=]{40,})$/;

export function hashPassword(password) {
  if (typeof password !== "string" || password.length < 12 || password.length > 128) {
    throw new Error("A workshop password must contain 12 to 128 characters.");
  }
  const salt = randomBytes(16);
  const derived = scryptSync(password.normalize("NFKC"), salt, KEY_LENGTH, {
    N: COST,
    r: BLOCK,
    p: PARALLEL,
    maxmem: 128 * COST * BLOCK * 2,
  });
  return `scrypt$${COST}$${BLOCK}$${PARALLEL}$${salt.toString("base64")}$${derived.toString("base64")}`;
}

export function verifyPassword(password, encoded) {
  const parts = FORMAT.exec(encoded ?? "");
  if (!parts || typeof password !== "string" || password.length > 128) return false;
  const [, cost, block, parallel, salt, expected] = parts;
  const expectedBytes = Buffer.from(expected, "base64");
  let derived;
  try {
    derived = scryptSync(password.normalize("NFKC"), Buffer.from(salt, "base64"), expectedBytes.length, {
      N: Number(cost),
      r: Number(block),
      p: Number(parallel),
      maxmem: 128 * Number(cost) * Number(block) * 2,
    });
  } catch {
    return false;
  }
  return derived.length === expectedBytes.length && timingSafeEqual(derived, expectedBytes);
}

// Accounts arrive as environment configuration read from Key Vault at boot.
// Neither a password nor a hash is ever written into this repository.
export function loadAccounts(environment = process.env) {
  const accounts = new Map();
  for (const role of ["ADMIN", "VIEWER"]) {
    const username = environment[`SIFAP_${role}_USERNAME`];
    const hash = environment[`SIFAP_${role}_PASSWORD_HASH`];
    if (!username || !hash) continue;
    if (!/^[a-zA-Z0-9._-]{2,32}$/.test(username)) {
      throw new Error(`SIFAP_${role}_USERNAME has an invalid format.`);
    }
    if (!FORMAT.test(hash)) {
      throw new Error(`SIFAP_${role}_PASSWORD_HASH must be a scrypt hash from hash-password.mjs.`);
    }
    accounts.set(role, { username, hash });
  }
  if (accounts.size === 0) throw new Error("At least one workshop account must be configured.");
  return accounts;
}

export function authenticate(accounts, role, username, password) {
  const account = accounts.get(role);
  // Verify a decoy hash for an unknown role so response time cannot enumerate accounts.
  const reference = account ?? { username: "\u0000", hash: accounts.values().next().value.hash };
  const correctPassword = verifyPassword(password, reference.hash);
  const correctUser = Buffer.byteLength(username ?? "") === Buffer.byteLength(reference.username) &&
    timingSafeEqual(Buffer.from(username ?? ""), Buffer.from(reference.username));
  return Boolean(account) && correctPassword && correctUser ? role : null;
}
