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
import { dirname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

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
import { searchPaths, refreshPaths, gitContext, repoRoot } from "./repo.js";

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

    // GET /api/paths?q=&limit= — autocomplete (feature « @ »).
    if (req.method === "GET" && path === "/api/paths") {
      return send(res, 200, searchPaths(q.get("q") || "", Number(q.get("limit")) || 30));
    }
    // POST /api/paths/refresh — re-scan git ls-files.
    if (req.method === "POST" && path === "/api/paths/refresh") {
      return send(res, 200, refreshPaths());
    }

    // GET /api/issues — liste filtrée.
    if (req.method === "GET" && path === "/api/issues") {
      const filter = {
        type: q.get("type") || undefined,
        status: q.get("status") || undefined,
        priority: q.get("priority") || undefined,
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

server.listen(PORT, HOST, () => {
  console.error(`[meowtrack] Dashboard prêt → http://${HOST}:${PORT}  (repo : ${repoRoot()})`);
  if (HOST !== "127.0.0.1" && HOST !== "localhost" && !TOKEN) {
    console.error(
      "[meowtrack] ⚠️  Écoute hors localhost SANS MEOWTRACK_TOKEN : l'API est ouverte à tout le réseau. " +
        "Définir MEOWTRACK_TOKEN en production."
    );
  }
});
