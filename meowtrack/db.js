// db.js — persistance SQLite du suivi (issues / références / commentaires).
//
// Source de vérité du schéma. Modèle calqué sur chatServer/database.js :
// better-sqlite3 synchrone, WAL, migrations additives idempotentes. La base
// `meowtrack.db` vit à côté de ce fichier et est gitignorée (locale par machine).
//
// Le MCP (mcp.js) et le dashboard (server.js) ouvrent tous deux la même base —
// WAL autorise lectures concurrentes + un seul writer, ce qui suffit ici.

import Database from "better-sqlite3";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { inspectPath, gitContext, normalizePath } from "./repo.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.MEOWTRACK_DB || join(HERE, "meowtrack.db");

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.pragma("synchronous = NORMAL");
db.pragma("foreign_keys = ON");

db.exec(`
  CREATE TABLE IF NOT EXISTS issues (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ref         TEXT UNIQUE NOT NULL,
    type        TEXT NOT NULL DEFAULT 'bug',
    title       TEXT NOT NULL,
    description TEXT DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'open',
    priority    TEXT NOT NULL DEFAULT 'medium',
    tags        TEXT NOT NULL DEFAULT '[]',
    branch      TEXT,
    git_commit  TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  );

  CREATE TABLE IF NOT EXISTS refs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_id    INTEGER NOT NULL,
    path        TEXT NOT NULL,
    kind        TEXT,
    line_start  INTEGER,
    line_end    INTEGER,
    existed     INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE CASCADE
  );
  CREATE INDEX IF NOT EXISTS idx_refs_issue ON refs(issue_id);

  CREATE TABLE IF NOT EXISTS comments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    issue_id    INTEGER NOT NULL,
    body        TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    FOREIGN KEY(issue_id) REFERENCES issues(id) ON DELETE CASCADE
  );
  CREATE INDEX IF NOT EXISTS idx_comments_issue ON comments(issue_id);

  CREATE TABLE IF NOT EXISTS counters (
    prefix TEXT PRIMARY KEY,
    value  INTEGER NOT NULL DEFAULT 0
  );
`);

// ── Vocabulaire ──────────────────────────────────────────────────────────────
export const TYPES = ["bug", "feature", "task", "chore"];
export const STATUSES = ["open", "in_progress", "done", "wontfix"];
export const PRIORITIES = ["low", "medium", "high", "critical"];

const PREFIX = { bug: "BUG", feature: "FEAT", task: "TASK", chore: "CHORE" };

function nowIso() {
  return db.prepare("SELECT strftime('%Y-%m-%dT%H:%M:%SZ','now') AS t").get().t;
}

// Code lisible suivant `BUG-1`, `FEAT-2`… Un compteur monotone par préfixe (pas
// de réutilisation après suppression).
function nextRef(type) {
  const prefix = PREFIX[type] || "ISSUE";
  const tx = db.transaction(() => {
    db.prepare("INSERT INTO counters(prefix, value) VALUES(?, 0) ON CONFLICT(prefix) DO NOTHING").run(prefix);
    db.prepare("UPDATE counters SET value = value + 1 WHERE prefix = ?").run(prefix);
    return db.prepare("SELECT value FROM counters WHERE prefix = ?").get(prefix).value;
  });
  return `${prefix}-${tx()}`;
}

// Extrait les tokens `@chemin` d'un texte (description). Accepte lettres, chiffres,
// `_ . / -`. Renvoie la liste dédupliquée (ordre d'apparition).
export function extractMentions(text) {
  if (!text) return [];
  const out = [];
  const seen = new Set();
  const re = /@([A-Za-z0-9_./-]+(?::\d+(?:-\d+)?)?)/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    const raw = m[1];
    if (!seen.has(raw)) {
      seen.add(raw);
      out.push(raw);
    }
  }
  return out;
}

// Décompose un token de référence `path` ou `path:120` ou `path:120-145`.
function parseRefSpec(spec) {
  if (typeof spec === "object" && spec) {
    return {
      path: spec.path,
      lineStart: spec.lineStart ?? spec.line_start ?? null,
      lineEnd: spec.lineEnd ?? spec.line_end ?? null,
    };
  }
  const s = String(spec);
  const mm = s.match(/^(.*?):(\d+)(?:-(\d+))?$/);
  if (mm) return { path: mm[1], lineStart: Number(mm[2]), lineEnd: mm[3] ? Number(mm[3]) : null };
  return { path: s, lineStart: null, lineEnd: null };
}

function sanitizeTags(tags) {
  if (!tags) return [];
  const arr = Array.isArray(tags) ? tags : String(tags).split(",");
  return [...new Set(arr.map((t) => String(t).trim()).filter(Boolean))];
}

// ── Sérialisation ────────────────────────────────────────────────────────────
function rowToIssue(row, { withDetail = false } = {}) {
  if (!row) return null;
  const issue = {
    id: row.id,
    ref: row.ref,
    type: row.type,
    title: row.title,
    description: row.description,
    status: row.status,
    priority: row.priority,
    tags: JSON.parse(row.tags || "[]"),
    branch: row.branch,
    commit: row.git_commit,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    references: listReferences(row.id),
  };
  if (withDetail) issue.comments = listComments(row.id);
  return issue;
}

// ── Références ───────────────────────────────────────────────────────────────
export function listReferences(issueId) {
  return db
    .prepare("SELECT * FROM refs WHERE issue_id = ? ORDER BY id")
    .all(issueId)
    .map((r) => ({
      id: r.id,
      path: r.path,
      kind: r.kind,
      lineStart: r.line_start,
      lineEnd: r.line_end,
      existed: !!r.existed,
    }));
}

export function addReference(issueId, spec) {
  const { path, lineStart, lineEnd } = parseRefSpec(spec);
  const norm = normalizePath(path);
  if (!norm) throw new Error(`Chemin invalide ou hors repo : ${path}`);
  const info = inspectPath(norm);
  const info2 = db
    .prepare(
      "INSERT INTO refs(issue_id, path, kind, line_start, line_end, existed) VALUES(?,?,?,?,?,?)"
    )
    .run(issueId, norm, info.kind, lineStart, lineEnd, info.exists ? 1 : 0);
  touchIssue(issueId);
  return db.prepare("SELECT * FROM refs WHERE id = ?").get(info2.lastInsertRowid);
}

export function removeReference(refId) {
  const row = db.prepare("SELECT issue_id FROM refs WHERE id = ?").get(refId);
  const res = db.prepare("DELETE FROM refs WHERE id = ?").run(refId);
  if (row) touchIssue(row.issue_id);
  return res.changes > 0;
}

// Remplace l'intégralité des références d'une issue par `specs` (dédupliqué).
function setReferences(issueId, specs) {
  db.prepare("DELETE FROM refs WHERE issue_id = ?").run(issueId);
  const seen = new Set();
  for (const spec of specs || []) {
    const { path, lineStart, lineEnd } = parseRefSpec(spec);
    const norm = normalizePath(path);
    if (!norm) continue;
    const key = `${norm}:${lineStart ?? ""}:${lineEnd ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const info = inspectPath(norm);
    db.prepare(
      "INSERT INTO refs(issue_id, path, kind, line_start, line_end, existed) VALUES(?,?,?,?,?,?)"
    ).run(issueId, norm, info.kind, lineStart, lineEnd, info.exists ? 1 : 0);
  }
}

// ── Commentaires ─────────────────────────────────────────────────────────────
export function listComments(issueId) {
  return db.prepare("SELECT id, body, created_at AS createdAt FROM comments WHERE issue_id = ? ORDER BY id").all(issueId);
}

export function addComment(refOrId, body) {
  const issue = findRow(refOrId);
  if (!issue) throw new Error(`Issue introuvable : ${refOrId}`);
  if (!body || !String(body).trim()) throw new Error("Commentaire vide");
  db.prepare("INSERT INTO comments(issue_id, body) VALUES(?, ?)").run(issue.id, String(body).trim());
  touchIssue(issue.id);
  return getIssue(issue.id);
}

// ── Issues ───────────────────────────────────────────────────────────────────
function findRow(refOrId) {
  if (refOrId == null) return null;
  // Numérique pur → id ; sinon → ref (insensible à la casse).
  if (typeof refOrId === "number" || /^\d+$/.test(String(refOrId))) {
    return db.prepare("SELECT * FROM issues WHERE id = ?").get(Number(refOrId));
  }
  return db.prepare("SELECT * FROM issues WHERE ref = ? COLLATE NOCASE").get(String(refOrId));
}

function touchIssue(id) {
  db.prepare("UPDATE issues SET updated_at = ? WHERE id = ?").run(nowIso(), id);
}

export function getIssue(refOrId) {
  return rowToIssue(findRow(refOrId), { withDetail: true });
}

export function createIssue(input = {}) {
  const type = TYPES.includes(input.type) ? input.type : "bug";
  const title = String(input.title || "").trim();
  if (!title) throw new Error("Titre requis");
  const status = STATUSES.includes(input.status) ? input.status : "open";
  const priority = PRIORITIES.includes(input.priority) ? input.priority : "medium";
  const description = String(input.description || "");
  const tags = JSON.stringify(sanitizeTags(input.tags));
  const ctx = gitContext();

  // Références = celles fournies explicitement + celles détectées via @mentions
  // dans la description (sauf si autoMention === false).
  const specs = [...(input.paths || input.references || [])];
  if (input.autoMention !== false) specs.push(...extractMentions(description));

  const ref = nextRef(type);
  const tx = db.transaction(() => {
    const res = db
      .prepare(
        `INSERT INTO issues(ref, type, title, description, status, priority, tags, branch, git_commit)
         VALUES(?,?,?,?,?,?,?,?,?)`
      )
      .run(ref, type, title, description, status, priority, tags, ctx.branch, ctx.commit);
    const id = res.lastInsertRowid;
    setReferences(id, specs);
    return id;
  });
  return getIssue(tx());
}

export function updateIssue(refOrId, fields = {}) {
  const row = findRow(refOrId);
  if (!row) throw new Error(`Issue introuvable : ${refOrId}`);
  const sets = [];
  const vals = [];
  const set = (col, v) => {
    sets.push(`${col} = ?`);
    vals.push(v);
  };
  if (fields.title != null) {
    const t = String(fields.title).trim();
    if (t) set("title", t);
  }
  if (fields.description != null) set("description", String(fields.description));
  if (fields.type != null && TYPES.includes(fields.type)) set("type", fields.type);
  if (fields.status != null) {
    if (!STATUSES.includes(fields.status)) throw new Error(`Statut invalide : ${fields.status}`);
    set("status", fields.status);
  }
  if (fields.priority != null) {
    if (!PRIORITIES.includes(fields.priority)) throw new Error(`Priorité invalide : ${fields.priority}`);
    set("priority", fields.priority);
  }
  if (fields.tags != null) set("tags", JSON.stringify(sanitizeTags(fields.tags)));

  const tx = db.transaction(() => {
    if (sets.length) {
      set("updated_at", nowIso());
      db.prepare(`UPDATE issues SET ${sets.join(", ")} WHERE id = ?`).run(...vals, row.id);
    }
    // Remplacement des références si `paths`/`references` fourni explicitement.
    if (fields.paths != null || fields.references != null) {
      setReferences(row.id, fields.paths || fields.references || []);
      touchIssue(row.id);
    }
  });
  tx();
  return getIssue(row.id);
}

export function deleteIssue(refOrId) {
  const row = findRow(refOrId);
  if (!row) return false;
  db.prepare("DELETE FROM issues WHERE id = ?").run(row.id); // cascade refs + comments
  return true;
}

export function listIssues(filter = {}) {
  const where = [];
  const vals = [];
  if (filter.type) {
    where.push("type = ?");
    vals.push(filter.type);
  }
  if (filter.status) {
    where.push("status = ?");
    vals.push(filter.status);
  } else if (filter.open !== undefined ? filter.open : filter.includeClosed !== true) {
    // Par défaut : on masque les clos (done/wontfix) sauf includeClosed.
    if (filter.includeClosed !== true && !filter.status) where.push("status IN ('open','in_progress')");
  }
  if (filter.priority) {
    where.push("priority = ?");
    vals.push(filter.priority);
  }
  if (filter.tag) {
    where.push("tags LIKE ?");
    vals.push(`%"${filter.tag}"%`);
  }
  if (filter.path) {
    where.push("id IN (SELECT issue_id FROM refs WHERE path LIKE ?)");
    vals.push(`%${filter.path}%`);
  }
  if (filter.text) {
    where.push("(title LIKE ? OR description LIKE ? OR ref LIKE ?)");
    const like = `%${filter.text}%`;
    vals.push(like, like, like);
  }
  const sql =
    "SELECT * FROM issues" +
    (where.length ? " WHERE " + where.join(" AND ") : "") +
    " ORDER BY " +
    // tri : statut actif d'abord, puis priorité décroissante, puis récence.
    "CASE status WHEN 'in_progress' THEN 0 WHEN 'open' THEN 1 WHEN 'wontfix' THEN 2 WHEN 'done' THEN 3 END, " +
    "CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END, " +
    "updated_at DESC";
  const rows = db.prepare(sql).all(...vals);
  const limit = filter.limit ? Math.max(1, Math.min(500, filter.limit)) : 200;
  return rows.slice(0, limit).map((r) => rowToIssue(r));
}

// Statistiques pour le dashboard / tool de résumé.
export function stats() {
  const byStatus = {};
  for (const r of db.prepare("SELECT status, COUNT(*) c FROM issues GROUP BY status").all()) byStatus[r.status] = r.c;
  const byType = {};
  for (const r of db.prepare("SELECT type, COUNT(*) c FROM issues GROUP BY type").all()) byType[r.type] = r.c;
  const byPriority = {};
  for (const r of db.prepare("SELECT priority, COUNT(*) c FROM issues GROUP BY priority").all())
    byPriority[r.priority] = r.c;
  const total = db.prepare("SELECT COUNT(*) c FROM issues").get().c;
  return { total, byStatus, byType, byPriority };
}

export { db };
