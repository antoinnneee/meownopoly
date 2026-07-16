# 12 — Spécification du banc d'essai hors-process (prototype R1 / D26)

> **Statut : spécification (2026-07-12).** Spécifie l'**étage 1** du sandbox
> (D26) : le banc d'essai hors-process qui valide tout artefact QML/JS candidat
> avant son introduction dans la partie. C'est aussi le **prototype R1** : ses
> mesures décident du maintien de D1 (critères de sortie Q-J06). L'étage 2
> (confinement runtime in-process, D13) est spécifié dans le [doc 04](./04_QML_GENERATIF_SANDBOX.md).

## 1. Rôle et position dans le pipeline

Le banc d'essai est un **process de test jetable**, distinct du jeu en cours,
avec son **propre moteur QML** et sa **propre instance de la carte**. Il est
le point de passage obligatoire de tout code avant application :

```
proposition (artifact_submit)
  → préfiltre mécanique (P0, dans le jeu : parse + allow-list D34)
  → arbitre (selon config D25 ; peut amender → D32)
  → BANC D'ESSAI (P1→P5, hors-process)          ← ce document
  → application dans la partie (exécution confinée D13)
```

Deux invariants :

- **Aucun code n'atteint la partie sans verdict `pass` du banc** — y compris
  un élément **amendé par l'arbitre** (D32) et tout artefact **rechargé depuis
  le disque** (revalidation au chargement, [doc 04](./04_QML_GENERATIF_SANDBOX.md) §3.5, avec cache §7).
- **Le jeu ne gèle jamais** : tout comportement pathologique (boucle infinie,
  allocation massive, crash) se produit dans le process de test, qui est tué.

## 2. Architecture

### 2.1 L'exécutable `meow_testbench`

- **Nouvelle cible CMake** (`meow_testbench.exe`), construite depuis le même
  arbre source que le jeu : elle réutilise la sérialisation de map
  (`MapFileManager`/`ItemSnapableFactory`), le moteur physique Pattounx v2 et
  l'enregistrement des types QML nécessaires — mais **aucun module réseau**
  (pas de Catway, pas de chat, pas de `PhysicsSession`) ni d'automation.
- **Headless** : lancé avec `-platform offscreen` (pas de fenêtre). Le rendu
  n'est pas évalué par le banc — on valide le **comportement** (chargement,
  budgets, effets), pas les pixels.
- **Un run = une validation** : le process reçoit un job, rend un verdict,
  et meurt (mode froid). Le mode pool (§6) garde des process chauds mais les
  **recycle après chaque verdict `fail` ou `timeout`** — un process ayant
  exécuté du code qui a dérapé n'est jamais réutilisé.

### 2.2 Communication jeu ↔ banc

- **Entrée** : un **fichier de job JSON** (chemin passé en argument) — pas de
  stdin, pour rester trivial à rejouer à la main en debug.
- **Sortie** : le **verdict JSON sur stdout** (une seule ligne, préfixée
  `MEOWBENCH:` pour survivre aux logs parasites) + code de sortie
  (`0` = verdict rendu quel qu'il soit, autre = crash du banc lui-même).
- **Supervision côté jeu** : `QProcess` avec **timeout dur global**
  (`MEOW_BENCH_TIMEOUT_MS`, défaut **30 000 ms**). Timeout ⇒ `kill()` ⇒
  verdict synthétique `{"verdict":"fail","failures":[{"code":"bench_timeout"}]}`.
  Crash (exit code ≠ 0 sans verdict) ⇒ `{"code":"crash","exitCode":N}`.

### 2.3 Le job (entrée)

```json
{
  "jobId": "uuid",
  "benchVersion": 1,
  "snapshot": {
    "map": { /* sérialisation map existante : mapInfo + snapableTiles */ },
    "memory": { /* namespaces config+state par uuid (doc 05) */ },
    "modules": { /* état d'activation des modules gameplay (D41), ex. {"stats": true} */ }
  },
  "artifact": {
    "source": "…QML/JS…",
    "targetUuid": "uuid de la tuile porteuse (optionnel)",
    "contentHash": "sha256",
    "meta": { "author": "...", "proposalId": "..." }
  },
  "budgets": { /* valeurs D34, sérialisées pour ne pas dépendre du build du banc */ },
  "stimuli": [ /* scénarios §4, générés par le jeu selon les hooks écoutés */ ],
  "seed": 12345
}
```

- **Snapshot** : réutilise la sérialisation de sauvegarde existante (map) +
  l'export mémoire ([doc 05](./05_ESPACE_MEMOIRE_SNAPABLE.md)). Le banc reconstruit la carte via
  `ItemSnapableFactory.createItemSnapableFromJson` — même chemin que le
  full-sync collab (pas de format nouveau).
- **Budgets sérialisés dans le job** : le jeu est la source de vérité des
  `#define` ; le banc applique ce qu'on lui donne (permet d'ajuster sans
  recompiler le banc).
- **Seed** : toute source d'aléa du banc (physique, stimuli) est seedée —
  un job rejoué produit le même verdict (reproductibilité, critère R1).

## 3. Phases de test (P1→P5)

Le préfiltre statique **P0** (parse QML, allow-list d'imports/types/fonctions
D34, taille ≤ 20 KB, **vérification des `requiresModules`** contre l'état de la
map et les opérations du lot — D41) tourne **dans le jeu** avant même de
spawner le banc — inutile de payer un process pour un import interdit.

**Localisation de P0 en collab (précision 2026-07-13).** P0 s'exécute
**toujours chez l'hôte** — c'est ce P0-là qui fait foi (calcul du
`requestType`, routage D25) — **et aussi chez l'auteur avant l'envoi**, en
best-effort : la passerelle MCP locale du client rejette immédiatement une
source manifestement invalide sans aller-retour réseau (fail-fast, S3).
Même code C++ aux deux endroits, pas de duplication de logique ; l'hôte ne
fait **jamais** confiance au résultat du P0 d'un pair.

| Phase | Contenu | Échec type |
|-------|---------|------------|
| **P1 — Reconstruction** | recharge le snapshot (carte + mémoire + état des modules gameplay, D41), démarre le moteur physique | `snapshot_invalid` (bug interne, pas la faute de l'artefact) |
| **P2 — Instanciation** | crée l'artefact dans le contexte restreint (même façade `Meow.GameApi` que le runtime), rattaché à `targetUuid` | `load_failed` (erreur QML), `load_timeout` (> 5 s : boucle au chargement) |
| **P3 — Simulation à vide** | `N_IDLE` ticks de simulation (défaut **600** ticks = 10 s à 60 Hz, accélérés : le banc ne dort pas entre les ticks) | `tick_budget` (> 0,5 ms/tick soutenu), `runaway_alloc` |
| **P4 — Stimulation** | rejoue les `stimuli` du job : pour chaque hook que l'artefact écoute (`events.on`), le jeu a généré un scénario — entrée/sortie de zone d'un acteur fantôme, écriture mémoire, action joueur simulée, ticks | `event_budget` (> 2 ms/handler), `event_flood` (> 30 émissions/s), `memory_quota` (écritures hors quotas D15) |
| **P5 — Teardown** | détruit l'artefact, vérifie la libération (objets, connexions, timers) | `leak` (objets/timers survivants) |

Mesures collectées en continu (toutes phases) : **CPU par tick et par
handler** (p50/p95/max), **pic mémoire** du process (delta depuis P1),
**nombre d'objets QML** instanciés, **écritures mémoire** effectuées
(write-set observé — comparé au write-set **déclaré** dans la proposition,
D11 : une écriture hors write-set est un `fail: writeset_violation`).

**Génération des stimuli.** Le jeu inspecte les abonnements de l'artefact
(handlers `events.on` déclarés, détectés en P0 par analyse statique +
confirmés en P2 à l'enregistrement) et génère un scénario par type écouté.
MVP : scénarios génériques par type d'événement (un acteur fantôme traverse
la zone cible, une clé mémoire écoutée change deux fois, 10 ticks). Les
scénarios spécifiques au gameplay restent l'affaire de l'arbitre (jugement),
pas du banc (mécanique).

## 4. Verdict (sortie)

```json
{
  "jobId": "uuid",
  "benchVersion": 1,
  "verdict": "pass" | "fail",
  "failures": [
    { "code": "event_budget", "phase": "P4", "details": "handler onZoneEntered: p95 4.1ms > 2ms", "retryable": false }
  ],
  "metrics": {
    "loadMs": 340, "tickUsP50": 80, "tickUsP95": 210,
    "handlerUsP95": { "onZoneEntered": 4100 },
    "peakMemMB": 3.2, "objectCount": 47,
    "writeSet": ["<uuid>/state/score"], "emitRate": 2.1
  },
  "durationMs": 4200
}
```

- Les `failures[].code` sont **stables et documentés dans le manifeste du
  canal** : ils remontent tels quels à l'IA cliente via le canal (S3 du
  vertical slice — le rejet doit être actionnable). `details` est une phrase
  exploitable par un LLM.
- Les `metrics` sont journalisées (D19) même en cas de `pass` — elles
  nourrissent les indicateurs Q-J04 et le recalibrage des budgets D34.

## 5. Sécurité du banc lui-même

Le banc exécute du code hostile : il est contraint, pas seulement jetable.

- **Même masquage que le runtime** : contexte restreint + façade — le banc
  est le **premier consommateur** du confinement D13 (le code du contexte
  restreint est partagé entre banc et jeu, pas dupliqué).
- **Pas de surface réseau** : les modules réseau ne sont **pas liés** dans
  l'exécutable (pas de Catway/chat/WS). Un import réseau est déjà rejeté en
  P0 ; ceinture et bretelles.
- **Filesystem** : le banc n'écrit que son verdict (stdout). MVP : pas de
  confinement OS supplémentaire. Post-MVP (tracé, non bloquant R1) : Job
  Object Windows / cgroups+seccomp Linux pour plafonner mémoire/CPU au niveau
  OS et couper tout accès réseau résiduel.
- **Plafond mémoire dur** : en attendant le confinement OS, le banc
  s'auto-surveille (poll RSS chaque 100 ms) et s'auto-tue au-delà de
  `MEOW_BENCH_MAX_RSS_MB` (défaut **512 Mo**) avec verdict `runaway_alloc`
  flushé avant `abort()` si possible ; sinon le superviseur conclut au crash.

## 6. Coût de spawn et pool

Le coût d'un process Qt offscreen (création QQmlEngine + enregistrement des
types + reconstruction de la carte) est **la mesure n°1 du prototype R1**.

- **Cibles** : démarrage froid **< 2 s** ; validation complète (P1→P5, carte
  moyenne, artefact sain) **< 8 s** de bout en bout.
- **Mode pool (si le froid est trop lent)** : `MEOW_BENCH_POOL` (défaut **1**)
  process pré-lancés ayant déjà initialisé moteur + types, attendant un job
  sur stdin. Le snapshot reste par job (la carte change). Recyclage :
  après chaque verdict `fail`/`timeout` (hygiène, §2.1), et tous les
  `MEOW_BENCH_JOBS_PER_PROCESS` (défaut **10**) jobs même en `pass`.
- **File de validation** : une seule validation à la fois au MVP (les
  propositions sont déjà sérialisées par la file transactionnelle D12) ;
  le pool > 1 ne sert que le collab futur.

## 6 bis. Mode atelier : dry-run pour l'IA cliente (D42)

Le banc sert aussi d'**outil d'itération pré-soumission** (décision D42,
2026-07-13) :

- **Tool `artifact_dryrun(source, targetUuid?)`** (manifeste MVP) : exécute
  un job de banc **en local chez l'auteur** et renvoie à l'IA le verdict
  complet **avec les métriques** (§4) — l'IA perfectionne son artefact avant
  `artifact_submit`.
- **Quota** : `MEOW_BENCH_DRYRUN_QUOTA` dry-runs par invocation (défaut 10).
- **Invariants** : un pass en dry-run n'est **jamais** un laissez-passer — la
  soumission repasse le pipeline complet, banc autoritaire chez l'hôte
  compris. En collab, les dry-runs des clients ne tournent jamais chez
  l'hôte (anti-DoS) ; aucun verdict calculé par un pair n'est accepté (R16).
  La skill énonce *pass local ≠ acceptation* (une divergence de
  `benchVersion`/budgets entre installations reste possible et explicable).
- **Palier 2 (post-MVP, tracé §11)** : session atelier interactive.

## 7. Cache de verdicts

Clé : `contentHash(artifact) + benchVersion + hash(budgets)`. Un artefact déjà
validé (même source, même banc, mêmes budgets) n'est **pas** re-testé — c'est
le mécanisme de « revalidation au chargement » à coût nul ([doc 04](./04_QML_GENERATIF_SANDBOX.md) §3.5) et de
la revalidation chez les pairs (D16). **Le snapshot ne fait pas partie de la
clé** : le verdict du banc porte sur le comportement intrinsèque de
l'artefact (budgets, chargement, fuites), pas sur une carte précise — c'est
l'arbitre qui juge l'adéquation à la partie en cours. Invalidation : bump de
`benchVersion` à chaque évolution des règles du banc.

## 8. Protocole du prototype R1 (mesures de sortie)

Le prototype est validé/invalidé sur un **corpus d'artefacts de test** commité
avec le banc (`test_artifacts/`) :

| Artefact | Attendu |
|----------|---------|
| `sain_plaque_piegee.qml` (fil rouge [doc 11](./11_VERTICAL_SLICE.md)) | `pass`, metrics dans les budgets |
| `boucle_infinie_onload.qml` (`while(true)` au `Component.onCompleted`) | `load_timeout`, jeu jamais gelé |
| `boucle_infinie_handler.qml` (boucle dans un handler d'événement) | `event_budget`/`bench_timeout` en P4 |
| `timer_spam.qml` (Timer 1 ms + emit) | `event_flood` ou rejet P0 (plancher Timer) |
| `alloc_massive.qml` (création d'objets en boucle) | `runaway_alloc` ou `object_quota` |
| `import_interdit.qml` (`QtWebSockets`) | rejeté **P0**, le banc n'est pas spawné |
| `acces_singleton.qml` (tentative `Game.`/`Catway.`) | erreur de référence en P2 (`load_failed`) — prouve le masquage |
| `writeset_hors_declaration.qml` (écrit une clé non déclarée) | `writeset_violation` en P4 |
| `fuite_teardown.qml` (Timer jamais détruit) | `leak` en P5 |

**Critères de réussite R1** (reportés sur Q-J06) :

1. **Fiabilité du kill** : 100 % des cas pathologiques ci-dessus tués/verdictés
   sans jamais bloquer le GUI du jeu superviseur.
2. **Reproductibilité** : 3 runs du corpus ⇒ 3 fois les mêmes verdicts
   (à seed fixe).
3. **Coût** : froid < 2 s, validation saine < 8 s (sinon : pool obligatoire ;
   si même le pool ne tient pas ⇒ signal négatif pour l'UX, à arbitrer).
4. **Masquage prouvé** : `acces_singleton.qml` ne peut atteindre aucun
   singleton du jeu — c'est la première brique mesurée de l'étage 2 (D13).
5. **Faux positifs** : l'artefact sain passe ; toute instabilité du verdict
   sur le cas sain est bloquante (un banc qui rejette du code correct rend
   l'itération S3 impossible).

## 9. Constantes (toutes derrière `#define`, pattern D22)

| Constante | Défaut | Rôle |
|-----------|--------|------|
| `MEOW_BENCH_TIMEOUT_MS` | 30 000 | timeout dur global côté superviseur |
| `MEOW_BENCH_LOAD_TIMEOUT_MS` | 5 000 | plafond P2 (D34) |
| `MEOW_BENCH_IDLE_TICKS` | 600 | ticks simulés en P3 |
| `MEOW_BENCH_MAX_RSS_MB` | 512 | auto-kill mémoire du banc |
| `MEOW_BENCH_POOL` | 1 | process chauds |
| `MEOW_BENCH_JOBS_PER_PROCESS` | 10 | recyclage même en `pass` |
| `MEOW_BENCH_DRYRUN_QUOTA` | 10 | dry-runs `artifact_dryrun` par invocation d'IA (D42) |
| Budgets artefact | valeurs D34 | sérialisés dans le job |

## 10. Points d'ancrage code

- **Sérialisation snapshot** : `MapFileManager` / `Map::toJSON` +
  `ItemSnapableFactory::createItemSnapableFromJson` (chemin full-sync).
  ⚠️ piège connu : la concat manuelle de strings dans `ItemSnapable::toJSON`
  (R4) — à assainir avant de s'appuyer dessus pour le job.
- **Moteur physique** : cœur Qt-free `pattounx::PattounX_engine`
  (`cpp/game/physics/pattounx_engine_v2.*`) — instanciable sans le worker
  thread ni `PhysicsSession` (le banc tick en direct).
- **Multi-instance** : `main.cpp --instance N` (pattern `dual_test_p2p`) pour
  l'isolation `AppDataLocation` si le banc a besoin d'un dossier de travail.
- **Nouveau dossier** : `cpp/ai/bench/` (superviseur côté jeu) + cible
  `meow_testbench` (main du banc) ; contexte restreint partagé dans
  `cpp/ai/sandbox/` (chantier M9, dont le banc est l'étage 1).

## 11. Questions restantes (propres au banc)

- **Quels types QML enregistrer dans le banc** : strictement l'allow-list D34
  + les briques snapables, ou tout l'enregistrement du jeu ? (Reco : ne lier
  que le nécessaire — c'est aussi ce qui garantit « pas de réseau ».)
- **P4 sans physique réelle** : l'acteur fantôme des stimuli traverse-t-il la
  zone via la vraie simulation Pattounx ou par téléport direct des
  callbacks ? (Reco MVP : injection directe des événements de zone, la
  physique réelle n'apporte rien au verdict budgets.)
- **Confinement OS post-MVP** : Job Objects / cgroups — après R1 si les
  mesures MVP suffisent.
- **Session atelier interactive (palier 2 de D42, post-MVP)** : process de
  banc persistant dédié à l'IA cliente — versions d'artefact poussées à
  chaud, stimuli déclenchés à la demande, métriques en continu,
  éventuellement rendu/capture (sortie du headless). Nouveau protocole
  jeu↔banc et cycle de vie de session à cadrer ; le mode pool (§6, jobs par
  stdin) fournit une partie de la plomberie.
