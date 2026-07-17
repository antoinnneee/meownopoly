#!/usr/bin/env node
/*
 * generate_ai_skill.js — Générateur de skill du canal IA (V3, tâche C8 / M12 minimal, D17).
 *
 * Source de vérité UNIQUE : le manifeste versionné du canal
 *   Meownopoly/cpp/ai/gateway/channel_manifest.json  (P0-4, décisions D43/D44).
 *
 * Produit deux couches (doc/v3/03_SKILL_CLIENT_IA.md §3) :
 *   1. Couche lisible par un agent générique : SKILL.md
 *      (front-matter YAML name/description + corps procédural : boucle
 *       perception→action, catalogue par rôle, garde-fous, recettes).
 *      C'est le pré-prompt injecté au spawn de l'agent (D10/D17/D20).
 *   2. Couche machine : channel_contract.json — sous-ensemble curé, stable et
 *      machine-lisible du manifeste (rôles, tools, params, quotas, enveloppe),
 *      débarrassé des métadonnées de gouvernance ($meow_status, $doc, …).
 *
 * La skill est versionnée avec le protocolVersion global du manifeste (D17/§5).
 * La validation de dérive en CI (échec build si non régénéré) est un chantier
 * ultérieur (M12/T5-2) — hors périmètre de cette v1.
 *
 * Aucune dépendance externe : Node built-ins uniquement (fs, path).
 *
 * Usage :
 *   node scripts/generate_ai_skill.js [--manifest <path>] [--out-dir <path>] [--check]
 *
 *   --manifest  chemin du manifeste (défaut : Meownopoly/cpp/ai/gateway/channel_manifest.json)
 *   --out-dir   dossier de sortie   (défaut : <dir(manifeste)>/generated)
 *   --check     ne rien écrire ; sortie code 1 si un fichier généré diffère de
 *               ce qui serait produit (préfiguration de la validation de dérive CI, M12).
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Arguments & chemins par défaut
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { manifest: null, outDir: null, check: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--manifest') args.manifest = argv[++i];
    else if (a === '--out-dir') args.outDir = argv[++i];
    else if (a === '--check') args.check = true;
    else if (a === '--help' || a === '-h') { printUsage(); process.exit(0); }
    else { console.error(`Argument inconnu : ${a}`); printUsage(); process.exit(2); }
  }
  return args;
}

function printUsage() {
  console.log('Usage : node scripts/generate_ai_skill.js [--manifest <path>] [--out-dir <path>] [--check]');
}

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_MANIFEST = path.join(
  REPO_ROOT, 'Meownopoly', 'cpp', 'ai', 'gateway', 'channel_manifest.json');

// ---------------------------------------------------------------------------
// Lecture / validation minimale du manifeste
// ---------------------------------------------------------------------------

function loadManifest(manifestPath) {
  let raw;
  try {
    raw = fs.readFileSync(manifestPath, 'utf8');
  } catch (e) {
    throw new Error(`Manifeste introuvable : ${manifestPath} (${e.message})`);
  }
  let manifest;
  try {
    manifest = JSON.parse(raw);
  } catch (e) {
    throw new Error(`Manifeste JSON invalide (${manifestPath}) : ${e.message}`);
  }
  for (const field of ['protocolVersion', 'roles', 'tools']) {
    if (manifest[field] === undefined) {
      throw new Error(`Champ requis absent du manifeste : "${field}"`);
    }
  }
  return manifest;
}

// ---------------------------------------------------------------------------
// Helpers de mise en forme
// ---------------------------------------------------------------------------

// Supprime récursivement les clés de gouvernance/documentation ($…) pour ne
// garder que le contrat machine effectif consommé par l'agent.
function stripMeta(value) {
  if (Array.isArray(value)) return value.map(stripMeta);
  if (value && typeof value === 'object') {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      if (k.startsWith('$')) continue;
      out[k] = stripMeta(v);
    }
    return out;
  }
  return value;
}

function toolByName(manifest, name) {
  return manifest.tools.find((t) => t.name === name);
}

// Rend un descriptif compact des paramètres d'un tool pour le SKILL.md.
function formatParams(params) {
  if (!params || Object.keys(params).length === 0) return '_(aucun paramètre)_';
  const lines = [];
  for (const [name, spec] of Object.entries(params)) {
    const req = spec.required ? '**requis**' : 'optionnel';
    let type = spec.type || 'any';
    if (spec.type === 'enum' && Array.isArray(spec.values)) {
      type = `enum(${spec.values.join(' | ')})`;
    }
    const doc = spec.doc ? ` — ${spec.doc}` : '';
    lines.push(`  - \`${name}\` : ${type}, ${req}${doc}`);
  }
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// Génération du contrat machine (couche 2)
// ---------------------------------------------------------------------------

function buildContract(manifest) {
  const roles = {};
  for (const [roleName, roleSpec] of Object.entries(manifest.roles)) {
    roles[roleName] = {
      description: roleSpec.description,
      tools: (roleSpec.toolAllowList || []).slice(),
      eventVisibility: roleSpec.eventVisibility,
    };
  }

  const tools = manifest.tools.map((t) => stripMeta({
    name: t.name,
    roles: t.roles,
    summary: t.summary,
    params: t.params,
    returns: t.returns,
    quota: t.quota,
    notes: t.notes,
  }));

  return {
    _generated: {
      by: 'scripts/generate_ai_skill.js',
      from: path.basename(DEFAULT_MANIFEST),
      note:
        'Contrat machine dérivé du manifeste du canal IA (source de vérité, D17). ' +
        'Ne pas éditer à la main : régénérer via scripts/generate_ai_skill.js.',
    },
    protocolVersion: manifest.protocolVersion,
    envelopeVersion: manifest.envelopeVersion,
    roles,
    tools,
    quotas: stripMeta(manifest.quotas || {}),
    envelope: stripMeta(manifest.envelopeSchemaRef || {}),
    eventSummary: stripMeta(manifest.eventSummary || {}),
  };
}

// ---------------------------------------------------------------------------
// Génération du SKILL.md (couche 1)
// ---------------------------------------------------------------------------

function buildSkillMarkdown(manifest) {
  const pv = manifest.protocolVersion;
  const roleNames = Object.keys(manifest.roles);
  const out = [];

  // --- Front-matter YAML (cohérent avec .agents/skills/, doc 03 §3) ---
  out.push('---');
  out.push('name: meownopoly-ai-channel');
  out.push(
    'description: >-',
    `  Contrat du canal IA <-> jeu de Meownopoly (protocolVersion ${pv}). Décrit`,
    '  comment ton IA observe l\'état du jeu et propose des briques de gameplay',
    '  (poses, éditions, mémoire de configuration, artefacts QML/JS) via les tools',
    '  MCP du jeu. Injecté en pré-prompt au lancement (D10/D17) — pas besoin de',
    '  lire le code du jeu.');
  out.push(`protocolVersion: ${pv}`);
  out.push(`roles: [${roleNames.join(', ')}]`);
  out.push('generatedBy: scripts/generate_ai_skill.js');
  out.push('---');
  out.push('');

  // --- Avertissement généré ---
  out.push('<!-- FICHIER GÉNÉRÉ — ne pas éditer à la main.');
  out.push(`     Source de vérité : ${path.basename(DEFAULT_MANIFEST)} (D17).`);
  out.push('     Régénérer : node scripts/generate_ai_skill.js -->');
  out.push('');

  // --- Intro ---
  out.push('# Canal IA de Meownopoly');
  out.push('');
  out.push(
    'Tu pilotes un jeu qui **tourne** : ce n\'est pas une procédure de modification',
    'de code, c\'est un **contrat de capacités runtime**. Ton but n\'est pas de',
    '*tester* le jeu mais de **produire des briques de gameplay porteuses de**',
    '**logique** (poses, éditions, écriture de l\'espace mémoire, artefacts QML/JS)',
    'qui influencent la partie.');
  out.push('');
  out.push(
    `Tu communiques uniquement par **tool calls MCP** (protocolVersion \`${pv}\`).`,
    'La connexion (endpoint + token de rôle) est fournie par l\'application au',
    'lancement : tu n\'as rien à configurer.');
  out.push('');

  // --- Rôles ---
  out.push('## Ton rôle');
  out.push('');
  out.push(
    'Ton token détermine ton rôle et la liste des tools qui te sont accessibles.',
    'Les appels hors de ta liste sont refusés par la passerelle.');
  out.push('');
  for (const roleName of roleNames) {
    const r = manifest.roles[roleName];
    out.push(`### \`${roleName}\``);
    out.push('');
    if (r.description) out.push(r.description, '');
    out.push(`- **Tools autorisés** : ${(r.toolAllowList || []).map((t) => `\`${t}\``).join(', ')}`);
    if (r.eventVisibility) out.push(`- **Événements visibles** : ${r.eventVisibility}`);
    out.push('');
  }

  // --- Boucle perception -> action ---
  out.push('## Boucle perception → action');
  out.push('');
  out.push(
    '1. **Observe** : `state_query(what, filter)` pour lire l\'état (compact,',
    '   paginé, des ids plutôt que des dumps). `help(topic)` déballe la doc',
    '   détaillée d\'une famille à la demande.',
    '2. **Agis** : pose/édite (`editor_place`, `editor_edit`), écris la',
    '   configuration (`memory_set`), configure le roster (`roster_edit`) ou un',
    '   module (`module_config`), soumets un artefact (`artifact_submit`).',
    '3. **Vérifie** : chaque appel renvoie un accusé/état ; `events_poll(cursor)`',
    '   te resynchronise en cours de tâche longue.');
  out.push('');
  out.push(
    'Un résumé des événements survenus depuis ton dernier tour t\'est **injecté**',
    'à chaque invocation (une invocation = un tour). Utilise `events_poll` seulement',
    'si tu as besoin de plus que ce résumé.');
  out.push('');

  // --- Garde-fous ---
  out.push('## Garde-fous (non négociables)');
  out.push('');
  out.push(
    '- Tu n\'as **aucun accès** au harnais d\'automation/test du jeu : seuls les',
    '  tools listés pour ton rôle existent pour toi.',
    '- **Le type de requête est recalculé par l\'hôte** (`requestType`), jamais',
    '  déclaré par toi : ne cherche pas à le forcer.',
    '- Un artefact soumis passe par le **banc d\'essai de l\'hôte** puis par',
    '  l\'**arbitre** : un `artifact_dryrun` qui passe **n\'est pas** une',
    '  acceptation.',
    '- L\'application des effets reste sous **autorité de l\'hôte** ; l\'arbitre',
    '  rend un verdict, il n\'applique rien.');
  out.push('');

  // Contraintes chiffrées (quotas / payload)
  const q = manifest.quotas || {};
  if (q.payload || q.rateLimit || q.perInvocation) {
    out.push('### Limites chiffrées');
    out.push('');
    if (q.payload) {
      if (q.payload.maxArtifactSourceBytes) {
        out.push(`- Source d\'artefact ≤ **${q.payload.maxArtifactSourceBytes} octets** (\`artifact_submit.source\`).`);
      }
      if (q.payload.maxRequestBytes) {
        out.push(`- Requête ≤ **${q.payload.maxRequestBytes} octets**, réponse ≤ **${q.payload.maxResponseBytes} octets**.`);
      }
    }
    if (q.rateLimit) {
      out.push(`- Débit : **${q.rateLimit.requestsPerSecond} req/s** (burst ${q.rateLimit.burst}).`);
    }
    if (q.perInvocation && q.perInvocation.maxToolCalls) {
      out.push(`- **${q.perInvocation.maxToolCalls} tool calls max** par invocation (quotas par tool détaillés dans le contrat machine).`);
    }
    out.push('');
    out.push(
      'Un dépassement renvoie une erreur `{ code: "quota_exceeded", retryable: true }` :',
      'ré-essaie plus tard ou réduis la taille du lot.');
    out.push('');
  }

  // --- Catalogue des tools ---
  out.push('## Catalogue des tools');
  out.push('');
  out.push(
    'Les schémas complets (types, valeurs d\'enum) sont portés par le MCP et par le',
    'contrat machine `channel_contract.json`. Ci-dessous, l\'**usage** de chaque tool.');
  out.push('');
  for (const t of manifest.tools) {
    out.push(`### \`${t.name}\``);
    out.push('');
    out.push(`- **Rôles** : ${(t.roles || []).map((r) => `\`${r}\``).join(', ')}`);
    out.push(`- **Objet** : ${t.summary}`);
    out.push('- **Paramètres** :');
    out.push(formatParams(t.params));
    if (t.returns) out.push(`- **Retour** : ${t.returns}`);
    if (t.notes) out.push(`- **Note** : ${t.notes}`);
    if (t.quota) {
      const cst = t.quota.constant ? ` (\`${t.quota.constant}\`)` : '';
      const def = t.quota.default !== undefined ? `, défaut ${t.quota.default}` : '';
      const unit = t.quota.unit ? ` ${t.quota.unit}` : '';
      out.push(`- **Quota** : ${(t.quota.default ?? '?')}${unit}${def && cst ? cst : cst}`);
    }
    out.push('');
  }

  // --- Recettes ---
  out.push('## Recettes fréquentes');
  out.push('');
  out.push('### Poser un élément et lui donner une configuration');
  out.push('```');
  out.push('editor_place(kind="case", params={ gx, gy, caseType })   -> { uuid }');
  out.push('memory_set(scope="tile", uuid, key="config/…", value=…)  -> { version }');
  out.push('```');
  out.push('');
  out.push('### Donner un comportement à une case (artefact QML/JS)');
  out.push('```');
  out.push('artifact_submit(source="<QML/JS ≤ limite>", target=uuid,');
  out.push('                meta={ aiSummary, requiresModules, declaredWriteSet,');
  out.push('                       listensTo, executionPolicy })');
  out.push('   -> verdict complet OU { status: "pending", proposalId }');
  out.push('```');
  out.push('Itère d\'abord avec `artifact_dryrun` (quota par invocation) avant de soumettre.');
  out.push('');
  out.push('### Se resynchroniser en cours de tâche');
  out.push('```');
  out.push('events_poll(cursor=<dernier seq connu>)  -> { entries, nextCursor, truncated? }');
  out.push('```');
  out.push('Si `truncated`, ne rejoue pas l\'historique : resynchronise via `state_query`.');
  out.push('');

  // --- Rôle arbitre : verdict ---
  if (toolByName(manifest, 'arbiter_verdict')) {
    out.push('### Rendre un verdict (rôle `arbiter` uniquement)');
    out.push('```');
    out.push('arbiter_verdict(proposalId, verdict="accepted|rejected|amended",');
    out.push('                reasons=[{ audience: "player|ai", text, code?, retryable? }],');
    out.push('                amendment?={ operationsPatch|artifactsPatch|note })');
    out.push('```');
    out.push('Un amendement de code **repasse au banc** (D32). Rédige au moins une raison');
    out.push('`audience: player` (affichée au joueur) et une `audience: ai` (actionnable).');
    out.push('');
  }

  out.push('---');
  out.push('');
  out.push(`_Généré depuis \`${path.basename(DEFAULT_MANIFEST)}\` — protocolVersion \`${pv}\`._`);
  out.push('');

  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Écriture / comparaison (mode --check)
// ---------------------------------------------------------------------------

// Normalise les fins de ligne pour rendre la comparaison --check robuste au
// autocrlf de git sous Windows.
function normalizeEol(s) {
  return s.replace(/\r\n/g, '\n');
}

function writeOrCheck(filePath, content, check, results) {
  const normalized = normalizeEol(content);
  let existing = null;
  if (fs.existsSync(filePath)) {
    existing = normalizeEol(fs.readFileSync(filePath, 'utf8'));
  }
  const differs = existing !== normalized;

  if (check) {
    results.push({ filePath, differs, missing: existing === null });
    return;
  }
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, normalized, 'utf8');
  results.push({ filePath, written: true, differs });
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifestPath = path.resolve(args.manifest || DEFAULT_MANIFEST);
  const outDir = path.resolve(args.outDir || path.join(path.dirname(manifestPath), 'generated'));

  const manifest = loadManifest(manifestPath);

  const skillMd = buildSkillMarkdown(manifest);
  const contract = buildContract(manifest);
  const contractJson = JSON.stringify(contract, null, 2) + '\n';

  const results = [];
  writeOrCheck(path.join(outDir, 'SKILL.md'), skillMd, args.check, results);
  writeOrCheck(path.join(outDir, 'channel_contract.json'), contractJson, args.check, results);

  if (args.check) {
    const drifted = results.filter((r) => r.differs);
    if (drifted.length > 0) {
      console.error('[generate_ai_skill] Dérive détectée — régénérer la skill :');
      for (const r of drifted) {
        console.error(`  - ${path.relative(REPO_ROOT, r.filePath)}${r.missing ? ' (absent)' : ''}`);
      }
      console.error('  node scripts/generate_ai_skill.js');
      process.exit(1);
    }
    console.log(`[generate_ai_skill] OK — skill synchrone avec le manifeste (protocolVersion ${manifest.protocolVersion}).`);
    return;
  }

  console.log(`[generate_ai_skill] Skill générée depuis ${path.relative(REPO_ROOT, manifestPath)} (protocolVersion ${manifest.protocolVersion}) :`);
  for (const r of results) {
    console.log(`  - ${path.relative(REPO_ROOT, r.filePath)}`);
  }
}

try {
  main();
} catch (e) {
  console.error(`[generate_ai_skill] ERREUR : ${e.message}`);
  process.exit(1);
}
