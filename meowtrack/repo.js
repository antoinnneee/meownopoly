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
import { existsSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));

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
//   2. `git rev-parse --show-toplevel` depuis ce dossier (cas dev in-repo) ;
//   3. fallback : dossier parent de meowtrack/.
let _root = null;
export function repoRoot() {
  if (_root) return _root;
  const override = process.env.MEOWTRACK_REPO;
  if (override && override.trim()) {
    _root = resolve(override.trim());
    return _root;
  }
  const top = git(["rev-parse", "--show-toplevel"]);
  _root = top ? resolve(top) : resolve(HERE, "..");
  return _root;
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

// Existence + nature (file/dir) d'un chemin relatif repo.
export function inspectPath(relPath) {
  const rel = normalizePath(relPath);
  if (!rel) return { path: relPath, exists: false, kind: null };
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

// ── Liste des chemins (autocomplete) ─────────────────────────────────────────
// Cache court : on respawn git ls-files au plus toutes les CACHE_MS.
const CACHE_MS = 4000;
let _files = null; // string[] de fichiers suivis (relatifs, slash avant)
let _dirs = null; // string[] de dossiers dérivés
let _stamp = 0;

function refreshIndex() {
  const now = Date.now();
  if (_files && now - _stamp < CACHE_MS) return;
  // IMPORTANT : depuis le sous-dossier meowtrack/, `git ls-files` ne listerait
  // que ce dossier. On force la racine du repo comme cwd pour tout l'arbre.
  const out = git(["ls-files"], repoRoot());
  const files = out ? out.split("\n").map((s) => s.trim()).filter(Boolean) : [];
  // Dossiers dérivés des chemins fichiers (uniques).
  const dirSet = new Set();
  for (const f of files) {
    const parts = f.split("/");
    for (let i = 1; i < parts.length; i++) dirSet.add(parts.slice(0, i).join("/"));
  }
  _files = files;
  _dirs = [...dirSet].sort();
  _stamp = now;
}

// Force le rafraîchissement immédiat (utile après un pull / changement de branche).
export function refreshPaths() {
  _stamp = 0;
  refreshIndex();
  return { files: _files.length, dirs: _dirs.length };
}

// Recherche de chemins (fichiers + dossiers) contenant `query` (insensible casse).
// Priorise : match en début de basename > début de chemin > sous-chaîne. Les
// dossiers remontent avant les fichiers à score égal. Limite par défaut 30.
export function searchPaths(query = "", limit = 30) {
  refreshIndex();
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
  for (const d of _dirs) {
    const s = score(d, "dir");
    if (s >= 0) candidates.push({ path: d, kind: "dir", _s: s });
  }
  for (const f of _files) {
    const s = score(f, "file");
    if (s >= 0) candidates.push({ path: f, kind: "file", _s: s });
  }
  candidates.sort((a, b) => a._s - b._s);
  return candidates.slice(0, Math.max(1, Math.min(200, limit))).map(({ path, kind }) => ({ path, kind }));
}
