// repos.js — orchestration git MULTI-REPOS.
//
// Fait le pont entre le registre des repos (table `repos`, CRUD dans db.js) et les
// primitives git bas niveau (repo.js). Résout le clone d'un repo, maintient un
// cache d'index de chemins par (repo, branche), et expose des wrappers « par
// repoId » utilisés par le serveur HTTP et par db.js (validation des chemins +
// contexte git à la création d'une issue).
//
// NB : import circulaire avec db.js (db.js importe gitContextFor/inspectPathFor…,
// ce module importe le registre). C'est SÛR : aucun binding n'est utilisé au
// moment de l'évaluation des modules — uniquement à l'intérieur des fonctions.

import { execFileSync } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  isGitClone,
  cloneInto,
  pull,
  normalizePath,
  inspectPath,
  gitContext,
  branchContext,
  buildIndex,
  listBranches,
  searchPaths,
} from "./repo.js";
import { getRepoRow, listRepoRows } from "./db.js";

const HERE = dirname(fileURLToPath(import.meta.url));

// Racine de clone d'un repo (mémoïsée par id) :
//   1. local_path explicite (clone géré à la main / dev in-repo ciblé) ;
//   2. url définie → dossier dédié `.repos/<slug>/` à côté du service ;
//   3. ni l'un ni l'autre → `git rev-parse --show-toplevel` depuis meowtrack/
//      (cas dev in-repo : le checkout qui contient ce dossier).
const _rootCache = new Map(); // repoId → root absolu
function topLevel() {
  try {
    return execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: HERE, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
}
export function rootForRepo(repoOrId) {
  const repo = typeof repoOrId === "object" ? repoOrId : getRepoRow(repoOrId);
  if (!repo) throw new Error(`Repo introuvable : ${repoOrId}`);
  if (_rootCache.has(repo.id)) return _rootCache.get(repo.id);
  let root;
  if (repo.local_path && String(repo.local_path).trim()) root = resolve(String(repo.local_path).trim());
  else if (repo.url && String(repo.url).trim()) root = resolve(HERE, ".repos", repo.slug);
  else {
    const top = topLevel();
    root = top ? resolve(top) : resolve(HERE, "..");
  }
  _rootCache.set(repo.id, root);
  return root;
}
// À appeler si un repo change de local_path/url (invalide la mémoïsation + l'index).
export function invalidateRepo(repoId) {
  _rootCache.delete(repoId);
  for (const key of [..._index.keys()]) if (key.startsWith(`${repoId}|`)) _index.delete(key);
}

// ── Cache d'index de chemins, par (repo, branche) ────────────────────────────
const CACHE_MS = 4000;
const _index = new Map(); // `${repoId}|${branch}` → index (branch "" = working tree)

function getIndex(repoId, branch) {
  const key = `${repoId}|${branch || ""}`;
  const cached = _index.get(key);
  if (cached && Date.now() - cached.stamp < CACHE_MS) return cached;
  const built = buildIndex(rootForRepo(repoId), branch);
  _index.set(key, built);
  return built;
}

export function refreshPathsFor(repoId, branch) {
  if (branch === undefined) {
    for (const key of [..._index.keys()]) if (key.startsWith(`${repoId}|`)) _index.delete(key);
  } else {
    _index.delete(`${repoId}|${branch || ""}`);
  }
  const idx = getIndex(repoId, branch);
  return { repoId, branch: branch || null, files: idx.files.length, dirs: idx.dirs.length };
}

// ── Wrappers « par repoId » (résolvent le root puis délèguent à repo.js) ─────
export function gitContextFor(repoId) {
  return gitContext(rootForRepo(repoId));
}
export function branchContextFor(repoId, branch) {
  return branchContext(rootForRepo(repoId), branch);
}
export function normalizePathFor(repoId, p) {
  return normalizePath(rootForRepo(repoId), p);
}
export function inspectPathFor(repoId, relPath, branch = null) {
  return inspectPath(rootForRepo(repoId), relPath, branch, (b) => getIndex(repoId, b));
}
export function searchPathsFor(repoId, query = "", limit = 30, branch = null) {
  return searchPaths(getIndex(repoId, branch), query, limit);
}
export function listBranchesFor(repoId) {
  return listBranches(rootForRepo(repoId));
}

// ── Clone / pull d'un repo ───────────────────────────────────────────────────
// Garantit un clone à jour : clone si absent (et url présente), sinon pull.
// No-op pour un repo sans url (clone géré à la main / dev in-repo).
export function ensureRepo(repoId) {
  const repo = getRepoRow(repoId);
  if (!repo) throw new Error(`Repo introuvable : ${repoId}`);
  const root = rootForRepo(repo);
  if (!repo.url || !String(repo.url).trim()) {
    // Pas d'URL : on ne clone/pull pas, on lit le clone existant.
    return { ok: true, skipped: true, reason: "no_url", branch: gitContext(root).branch, commit: gitContext(root).commit, root };
  }
  if (isGitClone(root)) return pullRepo(repoId);
  const r = cloneInto(repo.url, root);
  if (r.ok) refreshPathsFor(repoId);
  const ctx = gitContext(root);
  return { ok: r.ok, cloned: r.ok, branch: ctx.branch, commit: ctx.commit, output: r.output, root };
}

export function pullRepo(repoId) {
  const root = rootForRepo(repoId);
  if (!isGitClone(root)) return { ok: false, output: `Pas un clone git : ${root}`, root };
  const r = pull(root);
  refreshPathsFor(repoId); // l'arbre a pu changer
  const ctx = gitContext(root);
  return { ok: r.ok, pulled: r.pulled, branch: ctx.branch, commit: ctx.commit, output: r.output, root };
}

// Sync de TOUS les repos au démarrage (clone si absent, sinon pull). Renvoie un
// rapport par repo. Tolérant aux échecs (un repo cassé ne bloque pas les autres).
export function ensureAllRepos() {
  const out = [];
  for (const repo of listRepoRows()) {
    try {
      out.push({ slug: repo.slug, ...ensureRepo(repo.id) });
    } catch (e) {
      out.push({ slug: repo.slug, ok: false, output: e.message || String(e) });
    }
  }
  return out;
}
