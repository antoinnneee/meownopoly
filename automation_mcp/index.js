#!/usr/bin/env node
// Serveur MCP (stdio) — pilote l'app Meownopoly via son serveur d'automation
// WebSocket embarqué (cpp/automation/automation_server.*).
//
// Lancement : node index.js  (configuré dans .mcp.json à la racine du repo).
// Port par défaut : MEOW_AUTOMATION_PORT ou 7700. Chaque tool accepte un
// paramètre `port` optionnel pour piloter une 2e instance (ex. 7701).

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { getClient } from "./ws-client.js";

const DEFAULT_PORT = Number(process.env.MEOW_AUTOMATION_PORT) || 7700;

// Paramètre `port` commun à tous les tools.
const portSchema = z
  .number()
  .int()
  .optional()
  .describe(
    `Port du serveur d'automation de l'app (défaut ${DEFAULT_PORT}, ou MEOW_AUTOMATION_PORT). ` +
      `Utiliser 7701 pour piloter l'instance 2 (dual_test_p2p).`
  );

// Cible commune (objectName | id pointeur | target).
const targetSchema = {
  objectName: z.string().optional().describe("objectName de l'item QML cible."),
  id: z
    .string()
    .optional()
    .describe("Identifiant stable (pointeur '0x...') retourné par qml_find/qml_tree."),
  className: z
    .string()
    .optional()
    .describe("Filtre optionnel sur le nom de classe C++/QML (contient, insensible à la casse)."),
};

const server = new McpServer({
  name: "meownopoly-automation",
  version: "1.0.0",
});

// Helper : envoie une commande et formate le résultat en contenu MCP texte (JSON).
async function call(port, cmd, params, timeoutMs) {
  const client = getClient(port ?? DEFAULT_PORT);
  try {
    const result = await client.send(cmd, params, timeoutMs);
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Erreur: ${err.message}` }],
      isError: true,
    };
  }
}

// ── app_ping ────────────────────────────────────────────────────────────────
server.registerTool(
  "app_ping",
  {
    title: "Ping de l'app",
    description:
      "Vérifie que l'app répond et retourne ses infos (nom, version, instance, " +
      "titre de fenêtre, scène QML courante). À appeler en premier pour confirmer la connexion.",
    inputSchema: { port: portSchema },
  },
  async ({ port }) => call(port, "ping", {})
);

// ── qml_tree ─────────────────────────────────────────────────────────────────
server.registerTool(
  "qml_tree",
  {
    title: "Arbre QML",
    description:
      "Retourne l'arbre des objets QML (objectName, className, geometry, visible, enabled) " +
      "à partir des fenêtres top-level, ou d'une cible donnée. Profondeur limitable et filtre optionnel.",
    inputSchema: {
      port: portSchema,
      depth: z.number().int().optional().describe("Profondeur maximale (défaut 3)."),
      filter: z
        .string()
        .optional()
        .describe("Filtre (sous-chaîne sur className/objectName) pour élaguer l'arbre."),
      ...targetSchema,
    },
  },
  async ({ port, depth, filter, objectName, id, className }) =>
    call(port, "tree", { depth, filter, objectName, id, className })
);

// ── qml_find ─────────────────────────────────────────────────────────────────
server.registerTool(
  "qml_find",
  {
    title: "Trouver des items QML",
    description:
      "Trouve les items par objectName (et/ou className). Retourne un id stable, la géométrie " +
      "(coords item + scène/fenêtre), visible et enabled. Utiliser l'id pour cibler get/set/invoke/click.",
    inputSchema: {
      port: portSchema,
      objectName: z.string().optional().describe("objectName recherché (égalité exacte)."),
      className: z
        .string()
        .optional()
        .describe("Filtre sur className (contient, insensible à la casse)."),
    },
  },
  async ({ port, objectName, className }) => call(port, "find", { objectName, className })
);

// ── qml_get ──────────────────────────────────────────────────────────────────
server.registerTool(
  "qml_get",
  {
    title: "Lire une propriété QML",
    description: "Lit une propriété d'un objet QML ciblé (objectName ou id).",
    inputSchema: {
      port: portSchema,
      ...targetSchema,
      property: z.string().describe("Nom de la propriété à lire."),
    },
  },
  async ({ port, objectName, id, className, property }) =>
    call(port, "get", { objectName, id, className, property })
);

// ── qml_set ──────────────────────────────────────────────────────────────────
server.registerTool(
  "qml_set",
  {
    title: "Écrire une propriété QML",
    description:
      "Écrit une propriété sur un objet QML ciblé. Attention : écraser un binding QML déclenche " +
      "des avertissements ; préférer invoke d'une méthode dédiée quand elle existe.",
    inputSchema: {
      port: portSchema,
      ...targetSchema,
      property: z.string().describe("Nom de la propriété à écrire."),
      value: z.any().describe("Nouvelle valeur (JSON, convertie en QVariant)."),
    },
  },
  async ({ port, objectName, id, className, property, value }) =>
    call(port, "set", { objectName, id, className, property, value })
);

// ── qml_invoke ───────────────────────────────────────────────────────────────
server.registerTool(
  "qml_invoke",
  {
    title: "Appeler une méthode QML",
    description:
      "Appelle une méthode Q_INVOKABLE/slot/fonction QML par nom sur un objet ciblé. " +
      "Surcharges résolues par arité (premier match). Retourne la valeur de retour si applicable.",
    inputSchema: {
      port: portSchema,
      ...targetSchema,
      method: z.string().describe("Nom de la méthode."),
      args: z.array(z.any()).optional().describe("Arguments JSON (défaut: aucun)."),
    },
  },
  async ({ port, objectName, id, className, method, args }) =>
    call(port, "invoke", { objectName, id, className, method, args: args ?? [] })
);

// ── mouse_click (+ double/press/release/move) ────────────────────────────────
const mouseInput = {
  port: portSchema,
  ...targetSchema,
  x: z.number().optional().describe("Coordonnée X en scène (alternative à une cible item)."),
  y: z.number().optional().describe("Coordonnée Y en scène (alternative à une cible item)."),
  offsetX: z.number().optional().describe("Offset X dans l'item (défaut: centre)."),
  offsetY: z.number().optional().describe("Offset Y dans l'item (défaut: centre)."),
};

for (const [tool, cmd, desc] of [
  ["mouse_click", "click", "Clic gauche (press+release) au centre de l'item ciblé ou à (x,y)."],
  ["mouse_double_click", "doubleClick", "Double-clic gauche sur l'item ciblé ou à (x,y)."],
  ["mouse_press", "press", "Enfonce le bouton gauche (sans relâcher)."],
  ["mouse_release", "release", "Relâche le bouton gauche."],
  ["mouse_move", "move", "Déplace le curseur (sans bouton enfoncé)."],
]) {
  server.registerTool(
    tool,
    { title: tool, description: desc, inputSchema: mouseInput },
    async ({ port, objectName, id, className, x, y, offsetX, offsetY }) =>
      call(port, cmd, { objectName, id, className, x, y, offsetX, offsetY })
  );
}

// ── mouse_wheel ──────────────────────────────────────────────────────────────
server.registerTool(
  "mouse_wheel",
  {
    title: "Molette souris",
    description:
      "Envoie un événement molette (pour tester le zoom de l'éditeur). delta positif = vers le haut.",
    inputSchema: {
      port: portSchema,
      ...targetSchema,
      x: z.number().optional().describe("X en scène."),
      y: z.number().optional().describe("Y en scène."),
      delta: z.number().int().optional().describe("angleDelta vertical (défaut 120 = 1 cran)."),
    },
  },
  async ({ port, objectName, id, className, x, y, delta }) =>
    call(port, "wheel", { objectName, id, className, x, y, delta })
);

// ── send_keys ────────────────────────────────────────────────────────────────
server.registerTool(
  "send_keys",
  {
    title: "Synthèse clavier",
    description:
      "Tape du texte (`text`) caractère par caractère, ou envoie une touche (`key` = valeur Qt::Key " +
      "numérique, ex. 16777220 = Enter) avec modifiers optionnels. Si une cible est fournie, lui donne le focus.",
    inputSchema: {
      port: portSchema,
      ...targetSchema,
      text: z.string().optional().describe("Texte à taper."),
      key: z.number().int().optional().describe("Valeur numérique Qt::Key."),
      modifiers: z
        .array(z.enum(["ctrl", "shift", "alt", "meta"]))
        .optional()
        .describe("Modifiers pour `key`."),
    },
  },
  async ({ port, objectName, id, className, text, key, modifiers }) =>
    call(port, "keys", { objectName, id, className, text, key, modifiers })
);

// ── screenshot ───────────────────────────────────────────────────────────────
server.registerTool(
  "screenshot",
  {
    title: "Capture d'écran",
    description:
      "Capture la fenêtre principale (grabWindow) en PNG. Retourne le chemin absolu du fichier " +
      "(lisible directement). `path` optionnel sinon dossier temp.",
    inputSchema: {
      port: portSchema,
      path: z.string().optional().describe("Chemin de sortie PNG (défaut: dossier temp)."),
    },
  },
  async ({ port, path }) => call(port, "screenshot", { path })
);

// ── wait_for ─────────────────────────────────────────────────────────────────
server.registerTool(
  "wait_for",
  {
    title: "Attendre un item / une condition",
    description:
      "Attend (polling côté app) qu'un item (objectName) existe, soit visible, ou qu'une propriété " +
      "atteigne une valeur. Timeout en ms (défaut 5000). Réponse différée jusqu'à satisfaction ou timeout.",
    inputSchema: {
      port: portSchema,
      objectName: z.string().describe("objectName attendu."),
      property: z.string().optional().describe("Propriété à surveiller (avec `value`)."),
      value: z.any().optional().describe("Valeur attendue de `property`."),
      visible: z.boolean().optional().describe("Attendre que l'item soit visible."),
      timeout: z.number().int().optional().describe("Timeout en ms (défaut 5000)."),
    },
  },
  async ({ port, objectName, property, value, visible, timeout }) =>
    call(port, "waitFor", { objectName, property, value, visible, timeout }, (timeout ?? 5000) + 5000)
);

// ════════════════════════════════════════════════════════════════════════════
// Commandes haut niveau ÉDITEUR
// ════════════════════════════════════════════════════════════════════════════
// Ces tools localisent les hooks QML (objectName="editorAutomationHooks",
// QtObject passif posé dans Editor.qml) via `find`, puis appellent leurs
// fonctions via `invoke`. Erreur claire si l'éditeur n'est pas ouvert.

// Localise le hook une fois et invoque `method` avec `args`.
async function invokeEditorHook(port, method, args) {
  const client = getClient(port ?? DEFAULT_PORT);
  // 1) Localiser le QtObject de hooks.
  const found = await client.send("find", {
    objectName: "editorAutomationHooks",
  });
  if (!Array.isArray(found) || found.length === 0) {
    throw new Error(
      "Hooks d'automation éditeur introuvables (objectName='editorAutomationHooks'). " +
        "L'éditeur n'est probablement pas ouvert."
    );
  }
  // 2) Invoquer la fonction par id stable.
  const res = await client.send("invoke", {
    id: found[0].id,
    method,
    args: args ?? [],
  });
  // res = { method, result }. On déballe la valeur de retour QML.
  return res && "result" in res ? res.result : res;
}

// Wrapper MCP : formate le retour JSON ou une erreur.
async function editorCall(port, method, args) {
  try {
    const result = await invokeEditorHook(port, method, args);
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
      // result.ok === false ⇒ remonter comme erreur côté MCP pour visibilité.
      isError: result && result.ok === false,
    };
  } catch (err) {
    return {
      content: [{ type: "text", text: `Erreur: ${err.message}` }],
      isError: true,
    };
  }
}

// ── editor_list_assets ───────────────────────────────────────────────────────
server.registerTool(
  "editor_list_assets",
  {
    title: "Lister les assets de l'éditeur",
    description:
      "Sans `category`/`type` : liste les catégories d'assets et leurs types disponibles. " +
      "Avec `category` ET `type` : liste les assets (id, filename, dimensions, ratio) de ce couple. " +
      "Requiert l'éditeur ouvert.",
    inputSchema: {
      port: portSchema,
      category: z
        .string()
        .optional()
        .describe("Catégorie d'asset (ex. 'decoration'). Avec `type`, liste les assets."),
      type: z
        .string()
        .optional()
        .describe("Type d'asset (ex. 'grass'). Requis avec `category` pour lister les assets."),
    },
  },
  async ({ port, category, type }) => {
    if (category && type)
      return editorCall(port, "listAssets", [category, type]);
    return editorCall(port, "listAssetCategories", []);
  }
);

// ── editor_place_item ────────────────────────────────────────────────────────
server.registerTool(
  "editor_place_item",
  {
    title: "Poser un asset dans l'éditeur",
    description:
      "Sélectionne programmatiquement l'asset (category/type/assetId) et le pose à la cellule " +
      "(gridX, gridY) via le même chemin que l'UI (compatible collab/undo). Retourne l'uuid et la " +
      "position de la tile créée. Le mode normal est restauré après la pose.",
    inputSchema: {
      port: portSchema,
      category: z.string().describe("Catégorie de l'asset (ex. 'decoration')."),
      type: z.string().describe("Type de l'asset (ex. 'grass')."),
      assetId: z.string().describe("Identifiant de l'asset (ex. 'grass_01')."),
      gridX: z.number().int().describe("Coordonnée X en cellules de grille."),
      gridY: z.number().int().describe("Coordonnée Y en cellules de grille."),
    },
  },
  async ({ port, category, type, assetId, gridX, gridY }) =>
    editorCall(port, "placeAsset", [assetId, category, type, gridX, gridY])
);

// ── editor_place_case ────────────────────────────────────────────────────────
server.registerTool(
  "editor_place_case",
  {
    title: "Poser une case typée dans l'éditeur",
    description:
      "Pose une case typée (caseType = valeur Case::CaseType) à la cellule (gridX, gridY) via le " +
      "chemin UI. Retourne l'uuid et la position de la case créée.",
    inputSchema: {
      port: portSchema,
      caseType: z.number().int().describe("Valeur numérique du Case::CaseType à poser."),
      gridX: z.number().int().describe("Coordonnée X en cellules de grille."),
      gridY: z.number().int().describe("Coordonnée Y en cellules de grille."),
    },
  },
  async ({ port, caseType, gridX, gridY }) =>
    editorCall(port, "placeCase", [caseType, gridX, gridY])
);

// ── editor_place_zone ────────────────────────────────────────────────────────
server.registerTool(
  "editor_place_zone",
  {
    title: "Créer une zone physique polygonale dans l'éditeur",
    description:
      "Crée une zone physique (PhysicZoneTile : zone d'exclusion ou zone d'effet) définie par un " +
      "polygone d'au moins 3 points en coordonnées GRILLE ABSOLUES, sans passer par le mode dessin. " +
      "Même chemin que l'UI (compatible collab/undo). Par défaut la zone est une zone d'exclusion ; " +
      "passer exclusion=false + velocity*/friction*/multipliers pour une zone d'effet. " +
      "Retourne l'uuid, la position/taille de la tile et le nombre de points.",
    inputSchema: {
      port: portSchema,
      points: z
        .array(z.object({ x: z.number(), y: z.number() }))
        .min(3)
        .describe("Sommets du polygone en coordonnées grille absolues (≥ 3 points, réels acceptés)."),
      color: z.string().optional().describe("Couleur de la zone '#RRGGBB' (défaut '#FF5722')."),
      name: z.string().optional().describe("Nom de la zone (défaut '')."),
      exclusion: z
        .boolean()
        .optional()
        .describe("true = zone d'exclusion (mur, défaut) ; false = zone d'effet (vent/friction/boost)."),
      velocityX: z.number().optional().describe("Direction X de la vélocité appliquée (zone d'effet)."),
      velocityY: z.number().optional().describe("Direction Y de la vélocité appliquée (zone d'effet)."),
      velocityStrength: z.number().optional().describe("Force de la vélocité (défaut 0)."),
      frictionStrength: z.number().optional().describe("Friction additionnelle (défaut 0)."),
      speedMultiplier: z.number().optional().describe("Multiplicateur de vitesse max (défaut 1.0)."),
      accelerationMultiplier: z.number().optional().describe("Multiplicateur d'accélération (défaut 1.0)."),
    },
  },
  async ({ port, points, ...options }) =>
    editorCall(port, "placeZone", [points, options])
);

// ── editor_camera_get ────────────────────────────────────────────────────────
server.registerTool(
  "editor_camera_get",
  {
    title: "État de la caméra éditeur",
    description:
      "Retourne le centre de la vue en coordonnées grille, le niveau de zoom (scaleLevel/mmSize/" +
      "gridSize) et la taille du viewport.",
    inputSchema: { port: portSchema },
  },
  async ({ port }) => editorCall(port, "getCamera", [])
);

// ── editor_camera_center ─────────────────────────────────────────────────────
server.registerTool(
  "editor_camera_center",
  {
    title: "Centrer la caméra éditeur",
    description:
      "Pan absolu : centre la vue sur la cellule (gridX, gridY). Resynchronise la caméra 3D. " +
      "Retourne le nouvel état caméra.",
    inputSchema: {
      port: portSchema,
      gridX: z.number().describe("Coordonnée X (cellules) à centrer."),
      gridY: z.number().describe("Coordonnée Y (cellules) à centrer."),
    },
  },
  async ({ port, gridX, gridY }) =>
    editorCall(port, "setCamera", [gridX, gridY])
);

// ── editor_camera_pan ────────────────────────────────────────────────────────
server.registerTool(
  "editor_camera_pan",
  {
    title: "Pan relatif de la caméra éditeur",
    description:
      "Déplace la vue de (dx, dy) cellules. Retourne le nouvel état caméra.",
    inputSchema: {
      port: portSchema,
      dx: z.number().describe("Déplacement X en cellules (positif = vers la droite du contenu)."),
      dy: z.number().describe("Déplacement Y en cellules."),
    },
  },
  async ({ port, dx, dy }) => editorCall(port, "panCamera", [dx, dy])
);

// ── editor_camera_zoom ───────────────────────────────────────────────────────
server.registerTool(
  "editor_camera_zoom",
  {
    title: "Zoom de la caméra éditeur",
    description:
      "Zoome de ±N crans (×1.1 par cran), centré sur le viewport, comme la molette de l'UI. " +
      "steps positif = zoom in. Retourne le nouvel état caméra.",
    inputSchema: {
      port: portSchema,
      steps: z.number().int().describe("Nombre de crans (positif = zoom in, négatif = zoom out)."),
    },
  },
  async ({ port, steps }) => editorCall(port, "zoomCamera", [steps])
);

// ── app_quit ─────────────────────────────────────────────────────────────────
server.registerTool(
  "app_quit",
  {
    title: "Quitter l'app",
    description: "Ferme proprement l'application.",
    inputSchema: { port: portSchema },
  },
  async ({ port }) => call(port, "quit", {})
);

// Démarrage du transport stdio.
const transport = new StdioServerTransport();
await server.connect(transport);
console.error("[meownopoly-automation] MCP server prêt (stdio).");
