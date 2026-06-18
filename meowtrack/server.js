#!/usr/bin/env node
// server.js — serveur HTTP du dashboard Meowtrack (dev-only, localhost).
//
// Sert le dashboard statique + une petite API REST JSON par-dessus db.js.
// Partage la même base meowtrack.db que le MCP (WAL → lectures concurrentes).
// Lancement : node server.js  (port MEOWTRACK_PORT, défaut 7702).
//
// Pas de framework : http natif + routage manuel, comme chatServer/server.js.
//
// Déploiement (serveur de dev, port dédié, pas de nginx) : binder 0.0.0.0 via
// MEOWTRACK_HOST et protéger l'API par MEOWTRACK_TOKEN (Bearer). Le clone du
// repo est ciblé par MEOWTRACK_REPO. Cf. .env.example + install-service.sh.

import "dotenv/config";
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);

import {
  createIssue,
  getIssue,
  updateIssue,
  deleteIssue,
  listIssues,
  addReference,
  removeReference,
  addComment,
  stats,
} from "./db.js";
import { searchPaths, refreshPaths, gitContext, repoRoot, ensureRepo, repoUrl, listBranches } from "./repo.js";

const HERE = dirname(fileURLToPath(import.meta.url));
const PUBLIC = join(HERE, "dashboard");
const PORT = Number(process.env.MEOWTRACK_PORT) || 7702;
// Défaut localhost (dev). En déploiement, MEOWTRACK_HOST=0.0.0.0 pour être
// joignable sur le réseau du serveur (pas de reverse-proxy).
const HOST = process.env.MEOWTRACK_HOST || "127.0.0.1";
// Token d'accès à l'API. S'il est défini, toute requête /api/* doit présenter
// `Authorization: Bearer <token>` (ou en-tête `X-Meowtrack-Token`). Vide = ouvert
// (OK en local). Génér. : node -e "console.log(require('crypto').randomBytes(24).toString('hex'))"
const TOKEN = (process.env.MEOWTRACK_TOKEN || "").trim();
// Binaire CLI Claude pour la feature « Améliorer la description » (claude -p).
// Doit être installé + authentifié sur la machine du serveur. Configurable.
const CLAUDE_BIN = (process.env.MEOWTRACK_CLAUDE_BIN || "claude").trim();

// Réécrit une description via Claude en mode headless (sonnet). Aucune exécution
// shell (execFile sans shell) → pas d'injection via le contenu utilisateur.
async function improveDescriptionWithClaude(title, description) {
  const base = String(description || "").trim();
  if (!base) throw new Error("Description vide");
  const prompt =
    "Tu améliores la description d'une entrée de suivi (bug/feature/tâche) d'un projet logiciel.\n" +
    "Réécris la description ci-dessous pour qu'elle soit claire, structurée et actionnable " +
    "(contexte, comportement attendu/observé, étapes de repro si pertinent). Reste concis.\n" +
    "Garde la langue d'origine (français). Conserve TELS QUELS les éventuels tokens @chemin/vers/fichier.\n" +
    "Réponds UNIQUEMENT avec la description améliorée, sans préambule, sans guillemets, sans bloc de code.\n\n" +
    `Titre : ${title || "(sans titre)"}\n\nDescription actuelle :\n${base}`;
  try {
    const { stdout } = await execFileAsync(CLAUDE_BIN, ["-p", prompt, "--model", "sonnet"], {
      timeout: 120000,
      maxBuffer: 8 * 1024 * 1024,
    });
    const out = String(stdout || "").trim();
    if (!out) throw new Error("Réponse vide de Claude");
    return out;
  } catch (e) {
    if (e.code === "ENOENT") throw new Error(`CLI Claude introuvable (${CLAUDE_BIN}). Installer/configurer MEOWTRACK_CLAUDE_BIN.`);
    throw new Error(e.stderr ? String(e.stderr).trim() : e.message || String(e));
  }
}

// Allowlist stricte des fichiers statiques (pas de path traversal).
const STATIC = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/dashboard.css": ["dashboard.css", "text/css; charset=utf-8"],
  "/dashboard.js": ["dashboard.js", "text/javascript; charset=utf-8"],
};

function send(res, status, body, headers = {}) {
  const data = typeof body === "string" || Buffer.isBuffer(body) ? body : JSON.stringify(body);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    ...headers,
  });
  res.end(data);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let raw = "";
    let size = 0;
    req.on("data", (c) => {
      size += c.length;
      if (size > 1_000_000) {
        reject(new Error("Payload trop volumineux"));
        req.destroy();
        return;
      }
      raw += c;
    });
    req.on("end", () => {
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new Error("JSON invalide"));
      }
    });
    req.on("error", reject);
  });
}

async function serveStatic(pathname, res) {
  const entry = STATIC[pathname];
  if (!entry) return false;
  const [file, mime] = entry;
  try {
    const data = await readFile(join(PUBLIC, file));
    res.writeHead(200, { "Content-Type": mime, "Cache-Control": "no-store" });
    res.end(data);
  } catch {
    send(res, 404, { error: "not_found" });
  }
  return true;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const path = normalize(url.pathname).replace(/\\/g, "/");
  const q = url.searchParams;

  try {
    // ── Statique ── (toujours servi : la page doit pouvoir demander le token)
    if (req.method === "GET" && (await serveStatic(path, res))) return;

    // ── Auth API ── si un token est configuré, /api/* l'exige.
    if (path.startsWith("/api/") && TOKEN) {
      const auth = req.headers["authorization"] || "";
      const bearer = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
      const provided = bearer || req.headers["x-meowtrack-token"] || q.get("token") || "";
      if (provided !== TOKEN) {
        return send(res, 401, { error: "unauthorized" });
      }
    }

    // ── API ──
    // GET /api/meta — contexte git + stats + racine repo.
    if (req.method === "GET" && path === "/api/meta") {
      return send(res, 200, { ...stats(), git: gitContext(), repoRoot: repoRoot(), port: PORT });
    }

    // GET /api/branches — branches connues du clone (+ branche courante).
    if (req.method === "GET" && path === "/api/branches") {
      return send(res, 200, listBranches());
    }

    // GET /api/paths?q=&limit=&branch= — autocomplete (feature « @ »), arbre de
    // la branche `branch` si fournie (sinon working tree courant).
    if (req.method === "GET" && path === "/api/paths") {
      return send(
        res,
        200,
        searchPaths(q.get("q") || "", Number(q.get("limit")) || 30, q.get("branch") || null)
      );
    }
    // POST /api/paths/refresh?branch= — re-scan d'une source (ou de toutes).
    if (req.method === "POST" && path === "/api/paths/refresh") {
      return send(res, 200, refreshPaths(q.get("branch") ?? undefined));
    }
    // POST /api/repo/update — clone (si absent) ou git fetch+pull du repo, puis
    // re-scan des chemins. No-op si MEOWTRACK_REPO_URL n'est pas défini.
    if (req.method === "POST" && path === "/api/repo/update") {
      return send(res, 200, { ...ensureRepo(), git: gitContext() });
    }
    // POST /api/improve-description { title, description } — réécriture via Claude.
    if (req.method === "POST" && path === "/api/improve-description") {
      const { title, description } = await readBody(req);
      const improved = await improveDescriptionWithClaude(title, description);
      return send(res, 200, { description: improved });
    }

    // GET /api/issues — liste filtrée.
    if (req.method === "GET" && path === "/api/issues") {
      const filter = {
        type: q.get("type") || undefined,
        status: q.get("status") || undefined,
        priority: q.get("priority") || undefined,
        branch: q.get("branch") || undefined,
        tag: q.get("tag") || undefined,
        path: q.get("path") || undefined,
        text: q.get("text") || undefined,
        includeClosed: q.get("includeClosed") === "true",
        limit: Number(q.get("limit")) || undefined,
      };
      return send(res, 200, listIssues(filter));
    }
    // POST /api/issues — créer.
    if (req.method === "POST" && path === "/api/issues") {
      const body = await readBody(req);
      return send(res, 201, createIssue(body));
    }

    // /api/issues/:ref…
    const issueMatch = path.match(/^\/api\/issues\/([^/]+)(\/comments|\/references)?$/);
    if (issueMatch) {
      const ref = decodeURIComponent(issueMatch[1]);
      const sub = issueMatch[2];

      if (!sub && req.method === "GET") {
        const issue = getIssue(ref);
        return issue ? send(res, 200, issue) : send(res, 404, { error: "not_found", ref });
      }
      if (!sub && req.method === "PATCH") {
        return send(res, 200, updateIssue(ref, await readBody(req)));
      }
      if (!sub && req.method === "DELETE") {
        return send(res, 200, { deleted: deleteIssue(ref), ref });
      }
      if (sub === "/comments" && req.method === "POST") {
        const { body } = await readBody(req);
        return send(res, 201, addComment(ref, body));
      }
      if (sub === "/references" && req.method === "POST") {
        const issue = getIssue(ref);
        if (!issue) return send(res, 404, { error: "not_found", ref });
        const { path: p } = await readBody(req);
        addReference(issue.id, p);
        return send(res, 201, getIssue(issue.id));
      }
    }

    // DELETE /api/references/:id
    const refMatch = path.match(/^\/api\/references\/(\d+)$/);
    if (refMatch && req.method === "DELETE") {
      return send(res, 200, { removed: removeReference(Number(refMatch[1])) });
    }

    send(res, 404, { error: "not_found", path });
  } catch (e) {
    send(res, 400, { error: e.message || String(e) });
  }
});

// Sync du repo au démarrage : clone si absent, sinon pull. No-op sans URL.
if (repoUrl()) {
  console.error(`[meowtrack] Sync du repo (${repoUrl()}) → ${repoRoot()}…`);
  const r = ensureRepo();
  if (r.ok) {
    console.error(`[meowtrack] Repo ${r.cloned ? "cloné" : "à jour"} (${r.branch || "?"} @ ${r.commit || "?"}).`);
  } else {
    console.error(`[meowtrack] ⚠️  Sync du repo échouée : ${r.output || "erreur inconnue"}`);
  }
}

server.listen(PORT, HOST, () => {
  console.error(`[meowtrack] Dashboard prêt → http://${HOST}:${PORT}  (repo : ${repoRoot()})`);
  if (HOST !== "127.0.0.1" && HOST !== "localhost" && !TOKEN) {
    console.error(
      "[meowtrack] ⚠️  Écoute hors localhost SANS MEOWTRACK_TOKEN : l'API est ouverte à tout le réseau. " +
        "Définir MEOWTRACK_TOKEN en production."
    );
  }
});
