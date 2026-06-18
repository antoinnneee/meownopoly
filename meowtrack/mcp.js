#!/usr/bin/env node
// mcp.js — serveur MCP (stdio) du suivi Meowtrack.
//
// Client de l'API HTTP du dashboard déployé : toutes les requêtes passent par le
// serveur distant (server.js), qui est la SEULE source de vérité (base SQLite +
// repo cloné). Le MCP ne touche JAMAIS de base locale — il relaie vers le serveur.
// Lancement : node mcp.js (configuré dans .mcp.json racine). Aucune dépendance à
// l'app Qt.
//
// Config (env ou meowtrack/.env, chargé explicitement quel que soit le cwd) :
//   MEOWTRACK_SERVER_URL  base de l'API (défaut http://127.0.0.1:7702 ; en prod
//                         ex. http://pattounecorp.ovh:7702).
//   MEOWTRACK_TOKEN       jeton Bearer si le serveur en exige un (sinon vide).

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const HERE = dirname(fileURLToPath(import.meta.url));
// Le MCP est lancé depuis la racine du repo (`node meowtrack/mcp.js`), donc
// dotenv/config (cwd) ne verrait pas meowtrack/.env. On le charge explicitement.
dotenv.config({ path: join(HERE, ".env") });

// Énumérations (doivent rester alignées sur db.js — dupliquées ici pour ne pas
// importer db.js, dont l'import ouvrirait une base SQLite locale).
const TYPES = ["bug", "feature", "task", "chore"];
const STATUSES = ["open", "in_progress", "done", "wontfix"];
const PRIORITIES = ["low", "medium", "high", "critical"];
// Good Vibes : arbre de NŒUDS (objectifs = jalons = sous-jalons).
const NODE_STATUSES = ["active", "paused", "done", "abandoned"];
const NODE_COLORS = ["accent", "feature", "task", "bug", "high"];

const BASE = (process.env.MEOWTRACK_SERVER_URL || "http://127.0.0.1:7702").replace(/\/+$/, "");
const TOKEN = (process.env.MEOWTRACK_TOKEN || "").trim();

// ── Client HTTP de l'API du serveur distant ──────────────────────────────────
async function apiFetch(method, path, body) {
  const headers = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (TOKEN) headers["Authorization"] = "Bearer " + TOKEN;
  let res;
  try {
    res = await fetch(BASE + path, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
  } catch (e) {
    throw new Error(`Serveur meowtrack injoignable (${BASE}) : ${e.message || e}`);
  }
  const text = await res.text();
  let data;
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    const msg = (data && data.error) || res.statusText || `HTTP ${res.status}`;
    throw new Error(`${msg} (HTTP ${res.status})`);
  }
  return data;
}
const apiGet = (path) => apiFetch("GET", path);

// Construit une query string à partir des champs définis (ignore null/undefined/"").
function qs(obj) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(obj || {})) {
    if (v !== undefined && v !== null && v !== "") p.set(k, String(v));
  }
  const s = p.toString();
  return s ? "?" + s : "";
}

const server = new McpServer({ name: "meowtrack", version: "1.0.0" });

// Helper : encapsule un résultat JSON ou une erreur en contenu MCP.
function ok(data) {
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}
function fail(err) {
  return { content: [{ type: "text", text: `Erreur: ${err.message || err}` }], isError: true };
}
function guard(fn) {
  return async (args) => {
    try {
      return ok(await fn(args));
    } catch (e) {
      return fail(e);
    }
  };
}

const refSpecSchema = z
  .string()
  .describe("Chemin repo-relatif, avec lignes optionnelles : 'chemin', 'chemin:120' ou 'chemin:120-145'.");

// ── meowtrack_create ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_create",
  {
    title: "Créer un bug / feature / tâche",
    description:
      "Enregistre une nouvelle entrée de suivi. `type` ∈ {bug,feature,task,chore}. Les chemins de " +
      "`paths` sont validés contre le repo cloné (et leur existence + contexte git sont capturés). " +
      "Tout token `@chemin` (ou `@chemin:120-145`) présent dans `description` est aussi ajouté en " +
      "référence automatiquement. Retourne l'issue créée avec son code (ex. BUG-1).",
    inputSchema: {
      type: z.enum(TYPES).optional().describe("Type (défaut 'bug')."),
      title: z.string().describe("Titre court."),
      description: z.string().optional().describe("Description détaillée (peut contenir des @chemin)."),
      priority: z.enum(PRIORITIES).optional().describe("Priorité (défaut 'medium')."),
      status: z.enum(STATUSES).optional().describe("Statut initial (défaut 'open')."),
      tags: z.array(z.string()).optional().describe("Étiquettes libres."),
      branch: z.string().optional().describe("Branche git de rattachement (tracking + validation des chemins). Défaut : branche checkout du serveur."),
      paths: z.array(refSpecSchema).optional().describe("Fichiers/dossiers associés (validés contre la branche)."),
    },
  },
  guard(async (a) => apiFetch("POST", "/api/issues", a))
);

// ── meowtrack_list ───────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_list",
  {
    title: "Lister / filtrer les entrées",
    description:
      "Liste les entrées de suivi, triées par activité puis priorité. Par défaut masque les entrées " +
      "closes (done/wontfix) — passer includeClosed=true pour tout voir. Filtres combinables.",
    inputSchema: {
      type: z.enum(TYPES).optional(),
      status: z.enum(STATUSES).optional().describe("Filtre exact sur le statut."),
      priority: z.enum(PRIORITIES).optional(),
      branch: z.string().optional().describe("Ne garder que les entrées rattachées à cette branche."),
      tag: z.string().optional().describe("Ne garder que les entrées portant cette étiquette."),
      path: z.string().optional().describe("Ne garder que les entrées référençant un chemin contenant cette sous-chaîne."),
      text: z.string().optional().describe("Recherche plein-texte sur titre/description/ref."),
      includeClosed: z.boolean().optional().describe("Inclure les entrées done/wontfix (défaut false)."),
      limit: z.number().int().optional().describe("Nombre max d'entrées (défaut 200)."),
    },
  },
  guard(async (a) => apiGet("/api/issues" + qs(a)))
);

// ── meowtrack_get ────────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_get",
  {
    title: "Détail d'une entrée",
    description: "Retourne une entrée complète (références + commentaires) par code (ex. 'BUG-1') ou id numérique.",
    inputSchema: { ref: z.string().describe("Code (BUG-1, FEAT-2…) ou id numérique.") },
  },
  guard(async ({ ref }) => {
    try {
      return await apiGet("/api/issues/" + encodeURIComponent(ref));
    } catch (e) {
      if (String(e.message).includes("404")) throw new Error(`Issue introuvable : ${ref}`);
      throw e;
    }
  })
);

// ── meowtrack_update ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_update",
  {
    title: "Modifier une entrée",
    description:
      "Met à jour les champs fournis d'une entrée existante. Fournir `paths` REMPLACE l'ensemble des " +
      "références (utiliser meowtrack_add_reference pour en ajouter une sans tout réécrire).",
    inputSchema: {
      ref: z.string().describe("Code ou id de l'entrée."),
      title: z.string().optional(),
      description: z.string().optional(),
      type: z.enum(TYPES).optional(),
      status: z.enum(STATUSES).optional(),
      priority: z.enum(PRIORITIES).optional(),
      tags: z.array(z.string()).optional(),
      branch: z.string().optional().describe("Rattacher l'entrée à cette branche (recapture le commit + revalide les chemins)."),
      paths: z.array(refSpecSchema).optional().describe("Remplace TOUTES les références par cette liste."),
    },
  },
  guard(async ({ ref, ...fields }) => apiFetch("PATCH", "/api/issues/" + encodeURIComponent(ref), fields))
);

// ── meowtrack_set_status (raccourci) ─────────────────────────────────────────
server.registerTool(
  "meowtrack_set_status",
  {
    title: "Changer le statut",
    description: "Raccourci pour passer une entrée à open / in_progress / done / wontfix.",
    inputSchema: {
      ref: z.string().describe("Code ou id de l'entrée."),
      status: z.enum(STATUSES).describe("Nouveau statut."),
    },
  },
  guard(async ({ ref, status }) => apiFetch("PATCH", "/api/issues/" + encodeURIComponent(ref), { status }))
);

// ── meowtrack_delete ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_delete",
  {
    title: "Supprimer une entrée",
    description: "Supprime définitivement une entrée et ses références/commentaires (cascade).",
    inputSchema: { ref: z.string().describe("Code ou id de l'entrée.") },
  },
  guard(async ({ ref }) => apiFetch("DELETE", "/api/issues/" + encodeURIComponent(ref)))
);

// ── meowtrack_add_reference ──────────────────────────────────────────────────
server.registerTool(
  "meowtrack_add_reference",
  {
    title: "Ajouter une référence fichier/dossier",
    description:
      "Associe un chemin du repo (validé) à une entrée, avec plage de lignes optionnelle " +
      "(via la syntaxe 'chemin:120-145'). N'écrase pas les références existantes.",
    inputSchema: {
      ref: z.string().describe("Code ou id de l'entrée."),
      path: refSpecSchema,
    },
  },
  guard(async ({ ref, path }) =>
    apiFetch("POST", "/api/issues/" + encodeURIComponent(ref) + "/references", { path })
  )
);

// ── meowtrack_remove_reference ───────────────────────────────────────────────
server.registerTool(
  "meowtrack_remove_reference",
  {
    title: "Retirer une référence",
    description: "Supprime une référence par son id (visible dans le détail de l'entrée).",
    inputSchema: { referenceId: z.number().int().describe("id de la référence à retirer.") },
  },
  guard(async ({ referenceId }) => ({
    ...(await apiFetch("DELETE", "/api/references/" + referenceId)),
    referenceId,
  }))
);

// ── meowtrack_comment ────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_comment",
  {
    title: "Ajouter un commentaire",
    description: "Ajoute une note de suivi (avancement, reproduction, piste…) à une entrée.",
    inputSchema: {
      ref: z.string().describe("Code ou id de l'entrée."),
      body: z.string().describe("Contenu du commentaire."),
    },
  },
  guard(async ({ ref, body }) =>
    apiFetch("POST", "/api/issues/" + encodeURIComponent(ref) + "/comments", { body })
  )
);

// ── meowtrack_search_paths (feature « @ ») ───────────────────────────────────
server.registerTool(
  "meowtrack_search_paths",
  {
    title: "Rechercher des chemins du repo",
    description:
      "Autocomplete des fichiers/dossiers suivis par git sur le serveur (même source que le « @ » du " +
      "dashboard). Sert à découvrir les chemins exacts à associer à une entrée. Trié par pertinence.",
    inputSchema: {
      query: z.string().optional().describe("Sous-chaîne à rechercher (vide = premiers chemins)."),
      limit: z.number().int().optional().describe("Nombre max de résultats (défaut 30)."),
      branch: z.string().optional().describe("Chercher dans l'arbre de cette branche (défaut : branche checkout du serveur)."),
    },
  },
  guard(async ({ query, limit, branch }) => apiGet("/api/paths" + qs({ q: query, limit, branch })))
);

// ── meowtrack_branches ───────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_branches",
  {
    title: "Lister les branches du repo",
    description:
      "Branches connues du clone serveur (pour rattacher une entrée ou cibler l'autocomplete d'une " +
      "branche précise). Renvoie { branches: [...], current }.",
    inputSchema: {},
  },
  guard(async () => apiGet("/api/branches"))
);

// ── meowtrack_stats ──────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_stats",
  {
    title: "Statistiques de suivi",
    description: "Compte des entrées par statut / type / priorité, plus le contexte git courant et la racine du repo (serveur).",
    inputSchema: {},
  },
  guard(async () => apiGet("/api/meta"))
);

// ── meowtrack_refresh_paths ──────────────────────────────────────────────────
server.registerTool(
  "meowtrack_refresh_paths",
  {
    title: "Rafraîchir l'index des chemins",
    description: "Force un nouveau `git ls-files` côté serveur (après un pull / changement de branche / nouveaux fichiers).",
    inputSchema: {},
  },
  guard(async () => apiFetch("POST", "/api/paths/refresh"))
);

// ═══════════════════════════════════════════════════════════════════════════
// Good Vibes — arbre de NŒUDS récursif (objectifs / jalons / sous-jalons).
// Un nœud = un objectif ; il peut avoir des sous-nœuds à profondeur libre. Chaque
// nœud porte titre, description, une LISTE de notes markdown, statut, couleur,
// emoji, échéance, et une progression (0..100) recalculée automatiquement depuis
// ses enfants. Les mêmes routes /api/nodes que le dashboard.
// ═══════════════════════════════════════════════════════════════════════════

// Référence d'un nœud : code lisible (ex. 'NODE-1') ou id numérique.
const nodeRefSchema = z.union([z.string(), z.number()]).describe("Code (ex. 'NODE-1') ou id numérique du nœud.");
// Notes : liste de sections markdown collapsables. Remplace TOUTE la liste à l'écriture.
const notesSchema = z
  .array(z.object({ title: z.string().optional().describe("Titre de la section (optionnel)."), body: z.string().describe("Corps markdown.") }))
  .describe("Liste de notes markdown [{title, body}]. REMPLACE toutes les notes existantes (reprends l'existant pour compléter).");

// ── meowtrack_node_create ────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_create",
  {
    title: "Créer un nœud (objectif / jalon)",
    description:
      "Crée un nœud Good Vibes. Sans `parentId` → objectif racine. Avec `parentId` → sous-jalon de ce " +
      "nœud. La progression est dérivée automatiquement (ne pas la fixer). Retourne le nœud créé (avec son code NODE-N).",
    inputSchema: {
      title: z.string().describe("Titre du nœud."),
      parentId: nodeRefSchema.optional().describe("Parent (absent = nœud racine)."),
      description: z.string().optional().describe("Description courte."),
      notes: notesSchema.optional(),
      status: z.enum(NODE_STATUSES).optional().describe("Statut (défaut 'active')."),
      color: z.enum(NODE_COLORS).optional().describe("Couleur (défaut 'accent', ou héritée du parent)."),
      emoji: z.string().optional().describe("Emoji (défaut 🎯)."),
      targetDate: z.string().optional().describe("Échéance 'YYYY-MM-DD' (ou null pour aucune)."),
      position: z.number().int().optional().describe("Position parmi les frères (défaut : à la fin)."),
    },
  },
  guard(async (a) => apiFetch("POST", "/api/nodes", a))
);

// ── meowtrack_node_list ──────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_list",
  {
    title: "Lister les nœuds (forêt ou racines)",
    description:
      "Liste les nœuds. `view='forest'` (défaut) renvoie TOUT l'arbre à plat (avec parentId/depth) — " +
      "idéal pour comprendre la structure. `view='roots'` ne renvoie que les objectifs racines.",
    inputSchema: {
      view: z.enum(["forest", "roots"]).optional().describe("'forest' (tout, défaut) ou 'roots' (racines seules)."),
      status: z.enum(NODE_STATUSES).optional().describe("Filtre statut (racines uniquement)."),
      text: z.string().optional().describe("Recherche plein-texte (racines uniquement)."),
      limit: z.number().int().optional(),
    },
  },
  guard(async ({ view, ...rest }) =>
    (view ?? "forest") === "forest" ? apiGet("/api/nodes?view=forest") : apiGet("/api/nodes" + qs(rest))
  )
);

// ── meowtrack_node_get ───────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_get",
  {
    title: "Détail d'un nœud (+ sous-arbre)",
    description: "Retourne un nœud complet (notes incluses) et, par défaut, son sous-arbre imbriqué (children).",
    inputSchema: {
      ref: nodeRefSchema,
      tree: z.boolean().optional().describe("Inclure le sous-arbre imbriqué (défaut true)."),
      messages: z.boolean().optional().describe("Inclure l'historique de chat du nœud (défaut false)."),
    },
  },
  guard(async ({ ref, tree, messages }) => {
    try {
      return await apiGet("/api/nodes/" + encodeURIComponent(ref) + qs({ tree: tree === false ? "false" : undefined, messages: messages ? "true" : undefined }));
    } catch (e) {
      if (String(e.message).includes("404")) throw new Error(`Nœud introuvable : ${ref}`);
      throw e;
    }
  })
);

// ── meowtrack_node_update ────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_update",
  {
    title: "Modifier un nœud",
    description:
      "Met à jour les champs fournis d'un nœud (titre, description, NOTES markdown, statut, couleur, emoji, " +
      "échéance). `notes` remplace toute la liste de notes. La progression reste automatique.",
    inputSchema: {
      ref: nodeRefSchema,
      title: z.string().optional(),
      description: z.string().optional(),
      notes: notesSchema.optional(),
      status: z.enum(NODE_STATUSES).optional(),
      color: z.enum(NODE_COLORS).optional(),
      emoji: z.string().optional(),
      targetDate: z.string().nullable().optional().describe("'YYYY-MM-DD' ou null pour effacer."),
    },
  },
  guard(async ({ ref, ...fields }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref), fields))
);

// ── meowtrack_node_set_status (raccourci) ────────────────────────────────────
server.registerTool(
  "meowtrack_node_set_status",
  {
    title: "Changer le statut d'un nœud",
    description: "Raccourci : active / paused / done / abandoned. Passer à 'done' marque le jalon comme atteint.",
    inputSchema: { ref: nodeRefSchema, status: z.enum(NODE_STATUSES) },
  },
  guard(async ({ ref, status }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref), { status }))
);

// ── meowtrack_node_set_notes (raccourci) ─────────────────────────────────────
server.registerTool(
  "meowtrack_node_set_notes",
  {
    title: "Définir les notes d'un nœud",
    description:
      "Remplace la liste de notes markdown d'un nœud. Pour AJOUTER sans perdre l'existant, récupère d'abord " +
      "les notes via meowtrack_node_get puis renvoie l'ancienne liste + la nouvelle entrée.",
    inputSchema: { ref: nodeRefSchema, notes: notesSchema },
  },
  guard(async ({ ref, notes }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref), { notes }))
);

// ── meowtrack_node_move ──────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_move",
  {
    title: "Déplacer / rattacher un nœud",
    description:
      "Reparente un nœud (et tout son sous-arbre). `newParentId=null` → en fait un objectif racine. " +
      "Refusé si cela créerait un cycle. `position` ordonne parmi les nouveaux frères.",
    inputSchema: {
      ref: nodeRefSchema,
      newParentId: nodeRefSchema.nullable().describe("Nouveau parent, ou null pour détacher (racine)."),
      position: z.number().int().optional(),
    },
  },
  guard(async ({ ref, newParentId, position }) =>
    apiFetch("POST", "/api/nodes/" + encodeURIComponent(ref) + "/move", { newParentId: newParentId ?? null, position })
  )
);

// ── meowtrack_node_reorder ───────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_reorder",
  {
    title: "Réordonner les enfants d'un nœud",
    description: "Définit l'ordre des sous-nœuds directs d'un parent. `order` = liste d'ids enfants dans l'ordre voulu.",
    inputSchema: {
      ref: nodeRefSchema.describe("Le parent dont on réordonne les enfants."),
      order: z.array(z.union([z.string(), z.number()])).describe("Ids enfants dans le nouvel ordre."),
    },
  },
  guard(async ({ ref, order }) => apiFetch("POST", "/api/nodes/" + encodeURIComponent(ref) + "/reorder", { order }))
);

// ── meowtrack_node_delete ────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_delete",
  {
    title: "Supprimer un nœud",
    description: "Supprime un nœud ET tout son sous-arbre (cascade). Irréversible.",
    inputSchema: { ref: nodeRefSchema },
  },
  guard(async ({ ref }) => apiFetch("DELETE", "/api/nodes/" + encodeURIComponent(ref)))
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[meowtrack] MCP server prêt (stdio) → API ${BASE}.`);
