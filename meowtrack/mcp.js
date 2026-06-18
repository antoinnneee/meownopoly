#!/usr/bin/env node
// mcp.js — serveur MCP (stdio) du suivi Meowtrack.
//
// Expose les bugs / features / tâches stockés dans meowtrack.db et les chemins
// du repo git cloné. Lancement : node mcp.js (configuré dans .mcp.json racine).
// Aucune dépendance à l'app Qt : c'est un service de données autonome.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import {
  TYPES,
  STATUSES,
  PRIORITIES,
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
      paths: z.array(refSpecSchema).optional().describe("Fichiers/dossiers associés (validés contre le repo)."),
    },
  },
  guard(async (a) => createIssue(a))
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
      tag: z.string().optional().describe("Ne garder que les entrées portant cette étiquette."),
      path: z.string().optional().describe("Ne garder que les entrées référençant un chemin contenant cette sous-chaîne."),
      text: z.string().optional().describe("Recherche plein-texte sur titre/description/ref."),
      includeClosed: z.boolean().optional().describe("Inclure les entrées done/wontfix (défaut false)."),
      limit: z.number().int().optional().describe("Nombre max d'entrées (défaut 200)."),
    },
  },
  guard(async (a) => listIssues(a))
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
    const issue = getIssue(ref);
    if (!issue) throw new Error(`Issue introuvable : ${ref}`);
    return issue;
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
      paths: z.array(refSpecSchema).optional().describe("Remplace TOUTES les références par cette liste."),
    },
  },
  guard(async ({ ref, ...fields }) => updateIssue(ref, fields))
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
  guard(async ({ ref, status }) => updateIssue(ref, { status }))
);

// ── meowtrack_delete ─────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_delete",
  {
    title: "Supprimer une entrée",
    description: "Supprime définitivement une entrée et ses références/commentaires (cascade).",
    inputSchema: { ref: z.string().describe("Code ou id de l'entrée.") },
  },
  guard(async ({ ref }) => ({ deleted: deleteIssue(ref), ref }))
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
  guard(async ({ ref, path }) => {
    const issue = getIssue(ref);
    if (!issue) throw new Error(`Issue introuvable : ${ref}`);
    addReference(issue.id, path);
    return getIssue(issue.id);
  })
);

// ── meowtrack_remove_reference ───────────────────────────────────────────────
server.registerTool(
  "meowtrack_remove_reference",
  {
    title: "Retirer une référence",
    description: "Supprime une référence par son id (visible dans le détail de l'entrée).",
    inputSchema: { referenceId: z.number().int().describe("id de la référence à retirer.") },
  },
  guard(async ({ referenceId }) => ({ removed: removeReference(referenceId), referenceId }))
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
  guard(async ({ ref, body }) => addComment(ref, body))
);

// ── meowtrack_search_paths (feature « @ ») ───────────────────────────────────
server.registerTool(
  "meowtrack_search_paths",
  {
    title: "Rechercher des chemins du repo",
    description:
      "Autocomplete des fichiers/dossiers suivis par git (même source que le « @ » du dashboard). " +
      "Sert à découvrir les chemins exacts à associer à une entrée. Trié par pertinence.",
    inputSchema: {
      query: z.string().optional().describe("Sous-chaîne à rechercher (vide = premiers chemins)."),
      limit: z.number().int().optional().describe("Nombre max de résultats (défaut 30)."),
    },
  },
  guard(async ({ query, limit }) => searchPaths(query || "", limit || 30))
);

// ── meowtrack_stats ──────────────────────────────────────────────────────────
server.registerTool(
  "meowtrack_stats",
  {
    title: "Statistiques de suivi",
    description: "Compte des entrées par statut / type / priorité, plus le contexte git courant et la racine du repo.",
    inputSchema: {},
  },
  guard(async () => ({ ...stats(), git: gitContext(), repoRoot: repoRoot() }))
);

// ── meowtrack_refresh_paths ──────────────────────────────────────────────────
server.registerTool(
  "meowtrack_refresh_paths",
  {
    title: "Rafraîchir l'index des chemins",
    description: "Force un nouveau `git ls-files` (après un pull / changement de branche / nouveaux fichiers).",
    inputSchema: {},
  },
  guard(async () => refreshPaths())
);

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[meowtrack] MCP server prêt (stdio).");
