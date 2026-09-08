import { randomBytes } from "node:crypto";

export function createSessionStore({ now = Date.now, ttlMs = 3600000, limit = 1000 } = {}) {
  const sessions = new Map();
  function prune() {
    const time = now();
    for (const [id, expires] of sessions) if (expires <= time) sessions.delete(id);
  }
  return {
    create(previous) {
      prune();
      if (previous) sessions.delete(previous);
      if (sessions.size >= limit) return null;
      const id = randomBytes(32).toString("base64url");
      sessions.set(id, now() + ttlMs);
      return id;
    },
    valid(id) {
      if (!id || !/^[\w-]{43}$/.test(id)) return false;
      const expires = sessions.get(id);
      if (!expires) return false;
      if (expires <= now()) { sessions.delete(id); return false; }
      return true;
    },
    remove(id) { sessions.delete(id); },
  };
}

export function cookieId(header = "") {
  const matches = header.split(";").map(v => v.trim()).filter(v => v.startsWith("sifap_viewer="));
  return matches.length === 1 ? matches[0].slice("sifap_viewer=".length) : undefined;
}
