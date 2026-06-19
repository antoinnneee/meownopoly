#!/usr/bin/env node
// mcp.js — serveur MCP (stdio) du suivi Meowtrack.
//
// Client de l'API HTTP du dashboard déployé : toutes les requêtes passent par le
// serveur distant (server.js), qui est la SEULE source de vérité (base SQLite +
// repos clonés). Le MCP ne touche JAMAIS de base locale — il relaie vers le serveur.
// Lancement : node mcp.js (configuré dans .mcp.json racine). Aucune dépendance à
// l'app Qt.
//
// MULTI-REPOS : le suivi gère plusieurs dépôts git distincts. Chaque entrée /
// nœud appartient à UN repo. Le paramètre `repo` (slug ou id, ex. 'meownopoly')
// cible le repo ; omis, le serveur retombe sur le repo par défaut. Un défaut local
// peut être fixé via MEOWTRACK_DEFAULT_REPO (injecté si l'appel n'en fournit pas).
//
// Config (env ou meowtrack/.env, chargé explicitement quel que soit le cwd) :
//   MEOWTRACK_SERVER_URL    base de l'API (défaut http://127.0.0.1:7702 ; en prod
//                           ex. http://pattounecorp.ovh:7702).
//   MEOWTRACK_TOKEN         jeton Bearer si le serveur en exige un (sinon vide).
//   MEOWTRACK_DEFAULT_REPO  repo (slug/id) appliqué quand un appel n'en précise pas.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import dotenv from "dotenv";

const HERE = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: join(HERE, ".env") });

// Énumérations (doivent rester alignées sur db.js — dupliquées ici pour ne pas
// importer db.js, dont l'import ouvrirait une base SQLite locale).
const TYPES = ["bug", "feature", "task", "chore"];
const STATUSES = ["open", "in_progress", "done", "wontfix"];
const PRIORITIES = ["low", "medium", "high", "critical"];
const NODE_STATUSES = ["active", "paused", "done", "abandoned"];
const NODE_COLORS = ["accent", "feature", "task", "bug", "high"];

const BASE = (process.env.MEOWTRACK_SERVER_URL || "http://127.0.0.1:7702").replace(/\/+$/, "");
const TOKEN = (process.env.MEOWTRACK_TOKEN || "").trim();
const DEFAULT_REPO = (process.env.MEOWTRACK_DEFAULT_REPO || "").trim();

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
// Résout le repo effectif d'un appel (param explicite sinon défaut local). Peut
// être undefined → le serveur utilisera SON repo par défaut.
function repoOf(repo) {
  return repo != null && repo !== "" ? String(repo) : DEFAULT_REPO || undefined;
}

const server = new McpServer({ name: "meowtrack", version: "1.0.0" });

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
// Paramètre repo commun à (presque) tous les outils.
const repoParam = z
  .union([z.string(), z.number()])
  .optional()
  .describe("Repo cible (slug ou id, ex. 'meownopoly'). Omis : repo par défaut du serveur. Voir meowtrack_repos.");

// ═══════════════════════════════════════════════════════════════════════════
// Repos — registre des dépôts git suivis.
// ═══════════════════════════════════════════════════════════════════════════
server.registerTool(
  "meowtrack_repos",
  {
    title: "Lister les repos suivis",
    description:
      "Liste les dépôts git du registre (slug, nom, url, branche par défaut, repo par défaut). Le `slug` " +
      "ou l'`id` sert de paramètre `repo` aux autres outils. Les entrées/nœuds sont scopés par repo.",
    inputSchema: {},
  },
  guard(async () => apiGet("/api/repos"))
);
server.registerTool(
  "meowtrack_repo_add",
  {
    title: "Ajouter un repo",
    description:
      "Enregistre un nouveau dépôt git à suivre (et le clone immédiatement si une `url` est fournie). " +
      "Le `slug` est dérivé de l'url s'il n'est pas donné. Retourne le repo créé + le rapport de clone.",
    inputSchema: {
      slug: z.string().optional().describe("Identifiant court (ex. 'chatserver'). Dérivé de l'url si absent."),
      name: z.string().optional().describe("Libellé affiché (défaut : slug)."),
      url: z.string().optional().describe("URL git de clone (https/ssh). Absente : clone géré à la main / dev in-repo."),
      localPath: z.string().optional().describe("Chemin de clone explicite (sinon .repos/<slug>/)."),
      defaultBranch: z.string().optional().describe("Branche par défaut pour l'autocomplete/contexte."),
      isDefault: z.boolean().optional().describe("Faire de ce repo le repo par défaut."),
    },
  },
  guard(async (a) => apiFetch("POST", "/api/repos", a))
);
server.registerTool(
  "meowtrack_repo_update",
  {
    title: "Mettre à jour un repo (pull) ou ses métadonnées",
    description:
      "Sans autre champ : clone (si absent) ou git fetch+pull du repo. Avec des champs (name/url/localPath/" +
      "defaultBranch/isDefault) : modifie le registre. `action='pull'` force le pull même avec des champs.",
    inputSchema: {
      repo: z.union([z.string(), z.number()]).describe("Repo cible (slug ou id)."),
      action: z.enum(["pull", "edit"]).optional().describe("'pull' (défaut si aucun champ) ou 'edit' (métadonnées)."),
      name: z.string().optional(),
      url: z.string().optional(),
      localPath: z.string().optional(),
      defaultBranch: z.string().optional(),
      isDefault: z.boolean().optional(),
    },
  },
  guard(async ({ repo, action, ...fields }) => {
    const key = encodeURIComponent(String(repo));
    const hasEdits = Object.keys(fields).length > 0;
    if (action === "edit" || (hasEdits && action !== "pull")) {
      const updated = await apiFetch("PATCH", "/api/repos/" + key, fields);
      return action === "pull" || !hasEdits ? { ...updated, ...(await apiFetch("POST", "/api/repos/" + key + "/update")) } : updated;
    }
    return apiFetch("POST", "/api/repos/" + key + "/update");
  })
);
server.registerTool(
  "meowtrack_repo_remove",
  {
    title: "Supprimer un repo",
    description: "Retire un dépôt du registre ET toutes ses entrées/nœuds (cascade). Le dernier repo ne peut pas être supprimé. Irréversible.",
    inputSchema: { repo: z.union([z.string(), z.number()]).describe("Repo cible (slug ou id).") },
  },
  guard(async ({ repo }) => apiFetch("DELETE", "/api/repos/" + encodeURIComponent(String(repo))))
);

// ── meowtrack_create ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_create",
  {
    title: "Créer un bug / feature / tâche",
    description:
      "Enregistre une nouvelle entrée de suivi dans un repo. `type` ∈ {bug,feature,task,chore}. Les chemins " +
      "de `paths` sont validés contre le repo cloné (existence + contexte git capturés). Tout token `@chemin` " +
      "(ou `@chemin:120-145`) présent dans `description` est aussi ajouté en référence. Retourne l'issue créée " +
      "(code ex. BUG-1, numéroté PAR repo).",
    inputSchema: {
      repo: repoParam,
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
  guard(async ({ repo, ...a }) => apiFetch("POST", "/api/issues" + qs({ repo: repoOf(repo) }), a))
);

// ── meowtrack_list ───────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_list",
  {
    title: "Lister / filtrer les entrées",
    description:
      "Liste les entrées de suivi d'un repo, triées par activité puis priorité. Par défaut masque les entrées " +
      "closes (done/wontfix) — passer includeClosed=true pour tout voir. Filtres combinables.",
    inputSchema: {
      repo: repoParam,
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
  guard(async ({ repo, ...a }) => apiGet("/api/issues" + qs({ repo: repoOf(repo), ...a })))
);

// ── meowtrack_get ────────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_get",
  {
    title: "Détail d'une entrée",
    description:
      "Retourne une entrée complète (références + commentaires) par code (ex. 'BUG-1') ou id numérique. " +
      "Les codes étant numérotés PAR repo, préciser `repo` quand on cible par code.",
    inputSchema: { repo: repoParam, ref: z.string().describe("Code (BUG-1, FEAT-2…) ou id numérique.") },
  },
  guard(async ({ repo, ref }) => {
    try {
      return await apiGet("/api/issues/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }));
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
      repo: repoParam,
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
  guard(async ({ repo, ref, ...fields }) => apiFetch("PATCH", "/api/issues/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }), fields))
);

// ── meowtrack_set_status (raccourci) ─────────────────────────────────────────
server.registerTool(
  "meowtrack_set_status",
  {
    title: "Changer le statut",
    description: "Raccourci pour passer une entrée à open / in_progress / done / wontfix.",
    inputSchema: {
      repo: repoParam,
      ref: z.string().describe("Code ou id de l'entrée."),
      status: z.enum(STATUSES).describe("Nouveau statut."),
    },
  },
  guard(async ({ repo, ref, status }) => apiFetch("PATCH", "/api/issues/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }), { status }))
);

// ── meowtrack_delete ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_delete",
  {
    title: "Supprimer une entrée",
    description: "Supprime définitivement une entrée et ses références/commentaires (cascade).",
    inputSchema: { repo: repoParam, ref: z.string().describe("Code ou id de l'entrée.") },
  },
  guard(async ({ repo, ref }) => apiFetch("DELETE", "/api/issues/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) })))
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
      repo: repoParam,
      ref: z.string().describe("Code ou id de l'entrée."),
      path: refSpecSchema,
    },
  },
  guard(async ({ repo, ref, path }) =>
    apiFetch("POST", "/api/issues/" + encodeURIComponent(ref) + "/references" + qs({ repo: repoOf(repo) }), { path })
  )
);

// ── meowtrack_remove_reference ───────────────────────────────────────────────
server.registerTool(
  "meowtrack_remove_reference",
  {
    title: "Retirer une référence",
    description: "Supprime une référence par son id (visible dans le détail de l'entrée). L'id est global, indépendant du repo.",
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
      repo: repoParam,
      ref: z.string().describe("Code ou id de l'entrée."),
      body: z.string().describe("Contenu du commentaire."),
    },
  },
  guard(async ({ repo, ref, body }) =>
    apiFetch("POST", "/api/issues/" + encodeURIComponent(ref) + "/comments" + qs({ repo: repoOf(repo) }), { body })
  )
);

// ── meowtrack_search_paths (feature « @ ») ───────────────────────────────────
server.registerTool(
  "meowtrack_search_paths",
  {
    title: "Rechercher des chemins du repo",
    description:
      "Autocomplete des fichiers/dossiers suivis par git sur le serveur (même source que le « @ » du " +
      "dashboard) pour un repo donné. Sert à découvrir les chemins exacts à associer à une entrée. Trié par pertinence.",
    inputSchema: {
      repo: repoParam,
      query: z.string().optional().describe("Sous-chaîne à rechercher (vide = premiers chemins)."),
      limit: z.number().int().optional().describe("Nombre max de résultats (défaut 30)."),
      branch: z.string().optional().describe("Chercher dans l'arbre de cette branche (défaut : branche checkout du serveur)."),
    },
  },
  guard(async ({ repo, query, limit, branch }) => apiGet("/api/paths" + qs({ repo: repoOf(repo), q: query, limit, branch })))
);

// ── meowtrack_branches ───────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_branches",
  {
    title: "Lister les branches d'un repo",
    description:
      "Branches connues du clone serveur d'un repo (pour rattacher une entrée ou cibler l'autocomplete d'une " +
      "branche précise). Renvoie { branches: [...], current }.",
    inputSchema: { repo: repoParam },
  },
  guard(async ({ repo }) => apiGet("/api/branches" + qs({ repo: repoOf(repo) })))
);

// ── meowtrack_stats ──────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_stats",
  {
    title: "Statistiques de suivi",
    description: "Compte des entrées d'un repo par statut / type / priorité, plus le contexte git courant, la racine du clone et le registre des repos.",
    inputSchema: { repo: repoParam },
  },
  guard(async ({ repo }) => apiGet("/api/meta" + qs({ repo: repoOf(repo) })))
);

// ── meowtrack_refresh_paths ──────────────────────────────────────────────────
server.registerTool(
  "meowtrack_refresh_paths",
  {
    title: "Rafraîchir l'index des chemins",
    description: "Force un nouveau scan des chemins d'un repo côté serveur (après un pull / changement de branche / nouveaux fichiers).",
    inputSchema: { repo: repoParam },
  },
  guard(async ({ repo }) => apiFetch("POST", "/api/paths/refresh" + qs({ repo: repoOf(repo) })))
);

// ═══════════════════════════════════════════════════════════════════════════
// Good Vibes — arbre de NŒUDS récursif (objectifs / jalons / sous-jalons), scopé repo.
// ═══════════════════════════════════════════════════════════════════════════
const nodeRefSchema = z.union([z.string(), z.number()]).describe("Code (ex. 'NODE-1') ou id numérique du nœud.");
const notesSchema = z
  .array(z.object({ title: z.string().optional().describe("Titre de la section (optionnel)."), body: z.string().describe("Corps markdown.") }))
  .describe("Liste de notes markdown [{title, body}]. REMPLACE toutes les notes existantes (reprends l'existant pour compléter).");

// ── meowtrack_node_create ────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_create",
  {
    title: "Créer un nœud (objectif / jalon)",
    description:
      "Crée un nœud Good Vibes dans un repo. Sans `parentId` → objectif racine. Avec `parentId` → sous-jalon " +
      "(qui hérite du repo du parent). La progression est dérivée automatiquement (ne pas la fixer). Retourne le nœud créé (code NODE-N, numéroté par repo).",
    inputSchema: {
      repo: repoParam,
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
  guard(async ({ repo, ...a }) => apiFetch("POST", "/api/nodes" + qs({ repo: repoOf(repo) }), a))
);

// ── meowtrack_node_list ──────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_list",
  {
    title: "Lister les nœuds (forêt ou racines)",
    description:
      "Liste les nœuds d'un repo. `view='forest'` (défaut) renvoie TOUT l'arbre à plat (avec parentId/depth) — " +
      "idéal pour comprendre la structure. `view='roots'` ne renvoie que les objectifs racines.",
    inputSchema: {
      repo: repoParam,
      view: z.enum(["forest", "roots"]).optional().describe("'forest' (tout, défaut) ou 'roots' (racines seules)."),
      status: z.enum(NODE_STATUSES).optional().describe("Filtre statut (racines uniquement)."),
      text: z.string().optional().describe("Recherche plein-texte (racines uniquement)."),
      limit: z.number().int().optional(),
    },
  },
  guard(async ({ repo, view, ...rest }) =>
    (view ?? "forest") === "forest"
      ? apiGet("/api/nodes" + qs({ repo: repoOf(repo), view: "forest" }))
      : apiGet("/api/nodes" + qs({ repo: repoOf(repo), ...rest }))
  )
);

// ── meowtrack_node_get ───────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_get",
  {
    title: "Détail d'un nœud (+ sous-arbre)",
    description: "Retourne un nœud complet (notes incluses) et, par défaut, son sous-arbre imbriqué (children). Préciser `repo` quand on cible par code.",
    inputSchema: {
      repo: repoParam,
      ref: nodeRefSchema,
      tree: z.boolean().optional().describe("Inclure le sous-arbre imbriqué (défaut true)."),
      messages: z.boolean().optional().describe("Inclure l'historique de chat du nœud (défaut false)."),
    },
  },
  guard(async ({ repo, ref, tree, messages }) => {
    try {
      return await apiGet(
        "/api/nodes/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo), tree: tree === false ? "false" : undefined, messages: messages ? "true" : undefined })
      );
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
      repo: repoParam,
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
  guard(async ({ repo, ref, ...fields }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }), fields))
);

// ── meowtrack_node_set_status (raccourci) ────────────────────────────────────
server.registerTool(
  "meowtrack_node_set_status",
  {
    title: "Changer le statut d'un nœud",
    description: "Raccourci : active / paused / done / abandoned. Passer à 'done' marque le jalon comme atteint.",
    inputSchema: { repo: repoParam, ref: nodeRefSchema, status: z.enum(NODE_STATUSES) },
  },
  guard(async ({ repo, ref, status }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }), { status }))
);

// ── meowtrack_node_set_notes (raccourci) ─────────────────────────────────────
server.registerTool(
  "meowtrack_node_set_notes",
  {
    title: "Définir les notes d'un nœud",
    description:
      "Remplace la liste de notes markdown d'un nœud. Pour AJOUTER sans perdre l'existant, récupère d'abord " +
      "les notes via meowtrack_node_get puis renvoie l'ancienne liste + la nouvelle entrée.",
    inputSchema: { repo: repoParam, ref: nodeRefSchema, notes: notesSchema },
  },
  guard(async ({ repo, ref, notes }) => apiFetch("PATCH", "/api/nodes/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) }), { notes }))
);

// ── meowtrack_node_move ──────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_move",
  {
    title: "Déplacer / rattacher un nœud",
    description:
      "Reparente un nœud (et tout son sous-arbre) DANS LE MÊME repo. `newParentId=null` → en fait un objectif " +
      "racine. Refusé si cela créerait un cycle ou traverserait deux repos. `position` ordonne parmi les nouveaux frères.",
    inputSchema: {
      repo: repoParam,
      ref: nodeRefSchema,
      newParentId: nodeRefSchema.nullable().describe("Nouveau parent, ou null pour détacher (racine)."),
      position: z.number().int().optional(),
    },
  },
  guard(async ({ repo, ref, newParentId, position }) =>
    apiFetch("POST", "/api/nodes/" + encodeURIComponent(ref) + "/move" + qs({ repo: repoOf(repo) }), { newParentId: newParentId ?? null, position })
  )
);

// ── meowtrack_node_reorder ───────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_reorder",
  {
    title: "Réordonner les enfants d'un nœud",
    description: "Définit l'ordre des sous-nœuds directs d'un parent. `order` = liste d'ids enfants dans l'ordre voulu.",
    inputSchema: {
      repo: repoParam,
      ref: nodeRefSchema.describe("Le parent dont on réordonne les enfants."),
      order: z.array(z.union([z.string(), z.number()])).describe("Ids enfants dans le nouvel ordre."),
    },
  },
  guard(async ({ repo, ref, order }) => apiFetch("POST", "/api/nodes/" + encodeURIComponent(ref) + "/reorder" + qs({ repo: repoOf(repo) }), { order }))
);

// ── meowtrack_node_delete ────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_node_delete",
  {
    title: "Supprimer un nœud",
    description: "Supprime un nœud ET tout son sous-arbre (cascade). Irréversible.",
    inputSchema: { repo: repoParam, ref: nodeRefSchema },
  },
  guard(async ({ repo, ref }) => apiFetch("DELETE", "/api/nodes/" + encodeURIComponent(ref) + qs({ repo: repoOf(repo) })))
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error(`[meowtrack] MCP server prêt (stdio) → API ${BASE}.`);
