import { randomBytes } from "node:crypto";

export function createSessionStore({ now = Date.now, ttlMs = 3600000, limit = 1000 } = {}) {
  const sessions = new Map();
  function prune() {
    const time = now();
    for (const [id, session] of sessions) if (session.expires <= time) sessions.delete(id);
  }
  return {
    create(role, previous) {
      prune();
      if (previous) sessions.delete(previous);
      if (sessions.size >= limit) return null;
      const id = randomBytes(32).toString("base64url");
      sessions.set(id, { role, expires: now() + ttlMs });
      return id;
    },
    role(id) {
      if (!id || !/^[\w-]{43}$/.test(id)) return null;
      const session = sessions.get(id);
      if (!session) return null;
      if (session.expires <= now()) {
        sessions.delete(id);
        return null;
      }
      return session.role;
    },
    remove(id) { sessions.delete(id); },
  };
}

export function cookieId(header = "") {
  const matches = header.split(";").map(v => v.trim()).filter(v => v.startsWith("sifap_viewer="));
  return matches.length === 1 ? matches[0].slice("sifap_viewer=".length) : undefined;
}
