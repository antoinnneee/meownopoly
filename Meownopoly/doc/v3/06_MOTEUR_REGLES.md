# 06 — Règles de partie (gouvernées par l'arbitre)

> **Statut : cadré pour l'implémentation (re-cadrage T4-4, 2026-07-18).**
> **D8 décide l'autorité de politique** : les règles sont **gouvernées par l'IA
> arbitre** (pas de moteur générique séparé décidé à ce stade) ; il n'y a pas de
> tour imposé, il s'introduit par prompt ou proposition acceptée. Le §5 fixe le
> cadrage exécutable du MVP (règlement matérialisé, formes D12, ordre D33) ;
> les points encore ouverts sont listés en §6 et restent à ré-arbitrer en revue.

## 1. Intention & décision cadre (D8)

Chaque joueur, via son IA, doit pouvoir **construire une partie selon ses propres
règles**. **Décision (D8) : les règles sont gouvernées par l'IA arbitre**
([doc 00](./00_VISION.md) §4, D6) — c'est l'arbitre qui accepte ou refuse les propositions et
maintient la politique courante. Cela ne signifie pas que le LLM exécute chaque
événement du runtime : une règle acceptée doit être **matérialisée** sous une forme
exécutable par le jeu (configuration, module, primitive ou artefact QML/JS validé).
Aucun moteur de règles générique séparé n'est décidé à ce stade.

Conséquences directes :

- **Pas de notion de tour imposée.** Aucune règle de tour n'est câblée par défaut
  (V2 n'en a **pas** — cf. §3).
- **Les règles (dont le tour) sont introduites de deux façons :**
  1. par le **prompt donné à l'arbitre** (le joueur hôte configure son MJ : « joue
     au tour par tour », « loyer doublé au bord de l'eau »…) ;
  2. par une **modification proposée par une IA cliente**, **si l'arbitre
     l'accepte** — le règlement est donc **négociable et évolutif en cours de
     partie**, sous l'autorité de l'arbitre.
- **Les invariants durs restent hors de l'arbitre** : intégrité/sécurité sont
  tenues par le **sandbox** ([doc 04](./04_QML_GENERATIF_SANDBOX.md)), pas par le jugement souple du MJ ([doc 00](./00_VISION.md) §9).

## 2. Périmètre (recadré par D8)

- **Règlement souple = politique de l'arbitre.** L'ensemble des règles de partie
  (déclencheurs → effets, phases/tour éventuels, conditions de victoire,
  économie/loyers) n'est **pas** un DSL figé côté cœur : c'est ce que l'arbitre
  **connaît** et fait évoluer via des propositions acceptées. Le prompt seul ne
  suffit toutefois ni à la reprise, ni à la migration d'hôte, ni à l'exécution
  déterministe : le règlement accepté a un **état matérialisé** (§5.1).
  L'arbitre choisit la vue du règlement exposée aux joueurs et peut la modifier
  en cours de partie ; l'état autoritatif complet reste néanmoins versionné pour
  migration et audit.
- **Exécution = capacités du jeu.** Les effets runtime sont appliqués par des
  primitives/modules existants ou par du QML/JS validé. L'arbitre juge et produit
  un plan/verdict ; il ne devient pas implicitement une boucle temps réel.
- **Représentation hiérarchique (D12).** Le jeu choisit la forme la moins libre
  suffisante : plan de capacités, configuration de module, DSL/machine à états,
  puis QML/JS sandboxé. Le règlement autoritatif est un document structuré
  versionné ; le prompt n'en est qu'une vue/configuration.
- **Invariants durs = sandbox + garde-fous** ([doc 04](./04_QML_GENERATIF_SANDBOX.md)) : intégrité de partie,
  anti-triche, limites de ressources, sécurité — **non-négociables**, hors du
  jugement de l'arbitre. L'arbitre affine ; il ne peut jamais lever ces invariants.

## 3. Ancrages avec le reste du cadrage

- **Consomme l'espace mémoire** ([doc 05](./05_ESPACE_MEMOIRE_SNAPABLE.md)) : les règles lisent **et écrivent** la
  configuration et l'état des tuiles (`config`, `state`, `tags`) pour décider des
  effets (« si `tags` contient `water-adjacent`, loyer
  ×`config.rentMultiplier` »). Surtout, elles
  **réagissent** aux changements via le signal `userMemoryChanged` ([doc 05](./05_ESPACE_MEMOIRE_SNAPABLE.md) §1
  usage 3) — un changement de variable, local ou reçu par broadcast, réveille la
  règle. L'espace mémoire est donc le **bus de variables** des comportements, pas
  un simple stockage passif.
- **Peut déléguer au QML génératif** ([doc 04](./04_QML_GENERATIF_SANDBOX.md)) pour les effets non exprimables en
  données.
- **Compatible host-authoritative** : l'exécution des règles est **hôte
  uniquement** (D33 — un client ne déclenche jamais une règle localement) ; les
  effets se répliquent par leurs canaux existants (mémoire `state` via le bus
  D15/StateBus, structure via le pipeline d'édition).
- Existant V2 cartographié (§5.6) : `GameplayModuleManager`
  (modules activables : vie, inventaire, monnaie, stats, XP/niveau, équipement)
  est la couche de **primitives** sous les règles (D12). **⚠️ Il n'existe pas de
  système de tour en V2** : le socle de règles l'**introduit** (déclencheurs,
  phases, conditions de victoire), il ne surcharge pas un existant.

## 4. Historique des questions (instruites ou tranchées)

- ~~**Mémorisation du règlement en cours**~~ **Cadré §5.1** : document structuré
  versionné (`Rulebook`) tenu par le moteur hôte (`RulesEngine`), sérialisé pour
  la sauvegarde de partie (M7/T4-2) et le checkpoint de migration (D37/T4-3,
  « règlement versionné — bloquant »). Le contexte de l'arbitre n'est qu'une vue.
- ~~**Format d'une règle proposée**~~ **Cadré §5.2** : opération `rulebook_set`
  dans l'enveloppe D11 (catégorie `rules` déjà reconnue par le P0), portant des
  règles structurées aux formes D12. Le texte libre reste possible côté arbitre
  (prompt), mais rien n'est exécutable sans matérialisation structurée.
- ~~**Forme exécutable d'une règle acceptée**~~ **Tranché D32** : sélection
  **mécanique** d'abord (l'échelle D12 choisit la forme la plus basse
  suffisante), l'arbitre confirme ou rétrograde ; un élément amendé repasse par
  le banc D26. Détail des formes intermédiaires : §5.2.
- ~~**Déclenchement runtime**~~ **Tranché D33** : autorité **par source** (rien
  n'est autoritatif sans passer par l'hôte), ordre déterministe physique →
  mémoire → actions → tick via la file D12. Réalisation : §5.3.
- **Réplication** : partiellement cadrée (§5.4) — exécution hôte seul au MVP,
  effets répliqués par leurs canaux existants ; la **diffusion du document de
  règlement** aux pairs/IA clientes reste ouverte (§6).
- ~~**Rapport avec `GameplayModuleManager`**~~ **Tranché D12 : les deux** ;
  les modules sont des primitives sous la couche de règles (forme `module`, §5.2).
- ~~**Bootstrap du tour**~~ **tranché D12** — artefact généré et/ou orchestration
  directe de l'arbitre, sans primitive native exigée.
- **Amendement** : D11 autorise l'arbitre à modifier et appliquer immédiatement
  une proposition. La proposition originale et la forme appliquée sont toutes
  deux persistées (journal D19 + `originProposalId` sur chaque règle, §5.2).

## 5. Cadrage T4-4 (2026-07-18) — règlement matérialisé et pipeline runtime

Réalisé dans `cpp/game/rules/` (`rulebook.{h,cpp}` : modèle de données pur ;
`rules_engine.{h,cpp}` : singleton QML `MeowRules 1.0 · RulesEngine`).

### 5.1 Le règlement : document structuré versionné (`Rulebook`)

- `Rulebook = { schemaVersion, version, title, rules[] }`.
- `version` est un **compteur monotone côté hôte**, incrémenté à chaque
  opération de règlement appliquée. C'est **le champ `rulebook` de
  `baseVersion`** des enveloppes de proposition ([doc 13](./13_ENVELOPPE_PROPOSITION.md) §3) : une
  proposition bâtie sur un règlement dépassé part en `stale_base`
  (déjà câblé dans `proposal_lifecycle.cpp`).
- Le document vit chez l'hôte dans `RulesEngine` ; il est **sérialisable**
  (`toJson`/`loadJson`) pour : la sauvegarde de partie M7 (T4-2), le checkpoint
  de migration D37 (T4-3, priorité 1 « bloquant »), et l'audit. Le prompt/
  contexte de l'arbitre n'est **jamais** le lieu de vérité.

### 5.2 Format d'une règle et formes D12

Une `Rule` porte : identité (`id`, `title`, `notes` — la vue lisible que
l'arbitre choisit d'exposer), origine (`originProposalId`, `author` — trace
d'amendement D11), un déclencheur, et une **forme** parmi (échelle D12, du moins
libre au plus libre) :

1. **`module`** — configuration de primitive : active/désactive un module
   `GameplayModuleManager` (`moduleId`, `moduleEnabled`). Validation par schéma.
2. **`dsl`** — règle déclarative bornée : `trigger` (type d'événement de la
   taxonomie canal Q-E06 : `tile.placed`, `memory.changed`, `combat.resolved`,
   `game.tick`, … ou `*`), `conditions[]` (ET logique ; sources
   `event.<champ>` / `memory.<portée>.<clé>` ; opérateurs
   `eq/neq/lt/lte/gt/gte/contains/exists/missing`), `effects[]` (actions
   fermées : `memory.set`, `event.emit`, `module.config`). **Pas de boucle, pas
   d'expression arbitraire** — l'interpréteur est borné par construction ;
   validation par l'interpréteur (`Rule::isValid`).
3. **`artifact`** — référence à un artefact QML/JS **déjà validé au banc**
   (`artifactHash`, `artifactUuid`). Le moteur ne l'exécute pas lui-même : il
   publie le déclenchement (`rule.triggered`) que la couche sandbox/runtime
   (S-6, D13) consomme. Aucun code ne contourne le banc (D32).

Le canal de modification est l'op **`rulebook_set`** de l'enveloppe D11
(catégorie `rules` — `proposal_envelope.cpp` la classe déjà), payload
`{ mode: set | add_rule | update_rule | remove_rule | clear, … }`, appliquée à
l'hôte par `RulesEngine::applyRulebookOp` après verdict. Chaque application
bump `version` et publie l'événement durable **`rules.changed`** (déjà prévu
dans les types pertinents du résumé injecté, D44).

### 5.3 Ordre déterministe D33 (physique → mémoire → actions → tick)

Le moteur s'abonne au `GameplayEventBus` (file transactionnelle D12 déjà en
place : profondeur max, budget de cascade, détection de cycles) et classe chaque
événement admis dans **quatre phases** : physique (types 4xx), mémoire (5xx),
actions/édition (2xx-3xx), tick/divers (1xx, 6xx). Un **pas de simulation** =
un drainage : les phases sont traitées dans l'ordre D33, et à l'intérieur d'une
phase par `seq` croissante (séquence d'arrivée hôte). Au MVP le pas est
coalescé sur le tour de boucle d'événements (drain différé) ; `tick()` publie
en outre un événement `game.tick` explicite (le « tour » D12 s'orchestre
au-dessus, par règle ou par l'arbitre — aucune primitive native de tour).

Les **écritures mémoire** session/joueur (`MemoryStore.memoryValueChanged`)
sont **ingérées comme événements** `memory.changed` par le moteur — l'espace
mémoire devient réellement le bus de variables des règles (§3). Un effet de
règle qui écrit la mémoire produit un `memory.changed` **causé** par
l'événement déclencheur (`causeId`) : les garde-fous D12 du bus (profondeur,
budget, cycle par write-target) couvrent donc gratuitement les cascades de
règles, y compris les boucles règle→mémoire→règle.

### 5.4 Autorité et réplication (MVP)

- **Exécution hôte uniquement** (`hostAuthority`) : conforme D33 (« un client ne
  déclenche jamais une règle localement »). Un client garde une copie passive du
  règlement (affichage/anticipation) mais n'exécute rien.
- Les **effets** se répliquent par leurs canaux existants : mémoire `state` via
  le bus d'état D15/D35 (`StateBus`, T3-3), structure via le pipeline d'édition,
  modules via l'op `structure` (D41).
- La **diffusion du document `Rulebook`** lui-même (push aux pairs + IA clientes
  après acceptation) reste ouverte — candidate naturelle : `ProposalSession`
  (plage 0x60+, T3-2) qui transporte déjà les verdicts. Voir §6.

### 5.5 Protections

Réutilisées, pas dupliquées : plafonds D12 du bus (profondeur 32, budget 512,
64 écritures/cible, file bornée) + plafonds D35 de la mémoire (1 KB/valeur,
quotas par portée) + garde de réentrance du moteur (profondeur d'évaluation) et
plafond d'effets par règle. Rejets comptés (`rejectedCount`) et journalisés.

### 5.6 Cartographie V2 consommée

- `GameplayModuleManager` + 7 modules (santé, inventaire, monnaie, stats,
  XP, niveau, équipement) → primitives de la forme `module` ; l'état des
  modules est déjà dans le snapshot du banc (S-5/D41).
- `GameplayEventBus` (M5, D1-D4) → source unique d'événements + protections.
- `MemoryStore` (S-4) / `ItemSnapable.userMemory` (S-3) → lecture/écriture des
  conditions et effets.
- **Aucun système de tour V2** à réutiliser — confirmé.

## 6. Reste ouvert (à ré-arbitrer en revue Antoine/Valou)

- **Diffusion du `Rulebook` aux pairs et aux IA clientes** après acceptation
  (transport pressenti : `ProposalSession` ; format : le JSON §5.1) — non
  implémentée au MVP (exécution hôte seul, clients passifs).
- **Ingestion des `memory.changed` de tuiles** : `ItemSnapable.memoryValueChanged`
  n'est pas agrégé centralement (contrairement à session/joueurs via
  `MemoryStore`) — un agrégateur tuiles (patron `ItemSnapableEvents`) est requis
  pour déclencher des règles sur la mémoire d'une tuile ; au MVP seules les
  portées session/joueur réveillent les règles.
- **Formes intermédiaires du DSL** au-delà des trois actions MVP (machine à
  états déclarée, arithmétique bornée dans les effets) — au cas par cas (D32).
- **`priority` par règle** (D33 : « possible plus tard, pas au MVP »).
- **Exposition tool du règlement** côté canal (`state_query what:"rules"`
  renvoie encore `notImplemented` — branchement gateway hors périmètre T4-4).
