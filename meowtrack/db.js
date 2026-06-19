// db.js — persistance SQLite du suivi (repos / issues / références / commentaires
// / nœuds Good Vibes).
//
// Source de vérité du schéma. Modèle calqué sur chatServer/database.js :
// better-sqlite3 synchrone, WAL, migrations additives idempotentes. La base
// `meowtrack.db` vit à côté de ce fichier et est gitignorée (locale par machine).
//
// MULTI-REPOS : un registre `repos` scope toutes les données. Chaque issue / nœud
// porte un `repo_id` ; les codes (BUG-1, NODE-2…) sont numérotés PAR REPO (unicité
// `(repo_id, ref)`, un compteur par (repo, préfixe)). L'orchestration git par repo
// (clone, branches, validation des chemins) vit dans repos.js.
//
// Le MCP (mcp.js) et le dashboard (server.js) ouvrent tous deux la même base —
// WAL autorise lectures concurrentes + un seul writer, ce qui suffit ici.

import Database from "better-sqlite3";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
// Wrappers git PAR repoId (repos.js). Import circulaire SÛR : utilisés uniquement
// dans le corps des fonctions, jamais à l'évaluation du module.
import { inspectPathFor, gitContextFor, branchContextFor, normalizePathFor } from "./repos.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.MEOWTRACK_DB || join(HERE, "meowtrack.db");

const db = new Database(DB_PATH);
db.pragma("journal_mode = WAL");
db.pragma("synchronous = NORMAL");
db.pragma("foreign_keys = ON");

// ── Schéma (CREATE IF NOT EXISTS = nouveau schéma multi-repos) ────────────────
// Sur une base VIERGE, ces tables naissent directement scopées par repo. Sur une
// base PRÉ-EXISTANTE (ancien schéma mono-repo), le CREATE est sauté puis la
// migration `migrateMultiRepo()` reconstruit issues/nodes/counters (cf. plus bas).
db.exec(`
  CREATE TABLE IF NOT EXISTS repos (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    slug          TEXT UNIQUE NOT NULL,                 -- identifiant court stable (ex: 'meownopoly')
    name          TEXT NOT NULL,                        -- libellé affiché
    url           TEXT,                                 -- URL git de clone (null = clone géré à la main / dev in-repo)
    local_path    TEXT,                                 -- override du chemin de clone (sinon .repos/<slug>/)
    default_branch TEXT,                                -- branche par défaut (autocomplete / contexte)
    is_default    INTEGER NOT NULL DEFAULT 0,           -- repo utilisé quand le paramètre repo est omis
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
  );

  CREATE TABLE IF NOT EXISTS issues (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_id     INTEGER NOT NULL,
    ref         TEXT NOT NULL,
    type        TEXT NOT NULL DEFAULT 'bug',
    title       TEXT NOT NULL,
    description TEXT DEFAULT '',
    status      TEXT NOT NULL DEFAULT 'open',
    priority    TEXT NOT NULL DEFAULT 'medium',
    tags        TEXT NOT NULL DEFAULT '[]',
    branch      TEXT,
    git_commit  TEXT,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    UNIQUE(repo_id, ref),
    FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
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
    repo_id INTEGER NOT NULL,
    prefix  TEXT NOT NULL,
    value   INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (repo_id, prefix),
    FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
  );

  -- ── Good Vibes v2 : arbre de NŒUDS récursif (objectifs = jalons = sous-jalons) ─
  -- v1 (goals/milestones) jamais déployée → on remplace sans migration.
  DROP TABLE IF EXISTS goal_messages;
  DROP TABLE IF EXISTS milestones;
  DROP TABLE IF EXISTS goals;

  CREATE TABLE IF NOT EXISTS nodes (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_id     INTEGER NOT NULL,                     -- repo de rattachement (un arbre ne traverse jamais 2 repos)
    ref         TEXT NOT NULL,                        -- NODE-1… via nextRef(repoId,'node'), unique PAR repo
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
    pos_x       REAL,                                 -- position manuelle graphe (drag & drop), NULL = auto
    pos_y       REAL,
    version     INTEGER NOT NULL DEFAULT 1,           -- pivot CAS, bumpé soi + ancêtres
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    done_at     TEXT,
    CHECK (parent_id IS NULL OR parent_id <> id),     -- anti auto-parent direct
    UNIQUE(repo_id, ref),
    FOREIGN KEY(parent_id) REFERENCES nodes(id) ON DELETE CASCADE,
    FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
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
function tableHasColumn(table, column) {
  return db.prepare(`PRAGMA table_info(${table})`).all().some((c) => c.name === column);
}
ensureColumn("nodes", "notes", "notes TEXT NOT NULL DEFAULT ''"); // notes markdown par nœud (JSON liste)
ensureColumn("nodes", "pos_x", "pos_x REAL"); // position manuelle graphe (drag & drop)
ensureColumn("nodes", "pos_y", "pos_y REAL");

// ── Migration mono-repo → multi-repos (idempotente, data-préservante) ─────────
// Slug dérivé d'une URL git : dernier segment sans .git, normalisé.
function deriveSlug(url) {
  if (!url) return null;
  const cleaned = String(url).trim().replace(/\.git$/i, "").replace(/[/]+$/, "");
  const seg = cleaned.split(/[/:]/).filter(Boolean).pop();
  if (!seg) return null;
  return seg.toLowerCase().replace(/[^a-z0-9._-]/g, "-") || null;
}
// Crée le repo par défaut (depuis l'env) si le registre est vide.
function bootstrapDefaultRepo() {
  if (db.prepare("SELECT COUNT(*) c FROM repos").get().c > 0) return;
  const url = (process.env.MEOWTRACK_REPO_URL || "").trim() || null;
  const localPath = (process.env.MEOWTRACK_REPO || "").trim() || null;
  const slug = deriveSlug(url) || "default";
  db.prepare(
    "INSERT INTO repos(slug, name, url, local_path, default_branch, is_default) VALUES(?,?,?,?,?,1)"
  ).run(slug, slug, url, localPath, null);
}
// Garantit que chaque compteur (repo, préfixe) est ≥ au plus grand suffixe des
// refs existants — évite toute collision de `nextRef` si la table counters était
// absente / en retard sur les issues/nodes déjà présents (robustesse migration).
function reconcileCounters(repoId) {
  const upsertMax = db.prepare(
    "INSERT INTO counters(repo_id, prefix, value) VALUES(?,?,?) ON CONFLICT(repo_id, prefix) DO UPDATE SET value = MAX(value, excluded.value)"
  );
  const bump = (rows) => {
    const max = {};
    for (const r of rows) {
      const mm = String(r.ref).match(/^([A-Z]+)-(\d+)$/);
      if (!mm) continue;
      const p = mm[1];
      const n = Number(mm[2]);
      if (!(p in max) || n > max[p]) max[p] = n;
    }
    for (const [p, n] of Object.entries(max)) upsertMax.run(repoId, p, n);
  };
  bump(db.prepare("SELECT ref FROM issues WHERE repo_id = ?").all(repoId));
  bump(db.prepare("SELECT ref FROM nodes WHERE repo_id = ?").all(repoId));
}
function migrateMultiRepo() {
  bootstrapDefaultRepo();
  const defaultId = db.prepare("SELECT id FROM repos WHERE is_default = 1").get()?.id
    || db.prepare("SELECT id FROM repos ORDER BY id LIMIT 1").get()?.id;
  if (defaultId == null) return; // aucun repo (ne devrait pas arriver)

  // Reconstruit une table de l'ancien schéma vers le nouveau (scopée repo_id).
  // foreign_keys doit être OFF pendant le DROP/RENAME (changement de pragma hors transaction).
  const needIssues = !tableHasColumn("issues", "repo_id");
  const needNodes = !tableHasColumn("nodes", "repo_id");
  const needCounters = !tableHasColumn("counters", "repo_id");
  if (!needIssues && !needNodes && !needCounters) return;

  db.pragma("foreign_keys = OFF");
  db.transaction(() => {
    if (needIssues) {
      db.exec(`
        CREATE TABLE issues_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT, repo_id INTEGER NOT NULL, ref TEXT NOT NULL,
          type TEXT NOT NULL DEFAULT 'bug', title TEXT NOT NULL, description TEXT DEFAULT '',
          status TEXT NOT NULL DEFAULT 'open', priority TEXT NOT NULL DEFAULT 'medium',
          tags TEXT NOT NULL DEFAULT '[]', branch TEXT, git_commit TEXT,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
          updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
          UNIQUE(repo_id, ref), FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
        );`);
      db.prepare(
        `INSERT INTO issues_new (id, repo_id, ref, type, title, description, status, priority, tags, branch, git_commit, created_at, updated_at)
         SELECT id, ?, ref, type, title, description, status, priority, tags, branch, git_commit,
                COALESCE(created_at, strftime('%Y-%m-%dT%H:%M:%SZ','now')), COALESCE(updated_at, strftime('%Y-%m-%dT%H:%M:%SZ','now')) FROM issues`
      ).run(defaultId);
      db.exec("DROP TABLE issues; ALTER TABLE issues_new RENAME TO issues;");
      db.exec("CREATE INDEX IF NOT EXISTS idx_issues_repo ON issues(repo_id);");
    }
    if (needNodes) {
      db.exec(`
        CREATE TABLE nodes_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT, repo_id INTEGER NOT NULL, ref TEXT NOT NULL,
          parent_id INTEGER, root_id INTEGER NOT NULL, depth INTEGER NOT NULL DEFAULT 0,
          path TEXT NOT NULL DEFAULT '', title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'active',
          color TEXT NOT NULL DEFAULT 'accent', emoji TEXT NOT NULL DEFAULT '🎯', target_date TEXT,
          progress INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL DEFAULT 0, pos_x REAL, pos_y REAL,
          version INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
          updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')), done_at TEXT,
          CHECK (parent_id IS NULL OR parent_id <> id), UNIQUE(repo_id, ref),
          FOREIGN KEY(parent_id) REFERENCES nodes(id) ON DELETE CASCADE,
          FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
        );`);
      db.prepare(
        `INSERT INTO nodes_new (id, repo_id, ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position, pos_x, pos_y, version, created_at, updated_at, done_at)
         SELECT id, ?, ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position, pos_x, pos_y, version,
                COALESCE(created_at, strftime('%Y-%m-%dT%H:%M:%SZ','now')), COALESCE(updated_at, strftime('%Y-%m-%dT%H:%M:%SZ','now')), done_at FROM nodes`
      ).run(defaultId);
      db.exec("DROP TABLE nodes; ALTER TABLE nodes_new RENAME TO nodes;");
      db.exec(`
        CREATE INDEX IF NOT EXISTS idx_nodes_repo   ON nodes(repo_id);
        CREATE INDEX IF NOT EXISTS idx_nodes_parent ON nodes(parent_id, position, id);
        CREATE INDEX IF NOT EXISTS idx_nodes_root   ON nodes(root_id);
        CREATE INDEX IF NOT EXISTS idx_nodes_path   ON nodes(path);
        CREATE INDEX IF NOT EXISTS idx_nodes_status ON nodes(status);`);
    }
    if (needCounters) {
      db.exec(`
        CREATE TABLE counters_new (
          repo_id INTEGER NOT NULL, prefix TEXT NOT NULL, value INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (repo_id, prefix), FOREIGN KEY(repo_id) REFERENCES repos(id) ON DELETE CASCADE
        );`);
      db.prepare("INSERT INTO counters_new (repo_id, prefix, value) SELECT ?, prefix, value FROM counters").run(defaultId);
      db.exec("DROP TABLE counters; ALTER TABLE counters_new RENAME TO counters;");
    }
  })();
  db.pragma("foreign_keys = ON");
  reconcileCounters(defaultId); // compteurs ≥ refs existants (anti-collision)
}
migrateMultiRepo();

// Index sur repo_id — créés APRÈS la migration (colonnes garanties présentes,
// que la base soit vierge ou reconstruite depuis l'ancien schéma).
db.exec(`
  CREATE INDEX IF NOT EXISTS idx_issues_repo ON issues(repo_id);
  CREATE INDEX IF NOT EXISTS idx_nodes_repo  ON nodes(repo_id);
`);

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
const MAX_NOTES = 50000; // taille max du corps markdown d'UNE note (~50 Ko)
const MAX_NOTE_COUNT = 50; // nombre max de notes par nœud

const PREFIX = { bug: "BUG", feature: "FEAT", task: "TASK", chore: "CHORE", node: "NODE" };

function nowIso() {
  return db.prepare("SELECT strftime('%Y-%m-%dT%H:%M:%SZ','now') AS t").get().t;
}

// Code lisible suivant `BUG-1`, `FEAT-2`… Un compteur monotone PAR (repo, préfixe)
// — pas de réutilisation après suppression. Chaque repo a sa propre série.
function nextRef(repoId, type) {
  const prefix = PREFIX[type] || "ISSUE";
  const tx = db.transaction(() => {
    db.prepare("INSERT INTO counters(repo_id, prefix, value) VALUES(?, ?, 0) ON CONFLICT(repo_id, prefix) DO NOTHING").run(repoId, prefix);
    db.prepare("UPDATE counters SET value = value + 1 WHERE repo_id = ? AND prefix = ?").run(repoId, prefix);
    return db.prepare("SELECT value FROM counters WHERE repo_id = ? AND prefix = ?").get(repoId, prefix).value;
  });
  return `${prefix}-${tx()}`;
}

// ═══════════════════════════════════════════════════════════════════════════
// Registre des repos (CRUD pur — aucune dépendance git ; cf. repos.js pour le clone).
// ═══════════════════════════════════════════════════════════════════════════
function rowToRepo(r) {
  if (!r) return null;
  return {
    id: r.id,
    slug: r.slug,
    name: r.name,
    url: r.url,
    localPath: r.local_path,
    defaultBranch: r.default_branch,
    isDefault: !!r.is_default,
    createdAt: r.created_at,
  };
}
// Ligne brute par id (numérique) ou slug (chaîne). Utilisé par repos.js.
export function getRepoRow(idOrSlug) {
  if (idOrSlug == null || idOrSlug === "") return null;
  if (typeof idOrSlug === "number" || /^\d+$/.test(String(idOrSlug)))
    return db.prepare("SELECT * FROM repos WHERE id = ?").get(Number(idOrSlug));
  return db.prepare("SELECT * FROM repos WHERE slug = ? COLLATE NOCASE").get(String(idOrSlug));
}
export function listRepoRows() {
  return db.prepare("SELECT * FROM repos ORDER BY is_default DESC, id").all();
}
export function listRepos() {
  return listRepoRows().map(rowToRepo);
}
export function getRepo(idOrSlug) {
  return rowToRepo(getRepoRow(idOrSlug));
}
function defaultRepoRow() {
  return db.prepare("SELECT * FROM repos WHERE is_default = 1").get() || db.prepare("SELECT * FROM repos ORDER BY id LIMIT 1").get();
}
// Résout le paramètre `repo` (id ou slug, ou vide) → id. Vide → repo par défaut.
// Lève si le repo demandé est inconnu (jamais de fallback silencieux sur défaut).
export function resolveRepoId(param) {
  if (param == null || param === "") {
    const d = defaultRepoRow();
    if (!d) throw new Error("Aucun repo configuré");
    return d.id;
  }
  const r = getRepoRow(param);
  if (!r) throw new Error(`Repo inconnu : ${param}`);
  return r.id;
}
function sanitizeSlug(slug) {
  return String(slug || "").trim().toLowerCase().replace(/[^a-z0-9._-]/g, "-").replace(/^-+|-+$/g, "");
}
export function createRepo({ slug, name, url, localPath, defaultBranch, isDefault } = {}) {
  let s = sanitizeSlug(slug) || deriveSlug(url);
  if (!s) throw new Error("slug requis (ou URL permettant de le dériver)");
  if (getRepoRow(s)) throw new Error(`slug déjà utilisé : ${s}`);
  const tx = db.transaction(() => {
    if (isDefault) db.prepare("UPDATE repos SET is_default = 0").run();
    const res = db
      .prepare("INSERT INTO repos(slug, name, url, local_path, default_branch, is_default) VALUES(?,?,?,?,?,?)")
      .run(s, String(name || s), url || null, localPath || null, defaultBranch || null, isDefault ? 1 : 0);
    // Premier repo du registre → forcément défaut.
    if (db.prepare("SELECT COUNT(*) c FROM repos WHERE is_default = 1").get().c === 0)
      db.prepare("UPDATE repos SET is_default = 1 WHERE id = ?").run(res.lastInsertRowid);
    return Number(res.lastInsertRowid);
  });
  return getRepo(tx());
}
export function updateRepo(idOrSlug, fields = {}) {
  const row = getRepoRow(idOrSlug);
  if (!row) throw new Error(`Repo introuvable : ${idOrSlug}`);
  const sets = [];
  const vals = [];
  if (fields.name != null) { sets.push("name = ?"); vals.push(String(fields.name)); }
  if ("url" in fields) { sets.push("url = ?"); vals.push(fields.url || null); }
  if ("localPath" in fields) { sets.push("local_path = ?"); vals.push(fields.localPath || null); }
  if ("defaultBranch" in fields) { sets.push("default_branch = ?"); vals.push(fields.defaultBranch || null); }
  const tx = db.transaction(() => {
    if (sets.length) db.prepare(`UPDATE repos SET ${sets.join(", ")} WHERE id = ?`).run(...vals, row.id);
    if (fields.isDefault === true) {
      db.prepare("UPDATE repos SET is_default = 0").run();
      db.prepare("UPDATE repos SET is_default = 1 WHERE id = ?").run(row.id);
    }
  });
  tx();
  return getRepo(row.id);
}
export function deleteRepo(idOrSlug) {
  const row = getRepoRow(idOrSlug);
  if (!row) return { deleted: false };
  if (db.prepare("SELECT COUNT(*) c FROM repos").get().c <= 1) throw new Error("Impossible de supprimer le dernier repo");
  const wasDefault = row.is_default;
  // Cascade : issues/nodes/counters du repo supprimés via FK ON DELETE CASCADE.
  db.prepare("DELETE FROM repos WHERE id = ?").run(row.id);
  if (wasDefault) {
    const n = db.prepare("SELECT id FROM repos ORDER BY id LIMIT 1").get();
    if (n) db.prepare("UPDATE repos SET is_default = 1 WHERE id = ?").run(n.id);
  }
  return { deleted: true, id: row.id, slug: row.slug };
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
    repoId: row.repo_id,
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
  // Repo + branche de l'issue : la validation des chemins se fait dans CE repo,
  // dans l'arbre de la branche de l'issue (pas le working tree courant).
  const issueRow = db.prepare("SELECT repo_id, branch FROM issues WHERE id = ?").get(issueId);
  if (!issueRow) throw new Error(`Issue introuvable : ${issueId}`);
  const { repo_id: repoId, branch } = issueRow;
  const { path, lineStart, lineEnd } = parseRefSpec(spec);
  const norm = normalizePathFor(repoId, path);
  if (!norm) throw new Error(`Chemin invalide ou hors repo : ${path}`);
  const info = inspectPathFor(repoId, norm, branch);
  const info2 = db
    .prepare("INSERT INTO refs(issue_id, path, kind, line_start, line_end, existed) VALUES(?,?,?,?,?,?)")
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
// Validées dans `repoId`, dans l'arbre de `branch`.
function setReferences(issueId, repoId, specs, branch = null) {
  db.prepare("DELETE FROM refs WHERE issue_id = ?").run(issueId);
  const seen = new Set();
  for (const spec of specs || []) {
    const { path, lineStart, lineEnd } = parseRefSpec(spec);
    const norm = normalizePathFor(repoId, path);
    if (!norm) continue;
    const key = `${norm}:${lineStart ?? ""}:${lineEnd ?? ""}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const info = inspectPathFor(repoId, norm, branch);
    db.prepare(
      "INSERT INTO refs(issue_id, path, kind, line_start, line_end, existed) VALUES(?,?,?,?,?,?)"
    ).run(issueId, norm, info.kind, lineStart, lineEnd, info.exists ? 1 : 0);
  }
}

// ── Commentaires ─────────────────────────────────────────────────────────────
export function listComments(issueId) {
  return db.prepare("SELECT id, body, created_at AS createdAt FROM comments WHERE issue_id = ? ORDER BY id").all(issueId);
}

export function addComment(repoId, refOrId, body) {
  const issue = findRow(repoId, refOrId);
  if (!issue) throw new Error(`Issue introuvable : ${refOrId}`);
  if (!body || !String(body).trim()) throw new Error("Commentaire vide");
  db.prepare("INSERT INTO comments(issue_id, body) VALUES(?, ?)").run(issue.id, String(body).trim());
  touchIssue(issue.id);
  return getIssueById(issue.id);
}

// ── Issues ───────────────────────────────────────────────────────────────────
// Résout une issue par id numérique (repo ignoré, id global) ou par code (exige
// repoId — les codes sont uniques PAR repo). `repoId` peut être null pour un id.
function findRow(repoId, refOrId) {
  if (refOrId == null) return null;
  if (typeof refOrId === "number" || /^\d+$/.test(String(refOrId))) {
    return db.prepare("SELECT * FROM issues WHERE id = ?").get(Number(refOrId));
  }
  if (repoId == null) throw new Error("repo requis pour résoudre un code d'issue");
  return db.prepare("SELECT * FROM issues WHERE repo_id = ? AND ref = ? COLLATE NOCASE").get(repoId, String(refOrId));
}
function getIssueById(id) {
  return rowToIssue(db.prepare("SELECT * FROM issues WHERE id = ?").get(id), { withDetail: true });
}

function touchIssue(id) {
  db.prepare("UPDATE issues SET updated_at = ? WHERE id = ?").run(nowIso(), id);
}

export function getIssue(repoId, refOrId) {
  return rowToIssue(findRow(repoId, refOrId), { withDetail: true });
}

export function createIssue(repoId, input = {}) {
  if (repoId == null) throw new Error("repoId requis");
  const type = TYPES.includes(input.type) ? input.type : "bug";
  const title = String(input.title || "").trim();
  if (!title) throw new Error("Titre requis");
  const status = STATUSES.includes(input.status) ? input.status : "open";
  const priority = PRIORITIES.includes(input.priority) ? input.priority : "medium";
  const description = String(input.description || "");
  const tags = JSON.stringify(sanitizeTags(input.tags));
  // Branche choisie explicitement (tracking + validation des chemins) sinon HEAD du repo.
  const ctx = input.branch ? branchContextFor(repoId, String(input.branch)) : gitContextFor(repoId);

  const specs = [...(input.paths || input.references || [])];
  if (input.autoMention !== false) specs.push(...extractMentions(description));

  const ref = nextRef(repoId, type);
  const tx = db.transaction(() => {
    const res = db
      .prepare(
        `INSERT INTO issues(repo_id, ref, type, title, description, status, priority, tags, branch, git_commit)
         VALUES(?,?,?,?,?,?,?,?,?,?)`
      )
      .run(repoId, ref, type, title, description, status, priority, tags, ctx.branch, ctx.commit);
    const id = res.lastInsertRowid;
    setReferences(id, repoId, specs, ctx.branch);
    return id;
  });
  return getIssueById(tx());
}

export function updateIssue(repoId, refOrId, fields = {}) {
  const row = findRow(repoId, refOrId);
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
    const ctx = branchContextFor(row.repo_id, String(fields.branch) || null);
    newBranch = ctx.branch;
    set("branch", ctx.branch);
    set("git_commit", ctx.commit);
  }

  const tx = db.transaction(() => {
    if (sets.length) {
      set("updated_at", nowIso());
      db.prepare(`UPDATE issues SET ${sets.join(", ")} WHERE id = ?`).run(...vals, row.id);
    }
    if (fields.paths != null || fields.references != null) {
      setReferences(row.id, row.repo_id, fields.paths || fields.references || [], newBranch);
      touchIssue(row.id);
    }
  });
  tx();
  return getIssueById(row.id);
}

export function deleteIssue(repoId, refOrId) {
  const row = findRow(repoId, refOrId);
  if (!row) return false;
  db.prepare("DELETE FROM issues WHERE id = ?").run(row.id); // cascade refs + comments
  return true;
}

export function listIssues(repoId, filter = {}) {
  if (repoId == null) throw new Error("repoId requis");
  const where = ["repo_id = ?"];
  const vals = [repoId];
  if (filter.type) {
    where.push("type = ?");
    vals.push(filter.type);
  }
  if (filter.status) {
    where.push("status = ?");
    vals.push(filter.status);
  } else if (filter.open !== undefined ? filter.open : filter.includeClosed !== true) {
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
    "SELECT * FROM issues WHERE " +
    where.join(" AND ") +
    " ORDER BY " +
    "CASE status WHEN 'in_progress' THEN 0 WHEN 'open' THEN 1 WHEN 'wontfix' THEN 2 WHEN 'done' THEN 3 END, " +
    "CASE priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 WHEN 'low' THEN 3 END, " +
    "updated_at DESC";
  const rows = db.prepare(sql).all(...vals);
  const limit = filter.limit ? Math.max(1, Math.min(500, filter.limit)) : 200;
  return rows.slice(0, limit).map((r) => rowToIssue(r));
}

// Statistiques pour le dashboard / tool de résumé, scopées par repo.
export function stats(repoId) {
  if (repoId == null) throw new Error("repoId requis");
  const byStatus = {};
  for (const r of db.prepare("SELECT status, COUNT(*) c FROM issues WHERE repo_id = ? GROUP BY status").all(repoId)) byStatus[r.status] = r.c;
  const byType = {};
  for (const r of db.prepare("SELECT type, COUNT(*) c FROM issues WHERE repo_id = ? GROUP BY type").all(repoId)) byType[r.type] = r.c;
  const byPriority = {};
  for (const r of db.prepare("SELECT priority, COUNT(*) c FROM issues WHERE repo_id = ? GROUP BY priority").all(repoId))
    byPriority[r.priority] = r.c;
  const total = db.prepare("SELECT COUNT(*) c FROM issues WHERE repo_id = ?").get(repoId).c;
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
//
// MULTI-REPOS : chaque nœud porte `repo_id` (un arbre ne traverse jamais 2 repos —
// move inter-repo refusé). Les listes (forêt / racines) sont scopées par repo.
// Les ids étant globaux (PK), les lectures par id n'exigent pas de repo ; seules
// les résolutions par CODE (NODE-1) exigent un repoId (codes uniques par repo).
// ═══════════════════════════════════════════════════════════════════════════

const NODE_STATUS_SET = new Set(NODE_STATUSES);
const NODE_COLOR_SET = new Set(NODE_COLORS);
const MSG_STATE_SET = new Set(MESSAGE_STATES);
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

function clampStr(v, max) {
  return String(v ?? "").slice(0, max);
}
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
function parseNotes(raw) {
  const s = String(raw || "");
  if (!s.trim()) return [];
  try {
    const a = JSON.parse(s);
    if (Array.isArray(a)) {
      return a
        .map((n) => ({ title: clampStr(n && n.title, 200), body: clampStr(n && n.body, MAX_NOTES) }))
        .filter((n) => n.title || n.body)
        .slice(0, MAX_NOTE_COUNT);
    }
  } catch {
    /* pas du JSON → legacy string */
  }
  return [{ title: "", body: clampStr(s, MAX_NOTES) }];
}
function normalizeNotesInput(input) {
  let arr;
  if (Array.isArray(input)) arr = input;
  else if (typeof input === "string") arr = input.trim() ? [{ title: "", body: input }] : [];
  else if (input && typeof input === "object") arr = [input];
  else arr = [];
  arr = arr
    .map((n) => ({ title: clampStr(n && n.title, 200), body: clampStr(n && n.body, MAX_NOTES) }))
    .filter((n) => n.title || n.body)
    .slice(0, MAX_NOTE_COUNT);
  return JSON.stringify(arr);
}

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
    repoId: r.repo_id,
    ref: r.ref,
    parentId: r.parent_id,
    rootId: r.root_id,
    depth: r.depth,
    title: r.title,
    description: r.description,
    notes: parseNotes(r.notes),
    status: r.status,
    color: r.color,
    emoji: r.emoji,
    targetDate: r.target_date,
    progress: pct,
    position: r.position,
    posX: r.pos_x != null ? r.pos_x : null,
    posY: r.pos_y != null ? r.pos_y : null,
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
// Résout par id numérique (repo ignoré) ou par code (exige repoId).
function findNodeRow(refOrId, repoId = null) {
  if (refOrId == null) return null;
  if (typeof refOrId === "number" || /^\d+$/.test(String(refOrId)))
    return db.prepare("SELECT * FROM nodes WHERE id = ?").get(Number(refOrId));
  if (repoId == null) throw new Error("repo requis pour résoudre un code de nœud");
  return db.prepare("SELECT * FROM nodes WHERE repo_id = ? AND ref = ? COLLATE NOCASE").get(repoId, String(refOrId));
}

function ancestorIds(row) {
  const ids = String(row.path || "").split("/").filter(Boolean).map(Number);
  return ids.slice(0, -1);
}

function loadSubtreeRows(rootRow) {
  return db.prepare("SELECT * FROM nodes WHERE path LIKE ? ORDER BY depth, position, id").all(rootRow.path + "%");
}

function descendantCount(row) {
  return db.prepare("SELECT COUNT(*) c FROM nodes WHERE path LIKE ?").get(row.path + "%").c - 1;
}

function isInSubtree(rootId, targetId) {
  const root = findNodeRow(rootId);
  const target = findNodeRow(targetId);
  if (!root || !target) return false;
  return target.path.startsWith(root.path);
}

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
export function getNode(refOrId, { withMessages = false, withTree = false, repoId = null } = {}) {
  const row = findNodeRow(refOrId, repoId);
  if (!row) return null;
  const node = rowToNode(row);
  if (withTree) node.children = buildTree(loadSubtreeRows(row), row.id).children;
  if (withMessages) node.messages = listNodeMessages(row.id);
  return node;
}

export function getSubtree(refOrId, { maxNodes = MAX_NODES_PER_SUBTREE, repoId = null } = {}) {
  const row = findNodeRow(refOrId, repoId);
  if (!row) return null;
  const rows = loadSubtreeRows(row).slice(0, maxNodes);
  const counts = new Map();
  for (const r of rows) if (r.parent_id != null) counts.set(r.parent_id, (counts.get(r.parent_id) || 0) + 1);
  const toN = (r) => rowToNode(r, { childCount: counts.get(r.id) || 0 });
  return { node: toN(row), descendants: rows.filter((r) => r.id !== row.id).map(toN) };
}

export function listRootNodes(repoId, filter = {}) {
  if (repoId == null) throw new Error("repoId requis");
  const where = ["parent_id IS NULL", "repo_id = ?"];
  const vals = [repoId];
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

// Forêt entière d'un repo à plat (graphe). childCount dérivé en un passage.
export function listForest(repoId) {
  if (repoId == null) throw new Error("repoId requis");
  const rows = db.prepare("SELECT * FROM nodes WHERE repo_id = ? ORDER BY depth, position, id").all(repoId);
  const counts = new Map();
  for (const r of rows) if (r.parent_id != null) counts.set(r.parent_id, (counts.get(r.parent_id) || 0) + 1);
  return rows.map((r) => rowToNode(r, { childCount: counts.get(r.id) || 0 }));
}

export function listChildren(parentRefOrId, repoId = null) {
  const p = findNodeRow(parentRefOrId, repoId);
  if (!p) return [];
  return db.prepare("SELECT * FROM nodes WHERE parent_id = ? ORDER BY position, id").all(p.id).map((r) => rowToNode(r));
}

export function nodePathIds(refOrId) {
  const row = findNodeRow(refOrId);
  if (!row) return [];
  return String(row.path || "").split("/").filter(Boolean).map(Number);
}

// ── Rollup de progression + concurrence ──────────────────────────────────────
function recomputeAncestorProgress(nodeId, { bumpSelf = true } = {}) {
  const start = findNodeRow(nodeId);
  if (!start) return [];
  const chain = [start.id, ...ancestorIds(start).reverse()];
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
    vals.push(normalizeNotesInput(fields.notes));
  }
  if ("posX" in fields) {
    sets.push("pos_x = ?");
    vals.push(fields.posX == null ? null : Number(fields.posX));
  }
  if ("posY" in fields) {
    sets.push("pos_y = ?");
    vals.push(fields.posY == null ? null : Number(fields.posY));
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

// Insère un enfant sous parentId (depth+1, root_id, path, repo_id hérités). throw>MAX_DEPTH.
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
  const notes = normalizeNotesInput(input.notes != null ? input.notes : "");
  const targetDate = validDateOrNull(input.targetDate != null ? input.targetDate : input.dueDate);
  const ref = nextRef(parent.repo_id, "node");
  const nextPos = db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id = ?").get(parentId).p;
  const position = Number.isFinite(input.position) ? input.position : nextPos;
  const res = db
    .prepare(
      `INSERT INTO nodes(repo_id, ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position)
       VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
    )
    .run(parent.repo_id, ref, parentId, parent.root_id, parent.depth + 1, "", title, description, notes, status, color, emoji, targetDate, status === "done" ? 100 : 0, position);
  const newId = Number(res.lastInsertRowid);
  db.prepare("UPDATE nodes SET path = ?, done_at = ? WHERE id = ?").run(parent.path + newId + "/", status === "done" ? nowIso() : null, newId);
  return newId;
}

function _reparentSubtree(id, newParentId, position) {
  const row = db.prepare("SELECT * FROM nodes WHERE id = ?").get(id);
  if (!row) throw new Error("Nœud introuvable");
  const newParent = newParentId == null ? null : db.prepare("SELECT * FROM nodes WHERE id = ?").get(newParentId);
  if (newParentId != null && !newParent) throw new Error("Nouveau parent introuvable");
  // Un arbre ne traverse jamais 2 repos.
  if (newParent && newParent.repo_id !== row.repo_id) throw new Error("Reparentage inter-repos interdit");
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
      ? db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id IS NULL AND repo_id = ?").get(row.repo_id).p
      : db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id = ?").get(newParentId).p;
  db.prepare("UPDATE nodes SET parent_id = ?, position = ? WHERE id = ?").run(newParentId, pos, id);
  const rows = db.prepare("SELECT id, depth, path FROM nodes WHERE path LIKE ?").all(oldPath + "%");
  const upd = db.prepare("UPDATE nodes SET depth = ?, root_id = ?, path = ? WHERE id = ?");
  for (const r of rows) upd.run(r.depth + depthDelta, newRoot, newPath + r.path.slice(oldPath.length), r.id);
}

function _reorderChildrenRows(parentId, orderedIds, repoId = null) {
  let where, wargs;
  if (parentId == null) {
    where = "parent_id IS NULL AND repo_id = ?";
    wargs = [repoId];
  } else {
    where = "parent_id = ?";
    wargs = [parentId];
  }
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
export function createNode(repoId, parentRefOrId, input = {}) {
  if (parentRefOrId != null) {
    // L'enfant hérite du repo de son parent (repoId ignoré si incohérent).
    const parent = findNodeRow(parentRefOrId, repoId);
    if (!parent) throw new Error(`Parent introuvable : ${parentRefOrId}`);
    let id;
    db.transaction(() => {
      id = _insertChild(parent.id, input);
      recomputeAncestorProgress(id, { bumpSelf: false });
    })();
    return getNode(id);
  }
  // Racine.
  if (repoId == null) throw new Error("repoId requis pour un nœud racine");
  const title = String(input.title || "").trim().slice(0, 200);
  if (!title) throw new Error("Titre requis");
  const status = NODE_STATUS_SET.has(input.status) ? input.status : "active";
  const color = NODE_COLOR_SET.has(input.color) ? input.color : "accent";
  const emoji = clampEmoji(input.emoji);
  const description = clampStr(input.description || "", 4000);
  const notes = normalizeNotesInput(input.notes != null ? input.notes : "");
  const targetDate = validDateOrNull(input.targetDate);
  const ref = nextRef(repoId, "node");
  const id = db.transaction(() => {
    const nextPos = db.prepare("SELECT COALESCE(MAX(position), -1) + 1 AS p FROM nodes WHERE parent_id IS NULL AND repo_id = ?").get(repoId).p;
    const position = Number.isFinite(input.position) ? input.position : nextPos;
    const res = db
      .prepare(
        `INSERT INTO nodes(repo_id, ref, parent_id, root_id, depth, path, title, description, notes, status, color, emoji, target_date, progress, position)
         VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
      )
      .run(repoId, ref, null, 0, 0, "", title, description, notes, status, color, emoji, targetDate, status === "done" ? 100 : 0, position);
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
    if (newParent.repo_id !== row.repo_id) throw new Error("Déplacement inter-repos interdit");
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

export function reorderChildren(parentRefOrId, orderedIds = [], repoId = null) {
  let pId = null;
  let rId = repoId;
  if (parentRefOrId != null) {
    const p = findNodeRow(parentRefOrId, repoId);
    if (!p) throw new Error(`Nœud introuvable : ${parentRefOrId}`);
    pId = p.id;
    rId = p.repo_id;
  }
  if (pId == null && rId == null) throw new Error("repoId requis pour réordonner des racines");
  db.transaction(() => {
    _reorderChildrenRows(pId, orderedIds, rId);
    if (pId != null) recomputeAncestorProgress(pId, { bumpSelf: true });
  })();
  return pId != null ? getNode(pId, { withTree: true }) : listRootNodes(rId);
}

export function setNodePositions(positions = []) {
  const upd = db.prepare("UPDATE nodes SET pos_x = ?, pos_y = ? WHERE id = ?");
  db.transaction(() => {
    for (const p of positions || []) {
      const row = findNodeRow(p && p.id);
      if (row) upd.run(p.x == null ? null : Number(p.x), p.y == null ? null : Number(p.y), row.id);
    }
  })();
  return (positions || []).length;
}

// ── Chat (par nœud) ──────────────────────────────────────────────────────────
export function clearNodeMessages(nodeRefOrId) {
  const node = findNodeRow(nodeRefOrId);
  if (!node) throw new Error(`Nœud introuvable : ${nodeRefOrId}`);
  return db.prepare("DELETE FROM node_messages WHERE node_id = ?").run(node.id).changes;
}

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
    const tmpMap = new Map();
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
