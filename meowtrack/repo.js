// repo.js — accès au dépôt git cloné qui contient le dossier meowtrack/.
//
// Le service tourne dans `<repo>/meowtrack/`. On résout la racine du repo via
// `git rev-parse --show-toplevel` (au runtime, donc valable dans n'importe quel
// checkout/worktree où le dossier est copié). Sert deux besoins :
//   1. l'autocomplete des chemins (feature « @ » du dashboard + tool MCP),
//   2. la validation qu'un chemin référencé existe réellement, et le contexte
//      git (branche + commit court) capturé au moment où une référence est créée.
//
// Aucune écriture dans le repo : lecture seule (git ls-files / rev-parse + fs).

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));

// URL git du repo à cloner / mettre à jour. Si définie, le service clone le repo
// au démarrage (dans MEOWTRACK_REPO, ou un dossier dédié à défaut) puis fait un
// pull, et un bouton du dashboard permet de re-puller à la demande. Vide = mode
// « clone déjà présent » (dev in-repo ou MEOWTRACK_REPO pointant un checkout géré
// à la main).
const REPO_URL = (process.env.MEOWTRACK_REPO_URL || "").trim();
export function repoUrl() {
  return REPO_URL || null;
}

// Exécute git dans la racine du repo et retourne stdout trimé (ou null si échec).
function git(args, cwd) {
  try {
    return execFileSync("git", args, {
      cwd: cwd ?? HERE,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      maxBuffer: 64 * 1024 * 1024,
    }).trim();
  } catch {
    return null;
  }
}

// Racine du repo (mémoïsée). Ordre de résolution :
//   1. MEOWTRACK_REPO (chemin explicite du clone — indispensable en déploiement,
//      où meowtrack/ est copié seul, sans le reste du repo) ;
//   2. si MEOWTRACK_REPO_URL est défini sans chemin explicite : un dossier de
//      clone dédié `.repo-clone/` à côté du service ;
//   3. `git rev-parse --show-toplevel` depuis ce dossier (cas dev in-repo) ;
//   4. fallback : dossier parent de meowtrack/.
let _root = null;
export function repoRoot() {
  if (_root) return _root;
  const override = process.env.MEOWTRACK_REPO;
  if (override && override.trim()) {
    _root = resolve(override.trim());
    return _root;
  }
  if (REPO_URL) {
    _root = resolve(HERE, ".repo-clone");
    return _root;
  }
  const top = git(["rev-parse", "--show-toplevel"]);
  _root = top ? resolve(top) : resolve(HERE, "..");
  return _root;
}

// ── Clone / mise à jour du repo ──────────────────────────────────────────────
// Variante de git() qui capture stderr et renvoie {ok, output} (les commandes
// d'écriture clone/pull doivent remonter leurs erreurs, contrairement au git()
// lecture-seule qui swallow tout).
function gitRun(args, cwd) {
  try {
    const out = execFileSync("git", args, {
      cwd: cwd ?? HERE,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      maxBuffer: 64 * 1024 * 1024,
    });
    return { ok: true, output: String(out).trim() };
  } catch (e) {
    const msg = String(e.stderr || e.stdout || e.message || e).trim();
    return { ok: false, output: msg };
  }
}

function isGitClone(dir) {
  return existsSync(join(dir, ".git"));
}

// Pull (fetch + merge ff-only) le clone existant et rafraîchit le cache des
// chemins. Suppose que repoRoot() est déjà un clone git.
export function pullRepo() {
  const root = repoRoot();
  if (!isGitClone(root)) {
    return { ok: false, output: `Pas un clone git : ${root}` };
  }
  const fetch = gitRun(["fetch", "--all", "--prune"], root);
  const pull = gitRun(["pull", "--ff-only"], root);
  refreshPaths(); // l'index git ls-files peut avoir changé.
  const ctx = gitContext();
  return {
    ok: fetch.ok && pull.ok,
    pulled: pull.ok,
    branch: ctx.branch,
    commit: ctx.commit,
    output: [fetch.output, pull.output].filter(Boolean).join("\n"),
  };
}

// Garantit qu'un clone à jour est disponible : clone si absent, sinon pull.
// No-op (skipped) si aucune MEOWTRACK_REPO_URL n'est configurée. Appelé au
// démarrage du serveur et par l'endpoint « Mettre à jour » du dashboard.
export function ensureRepo() {
  if (!REPO_URL) return { ok: true, skipped: true, reason: "no_url" };
  const root = repoRoot();
  if (isGitClone(root)) return pullRepo();
  // Cloner : le dossier parent doit exister.
  try {
    mkdirSync(dirname(root), { recursive: true });
  } catch {
    /* ignore — clone remontera l'erreur si le parent est inaccessible */
  }
  const r = gitRun(["clone", REPO_URL, root]);
  if (r.ok) refreshPaths(); // (re)construit l'index des chemins
  const ctx = gitContext();
  return { ok: r.ok, cloned: r.ok, branch: ctx.branch, commit: ctx.commit, output: r.output };
}

// Normalise un chemin saisi par l'utilisateur en chemin relatif repo, à slashes
// avant. Retourne null si le chemin sort de la racine (anti path-traversal).
export function normalizePath(p) {
  if (!p || typeof p !== "string") return null;
  const cleaned = p.trim().replace(/\\/g, "/").replace(/^\.\//, "").replace(/^\/+/, "");
  if (!cleaned) return null;
  const root = repoRoot();
  const abs = resolve(root, cleaned);
  // Doit rester sous la racine.
  const rootWithSep = root.endsWith(sep) ? root : root + sep;
  if (abs !== root && !abs.startsWith(rootWithSep)) return null;
  return cleaned.replace(/\/+$/, "");
}

// Existence + nature (file/dir) d'un chemin relatif repo. Si `branch` est fourni,
// la vérification se fait dans l'arbre de cette branche (via l'index ls-tree),
// pas dans le working tree.
export function inspectPath(relPath, branch = null) {
  const rel = normalizePath(relPath);
  if (!rel) return { path: relPath, exists: false, kind: null };
  if (branch) {
    const idx = getIndex(branch);
    if (idx.fileSet.has(rel)) return { path: rel, exists: true, kind: "file" };
    if (idx.dirSet.has(rel)) return { path: rel, exists: true, kind: "dir" };
    return { path: rel, exists: false, kind: null };
  }
  const abs = join(repoRoot(), rel);
  if (!existsSync(abs)) return { path: rel, exists: false, kind: null };
  let kind = "file";
  try {
    kind = statSync(abs).isDirectory() ? "dir" : "file";
  } catch {
    /* ignore */
  }
  return { path: rel, exists: true, kind };
}

// Contexte git courant (branche + commit court), capturé à la création d'une réf.
export function gitContext() {
  const root = repoRoot();
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], root);
  const commit = git(["rev-parse", "--short", "HEAD"], root);
  return { branch: branch || null, commit: commit || null };
}

// Contexte d'une branche choisie (branche + commit court de son sommet). Repli
// sur le HEAD courant si `branch` est nul. Préfère origin/<branch> (clone miroir).
export function branchContext(branch) {
  if (!branch) return gitContext();
  const root = repoRoot();
  let commit = git(["rev-parse", "--short", `origin/${branch}`], root);
  if (!commit) commit = git(["rev-parse", "--short", branch], root);
  return { branch, commit: commit || null };
}

// ── Liste des chemins (autocomplete), par branche ────────────────────────────
// Un index par « source » : soit l'arbre d'une branche donnée (via `git ls-tree`,
// sans checkout — un seul clone sert toutes les branches), soit le working tree
// courant (clé "", via `git ls-files`). Cache court par source.
const CACHE_MS = 4000;
// clé branche ("" = working tree) → { files, dirs, fileSet, dirSet, stamp }
const _index = new Map();

// Construit l'index des chemins pour une source. `branch` falsy → working tree.
function buildIndex(branch) {
  let out;
  if (branch) {
    // Arbre de n'importe quelle branche sans checkout. On préfère la branche de
    // suivi distante (origin/<b>) — le clone a toutes les branches via fetch —
    // avec repli sur une éventuelle branche locale homonyme.
    out = git(["ls-tree", "-r", "--name-only", `origin/${branch}`], repoRoot());
    if (out == null) out = git(["ls-tree", "-r", "--name-only", branch], repoRoot());
  } else {
    // IMPORTANT : depuis meowtrack/, `git ls-files` ne listerait que ce dossier.
    // On force la racine du repo comme cwd pour tout l'arbre.
    out = git(["ls-files"], repoRoot());
  }
  const files = out ? out.split("\n").map((s) => s.trim()).filter(Boolean) : [];
  // Dossiers dérivés des chemins fichiers (uniques).
  const dirSet = new Set();
  for (const f of files) {
    const parts = f.split("/");
    for (let i = 1; i < parts.length; i++) dirSet.add(parts.slice(0, i).join("/"));
  }
  return { files, dirs: [...dirSet].sort(), fileSet: new Set(files), dirSet, stamp: Date.now() };
}

function getIndex(branch) {
  const key = branch || "";
  const cached = _index.get(key);
  if (cached && Date.now() - cached.stamp < CACHE_MS) return cached;
  const built = buildIndex(branch);
  _index.set(key, built);
  return built;
}

// Force le rafraîchissement (après un pull / changement de branche / nouveaux
// fichiers). Sans argument : invalide TOUTES les sources. Avec `branch` : seulement
// celle-là (ou "" pour le working tree).
export function refreshPaths(branch) {
  if (branch === undefined) _index.clear();
  else _index.delete(branch || "");
  const idx = getIndex(branch);
  return { branch: branch || null, files: idx.files.length, dirs: idx.dirs.length };
}

// Branches connues du clone (locales + refs/remotes/origin/*), en nom court, plus
// la branche actuellement checkout (working tree).
export function listBranches() {
  const root = repoRoot();
  const raw = git(["for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes"], root) || "";
  const names = new Set();
  for (let line of raw.split("\n").map((s) => s.trim()).filter(Boolean)) {
    if (/(^|\/)HEAD$/.test(line)) continue; // ignore origin/HEAD
    if (line.startsWith("origin/")) line = line.slice("origin/".length);
    if (line) names.add(line);
  }
  const current = git(["rev-parse", "--abbrev-ref", "HEAD"], root);
  return { branches: [...names].sort(), current: current || null };
}

// Recherche de chemins (fichiers + dossiers) contenant `query` (insensible casse).
// Priorise : match en début de basename > début de chemin > sous-chaîne. Les
// dossiers remontent avant les fichiers à score égal. `branch` cible l'arbre d'une
// branche précise (défaut : working tree). Limite par défaut 30.
export function searchPaths(query = "", limit = 30, branch = null) {
  const idx = getIndex(branch);
  const q = String(query || "").toLowerCase().replace(/\\/g, "/");
  const score = (path, kind) => {
    if (!q) return kind === "dir" ? 1 : 0;
    const lower = path.toLowerCase();
    const idx = lower.indexOf(q);
    if (idx === -1) return -1;
    const base = lower.slice(lower.lastIndexOf("/") + 1);
    let s = 100;
    if (base.startsWith(q)) s = 0;
    else if (lower.startsWith(q)) s = 10;
    else if (base.includes(q)) s = 30;
    else s = 60;
    return s + idx * 0.01 + (kind === "dir" ? -5 : 0) + path.length * 0.001;
  };
  const candidates = [];
  for (const d of idx.dirs) {
    const s = score(d, "dir");
    if (s >= 0) candidates.push({ path: d, kind: "dir", _s: s });
  }
  for (const f of idx.files) {
    const s = score(f, "file");
    if (s >= 0) candidates.push({ path: f, kind: "file", _s: s });
  }
  candidates.sort((a, b) => a._s - b._s);
  return candidates.slice(0, Math.max(1, Math.min(200, limit))).map(({ path, kind }) => ({ path, kind }));
}
