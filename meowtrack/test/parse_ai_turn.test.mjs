// parse_ai_turn.test.mjs — test de régression isolé du parsing IA de Good Vibes.
//
// parseAiTurn (server.js) sépare le texte conversationnel des actions structurées
// renvoyées par `claude -p`. Il doit être FAIL-CLOSED : au moindre doute, zéro
// action et le texte affiché tel quel (jamais de mutation devinée).
//
// Lancement (depuis meowtrack/) :  node test/parse_ai_turn.test.mjs
// MEOWTRACK_NO_LISTEN=1 évite de démarrer le serveur HTTP à l'import ; une base
// SQLite temporaire isole le test (le pipeline parse→apply touche la base).

import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

process.env.MEOWTRACK_NO_LISTEN = "1";
process.env.MEOWTRACK_DB = join(mkdtempSync(join(tmpdir(), "meowtrack-test-")), "parse.db");

const { parseAiTurn } = await import("../server.js");
const db = await import("../db.js");

let pass = 0;
let fail = 0;
function check(name, cond) {
  if (cond) pass++;
  else {
    fail++;
    console.error("  ✗ FAIL:", name);
  }
}

// 1. sentinelle + fence json
let r = parseAiTurn(
  'Voici mon analyse.\n<<<MEOWTRACK_ACTIONS>>>\n```json\n{"actions":[{"op":"add_milestone","title":"X"}],"note":"ajout"}\n```'
);
check("sentinel+fence: texte", r.text === "Voici mon analyse.");
check("sentinel+fence: action", r.actions.length === 1 && r.actions[0].op === "add_milestone");
check("sentinel+fence: note", r.note === "ajout");

// 2. fence json sans sentinelle (accepté car contient "actions")
r = parseAiTurn('Texte.\n```json\n{"actions":[{"op":"set_goal_fields","status":"done"}]}\n```\nfin');
check("fence-only: action", r.actions.length === 1 && r.actions[0].op === "set_goal_fields");

// 3. prose pure → 0 action, non malformed
r = parseAiTurn("Tu devrais ajouter un jalon pour le build vert. Qu'en penses-tu ?");
check("prose: 0 action", r.actions.length === 0 && r.malformed === false);
check("prose: texte préservé", r.text.includes("build vert"));

// 4. JSON malformé (guillemets typographiques + virgule traînante) réparé
r = parseAiTurn('ok\n<<<MEOWTRACK_ACTIONS>>>\n{“actions”:[{“op”:“add_milestone”,“title”:“Y”},],}');
check("réparation smart-quotes + virgule", r.actions.length === 1 && r.actions[0].op === "add_milestone");

// 5. sentinelle mais JSON cassé irréparable → 0 action + malformed
r = parseAiTurn("ok\n<<<MEOWTRACK_ACTIONS>>>\n{ ceci n'est pas du json {{{");
check("json cassé → malformed", r.actions.length === 0 && r.malformed === true);

// 6. objet équilibré sans fence (json brut après la sentinelle)
r = parseAiTurn('ok\n<<<MEOWTRACK_ACTIONS>>>\n{"actions":[{"op":"delete_milestone","id":3}],"note":"x"} suite');
check("objet équilibré extrait", r.actions.length === 1 && r.actions[0].op === "delete_milestone");

// 7. blob géant → malformed, 0 action
r = parseAiTurn("ok\n<<<MEOWTRACK_ACTIONS>>>\n" + "x".repeat(70000));
check("blob géant → malformed", r.actions.length === 0 && r.malformed === true);

// 8. faux positif : un ```json sans "actions" ne produit PAS d'action
r = parseAiTurn('Exemple :\n```json\n{"foo":1}\n```');
check("fence sans actions → ignoré", r.actions.length === 0 && r.malformed === false);

// 9. pipeline complet parse → applyNodeActions (tmpKey, add_node, reorder_children)
const g = db.createNode(null, { title: "Pipeline" });
const ai =
  'Je crée deux sous-jalons.\n<<<MEOWTRACK_ACTIONS>>>\n```json\n' +
  '{"actions":[{"op":"add_node","title":"Sous A","tmpKey":"a"},' +
  '{"op":"add_node","title":"Sous B","status":"done"},' +
  '{"op":"reorder_children","order":["a"]}],"note":"2 sous-jalons"}\n```';
const parsed = parseAiTurn(ai);
const applied = db.applyNodeActions(g.id, parsed.actions);
check("pipeline: 3 actions appliquées", applied.applied.length === 3);
const after = db.getNode(g.id, { withTree: true });
check("pipeline: 2 sous-nœuds", after.children.length === 2);
check("pipeline: progression 50%", after.progress === 50);
// action hors-scope rejetée (id inexistant hors sous-arbre)
const rej = db.applyNodeActions(g.id, [{ op: "update_node", id: 999999, title: "x" }]);
check("pipeline: hors-scope rejeté", rej.applied.length === 0 && rej.rejected.length === 1);

console.log(`\nparseAiTurn : ${pass} OK, ${fail} FAIL`);
process.exit(fail ? 1 : 0);
