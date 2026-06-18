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
import { inspectPath, gitContext, branchContext, normalizePath } from "./repo.js";

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

  -- ── Good Vibes v2 : arbre de NŒUDS récursif (objectifs = jalons = sous-jalons) ─
  -- v1 (goals/milestones) jamais déployée → on remplace sans migration.
  DROP TABLE IF EXISTS goal_messages;
  DROP TABLE IF EXISTS milestones;
  DROP TABLE IF EXISTS goals;

  CREATE TABLE IF NOT EXISTS nodes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ref         TEXT UNIQUE NOT NULL,                 -- NODE-1… via nextRef('node')
    parent_id   INTEGER,                              -- NULL = racine ; self-FK ON DELETE CASCADE
    root_id     INTEGER NOT NULL,                     -- racine de l'arbre (= id si racine)
    depth       INTEGER NOT NULL DEFAULT 0,           -- 0 = racine
    path        TEXT NOT NULL DEFAULT '',             -- '/1/4/9/' ids ancêtres + self → subtree via LIKE
    title       TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    notes       TEXT NOT NULL DEFAULT '',             -- notes libres markdown (rendu côté dashboard)
    status      TEXT NOT NULL DEFAULT 'active',       -- active|paused|done|abandoned
    color       TEXT NOT NULL DEFAULT 'accent',       -- accent|feature|task|bug|high (allowlist)
    emoji       TEXT NOT NULL DEFAULT '🎯',
    target_date TEXT,                                 -- 'YYYY-MM-DD' | null
    progress    INTEGER NOT NULL DEFAULT 0,           -- 0..100 STOCKÉ (rollup ascendant)
    position    INTEGER NOT NULL DEFAULT 0,           -- ordre parmi frères
    version     INTEGER NOT NULL DEFAULT 1,           -- pivot CAS, bumpé soi + ancêtres
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    done_at     TEXT,
    CHECK (parent_id IS NULL OR parent_id <> id),     -- anti auto-parent direct
    FOREIGN KEY(parent_id) REFERENCES nodes(id) ON DELETE CASCADE
  );
  CREATE INDEX IF NOT EXISTS idx_nodes_parent ON nodes(parent_id, position, id);
  CREATE INDEX IF NOT EXISTS idx_nodes_root   ON nodes(root_id);
  CREATE INDEX IF NOT EXISTS idx_nodes_path   ON nodes(path);
  CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status);

  CREATE TABLE IF NOT EXISTS node_messages (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id      INTEGER NOT NULL,
    role         TEXT NOT NULL,                        -- user|assistant
    author       TEXT NOT NULL DEFAULT 'anon',
    model        TEXT,                                 -- sonnet|opus|haiku | null
    body         TEXT NOT NULL DEFAULT '',             -- réponse finale (SANS bloc d'actions)
    reasoning    TEXT NOT NULL DEFAULT '',             -- réflexion streamée (repliable)
    state        TEXT NOT NULL DEFAULT 'complete',     -- pending|streaming|complete|error
    actions      TEXT NOT NULL DEFAULT '[]',           -- JSON audit (appliquées/proposées)
    client_nonce TEXT,
    created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    FOREIGN KEY(node_id) REFERENCES nodes(id) ON DELETE CASCADE
  );
  CREATE INDEX IF NOT EXISTS idx_node_messages_node ON node_messages(node_id, id);
`);

// ── Migrations additives idempotentes (colonnes ajoutées sur bases existantes) ─
function ensureColumn(table, column, ddl) {
  const cols = db.prepare(`PRAGMA table_info(${table})`).all();
  if (!cols.some((c) => c.name === column)) db.exec(`ALTER TABLE ${table} ADD COLUMN ${ddl}`);
}
ensureColumn("nodes", "notes", "notes TEXT NOT NULL DEFAULT ''"); // notes markdown par nœud

// ── Vocabulaire ──────────────────────────────────────────────────────────────
export const TYPES = ["bug", "feature", "task", "chore"];
export const STATUSES = ["open", "in_progress", "done", "wontfix"];
export const PRIORITIES = ["low", "medium", "high", "critical"];

// Vocabulaire Good Vibes v2 (arbre de nœuds).
export const NODE_STATUSES = ["active", "paused", "done", "abandoned"];
export const NODE_COLORS = ["accent", "feature", "task", "bug", "high"];
export const CHAT_MODELS = ["sonnet", "opus", "haiku"];
export const MESSAGE_STATES = ["pending", "streaming", "complete", "error"];
const MAX_DEPTH = 32; // profondeur max d'un arbre (anti-DoS récursion)
const MAX_NODES_PER_SUBTREE = 500; // garde-fou volume par sous-arbre
const MAX_ACTIONS = 20; // actions IA max appliquées par tour
const MAX_NOTES = 50000; // taille max des notes markdown d'un nœud (~50 Ko)

const PREFIX = { bug: "BUG", feature: "FEAT", task: "TASK", chore: "CHORE", node: "NODE" };

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
  // Existence validée contre la branche de l'issue (pas le working tree courant).
  const branch = db.prepare("SELECT branch FROM issues WHERE id = ?").get(issueId)?.branch || null;
  const { path, lineStart, lineEnd } = parseRefSpec(spec);
  const norm = normalizePath(path);
  if (!norm) throw new Error(`Chemin invalide ou hors repo : ${path}`);
  const info = inspectPath(norm, branch);
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
// `branch` cible l'arbre dans lequel valider l'existence des chemins.
function setReferences(issueId, specs, branch = null) {
  db.prepare("DELETE FROM refs WHERE issue_id = ?").run(issueId);
  const seen = new Set();
  for (const spec of specs || []) {
    const { path, lineStart, lineEnd } = parseRefSpec(spec);
    const norm = normalizePath(path);
    if (!norm) continue;
    const key = `${norm}:${lineStart ?? ""}:${lineEnd ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const info = inspectPath(norm, branch);
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
  // Branche choisie explicitement (tracking + validation des chemins) sinon HEAD.
  const ctx = input.branch ? branchContext(String(input.branch)) : gitContext();

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
    setReferences(id, specs, ctx.branch);
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
  // Changement de branche : recapture aussi le commit du sommet de cette branche.
  let newBranch = row.branch;
  if (fields.branch != null) {
    const ctx = branchContext(String(fields.branch) || null);
    newBranch = ctx.branch;
    set("branch", ctx.branch);
    set("git_commit", ctx.commit);
  }

  const tx = db.transaction(() => {
    if (sets.length) {
      set("updated_at", nowIso());
      db.prepare(`UPDATE issues SET ${sets.join(", ")} WHERE id = ?`).run(...vals, row.id);
    }
    // Remplacement des références si `paths`/`references` fourni explicitement
    // (validées contre la branche — éventuellement nouvelle — de l'issue).
    if (fields.paths != null || fields.references != null) {
      setReferences(row.id, fields.paths || fields.references || [], newBranch);
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
  if (filter.branch) {
    where.push("branch = ?");
    vals.push(filter.branch);
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

// ═══════════════════════════════════════════════════════════════════════════
// Good Vibes v2 — arbre de NŒUDS récursif + chat IA streaming scopé par sous-arbre.
//
// Un seul type de nœud (objectif = jalon = sous-jalon), `parent_id` self-réf.
// `path` ('/1/4/9/' ids ancêtres + self) rend subtree/ancestors/scope O(1) en SQL
// pur (LIKE). `progress` (0..100) est STOCKÉ et recalculé en remontant la chaîne
// d'ancêtres à chaque mutation (recomputeAncestorProgress). `version` par nœud =
// pivot de concurrence (bumpé sur le nœud + ses ancêtres). Chaque nœud a son chat
// (node_messages) ; le chat d'un nœud N ne peut éditer QUE subtree(N).
// ═══════════════════════════════════════════════════════════════════════════

const NODE_STATUS_SET = new Set(NODE_STATUSES);
const NODE_COLOR_SET = new Set(NODE_COLORS);
const MSG_STATE_SET = new Set(MESSAGE_STATES);
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function clampStr(v, max) {
  return String(v ?? "").slice(0, max);
}
// Clamp d'emoji par GRAPHÈMES (pas unités UTF-16) → ne coupe jamais une séquence
// ZWJ (👨‍👩‍👧) en plein milieu. Max 2 graphèmes, repli "🎯".
function clampEmoji(v) {
  const s = String(v ?? "").trim();
  if (!s) return "🎯";
  try {
    const seg = new Intl.Segmenter(undefined, { granularity: "grapheme" });
    return [...seg.segment(s)].slice(0, 2).map((x) => x.segment).join("") || "🎯";
  } catch {
    return s.slice(0, 8) || "🎯";
  }
}
// Valide une date 'YYYY-MM-DD' ; "" / null → null (effacement) ; sinon throw.
function validDateOrNull(v) {
  if (v == null || v === "") return null;
  const s = String(v).trim();
  if (!DATE_RE.test(s)) throw new Error(`Date invalide (attendu YYYY-MM-DD) : ${s}`);
  return s;
}

// ── Sérialisation ────────────────────────────────────────────────────────────
function childCountOf(id) {
  return db.prepare("SELECT COUNT(*) c FROM nodes WHERE parent_id = ?").get(id).c;
}

function rowToNode(r, { childCount } = {}) {
  if (!r) return null;
  const pct = Math.max(0, Math.min(100, r.progress | 0));
  return {
    id: r.id,
    ref: r.ref,
    parentId: r.parent_id,
    rootId: r.root_id,
    depth: r.depth,
    title: r.title,
    description: r.description,
    notes: r.notes || "",
    status: r.status,
    color: r.color,
    emoji: r.emoji,
    targetDate: r.target_date,
    progress: pct,
    position: r.position,
    version: r.version,
    childCount: childCount != null ? childCount : childCountOf(r.id),
    createdAt: r.created_at,
    updatedAt: r.updated_at,
    doneAt: r.done_at,
  };
}

function rowToNodeMessage(r) {
  if (!r) return null;
  let actions = [];
  try {
    actions = JSON.parse(r.actions || "[]");
  } catch {
    actions = [];
  }
  return {
    id: r.id,
    nodeId: r.node_id,
    role: r.role,
    author: r.author,
    model: r.model,
    body: r.body,
    reasoning: r.reasoning,
    state: r.state,
    actions,
    clientNonce: r.client_nonce,
    createdAt: r.created_at,
  };
}

// ── Primitives subtree / ancestors (via `path`, zéro CTE) ────────────────────
function findNodeRow(refOrId) {
  if (refOrId == null) return null;
  if (typeof refOrId === "number" || /^\d+$/.test(String(refOrId)))
    return db.prepare("SELECT * FROM nodes WHERE id = ?").get(Number(refOrId));
  return db.prepare("SELECT * FROM nodes WHERE ref = ? COLLATE NOCASE").get(String(refOrId));
}

// ids ancêtres (sans le self), de la racine vers le parent direct.
function ancestorIds(row) {
  const ids = String(row.path || "").split("/").filter(Boolean).map(Number);
  return ids.slice(0, -1);
}

// Toutes les lignes du sous-arbre de `rootRow` (self inclus), triées.
function loadSubtreeRows(rootRow) {
  return db.prepare("SELECT * FROM nodes WHERE path LIKE ? ORDER BY depth, position, id").all(rootRow.path + "%");
}

function descendantCount(row) {
  return db.prepare("SELECT COUNT(*) c FROM nodes WHERE path LIKE ?").get(row.path + "%").c - 1;
}

// true si targetId ∈ subtree(rootId) (root inclus). false si l'un est introuvable.
// La barrière de scope du chat IA repose dessus : on compare les `path` matérialisés.
function isInSubtree(rootId, targetId) {
  const root = findNodeRow(rootId);
  const target = findNodeRow(targetId);
  if (!root || !target) return false;
  return target.path.startsWith(root.path);
}

// Construit l'imbrication children[] d'un sous-arbre (rootId exclu du retour, ses
// children peuplés). `rows` = loadSubtreeRows(root).
function buildTree(rows, rootId) {
  const byId = new Map();
  for (const r of rows) byId.set(r.id, { ...rowToNode(r, { childCount: 0 }), children: [] });
  let root = null;
  for (const r of rows) {
    const n = byId.get(r.id);
    if (r.id === rootId) {
      root = n;
      continue;
    }
    const parent = byId.get(r.parent_id);
    if (parent) parent.children.push(n);
  }
  for (const n of byId.values()) n.childCount = n.children.length;
  return root || { children: [] };
}

// ── Lecture ──────────────────────────────────────────────────────────────────
export function getNode(refOrId, { withMessages = false, withTree = false } = {}) {
  const row = findNodeRow(refOrId);
  if (!row) return null;
  const node = rowToNode(row);
  if (withTree) node.children = buildTree(loadSubtreeRows(row), row.id).children;
  if (withMessages) node.messages = listNodeMessages(row.id);
  return node;
}

// {node, descendants:[…plats]} — contrat du prompt IA (état du sous-arbre scopé).
export function getSubtree(refOrId, { maxNodes = MAX_NODES_PER_SUBTREE } = {}) {
  const row = findNodeRow(refOrId);
  if (!row) return null;
  const rows = loadSubtreeRows(row).slice(0, maxNodes);
  const counts = new Map();
  for (const r of rows) if (r.parent_id != null) counts.set(r.parent_id, (counts.get(r.parent_id) || 0) + 1);
  const toN = (r) => rowToNode(r, { childCount: counts.get(r.id) || 0 });
  return { node: toN(row), descendants: rows.filter((r) => r.id !== row.id).map(toN) };
}

export function listRootNodes(filter = {}) {
  const where = ["parent_id IS NULL"];
  const vals = [];
  if (filter.status) {
    where.push("status = ?");
    vals.push(filter.status);
  }
  if (filter.text) {
    where.push("(title LIKE ? OR description LIKE ? OR ref LIKE ?)");
    const l = `%${filter.text}%`;
    vals.push(l, l, l);
  }
  const rows = db.prepare("SELECT * FROM nodes WHERE " + where.join(" AND ") + " ORDER BY position, id").all(...vals);
  const limit = filter.limit ? Math.max(1, Math.min(500, filter.limit)) : 200;
  return rows.slice(0, limit).map((r) => rowToNode(r));
}

// Forêt entière à plat (graphe). childCount dérivé en un passage.
export function listForest() {
  const rows = db.prepare("SELECT * FROM nodes ORDER BY depth, position, id").all();
  const counts = new Map();
  for (const r of rows) if (r.parent_id != null) counts.set(r.parent_id, (counts.get(r.parent_id) || 0) + 1);
  return rows.map((r) => rowToNode(r, { childCount: counts.get(r.id) || 0 }));
}

export function listChildren(parentRefOrId) {
  const p = findNodeRow(parentRefOrId);
  if (!p) return [];
  return db.prepare("SELECT * FROM nodes WHERE parent_id = ? ORDER BY position, id").all(p.id).map((r) => rowToNode(r));
}

// Ids du chemin racine→self (ancêtres + self), dérivés du `path` matérialisé.
// Sert au temps réel (diffuser un changement à la chaîne d'ancêtres). [] si absent.
export function nodePathIds(refOrId) {
  const row = findNodeRow(refOrId);
  if (!row) return [];
  return String(row.path || "").split("/").filter(Boolean).map(Number);
}

// ── Rollup de progression + concurrence ──────────────────────────────────────
// Recompute la progression du nœud + de ses ancêtres (chaîne via path). Bump
// version+updated_at du nœud (si bumpSelf) et de chaque ancêtre dont la progression
// change. Renvoie les nœuds réellement mis à jour, re-SELECTés : [node, …, root].
function recomputeAncestorProgress(nodeId, { bumpSelf = true } = {}) {
  const start = findNodeRow(nodeId);
  if (!start) return [];
  const chain = [start.id, ...ancestorIds(start).reverse()]; // [node, parent, …, root]
  const out = [];
  const ts = nowIso();
  const selKids = db.prepare("SELECT status, progress FROM nodes WHERE parent_id = ?");
  const upd = db.prepare("UPDATE nodes SET progress = ?, version = version + 1, updated_at = ? WHERE id = ?");
  const sel = db.prepare("SELECT * FROM nodes WHERE id = ?");
  for (let i = 0; i < chain.length; i++) {
    const row = sel.get(chain[i]);
    if (!row) continue;
    const kids = selKids.all(row.id);
    let prog;
    if (kids.length) prog = Math.round(kids.reduce((a, k) => a + (k.status === "done" ? 100 : k.progress), 0) / kids.length);
    else prog = row.status === "done" ? 100 : 0;
    const isSelf = i === 0;
    if ((isSelf && bumpSelf) || prog !== row.progress) {
      upd.run(prog, ts, row.id);
      out.push(sel.get(row.id));
    } else if (isSelf) {
      out.push(row);
    }
  }
  return out;
}

// ── Helpers de mutation internes (SANS bump : l'appelant rollup ensuite) ─────
function _setNodeFields(id, fields = {}) {
  const row = db.prepare("SELECT status FROM nodes WHERE id = ?").get(id);
  if (!row) throw new Error(`Nœud introuvable : ${id}`);
  const sets = [];
  const vals = [];
  if (fields.title != null) {
    const t = String(fields.title).trim().slice(0, 200);
    if (t) {
      sets.push("title = ?");
      vals.push(t);
    }
  }
  if (fields.description != null) {
    sets.push("description = ?");
    vals.push(clampStr(fields.description, 4000));
  }
  if (fields.notes != null) {
    sets.push("notes = ?");
    vals.push(clampStr(fields.notes, MAX_NOTES));
  }
  if (fields.status != null) {
    if (!NODE_STATUS_SET.has(fields.status)) throw new Error(`Statut invalide : ${fields.status}`);
    sets.push("status = ?");
    vals.push(fields.status);
    if (fields.status === "done" && row.status !== "done") {
      sets.push("done_at = ?");
      vals.push(nowIso());
    } else if (fields.status !== "done") {
      sets.push("done_at = ?");
      vals.push(null);
    }
  }
  if (fields.color != null) {
    if (!NODE_COLOR_SET.has(fields.color)) throw new Error(`Couleur invalide : ${fields.color}`);
    sets.push("color = ?");
    vals.push(fields.color);
  }
  if (fields.emoji != null) {
    sets.push("emoji = ?");
    vals.push(clampEmoji(fields.emoji));
  }
  if ("targetDate" in fields || "dueDate" in fields) {
    sets.push("target_date = ?");
    vals.push(validDateOrNull("targetDate" in fields ? fields.targetDate : fields.dueDate));
  }
  if (!sets.length) return 0;
  db.prepare(`UPDATE nodes SET ${sets.join(", ")} WHERE id = ?`).run(...vals, id);
  return sets.length;
}

// Insère un enfant sous parentId (depth+1, root_id, path matérialisé). throw>MAX_DEPTH.
function _insertChild(parentId, input = {}) {
  const parent = db.prepare("SELECT * FROM nodes WHERE id = ?").get(parentId);
  if (!parent) throw new Error("Parent introuvable");
  if (parent.depth + 1 > MAX_DEPTH) throw new Error("Profondeur maximale atteinte");
  const title = String(input.title || "").trim().slice(0, 200);
  if (!title) throw new Error("Titre de nœud requis");
  const status = NODE_STATUS_SET.has(input.status) ? input.status : "active";
  const color = NODE_COLOR_SET.has(input.color) ? input.color : parent.color || "accent";
  const emoji = clampEmoji(input.emoji);
  const description = clampStr(input.description != null ? input.description : input.detail || "", 4000);
  const notes = clampStr(input.notes != null ? input.notes : "", MAX_NOTES);
  const targetDate = validDateOrNull(input.targetDate != null ? input.targetDate : input.dueDate);
  const ref = nextRef("node");
  const nextPos = db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id = ?").get(parentId).p;
  const position = Number.isFinite(input.position) ? input.position : nextPos;
  const res = db
    .prepare(
      `INSERT INTO nodes(ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position)
       VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
    )
    .run(ref, parentId, parent.root_id, parent.depth + 1, "", title, description, notes, status, color, emoji, targetDate, status === "done" ? 100 : 0, position);
  const newId = Number(res.lastInsertRowid);
  db.prepare("UPDATE nodes SET path = ?, done_at = ? WHERE id = ?").run(parent.path + newId + "/", status === "done" ? nowIso() : null, newId);
  return newId;
}

// Re-parente un nœud ET réécrit depth/root_id/path de tout son sous-arbre.
function _reparentSubtree(id, newParentId, position) {
  const row = db.prepare("SELECT * FROM nodes WHERE id = ?").get(id);
  if (!row) throw new Error("Nœud introuvable");
  const newParent = newParentId == null ? null : db.prepare("SELECT * FROM nodes WHERE id = ?").get(newParentId);
  if (newParentId != null && !newParent) throw new Error("Nouveau parent introuvable");
  const newDepth = newParent ? newParent.depth + 1 : 0;
  const newRoot = newParent ? newParent.root_id : id;
  const newPath = (newParent ? newParent.path : "/") + id + "/";
  const oldPath = row.path;
  const subMaxDepth = db.prepare("SELECT MAX(depth) m FROM nodes WHERE path LIKE ?").get(oldPath + "%").m || row.depth;
  const depthDelta = newDepth - row.depth;
  if (subMaxDepth + depthDelta > MAX_DEPTH) throw new Error("Profondeur maximale dépassée");
  const pos =
    position != null
      ? position
      : newParentId == null
      ? db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id IS NULL").get().p
      : db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id = ?").get(newParentId).p;
  db.prepare("UPDATE nodes SET parent_id = ?, position = ? WHERE id = ?").run(newParentId, pos, id);
  const rows = db.prepare("SELECT id, depth, path FROM nodes WHERE path LIKE ?").all(oldPath + "%");
  const upd = db.prepare("UPDATE nodes SET depth = ?, root_id = ?, path = ? WHERE id = ?");
  for (const r of rows) upd.run(r.depth + depthDelta, newRoot, newPath + r.path.slice(oldPath.length), r.id);
}

function _reorderChildrenRows(parentId, orderedIds) {
  const where = parentId == null ? "parent_id IS NULL" : "parent_id = ?";
  const wargs = parentId == null ? [] : [parentId];
  const existing = db.prepare(`SELECT id FROM nodes WHERE ${where} ORDER BY position, id`).all(...wargs).map((r) => r.id);
  const set = new Set(existing);
  const seen = new Set();
  let pos = 0;
  const upd = db.prepare("UPDATE nodes SET position = ? WHERE id = ?");
  for (const raw of orderedIds) {
    const n = Number(raw);
    if (set.has(n) && !seen.has(n)) {
      seen.add(n);
      upd.run(pos++, n);
    }
  }
  for (const id of existing) if (!seen.has(id)) upd.run(pos++, id);
}

// ── CRUD public (chaque mutation → rollup ascendant) ─────────────────────────
export function createNode(parentRefOrId, input = {}) {
  if (parentRefOrId != null) {
    const parent = findNodeRow(parentRefOrId);
    if (!parent) throw new Error(`Parent introuvable : ${parentRefOrId}`);
    let id;
    db.transaction(() => {
      id = _insertChild(parent.id, input);
      recomputeAncestorProgress(id, { bumpSelf: false });
    })();
    return getNode(id);
  }
  // Racine.
  const title = String(input.title || "").trim().slice(0, 200);
  if (!title) throw new Error("Titre requis");
  const status = NODE_STATUS_SET.has(input.status) ? input.status : "active";
  const color = NODE_COLOR_SET.has(input.color) ? input.color : "accent";
  const emoji = clampEmoji(input.emoji);
  const description = clampStr(input.description || "", 4000);
  const notes = clampStr(input.notes != null ? input.notes : "", MAX_NOTES);
  const targetDate = validDateOrNull(input.targetDate);
  const ref = nextRef("node");
  const id = db.transaction(() => {
    const nextPos = db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id IS NULL").get().p;
    const position = Number.isFinite(input.position) ? input.position : nextPos;
    const res = db
      .prepare(
        `INSERT INTO nodes(ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position)
         VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
      )
      .run(ref, null, 0, 0, "", title, description, notes, status, color, emoji, targetDate, status === "done" ? 100 : 0, position);
    const newId = Number(res.lastInsertRowid);
    db.prepare("UPDATE nodes SET root_id = ?, path = ?, done_at = ? WHERE id = ?").run(newId, "/" + newId + "/", status === "done" ? nowIso() : null, newId);
    return newId;
  })();
  return getNode(id);
}

export function updateNode(refOrId, fields = {}, expectedVersion) {
  const row = findNodeRow(refOrId);
  if (!row) throw new Error(`Nœud introuvable : ${refOrId}`);
  const tx = db.transaction(() => {
    if (expectedVersion != null && expectedVersion !== "") {
      const cur = db.prepare("SELECT version FROM nodes WHERE id = ?").get(row.id).version;
      if (cur !== Number(expectedVersion)) {
        const err = new Error("version_conflict");
        err.code = "version_conflict";
        err.node = getNode(row.id);
        throw err;
      }
    }
    const changed = _setNodeFields(row.id, fields);
    recomputeAncestorProgress(row.id, { bumpSelf: changed > 0 });
  });
  tx();
  return getNode(row.id);
}

export function deleteNode(refOrId) {
  const row = findNodeRow(refOrId);
  if (!row) return { deleted: false };
  const parentId = row.parent_id;
  db.transaction(() => {
    db.prepare("DELETE FROM nodes WHERE id = ?").run(row.id); // cascade sous-arbre + messages
    if (parentId != null) recomputeAncestorProgress(parentId, { bumpSelf: true });
  })();
  return { deleted: true, id: row.id, parentId, rootId: row.root_id };
}

export function moveNode(refOrId, newParentRefOrId, position) {
  const row = findNodeRow(refOrId);
  if (!row) throw new Error(`Nœud introuvable : ${refOrId}`);
  const newParent = newParentRefOrId == null ? null : findNodeRow(newParentRefOrId);
  if (newParentRefOrId != null && !newParent) throw new Error("Nouveau parent introuvable");
  if (newParent) {
    if (newParent.id === row.id) throw new Error("Un nœud ne peut pas être son propre parent");
    if (newParent.path.startsWith(row.path)) throw new Error("Cycle : le nouveau parent est dans le sous-arbre déplacé");
  }
  const oldParentId = row.parent_id;
  const newParentId = newParent ? newParent.id : null;
  db.transaction(() => {
    _reparentSubtree(row.id, newParentId, Number.isFinite(position) ? position : null);
    recomputeAncestorProgress(row.id, { bumpSelf: true });
    if (oldParentId != null && oldParentId !== newParentId) recomputeAncestorProgress(oldParentId, { bumpSelf: true });
  })();
  return getNode(row.id);
}

export function reorderChildren(parentRefOrId, orderedIds = []) {
  let pId = null;
  if (parentRefOrId != null) {
    const p = findNodeRow(parentRefOrId);
    if (!p) throw new Error(`Nœud introuvable : ${parentRefOrId}`);
    pId = p.id;
  }
  db.transaction(() => {
    _reorderChildrenRows(pId, orderedIds);
    if (pId != null) recomputeAncestorProgress(pId, { bumpSelf: true });
  })();
  return pId != null ? getNode(pId, { withTree: true }) : listRootNodes();
}

// ── Chat (par nœud) ──────────────────────────────────────────────────────────
export function listNodeMessages(nodeId, { afterId = 0, limit = 500 } = {}) {
  return db
    .prepare("SELECT * FROM node_messages WHERE node_id = ? AND id > ? ORDER BY id LIMIT ?")
    .all(nodeId, afterId, Math.max(1, Math.min(1000, limit)))
    .map(rowToNodeMessage);
}

export function getNodeMessage(messageId) {
  return rowToNodeMessage(db.prepare("SELECT * FROM node_messages WHERE id = ?").get(messageId));
}

export function addNodeMessage(nodeRefOrId, { role, author, model, body, reasoning, state, actions, clientNonce } = {}) {
  const node = findNodeRow(nodeRefOrId);
  if (!node) throw new Error(`Nœud introuvable : ${nodeRefOrId}`);
  const r = role === "assistant" ? "assistant" : "user";
  const st = MSG_STATE_SET.has(state) ? state : "complete";
  const nonce = clientNonce ? String(clientNonce).replace(/[^A-Za-z0-9_-]/g, "").slice(0, 80) || null : null;
  const res = db
    .prepare(
      "INSERT INTO node_messages(node_id, role, author, model, body, reasoning, state, actions, client_nonce) VALUES(?,?,?,?,?,?,?,?,?)"
    )
    .run(
      node.id,
      r,
      String(author || "anon").slice(0, 60) || "anon",
      model || null,
      clampStr(body || "", 16384),
      clampStr(reasoning || "", 65536),
      st,
      JSON.stringify(actions || []),
      nonce
    );
  return getNodeMessage(Number(res.lastInsertRowid));
}

export function updateNodeMessage(messageId, { body, reasoning, state, actions } = {}) {
  const sets = [];
  const vals = [];
  if (body != null) {
    sets.push("body = ?");
    vals.push(clampStr(body, 16384));
  }
  if (reasoning != null) {
    sets.push("reasoning = ?");
    vals.push(clampStr(reasoning, 65536));
  }
  if (state != null) {
    if (!MSG_STATE_SET.has(state)) throw new Error(`État de message invalide : ${state}`);
    sets.push("state = ?");
    vals.push(state);
  }
  if (actions != null) {
    sets.push("actions = ?");
    vals.push(JSON.stringify(actions));
  }
  if (sets.length) db.prepare(`UPDATE node_messages SET ${sets.join(", ")} WHERE id = ?`).run(...vals, messageId);
  return getNodeMessage(messageId);
}

// ── Application des actions IA (cœur sécurité — catalogue scopé subtree) ──────
// Toutes les actions sont scopées à subtree(scopeNodeId). scopeNodeId vient de la
// ROUTE, jamais du payload IA. Fail-soft : une action invalide → rejected, jamais
// de throw global. delete_node interdit sur le scope racine (descendant strict).
export function applyNodeActions(scopeNodeId, actions = []) {
  const scope = findNodeRow(scopeNodeId);
  if (!scope) throw new Error(`Nœud introuvable : ${scopeNodeId}`);
  const applied = [];
  const rejected = [];
  const list = Array.isArray(actions) ? actions.slice(0, MAX_ACTIONS) : [];
  const touched = new Set();
  const affected = new Set();
  const roots = new Set();

  const tx = db.transaction(() => {
    const tmpMap = new Map(); // tmpKey → id réel (créé dans ce tour)
    const resolve = (x) => {
      if (x == null) return null;
      const s = String(x);
      if (tmpMap.has(s)) return tmpMap.get(s);
      const n = Number(x);
      return Number.isFinite(n) ? n : null;
    };
    const inScope = (id) => id != null && isInSubtree(scope.id, id);
    for (const a of list) {
      const op = a && a.op;
      try {
        switch (op) {
          case "set_node_fields":
          case "update_node": {
            const id = op === "set_node_fields" && a.id == null ? scope.id : resolve(a.id);
            if (!inScope(id)) {
              rejected.push({ op, reason: "hors_scope" });
              break;
            }
            const n = _setNodeFields(id, a);
            if (n) {
              applied.push({ op, id });
              touched.add(id);
            } else rejected.push({ op, id, reason: "aucun_champ" });
            break;
          }
          case "add_node": {
            const pid = a.parentId == null ? scope.id : resolve(a.parentId);
            if (!inScope(pid)) {
              rejected.push({ op, reason: "parent_hors_scope" });
              break;
            }
            if (descendantCount(findNodeRow(scope.id)) >= MAX_NODES_PER_SUBTREE) {
              rejected.push({ op, reason: "quota_sous_arbre" });
              break;
            }
            const newId = _insertChild(pid, a);
            if (a.tmpKey != null) tmpMap.set(String(a.tmpKey), newId);
            applied.push({ op, id: newId, parentId: pid, title: String(a.title || "").slice(0, 200) });
            touched.add(newId);
            touched.add(pid);
            break;
          }
          case "delete_node": {
            const id = resolve(a.id);
            if (!inScope(id)) {
              rejected.push({ op, reason: "hors_scope" });
              break;
            }
            if (id === scope.id) {
              rejected.push({ op, reason: "auto_suppression_racine_interdite" });
              break;
            }
            const node = findNodeRow(id);
            const parentId = node ? node.parent_id : null;
            const ch = db.prepare("DELETE FROM nodes WHERE id = ?").run(id).changes;
            if (ch) {
              applied.push({ op, id });
              if (parentId != null) touched.add(parentId);
            } else rejected.push({ op, id, reason: "introuvable" });
            break;
          }
          case "move_node": {
            const id = resolve(a.id);
            const newParent = a.parentId == null ? scope.id : resolve(a.parentId);
            if (!inScope(id)) {
              rejected.push({ op, reason: "source_hors_scope" });
              break;
            }
            if (!inScope(newParent)) {
              rejected.push({ op, reason: "cible_hors_scope" });
              break;
            }
            if (id === newParent || isInSubtree(id, newParent)) {
              rejected.push({ op, reason: "cycle" });
              break;
            }
            const oldParent = findNodeRow(id)?.parent_id ?? null;
            _reparentSubtree(id, newParent, Number.isFinite(a.position) ? a.position : null);
            applied.push({ op, id, parentId: newParent });
            touched.add(id);
            if (oldParent != null) touched.add(oldParent);
            touched.add(newParent);
            break;
          }
          case "reorder_children": {
            const pid = a.parentId == null ? scope.id : resolve(a.parentId);
            if (!inScope(pid)) {
              rejected.push({ op, reason: "parent_hors_scope" });
              break;
            }
            const ids = (a.order || []).map(resolve).filter((x) => x != null && inScope(x));
            _reorderChildrenRows(pid, ids);
            applied.push({ op, parentId: pid });
            touched.add(pid);
            break;
          }
          default:
            rejected.push({ op: op || "?", reason: "op_inconnu" });
        }
      } catch (e) {
        rejected.push({ op: op || "?", reason: e.message || String(e) });
      }
    }
    // Rollup de chaque nœud touché (même transaction).
    for (const id of touched) {
      affected.add(id);
      for (const r of recomputeAncestorProgress(id, { bumpSelf: true })) {
        affected.add(r.id);
        roots.add(r.root_id);
      }
    }
  });
  tx();
  return { applied, rejected, affectedNodeIds: [...affected], roots: [...roots] };
}

export { db };

