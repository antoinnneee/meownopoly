// repo.js — primitives git BAS NIVEAU, paramétrées par `root` (un clone donné).
//
// Multi-repos : ce module ne connaît AUCUN registre ni état global. Chaque fonction
// reçoit explicitement la racine d'un clone (`root`). L'orchestration par repo
// (résolution du clone, registre, caches) vit dans `repos.js`. Sert deux besoins :
//   1. l'autocomplete des chemins (feature « @ » du dashboard + tool MCP),
//   2. la validation qu'un chemin référencé existe réellement, et le contexte
//      git (branche + commit court) capturé au moment où une référence est créée.
//
// Aucune écriture dans le repo : lecture seule (git ls-files / rev-parse + fs),
// sauf clone/fetch/pull explicites (cloneInto / pull).

import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, statSync } from "node:fs";
import { dirname, join, resolve, sep } from "node:path";

// Exécute git dans `cwd` et retourne stdout trimé (ou null si échec). Lecture seule.
function git(args, cwd) {
  try {
    return execFileSync("git", args, {
      cwd,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
      maxBuffer: 64 * 1024 * 1024,
    }).trim();
  } catch {
    return null;
  }
}

// Variante qui capture stderr et renvoie {ok, output} (les commandes d'écriture
// clone/pull doivent remonter leurs erreurs, contrairement au git() lecture-seule).
function gitRun(args, cwd) {
  try {
    const out = execFileSync("git", args, {
      cwd,
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

export function isGitClone(dir) {
  return !!dir && existsSync(join(dir, ".git"));
}

// Clone `url` dans `root` (crée le dossier parent). Renvoie {ok, output}.
export function cloneInto(url, root) {
  try {
    mkdirSync(dirname(root), { recursive: true });
  } catch {
    /* ignore — clone remontera l'erreur si le parent est inaccessible */
  }
  return gitRun(["clone", url, root], dirname(root));
}

// Pull (fetch + merge ff-only) du clone `root`. Renvoie {ok, output}.
export function pull(root) {
  const fetch = gitRun(["fetch", "--all", "--prune"], root);
  const pulled = gitRun(["pull", "--ff-only"], root);
  return { ok: fetch.ok && pulled.ok, pulled: pulled.ok, output: [fetch.output, pulled.output].filter(Boolean).join("\n") };
}

// Normalise un chemin saisi par l'utilisateur en chemin relatif repo, à slashes
// avant. Retourne null si le chemin sort de la racine (anti path-traversal).
export function normalizePath(root, p) {
  if (!p || typeof p !== "string") return null;
  const cleaned = p.trim().replace(/\\/g, "/").replace(/^\.\//, "").replace(/^\/+/, "");
  if (!cleaned) return null;
  const abs = resolve(root, cleaned);
  const rootWithSep = root.endsWith(sep) ? root : root + sep;
  if (abs !== root && !abs.startsWith(rootWithSep)) return null;
  return cleaned.replace(/\/+$/, "");
}

// Existence + nature (file/dir) d'un chemin relatif repo. Si `branch` est fourni,
// la vérification se fait dans l'arbre de cette branche (via l'index ls-tree),
// pas dans le working tree. `getIdx(branch)` fournit l'index (caché par repos.js).
export function inspectPath(root, relPath, branch, getIdx) {
  const rel = normalizePath(root, relPath);
  if (!rel) return { path: relPath, exists: false, kind: null };
  if (branch) {
    const idx = getIdx(branch);
    if (idx.fileSet.has(rel)) return { path: rel, exists: true, kind: "file" };
    if (idx.dirSet.has(rel)) return { path: rel, exists: true, kind: "dir" };
    return { path: rel, exists: false, kind: null };
  }
  const abs = join(root, rel);
  if (!existsSync(abs)) return { path: rel, exists: false, kind: null };
  let kind = "file";
  try {
    kind = statSync(abs).isDirectory() ? "dir" : "file";
  } catch {
    /* ignore */
  }
  return { path: rel, exists: true, kind };
}

// Contexte git courant (branche + commit court du HEAD checkout du clone).
export function gitContext(root) {
  if (!isGitClone(root)) return { branch: null, commit: null };
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], root);
  const commit = git(["rev-parse", "--short", "HEAD"], root);
  return { branch: branch || null, commit: commit || null };
}

// Contexte d'une branche choisie (branche + commit court de son sommet). Repli
// sur le HEAD courant si `branch` est nul. Préfère origin/<branch> (clone miroir).
export function branchContext(root, branch) {
  if (!branch) return gitContext(root);
  let commit = git(["rev-parse", "--short", `origin/${branch}`], root);
  if (!commit) commit = git(["rev-parse", "--short", branch], root);
  return { branch, commit: commit || null };
}

// Construit l'index des chemins pour une source. `branch` falsy → working tree.
// Lit l'arbre d'une branche SANS checkout (un seul clone sert toutes les branches).
export function buildIndex(root, branch) {
  let out;
  if (branch) {
    out = git(["ls-tree", "-r", "--name-only", `origin/${branch}`], root);
    if (out == null) out = git(["ls-tree", "-r", "--name-only", branch], root);
  } else {
    out = git(["ls-files"], root);
  }
  const files = out ? out.split("\n").map((s) => s.trim()).filter(Boolean) : [];
  const dirSet = new Set();
  for (const f of files) {
    const parts = f.split("/");
    for (let i = 1; i < parts.length; i++) dirSet.add(parts.slice(0, i).join("/"));
  }
  return { files, dirs: [...dirSet].sort(), fileSet: new Set(files), dirSet, stamp: Date.now() };
}

// Branches connues du clone (locales + refs/remotes/origin/*), en nom court, plus
// la branche actuellement checkout (working tree).
export function listBranches(root) {
  if (!isGitClone(root)) return { branches: [], current: null };
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
// dossiers remontent avant les fichiers à score égal. `idx` = index pré-construit
// (fourni par repos.js, caché par repo+branche). Limite par défaut 30.
export function searchPaths(idx, query = "", limit = 30) {
  const q = String(query || "").toLowerCase().replace(/\\/g, "/");
  const score = (path, kind) => {
    if (!q) return kind === "dir" ? 1 : 0;
    const lower = path.toLowerCase();
    const at = lower.indexOf(q);
    if (at === -1) return -1;
    const base = lower.slice(lower.lastIndexOf("/") + 1);
    let s = 100;
    if (base.startsWith(q)) s = 0;
    else if (lower.startsWith(q)) s = 10;
    else if (base.includes(q)) s = 30;
    else s = 60;
    return s + at * 0.01 + (kind === "dir" ? -5 : 0) + path.length * 0.001;
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
