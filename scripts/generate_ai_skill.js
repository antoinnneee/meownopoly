#!/usr/bin/env node
/*
 * generate_ai_skill.js — Générateur de skill du canal IA (V3, tâches C8 / M12, D17).
 *
 * Source de vérité UNIQUE : le manifeste versionné du canal
 *   Meownopoly/cpp/ai/gateway/channel_manifest.json  (P0-4, décisions D43/D44).
 *
 * Produit trois familles de fichiers (doc/v3/03_SKILL_CLIENT_IA.md §3-5) :
 *   1. Une couche machine partagée : channel_contract.json — sous-ensemble curé,
 *      stable et machine-lisible du manifeste (rôles, tools, params, quotas,
 *      enveloppe, **négociation de version**), débarrassé des métadonnées de
 *      gouvernance ($meow_status, $doc, …).
 *   2. Une **variante par CLI cible** (D17 : Codex + Claude Code) de la couche
 *      lisible par l'agent :
 *        - `claude/SKILL.md`  : front-matter YAML name/description (convention
 *          `.agents/skills/`) + corps procédural. Consommé par `claude -p`.
 *        - `codex/AGENTS.md`  : préambule Codex (pas de front-matter `.agents/`,
 *          Codex lit AGENTS.md comme instructions projet) + même corps.
 *      Le **corps** (rôles, boucle, garde-fous, catalogue, recettes, négociation
 *      de version) est identique entre variantes : seul l'en-tête d'injection
 *      diffère. C'est ce fichier qui est injecté en pré-prompt au spawn de
 *      l'agent selon l'adaptateur choisi (D10/D17/D20 — `AiProcessSupervisor`).
 *
 * La skill est versionnée avec le protocolVersion global du manifeste (D17/§5).
 * Le contrat porte un bloc `versionNegotiation` (current + minCompatible +
 * policy semver-major) : c'est la **source de vérité de la négociation de
 * version au handshake** (doc 03 §5 « mode compatibilité négocié »). La logique
 * de comparaison vit côté hôte (`AiProcessSupervisor::evaluateHandshakeOutput`)
 * mais lit sa fenêtre de compatibilité ici.
 *
 * Validation de dérive en CI (M12/T5-2) : `--check` sort en code 1 si un fichier
 * généré diffère de ce qui serait produit. Câblé dans .github/workflows/ (échec
 * du job si la skill n'a pas été régénérée après une modif du manifeste).
 *
 * Aucune dépendance externe : Node built-ins uniquement (fs, path).
 *
 * Usage :
 *   node scripts/generate_ai_skill.js [--manifest <path>] [--out-dir <path>]
 *                                     [--variant all|claude|codex] [--check]
 *
 *   --manifest  chemin du manifeste (défaut : Meownopoly/cpp/ai/gateway/channel_manifest.json)
 *   --out-dir   dossier de sortie   (défaut : <dir(manifeste)>/generated)
 *   --variant   variante(s) à produire (défaut : all) — voir VARIANTS.
 *   --check     ne rien écrire ; sortie code 1 si un fichier généré diffère de
 *               ce qui serait produit (validation de dérive CI, M12/T5-2).
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Arguments & chemins par défaut
// ---------------------------------------------------------------------------

function parseArgs(argv) {
  const args = { manifest: null, outDir: null, variant: 'all', check: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--manifest') args.manifest = argv[++i];
    else if (a === '--out-dir') args.outDir = argv[++i];
    else if (a === '--variant') args.variant = argv[++i];
    else if (a === '--check') args.check = true;
    else if (a === '--help' || a === '-h') { printUsage(); process.exit(0); }
    else { console.error(`Argument inconnu : ${a}`); printUsage(); process.exit(2); }
  }
  if (!['all', 'claude', 'codex'].includes(args.variant)) {
    console.error(`Variante inconnue : ${args.variant} (attendu : all|claude|codex)`);
    printUsage();
    process.exit(2);
  }
  return args;
}

function printUsage() {
  console.log(
    'Usage : node scripts/generate_ai_skill.js [--manifest <path>] [--out-dir <path>]\n' +
    '                                          [--variant all|claude|codex] [--check]');
}

const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_MANIFEST = path.join(
  REPO_ROOT, 'Meownopoly', 'cpp', 'ai', 'gateway', 'channel_manifest.json');

// Marqueur de handshake émis par l'agent arbitre (cf.
// AiProcessSupervisor::kHandshakeMarker). Reporté ici pour co-versionner la
// consigne d'annonce avec le contrat — source de vérité unique côté skill.
const HANDSHAKE_MARKER = 'MEOW_ARBITER_HANDSHAKE:';

// ---------------------------------------------------------------------------
// Variantes par CLI cible (D17 : Codex + Claude Code)
// ---------------------------------------------------------------------------

// Chaque variante décrit son fichier de sortie et son en-tête d'injection. Le
// corps procédural (buildSkillBody) est partagé — seul l'en-tête diffère selon
// la façon dont le CLI consomme son pré-prompt.
const VARIANTS = {
  claude: { file: path.join('claude', 'SKILL.md'), header: buildClaudeHeader },
  codex: { file: path.join('codex', 'AGENTS.md'), header: buildCodexHeader },
};

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
// Négociation de version (source de vérité côté skill, doc 03 §5)
// ---------------------------------------------------------------------------

// Parse une version semver "MAJOR.MINOR.PATCH" en triplet numérique.
// Tolère un simple entier ("1" → 1.0.0) pour rester robuste.
function parseSemver(version) {
  const m = String(version).trim().match(/^(\d+)(?:\.(\d+))?(?:\.(\d+))?/);
  if (!m) throw new Error(`protocolVersion non semver : "${version}"`);
  return { major: Number(m[1]), minor: Number(m[2] || 0), patch: Number(m[3] || 0) };
}

// Construit la fenêtre de compatibilité négociable au handshake. Politique MVP :
// **semver-major** — un agent est compatible ssi il annonce la même version
// majeure (borne basse `<major>.0.0`, borne haute = version courante). Un major
// différent → incompatible → l'hôte propose une mise à jour de skill (doc 03 §5).
function buildVersionNegotiation(manifest) {
  const cur = parseSemver(manifest.protocolVersion);
  return {
    current: manifest.protocolVersion,
    minCompatible: `${cur.major}.0.0`,
    policy: 'semver-major',
    rule:
      'Compatible ssi la version annoncée par l\'agent a la même version majeure ' +
      'que `current` et est >= `minCompatible`. Un major différent est rejeté : ' +
      'l\'hôte propose alors une régénération/mise à jour de la skill (doc 03 §5).',
    handshake: {
      marker: HANDSHAKE_MARKER,
      // Ligne machine que l'agent émet sur stdout pour prouver rôle + version +
      // capacité (consommée par AiProcessSupervisor::evaluateHandshakeOutput).
      announceShape:
        `${HANDSHAKE_MARKER}{"role":"<proposer|arbiter>",` +
        `"protocolVersion":"${manifest.protocolVersion}","capabilities":[...]}`,
      announces: ['role', 'protocolVersion', 'capabilities'],
      note:
        'La version annoncée doit être celle réellement supportée par l\'agent, ' +
        'pas recopiée aveuglément : c\'est elle qui est négociée contre la fenêtre ' +
        'de compatibilité ci-dessus.',
    },
  };
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
// Génération du contrat machine (couche partagée)
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
    annotations: t.annotations,
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
    versionNegotiation: buildVersionNegotiation(manifest),
    roles,
    tools,
    quotas: stripMeta(manifest.quotas || {}),
    envelope: stripMeta(manifest.envelopeSchemaRef || {}),
    eventSummary: stripMeta(manifest.eventSummary || {}),
  };
}

// ---------------------------------------------------------------------------
// En-têtes d'injection par variante
// ---------------------------------------------------------------------------

// Variante Claude Code : front-matter YAML (convention `.agents/skills/`).
function buildClaudeHeader(manifest) {
  const pv = manifest.protocolVersion;
  const roleNames = Object.keys(manifest.roles);
  const out = [];
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
  out.push('variant: claude');
  out.push('generatedBy: scripts/generate_ai_skill.js');
  out.push('---');
  out.push('');
  out.push('<!-- FICHIER GÉNÉRÉ — ne pas éditer à la main.');
  out.push(`     Variante : Claude Code (claude -p). Source : ${path.basename(DEFAULT_MANIFEST)} (D17).`);
  out.push('     Régénérer : node scripts/generate_ai_skill.js -->');
  out.push('');
  return out.join('\n');
}

// Variante Codex : Codex non-interactif lit AGENTS.md comme instructions
// projet — pas de front-matter `.agents/skills/`. Métadonnées en bloc lisible.
function buildCodexHeader(manifest) {
  const pv = manifest.protocolVersion;
  const roleNames = Object.keys(manifest.roles);
  const out = [];
  out.push('<!-- FICHIER GÉNÉRÉ — ne pas éditer à la main.');
  out.push(`     Variante : Codex (mode non interactif). Source : ${path.basename(DEFAULT_MANIFEST)} (D17).`);
  out.push('     Régénérer : node scripts/generate_ai_skill.js -->');
  out.push('');
  out.push('# AGENTS.md — Canal IA de Meownopoly (Codex)');
  out.push('');
  out.push(
    'Ce document est injecté en **pré-prompt** au lancement de l\'agent Codex',
    'par l\'application (D10/D17) : il fait autorité sur ta façon d\'interagir',
    'avec le jeu. Tu n\'as ni compte à configurer ni code du jeu à lire.');
  out.push('');
  out.push(`- **protocolVersion** : \`${pv}\``);
  out.push(`- **rôles** : ${roleNames.map((r) => `\`${r}\``).join(', ')}`);
  out.push('- **variante** : codex');
  out.push('- **généré par** : scripts/generate_ai_skill.js');
  out.push('');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Corps procédural partagé (identique entre variantes)
// ---------------------------------------------------------------------------

function buildSkillBody(manifest) {
  const pv = manifest.protocolVersion;
  const roleNames = Object.keys(manifest.roles);
  const neg = buildVersionNegotiation(manifest);
  const out = [];

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

  // --- Négociation de version (handshake) ---
  out.push('## Négociation de version (handshake)');
  out.push('');
  out.push(
    `Le canal est versionné \`${neg.current}\` (politique **${neg.policy}**). Au`,
    'handshake, tu **annonces la version que tu supportes réellement** sur une ligne',
    'machine de stdout :');
  out.push('');
  out.push('```');
  out.push(neg.handshake.announceShape);
  out.push('```');
  out.push('');
  out.push(
    `- Compatible ssi ta version a la **même majeure** que \`${neg.current}\` et`,
    `  est **>= \`${neg.minCompatible}\`**.`,
    '- Une majeure différente est **rejetée** : l\'hôte régénère alors une skill à',
    '  jour et te la ré-injecte (pas d\'action de ta part).',
    '- N\'invente pas de version : annonce celle de cette skill si tu n\'as pas',
    '  d\'information plus précise.');
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

// Assemble en-tête (spécifique variante) + corps (partagé).
function buildSkillMarkdown(manifest, variant) {
  return VARIANTS[variant].header(manifest) + buildSkillBody(manifest);
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
  const selectedVariants =
    args.variant === 'all' ? Object.keys(VARIANTS) : [args.variant];

  const contract = buildContract(manifest);
  const contractJson = JSON.stringify(contract, null, 2) + '\n';

  const results = [];
  // Contrat machine partagé (indépendant de la variante).
  writeOrCheck(path.join(outDir, 'channel_contract.json'), contractJson, args.check, results);
  // Une variante de skill par CLI cible.
  for (const variant of selectedVariants) {
    const md = buildSkillMarkdown(manifest, variant);
    writeOrCheck(path.join(outDir, VARIANTS[variant].file), md, args.check, results);
  }

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
    console.log(`[generate_ai_skill] OK — skill synchrone avec le manifeste (protocolVersion ${manifest.protocolVersion}, variantes : ${selectedVariants.join(', ')}).`);
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
