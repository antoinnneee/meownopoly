export const meta = {
  name: 'v3-implementation',
  description: "Implémente le plan V3 (doc 15) phase par phase : modèle par complexité, pistes parallèles, contexte réutilisé par piste",
  whenToUse: "args = { phases: ['0','1','2','3','4','5'], r1: 'go' } — défaut ['0','1']. La phase 2 est bloquée tant que r1 !== 'go' (jalon humain).",
  phases: [
    { title: 'Phase 0', detail: 'Prérequis bloquants P0-1..P0-5' },
    { title: 'Phase 1 — Piste A', detail: 'M9.1 banc d\'essai (jalon R1)' },
    { title: 'Phase 1 — Piste B', detail: 'M3 fiabilité applicative' },
    { title: 'Phase 1 — Piste C', detail: 'M1 passerelle MCP → M2 superviseur' },
    { title: 'Phase 1 — Piste D', detail: 'M5 journal d\'événements' },
    { title: 'Phase 1 — Linux', detail: 'M13 transversal (après barrière, conflit CMakeLists)' },
    { title: 'Jalon R1', detail: 'Rapport go/no-go (décision humaine)' },
    { title: 'Phase 2', detail: 'Vertical slice solo (gate r1=go)' },
    { title: 'Phase 3', detail: 'Collab : transactions, ProposalSession, bus d\'état' },
    { title: 'Phase 4', detail: 'Robustesse : artefacts, save, migration, règles' },
    { title: 'Phase 5', detail: 'Distribution : GLB, skill CI, Linux L3' },
  ],
}

// ---------------------------------------------------------------------------
// Mapping complexité du plan → modèle/effort.
//   F (faible) et M (moyenne)  = tâche simple        → opus  medium
//   É (élevée)                 = tâche compliquée    → opus  high
//   TÉ (très élevée)           = très compliquée     → fable medium
const TIER = {
  F:  { model: 'opus',  effort: 'medium' },
  M:  { model: 'opus',  effort: 'medium' },
  E:  { model: 'opus',  effort: 'high'   },
  TE: { model: 'fable', effort: 'medium' },
}

const PLAN = 'Meownopoly/doc/v3/15_PLAN_IMPLEMENTATION.md'

const RESULT = {
  type: 'object',
  properties: {
    summary:      { type: 'string', description: 'Ce qui a été fait, décisions prises, points d\'intégration pour les tâches suivantes' },
    filesTouched: { type: 'array', items: { type: 'string' } },
    commits:      { type: 'array', items: { type: 'string' } },
    blockers:     { type: 'array', items: { type: 'string' } },
    done:         { type: 'boolean' },
  },
  required: ['summary', 'filesTouched', 'blockers', 'done'],
}

function buildPrompt(ids, ctx) {
  const parts = [
    `Tu es un agent d'implémentation du plan V3 de Meownopoly. Lis d'abord CLAUDE.md (racine du repo) puis ${PLAN} — uniquement la ou les sections des tâches ci-dessous — ainsi que les docs v3 que ces tâches référencent.`,
    `Tâche(s) à implémenter, dans l'ordre du plan : ${ids}.`,
  ]
  if (ctx) parts.push(`Contexte hérité des tâches précédentes de la même piste — réutilise-le au lieu de re-explorer le code :\n${ctx}`)
  parts.push(`Consignes :
- Périmètre fichiers strict : uniquement les fichiers [mod]/[new] listés par le plan pour ces tâches ; les [pat] sont en lecture seule.
- Compile avant de conclure : cmake --build build --config Release --target Meownopoly (PATH MinGW, commandes exactes dans CLAUDE.md). Corrige jusqu'au build vert.
- Un commit git par tâche terminée, message conventionnel en français (feat/fix/docs(v3): ...), pas de push.
- Prérequis manquant (décision Antoine/Valou non prise, manifeste P0-4 absent, jalon non tranché) → ne rien inventer : le signaler dans blockers et livrer le maximum possible sans lui.
- Ta réponse finale est l'objet structuré demandé, rien d'autre.`)
  return parts.join('\n\n')
}

// Une tâche, ou un cluster de tâches proches en contexte (= une seule session agent).
// Un échec de sortie structurée (retry cap) ne doit pas tuer le workflow : le travail
// est souvent déjà commité — on retourne null et fold() le signale (revérifier git log).
async function run(ids, tier, phaseLabel, ctx) {
  const t = TIER[tier]
  try {
    return await agent(buildPrompt(ids, ctx), {
      label: ids.split('(')[0].trim(),
      phase: phaseLabel,
      model: t.model,
      effort: t.effort,
      schema: RESULT,
    })
  } catch (e) {
    log(`[${ids.split('(')[0].trim()}] rapport d'agent perdu (${e && e.message ? e.message : e}) — vérifier git log, le travail peut être commité.`)
    return null
  }
}

// Accumule le résumé d'une tâche dans le contexte transmis aux suivantes.
function fold(ctx, id, r) {
  if (!r) return ctx + `\n[${id}] agent perdu, résultat inconnu — revérifier via git log.`
  return ctx
    + `\n[${id}] ${r.summary}`
    + `\n  fichiers: ${(r.filesTouched || []).join(', ') || '—'}`
    + `\n  blockers: ${(r.blockers || []).join(' | ') || 'aucun'}`
}

// args peut arriver en objet ou en chaîne JSON selon le mode d'invocation — normaliser.
const ARGS = (typeof args === 'string')
  ? (function () { try { return JSON.parse(args) } catch (e) { return {} } })()
  : (args || {})
const wanted = new Set((ARGS.phases || ['0', '1']).map(String))
log(`Phases demandées : ${Array.from(wanted).join(', ')}`)
const all = {}
function note(id, r) { all[id] = r ? { done: r.done, summary: r.summary, blockers: r.blockers } : null }

// ===========================================================================
// PHASE 0 — Prérequis bloquants (tous parallélisables entre eux)
// ===========================================================================
if (wanted.has('0')) {
  phase('Phase 0')
  log('Phase 0 : P0-1 ∥ P0-2 ∥ P0-3 en implémentation, P0-4/P0-5 en brouillons de décision (arbitrage humain)')
  const [p01, p02, p03, p045] = await parallel([
    () => run('P0-1 (add-on QtHttpServer, D21)', 'F', 'Phase 0'),
    () => run('P0-2 (assainir ItemSnapable::toJSON, R4 — tests round-trip sur les maps existantes obligatoires)', 'M', 'Phase 0'),
    () => run('P0-3 (réserver la plage de messages 0x60+ pour V3)', 'F', 'Phase 0'),
    () => run("P0-4 + P0-5 — BROUILLONS SEULEMENT : rédiger la proposition de manifeste versionné du canal (Q-E08/Q-E06) et la proposition de répartition de gouvernance (Q-J08) sous forme de docs à décider par Antoine et Valou. NE RIEN figer ni implémenter : ces décisions sont humaines.", 'M', 'Phase 0'),
  ])
  note('P0-1', p01); note('P0-2', p02); note('P0-3', p03); note('P0-4/P0-5 (brouillons)', p045)
}

// ===========================================================================
// PHASE 1 — 4 pistes parallèles (fichiers disjoints), Linux après barrière
// ===========================================================================
let r1Report = null
if (wanted.has('1')) {
  log('Phase 1 : pistes A ∥ B ∥ C ∥ D. Clusters mono-session pour les tâches proches en contexte et de même modèle.')

  // Piste A — banc d'essai (cpp/ai/bench + cpp/ai/sandbox)
  const pisteA = async () => {
    const P = 'Phase 1 — Piste A'
    let ctx = ''
    const a1  = await run('A1 (cible CMake meow_testbench headless)', 'E', P);            ctx = fold(ctx, 'A1', a1)
    const a23 = await run('A2 puis A3 (protocole job/verdict, puis superviseur bench_supervisor)', 'M', P, ctx); ctx = fold(ctx, 'A2+A3', a23)
    const a4  = await run('A4 (préfiltre P0 static_validator)', 'E', P, ctx);             ctx = fold(ctx, 'A4', a4)
    const a56 = await run('A5 puis A6 (phases P1→P5 du banc, puis contexte restreint + façade Meow.GameApi — code partagé banc/jeu)', 'TE', P, ctx); ctx = fold(ctx, 'A5+A6', a56)
    const a78 = await run('A7 puis A8 (corpus test_artifacts + critères R1, puis pool et cache de verdicts)', 'M', P, ctx); ctx = fold(ctx, 'A7+A8', a78)
    return { ctx, results: { A1: a1, 'A2+A3': a23, A4: a4, 'A5+A6': a56, 'A7+A8': a78 } }
  }

  // Piste B — fiabilité (cpp/communication + cpp/net/v3)
  const pisteB = async () => {
    const P = 'Phase 1 — Piste B'
    let ctx = ''
    const b1  = await run('B1 (enveloppe commune V3 sur 0x60+)', 'M', P);                 ctx = fold(ctx, 'B1', b1)
    const b2  = await run('B2 (ACK applicatif + retry + dédup côté worker — capturer les acks avant reliable_endpoint_clear_acks)', 'TE', P, ctx); ctx = fold(ctx, 'B2', b2)
    const b3  = await run('B3 (état supersédable)', 'M', P, ctx);                          ctx = fold(ctx, 'B3', b3)
    const b45 = await run('B4 puis B5 (chunking réparable, puis harnais de test réseau perte/dup/réordonnancement/corruption)', 'E', P, ctx); ctx = fold(ctx, 'B4+B5', b45)
    return { ctx, results: { B1: b1, B2: b2, B3: b3, 'B4+B5': b45 } }
  }

  // Piste C — gateway MCP puis superviseur d'agents (cpp/ai/gateway + supervisor)
  const pisteC = async () => {
    const P = 'Phase 1 — Piste C'
    let ctx = ''
    const c1 = await run('C1 (AiGatewayServer MCP streamable HTTP loopback — patron automation_server.cpp, AutomationServer inchangé)', 'E', P); ctx = fold(ctx, 'C1', c1)
    const c2 = await run('C2 (auth token éphémère, rôles proposer/arbiter, quotas)', 'M', P, ctx); ctx = fold(ctx, 'C2', c2)
    // C8 dès que possible (dépend seulement du manifeste P0-4), en parallèle de C3
    const [c3, c8] = await parallel([
      () => run('C3 (tools MVP du manifeste P0-4 → hooks editorAutomationHooks ; si le manifeste n\'est pas encore décidé, implémenter contre le brouillon P0-4 et le noter en blocker)', 'E', P, ctx),
      () => run('C8 (skill générée v1 : scripts/generate_ai_skill à partir du manifeste — même réserve sur le brouillon P0-4)', 'M', P, ctx),
    ])
    ctx = fold(fold(ctx, 'C3', c3), 'C8', c8)
    const [c4, c5] = await parallel([
      () => run('C4 (capacités manquantes doc 02 §5.2 : state.listTiles/getTile, editor_edit par uuid, state.enum, hooks roster, screenshot D22)', 'E', P, ctx),
      () => run('C5 (AiProcessSupervisor M2 : QProcess, adaptateurs claude -p / Codex, cycle de vie complet, aucun orphelin)', 'E', P, ctx),
    ])
    ctx = fold(fold(ctx, 'C4', c4), 'C5', c5)
    const c6 = await run('C6 (handshake + challenge arbitre D24/D31, lobby 4 états)', 'M', P, ctx); ctx = fold(ctx, 'C6', c6)
    const c7 = await run('C7 (tchat ingame IA — drawer nouveau réutilisant qml/chat/, distinct du ChatClient multijoueur)', 'E', P, ctx)
    ctx = fold(ctx, 'C7', c7)
    return { ctx, results: { C1: c1, C2: c2, C3: c3, C8: c8, C4: c4, C5: c5, C6: c6, C7: c7 } }
  }

  // Piste D — event bus (cpp/game/events) ; D4 sort de la piste (dépend de C3)
  const pisteD = async () => {
    const P = 'Phase 1 — Piste D'
    let ctx = ''
    const d1  = await run('D1 (GameplayEventBus + ingestion — attention threads, physique = worker)', 'E', P); ctx = fold(ctx, 'D1', d1)
    const d23 = await run('D2 puis D3 (curseur + noyau d\'audit D19, puis protections D12)', 'M', P, ctx); ctx = fold(ctx, 'D2+D3', d23)
    return { ctx, results: { D1: d1, 'D2+D3': d23 } }
  }

  phase('Phase 1 — Piste A')
  const [ra, rb, rc, rd] = await parallel([pisteA, pisteB, pisteC, pisteD])
  for (const r of [ra, rb, rc, rd]) if (r) for (const k of Object.keys(r.results)) note(k, r.results[k])

  // Post-barrière : dépendances croisées entre pistes
  const ctxCD = ((rd && rd.ctx) || '') + ((rc && rc.ctx) || '')
  const d4 = await run('D4 (branchement canal : events_poll(cursor) + résumé par invocation — se branche sur C3/M1)', 'F', 'Phase 1 — Piste D', ctxCD)
  note('D4', d4)
  const a9 = await run('A9 (tool artifact_dryrun D42, quota MEOW_BENCH_DRYRUN_QUOTA=10 — dépend de A1-A5 et de M1/C3)', 'F', 'Phase 1 — Piste A', ((ra && ra.ctx) || '') + ((rc && rc.ctx) || ''))
  note('A9', a9)

  // Transversal Linux — après la barrière car L1 touche CMakeLists.txt comme A1
  phase('Phase 1 — Linux')
  const l1 = await run('L1 (preset/toolchain Linux, purge chemins Android absolus, packaging plugins)', 'E', 'Phase 1 — Linux')
  note('L1', l1)
  const l2 = await run('L2 (porter dual_test_p2p sans cmd /c start)', 'F', 'Phase 1 — Linux', fold('', 'L1', l1))
  note('L2', l2)

  // Jalon R1 : rapport factuel, décision humaine
  phase('Jalon R1')
  log('Jalon R1 : production du rapport go/no-go (la décision reste humaine — relancer la phase 2 avec args.r1="go")')
  r1Report = await agent(
    `Tu prépares le rapport du jalon R1 du plan V3 de Meownopoly (${PLAN} — piste A, critères Q-J06 et doc/v3/12_BANC_ESSAI_R1.md §8). ` +
    `Exécute le corpus test_artifacts/ via meow_testbench (3 runs), mesure : reproductibilité, kill 100 % des boucles infinies, démarrage à froid < 2 s, validation < 8 s, acces_singleton.qml bloqué, tick p50/p95. ` +
    `Produis un rapport factuel avec une RECOMMANDATION argumentée (go / no-go / repli palette+mémoire / réduction à config modules + DSL) SANS trancher : la décision appartient à Antoine et Valou.` +
    ((ra && ra.ctx) ? `\n\nContexte de la piste A :\n${ra.ctx}` : ''),
    {
      label: 'rapport-R1', phase: 'Jalon R1', model: 'fable', effort: 'medium',
      schema: {
        type: 'object',
        properties: {
          recommendation: { type: 'string', enum: ['go', 'no-go', 'repli-palette-memoire', 'reduction-config-dsl'] },
          evidence: { type: 'array', items: { type: 'string' } },
          report: { type: 'string' },
        },
        required: ['recommendation', 'evidence', 'report'],
      },
    }
  )
}

// ===========================================================================
// PHASE 2 — Vertical slice solo (gate humain : args.r1 === 'go')
// ===========================================================================
if (wanted.has('2')) {
  if (ARGS.r1 !== 'go') {
    log('Phase 2 SAUTÉE : jalon R1 non tranché. Relancer le workflow avec args = { phases: ["2"], r1: "go" } après décision Antoine/Valou.')
  } else {
    phase('Phase 2')
    log('Phase 2 : S-1/S-2 ∥ S-3/S-4 ∥ S-5, puis S-6 → S-7')
    const s12 = async () => {
      let ctx = ''
      const s1 = await run('S-1 (enveloppe de proposition + cycle de vie, doc 13)', 'E', 'Phase 2'); ctx = fold(ctx, 'S-1', s1)
      const s2 = await run('S-2 (verdict 2 audiences + retour MCP)', 'M', 'Phase 2', ctx)
      return { ctx: fold(ctx, 'S-2', s2), results: { 'S-1': s1, 'S-2': s2 } }
    }
    const s34 = async () => {
      let ctx = ''
      const s3 = await run('S-3 (mémoire Étape A sur ItemSnapable, D15 — garde anti-boucle réactive)', 'E', 'Phase 2'); ctx = fold(ctx, 'S-3', s3)
      const s4 = await run('S-4 (portée session + joueurs, memory_store)', 'M', 'Phase 2', ctx)
      return { ctx: fold(ctx, 'S-4', s4), results: { 'S-3': s3, 'S-4': s4 } }
    }
    const [r12, r34, s5] = await parallel([s12, s34, () => run('S-5 (module_config D41)', 'M', 'Phase 2')])
    for (const r of [r12, r34]) if (r) for (const k of Object.keys(r.results)) note(k, r.results[k])
    note('S-5', s5)
    let ctx = ((r12 && r12.ctx) || '') + ((r34 && r34.ctx) || '') + fold('', 'S-5', s5)
    const s6 = await run('S-6 (façade Meow.GameApi complète MVP, D34 — prolonge A6)', 'E', 'Phase 2', ctx); ctx = fold(ctx, 'S-6', s6)
    const s7 = await run('S-7 (scénarios S1/S2/S3 + instrumentation, critères doc 11 §5)', 'M', 'Phase 2', ctx)
    note('S-6', s6); note('S-7', s7)
  }
}

// ===========================================================================
// PHASE 3 — Collab
// ===========================================================================
if (wanted.has('3')) {
  phase('Phase 3')
  log('Phase 3 : T3-1 ∥ T3-2 ∥ T3-3 (fichiers disjoints, dépendent tous de M3)')
  const [t31, t32, t33] = await parallel([
    () => run('T3-1 (M4 transactions atomiques prepare/commit/rollback — attention triple rôle de groupId)', 'TE', 'Phase 3'),
    () => run('T3-2 (ProposalSession D40, plage 0x60+, transport commit M3)', 'E', 'Phase 3'),
    () => run('T3-3 (M6-B bus d\'état runtime D35/D39 — ré-implémenter générique, ne pas fusionner physics_session)', 'TE', 'Phase 3'),
  ])
  note('T3-1', t31); note('T3-2', t32); note('T3-3', t33)
  const t34 = await run('T3-4 (mémoire Étape C : undo ciblé D28 — dépend de T3-1)', 'M', 'Phase 3', fold('', 'T3-1', t31))
  note('T3-4', t34)
  const t35 = await run('T3-5 (slice collab : proposition client distant, autorité hôte, P0 hôte fait foi)', 'M', 'Phase 3',
    fold(fold(fold(fold('', 'T3-1', t31), 'T3-2', t32), 'T3-3', t33), 'T3-4', t34))
  note('T3-5', t35)
}

// ===========================================================================
// PHASE 4 — Robustesse
// ===========================================================================
if (wanted.has('4')) {
  phase('Phase 4')
  log('Phase 4 : T4-1 ∥ T4-2 ∥ T4-4, puis T4-3 → T4-5')
  const [t41, t42, t44] = await parallel([
    () => run('T4-1 (M8 store d\'artefacts par hash D16/D36 — extraction prudente du SHA-256 de launcher_manager)', 'E', 'Phase 4'),
    () => run('T4-2 (M7 sauvegarde de partie D27 — peut démarrer sur son format, les hashes viennent de T4-1)', 'E', 'Phase 4'),
    () => run('T4-4 (règles runtime D8/D12/D33 — COMMENCER par le re-cadrage du doc 06 avant d\'implémenter)', 'TE', 'Phase 4'),
  ])
  note('T4-1', t41); note('T4-2', t42); note('T4-4', t44)
  const t43 = await run('T4-3 (M10 migration d\'hôte V3 D37 — coordination des deux HostLeaving 0x2A/0x46)', 'TE', 'Phase 4',
    fold(fold('', 'T4-1', t41), 'T4-2', t42))
  note('T4-3', t43)
  const t45 = await run('T4-5 (slice runtime : règles en partie, undo concurrent, reconnexion/resync)', 'E', 'Phase 4',
    fold(fold(fold('', 'T4-3', t43), 'T4-4', t44), 'T4-1', t41))
  note('T4-5', t45)
}

// ===========================================================================
// PHASE 5 — Distribution (+ L3 Linux CI)
// ===========================================================================
if (wanted.has('5')) {
  phase('Phase 5')
  log('Phase 5 : T5-1 ∥ T5-2 ∥ L3')
  const [t51, t52, l3] = await parallel([
    () => run('T5-1 (M11 bibliothèque officielle GLB D18/D29/D38)', 'E', 'Phase 5'),
    () => run('T5-2 (M12 industrialisation skill : validation de dérive en CI, variantes Codex/Claude)', 'M', 'Phase 5'),
    () => run('L3 (CI Windows + Linux : tests Pattounx, scénarios automation, corpus du banc)', 'E', 'Phase 5'),
  ])
  note('T5-1', t51); note('T5-2', t52); note('L3', l3)
}

// ===========================================================================
const blockers = []
for (const k of Object.keys(all)) {
  const r = all[k]
  if (r && r.blockers && r.blockers.length) blockers.push(...r.blockers.map(b => `[${k}] ${b}`))
  if (!r || r.done === false) blockers.push(`[${k}] tâche non terminée ou résultat perdu`)
}
return {
  phasesExecutees: Array.from(wanted),
  taches: all,
  jalonR1: r1Report,
  blockers,
}
