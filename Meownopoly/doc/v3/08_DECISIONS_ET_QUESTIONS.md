# 08 — Registre des décisions & questions ouvertes

> **Statut : document vivant.** Journal des décisions d'architecture (ADR léger)
> et des questions à trancher. Mettre à jour à chaque arbitrage.

## 1. Décisions prises

### D1 — Modèle d'exécution : **QML génératif complet**
- **Décision.** L'IA du joueur produit du **vrai code QML** chargé au runtime
  (`Qt.createQmlObject` / `Loader`), pas seulement des données ou une palette de
  briques figées.
- **Pourquoi.** Liberté maximale, cohérente avec « ajouter des éléments à la
  volée » et « une partie selon ses propres règles ». Exploite le fait que le QML
  est interprété.
- **Conséquence.** Le **sandbox** (doc 04) devient la pièce d'architecture la plus
  critique ; c'est la plus grande surface de sécurité du projet. Risque technique
  n°1 : la faisabilité réelle du sandboxing QML/JS dans Qt (à prototyper tôt).
- **Alternatives écartées.** « Palette + espace mémoire » (plus sûr, moins libre) ;
  « hybride validé » (compromis). Conservées comme **repli** si le sandbox complet
  s'avère infaisable.
- **Précision du but (2026-07-11).** Le mécanisme visé n'est pas « générer des
  scènes entières de zéro » mais **créer du gameplay** en **composant les briques
  graphiques et gameplay préexistantes** de l'éditeur (éléments posables, modules
  activables) **et en y embarquant du code JS** pour le comportement nouveau. D1
  reste « vrai code au runtime » (le JS embarqué en est), mais **adossé à un
  vocabulaire de briques validées** — ce qui rapproche l'usage courant de
  l'« hybride validé » et **réduit d'autant la surface du sandbox** (cf. doc 04 §5,
  doc 07 primitives).

### D2 — Canal d'interaction : **nouveau WebSocket dédié**
- **Décision.** Créer un canal WS **local dédié** IA↔jeu, distinct de
  l'`AutomationServer` (qui reste réservé au test/debug interne).
- **Pourquoi.** Séparer les responsabilités (debug bas niveau vs capacités
  gameplay de haut niveau), pouvoir **durcir la sécurité** du canal IA
  indépendamment (allow-list vs introspection totale), évoluer sans casser le
  harnais de dev.
- **Conséquence.** Réutiliser les **fondations** de l'automation (loopback strict,
  JSON corrélé, GUI thread) mais **pas** son catalogue permissif. Doc 02.
- **Frontière d'accès (non-négociable).** L'IA cliente n'a **aucun accès** au
  harnais d'automation (`AutomationServer` port 7700, `automation_mcp/`), réservé
  au test/debug. Le canal ré-expose un **sous-ensemble curé** (certaines features
  **portées** + durcies), orienté **création de briques de gameplay** — pas
  l'introspection/injection bas niveau. Réutilisation = **de code**, pas d'accès.
- **Alternatives écartées.** Étendre l'`AutomationServer` (couplage debug/prod
  indésirable) ; **exposer l'automation à l'IA** (surface de test dangereuse comme
  contrat d'IA) ; décider plus tard (le pivot a besoin du canal tôt).

### D3 — Moteur de règles : **cadrage différé** (partiellement levé par D8)
- **Décision.** Reporter le cadrage des **détails** (doc 06). L'**ownership** est,
  lui, tranché par **D8** : les règles sont **gouvernées par l'arbitre** et leur
  forme acceptée est exécutée par le jeu ; pas de moteur générique séparé acté.
- **Pourquoi.** Le format d'une règle proposée / sa mémorisation / sa réplication
  dépend encore des docs 04 (sandbox) et 05 (espace mémoire), à stabiliser d'abord.

### D4 — Bibliothèque : **cadrage différé**
- **Décision.** Reporter le cadrage (doc 07 = stub). Réserver l'emplacement.
- **Pourquoi.** Le format d'une entrée de bibliothèque dépend de la représentation
  d'un comportement/donnée (docs 04/05).
- **Précision du contenu (2026-07-12).** Une première brique de contenu est actée
  au niveau **intention** : une **bibliothèque d'assets 3D**, prévue au
  développement, pour **élargir le vocabulaire graphique** composable par l'IA
  (« large éventail de possibilités », doc 00 §2, doc 07 §1). Cela **précise** la
  lecture « primitives » (son versant graphique) **sans lever** le report : format
  d'entrée, pipeline d'import 3D, distribution et modèle de confiance restent à
  cadrer (doc 07 §3).

### D6 — Deux rôles d'IA : cliente (proposante) + arbitre (MJ) chez l'hôte
- **Décision (niveau vision).** Le modèle d'acteurs distingue **deux rôles** :
  une **IA cliente** proposante présente chez chaque joueur (hôte compris), et une
  **IA arbitre / MJ** présente **uniquement chez l'hôte**, qui vérifie la
  viabilité d'une proposition avant son introduction dans la partie. Topologie :
  **2 modèles chez l'hôte** (cliente + arbitre), **1 chez le client** (cliente).
  Cf. doc 00 §4.
- **Pourquoi.** Séparer une posture *créative/permissive* (proposer) d'une posture
  *conservatrice/responsable* (arbitrer) ; ajouter un jugement **contextuel**
  au-dessus des garde-fous **mécaniques** (sandbox doc 04, validateurs de
  capacités) ; garder un **point d'autorité unique** aligné sur le host-authoritative
  (`EditorSession`) pour éviter le split-brain.
- **Arbitre obligatoire.** Le mécanisme central ouvre la construction d'une
  partie partagée à plusieurs proposants : l'arbitrage de gouvernance n'est
  **pas** optionnel. Héberger une partie
  pilotée par IA **exige** un modèle arbitre branché ; sans lui, le mode IA est
  indisponible (repli sur le jeu classique). Pas de « host sans arbitre ». Cette
  obligation ne fournit aucune garantie de sécurité mécanique.
- **Conséquence.** L'arbitre se greffe sur le domaine d'autorité de l'édition.
  `EditorSession` fournit aujourd'hui rate-limit, séquencement et rebroadcast,
  mais pas une validation sémantique générique : la passerelle de proposition et
  ses validateurs sont une responsabilité V3 nouvelle. L'arbitre **ne porte pas**
  de garantie de sécurité dure.
- **Différé (sous-cadrage).** La **nature** de l'arbitre (LLM / règles
  déterministes / hybride), son **grain** (par action / par lot / par artefact
  QML), le **format de verdict** rendu au proposant, et son **articulation** avec
  l'exécution des règles (doc 06) restent à instruire — voir §2 « IA arbitre ».
- **Alternatives écartées.** IA unique par joueur mêlant proposition et validation
  (dilue la garantie d'intégrité) ; validation purement mécanique sans arbitre
  (perd le jugement contextuel « cohérence/équilibre »).

### D7 — Espace mémoire : configuration durable distincte de l'état runtime
- **Décision corrigée.** La **configuration durable** suit le pipeline
  `ApplyState`/`EditDelta` et peut participer à l'undo/persistance. L'**état
  runtime** suit une autorité hôte inspirée de `PhysicsSession` et n'est pas
  undoable au grain de l'écriture. Une écriture cliente est une intention.
- **Pourquoi.** Confondre les deux ferait soit saturer les piles undo, soit
  persister/annuler des états éphémères sans rapport. Un snapshot mémoire global
  lors d'un undo est dangereux en collaboration car il écrase des mutations
  concurrentes postérieures.
- **Conséquence.** `toJSON`/`applyJson` portent la configuration durable et,
  seulement si le produit le décide, un état de reprise distinct. L'undo d'un
  artefact repose sur son write-set durable ciblé, pas sur toute la mémoire.
- **À trancher (§2).** Noms/schéma des deux espaces ; protocole runtime dédié ou
  extension physique ; delta/snapshot, coalescence, fiabilité, cadence ; conflits
  d'undo/redo ciblé.
- **Alternative écartée pour le runtime.** « Voyage gratuit via `EditDelta`/`ApplyState` »
  (thèse initiale de doc 05) : simple mais **inadapté à la fréquence runtime** et
  polluerait l'undo d'édition. Conservé pour la configuration durable et sa
  persistance/transaction d'undo.

### D8 — L'arbitre gouverne les règles ; le jeu exécute leur forme acceptée
- **Décision.** L'IA arbitre est l'**autorité de politique** : elle valide ou non
  les propositions et maintient le règlement courant. Aucun moteur de règles
  générique séparé n'est acté. Une règle acceptée doit néanmoins être matérialisée
  sous une forme exécutable par les capacités du jeu (configuration, module,
  primitive ou QML/JS validé). **Aucune notion de tour imposée** — elle
  s'**introduit** (a) par le **prompt** donné à l'arbitre, ou (b) par une
  **modification proposée par une IA cliente que l'arbitre accepte** (règlement
  négociable/évolutif en cours de partie).
- **Pourquoi.** Cohérent avec « une partie selon ses propres règles » et avec le
  rôle de l'arbitre (D6). Évite de figer un DSL de règles côté cœur ; laisse la
  liberté maximale, l'autorité restant unique (hôte).
- **Conséquence.** Répond à la question d'autorité : l'arbitre gouverne, mais ne
  devient pas implicitement une boucle d'exécution temps réel. Les **invariants
  durs** (sécurité,
  intégrité) restent au **sandbox** (doc 04), pas à l'arbitre (jugement souple).
  Détails différés (format proposé/accepté, exécution, mémorisation, réplication)
  — doc 06 §4.
- **Alternatives écartées.** Moteur de règles déclaratif figé côté C++ (rigide,
  contraire à la liberté du pivot) ; règles hardcodées type « système de tour V2 »
  (**inexistant** de toute façon, cf. §Capacités).

### D5 — Dossier de cadrage
- **Décision.** Regrouper le cadrage V3 dans `Meownopoly/doc/v3/`, docs numérotés,
  en français, avec bandeaux de statut. Commit/push sur la branche **V3**.

## 2. Questions ouvertes (par thème)

Cette section reste le registre synthétique proche des décisions. Le questionnaire
remplissable et exhaustif est [`09_QUESTIONNAIRE_CADRAGE.md`](./09_QUESTIONNAIRE_CADRAGE.md).

### Sécurité (bloquant pour D1)
- Jusqu'où peut-on **verrouiller** un `QQmlContext` et l'allow-list d'imports dans
  Qt ? (prototype requis — risque technique n°1).
- **Réplication/exécution du QML génératif** en multi-joueurs : exécution locale
  après arbitrage hôte / répliqué+re-validé / host-validé+signé ? La source d'un
  client doit au minimum atteindre l'hôte pour arbitrage. Reco de départ :
  **exécution locale, sans broadcast aux pairs**.
- Isolation QML : contexte/moteur in-process, processus auxiliaire, ou repli
  DSL/capacités si l'arrêt préemptif d'un JS bloquant est impossible ?
- Authentification du canal local : simple loopback (comme l'automation) ou token
  de session ? Reco : **token**, car le canal exécute à terme du QML.

### Canal WS (doc 02)
- Un canal multiplexé vs plusieurs canaux (éditeur / runtime / règles) ?
- Comment distinguer et authentifier les deux clients locaux de l'hôte
  (proposant vs arbitre), avec quelles capacités pour chacun ?
- Sur quel bus interne brancher les **événements poussés** (signaux `Game`,
  `EditorOpBus.remoteOpReceived`, `ItemSnapableEvents`) ?
- **Quel sous-ensemble de l'automation porter** dans le catalogue curé du canal
  (pose, caméra, introspection d'état…) et lesquelles **rester** test-only ?
- Exposer une échappatoire `automation.raw` pour le prototypage ? (**tension** avec
  la frontière D2 : à n'envisager qu'en build de dev, jamais dans la skill livrée).

### Capacités manquantes (chantiers identifiés)
- Réconcilier **hooks ↔ tools MCP** (des hooks existent sans tool MCP) — prérequis
  à la génération de la skill (doc 03).
- Ajouter l'**introspection d'état** (lister tuiles par uuid/type/pos, énumérer les
  enums) — requise par la boucle perception→action.
- Ajouter l'**édition ciblée par uuid** (`deleteTile`, `moveTile`, `resizeTile`,
  `selectTile`).
- Ajouter les capacités **runtime** (piloter joueur/NPC en jeu, lire les bodies) —
  absentes en V2, requises pour « modules NPC/joueur ».

### IA arbitre / MJ (doc 00 §4, D6)
- **Nature de l'arbitre** : LLM (jugement souple, faillible), moteur de règles
  déterministe (fiable, rigide), ou hybride (règles dures + LLM pour le contextuel) ?
- **Grain d'arbitrage** : chaque action, un lot d'actions, ou seulement les
  artefacts QML génératifs ? Coût/latence d'un arbitrage LLM par action.
- **Format du verdict** : accepte / amende / rejette — l'« amende » modifie-t-il
  la proposition (et qui applique la modification) ? Le rejet doit être une
  **erreur actionnable** (doc 02 §5) pour que le proposant itère.
- ~~Auto-arbitrage de l'hôte~~ **Tranché (D6)** : les propositions de l'IA cliente
  de l'hôte passent par le même arbitre ; pas d'auto-exemption.
- ~~Frontière avec le contrat de règles : l'arbitre EST-il le moteur de règles ?~~
  **Tranché (D8) sur l'autorité** : l'arbitre gouverne les règles. L'exécution
  appartient à une forme matérialisée acceptée par le jeu. Restent ouverts :
  format proposé/accepté, exécution, mémorisation et réplication (doc 06 §4).
- ~~Panne / absence d'arbitre~~ **Tranché (D6)** : l'arbitre est **obligatoire**.
  Pas d'hôte sans arbitre ; à défaut, le mode IA est indisponible (repli jeu
  classique). Reste à définir l'**UX du prérequis** : comment le jeu détecte/exige
  qu'un arbitre soit branché avant d'autoriser l'hébergement d'une partie IA.

### Espace mémoire (doc 05, sémantiques tranchées par D7)
- Blob **global à la tuile** vs **par sous-paramètre** ? Reco : global.
- Schéma/noms de la **configuration durable** et de l'**état runtime** ; l'état
  doit-il être sauvegardable séparément pour reprendre une partie ?
- **Transport runtime** (D7) : protocole dédié vs extension physique ; delta vs
  snapshot, coalescence, reliable/raw, cadence et plafond.
- **Undo ciblé** (D7) : write-set durable, conflit si une clé a changé depuis,
  comportement du redo. Le snapshot global n'est plus recommandé.
- Traiter proprement la **sérialisation string-manuelle** de `ItemSnapable::toJSON`
  (piège n°1).
- Plafond de taille du blob.

### Skill client (doc 03)
- Quel agent client cible-t-on d'abord (format de skill natif) ?
- Emplacement d'installation standardisé multi-plateforme.
- Génération : script de build dédié ou étape d'installeur ?

## 3. Risques majeurs

| # | Risque | Impact | Atténuation |
|---|--------|--------|-------------|
| R1 | Sandbox QML infaisable/insuffisant dans Qt | Bloque D1 | Prototyper tôt ; repli « palette + mémoire » ; démarrer en exécution locale arbitrée par l'hôte |
| R2 | RCE inter-joueurs via QML répliqué | Critique | Local-only d'abord ; re-validation + host-authoritative ensuite |
| R3 | Canal local détourné par un autre process | Élevé | Token de session + loopback strict |
| R4 | Sérialisation cassée du blob mémoire | Moyen | Passer `toJSON` du blob par `QJsonDocument` (doc 05 §3) |
| R5 | Dérive skill ↔ capacités réelles | Moyen | Générer la skill depuis le manifeste versionné du canal (source unique) ; MCP = patron uniquement |
| R6 | Complexité multi-joueurs des règles custom | Moyen | Différé (D3) ; concevoir avec host-authoritative en tête |
| R7 | Confiance excédentaire dans l'arbitre (jugement faillible pris pour un garde-fou dur) | Élevé | Sécurité dure = sandbox (doc 04) + contrat (doc 06) ; l'arbitre n'affine que le contextuel (doc 00 §8) |
| R8 | Arbitrage LLM par action : latence/coût dégradant l'UX collab | Moyen | Grain à cadrer (D6) : arbitrer par lot / seulement le QML génératif ; fallback mécanique |
| R9 | Flux mémoire saturant la bande passante ou rejouant des états obsolètes | Moyen | Delta/coalescence + plafond ; mesurer cadence et reliable/raw (D7) |
| R10 | Undo d'un artefact écrasant un état concurrent | Élevé | Séparer config/runtime ; inverse ciblé par write-set, jamais snapshot global |
| R11 | Boucle JS bloquant le GUI malgré `destroy()` | Critique | Prototype d'isolation préemptive ; processus séparé ou repli DSL/capacités |
| R12 | Règles acceptées mais non exécutables/rejouables | Élevé | Matérialiser chaque règle acceptée dans une forme versionnée et validée |

## 4. Séquencement suggéré (non engageant)

1. **Prototype sandbox QML** (R1) — dé-risque D1 avant tout le reste.
2. **Espace mémoire** (doc 05) : Étape A (modèle + séparation config/runtime),
   puis prototypes distincts B (transport runtime) et C (undo ciblé concurrent).
3. **Canal WS minimal** (doc 02) : introspection d'état + `setMemory` + pose,
   réutilisant les hooks existants.
4. **Réconciliation hooks/MCP + génération de skill** (docs 03).
5. **Capacités runtime** (piloter joueur/NPC).
6. Rouvrir **règles** (D3) et **bibliothèque** (D4).
