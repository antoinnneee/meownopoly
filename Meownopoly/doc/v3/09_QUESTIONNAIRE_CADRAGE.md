# 09 — Questionnaire de cadrage V3 (questions ouvertes)

> **Statut : épuré le 2026-07-12, questions restantes détaillées le 2026-07-12.**
> Le questionnaire initial a été dépouillé et ses arbitrages reportés dans le
> doc 08 (**D9→D30**). Ce fichier ne contient plus que les **questions encore
> ouvertes**, chacune détaillée avec son contexte, ses options et une
> **proposition** prête à être validée ou amendée. Les questions tranchées ou
> devenues caduques sont retirées ; la table §0 en garde la trace.

## Mode d'emploi

- **B0** : bloque le choix d'architecture ou la preuve de faisabilité.
- **B1** : nécessaire avant un premier vertical slice multi-joueurs.
- **B2** : peut être différé après le prototype, mais doit rester tracé.
- Chaque question porte désormais une **Proposition** argumentée : valider,
  amender ou refuser suffit à la fermer.
- Après remplissage, reporter chaque arbitrage stable dans le doc 08 sous un ID
  de décision, puis retirer la question d'ici.
- Les mentions **Vérification stack** renvoient à
  [`10_AUDIT_STACK_EXISTANTE.md`](./10_AUDIT_STACK_EXISTANTE.md).

---

## 0. Questions retirées (traçabilité)

| Questions | Sort | Décision |
|-----------|------|----------|
| A02→A08 (arbitre solo, mode classique, entrée auto, modif en cours, liberté MVP, cible, plateformes) | tranchées | **D9** |
| B01→B03, B05→B08 (instances isolées, fournisseurs, supervision, panne/migration, budget, visibilité règles, changement d'arbitre) | tranchées | **D10** |
| C02→C05 (enveloppe, amendement immédiat, persistance verdict, ordre de contrôle) | tranchées | **D11** |
| C10→C12 (tour, GameplayModuleManager, application d'un effet partagé) | tranchées | **D12 / D16** |
| C09 (anti-boucle : profondeur + file + cycles, tous requis) | tranchée | **D12** |
| D01→D03, D07→D10 (niveau d'isolation, lieu d'exécution, repli, revue humaine, menace, artefacts disque, tests R1) | tranchées (conditionnel R1) | **D13** |
| E01, E04, E05, E07, E09 (canal multiplexé, version globale, adaptateur d'événements, tout-ou-rien, automation.raw dev-only) | tranchées | **D14** (transport révisé par **D20** : MCP local) |
| F01, F03, F04, F08, F09, F11 (namespaces config/state, portée tuiles+session+joueurs, bus générique, séquencement hôte/LWW, write-set, signaux) | tranchées | **D15** |
| G01→G05 (source → hôte, exécution par propriété, identité UUID+hash, store map+séparé, artefact manquant) | tranchées | **D16** |
| H01, H03, H05→H07 (Codex+Claude, manifeste source de vérité, génération au build, skill obsolète, catalogue curé) | tranchées | **D17** |
| H04 (emplacement d'installation de la skill) | caduque : skill embarquée dans l'app, injectée en pré-prompt à l'invocation ingame | précision **D17** (2026-07-12) |
| E02, E03 (découverte du secret, authentification locale) | tranchées par construction : l'app spawne l'agent et lui injecte config MCP + token éphémère ; tokens/capacités distincts par rôle | **D20** (2026-07-12) |
| H02 (comment l'agent atteint le canal) | tranchée : connecteur MCP natif de `claude -p`/Codex, config injectée au spawn | **D20** (2026-07-12) |
| I01→I03, I06, I07 (bibliothèque locale officielle, asset_server réutilisé, GLB, imports devs) | tranchées | **D18** |
| I08 (référencement d'un asset) | tranchée dans son principe : clés existantes + version/hash | **D16/D18** |
| J01 (journal configurable, noyau d'audit non désactivable) | tranchée (rétention → Q-J02) | **D19** |
| E11 (forme d'intégration du serveur MCP) | tranchée : streamable HTTP loopback **intégré au jeu** (les deux CLIs le supportent nativement, vérifié 2026-07-12 ; `QtHttpServer` à installer ; repli pont stdio documenté) | **D21** (2026-07-12) |
| E10 (politique de capture d'écran) | tranchée : écran de jeu à la demande de l'IA, plafond par requête via `#define` (défaut 5), rétention éphémère (quelques tours), aucun masquage, information une fois au lancement | **D22** (2026-07-12) |
| **A01 (ordre de livraison des trois modes)** | **tranchée** : éditeur solo → collaboratif → runtime | **D23** (2026-07-12) |
| **B04 — principe (preuve qu'un arbitre est prêt)** | **tranchée** : handshake de rôle sur le canal + challenge de capacité ; **l'UX du prérequis reste ci-dessous** | **D24** (2026-07-12) |
| **C01 (unité déclenchant un appel arbitre)** | **tranchée** : grain **configurable par UI** (types de requêtes soumis à l'arbitre) ; plancher proposé sur code/règles, défaut hybride | **D25** (2026-07-12) |
| **Note section D (nature de la sandbox)** | **tranchée** : la sandbox de validation est un **banc d'essai hors-process** (moteur/process distincts, réinstancie la carte depuis un snapshot, détecte non-chargement/boucle infinie) ; D13 recentré sur le confinement en partie | **D26** (2026-07-12) |
| **F02 (persistance de l'état runtime)** | **tranchée** : sauvegarde de partie **distincte** de la map | **D27** (2026-07-12) |
| **F10 (undo sur valeur modifiée depuis)** | **tranchée** : **restaure malgré tout** (LWW assumé, R10 accepté, trace au journal) | **D28** (2026-07-12) |
| **I04 — principe (format de package)** | **tranchée dans son principe** : même format que l'`AssetManager`/asset_server, étendu ; **les champs exacts restent ci-dessous** | **D29** (2026-07-12) |
| **J05 (scénarios du vertical slice)** | **tranchée** : slice solo S1/S2/S3, défini dans [`11_VERTICAL_SLICE.md`](./11_VERTICAL_SLICE.md) | **D30** (2026-07-12) |

---

## B. Arbitre : UX du prérequis

### Q-B04 (reste) — Comment le lobby affiche et impose l'état de l'arbitre ? — **B1**

Le principe est tranché (D24 : handshake de rôle + challenge de capacité,
exécutés par l'app avant d'ouvrir le mode IA). Reste l'**UX** : comment le
joueur voit, comprend et débloque le prérequis.

**Proposition.**
- **Indicateur d'état à 4 valeurs** dans le lobby/menu de création de partie IA :
  `Absent` (aucun CLI arbitre configuré) → `Test en cours` (handshake+challenge
  lancés) → `Prêt` (verdict de test OK, version protocole compatible) →
  `Erreur` (échec + raison actionnable : CLI introuvable, auth fournisseur
  manquante, timeout).
- Le bouton « Héberger une partie IA » est **grisé tant que l'état ≠ Prêt**,
  avec le motif affiché à côté (pas de dialogue bloquant).
- Un bouton **« Tester l'arbitre »** relance le handshake à la demande ;
  le test est aussi relancé automatiquement à l'ouverture du lobby.
- En cours de partie, si l'arbitre meurt (process terminé, timeouts répétés),
  bandeau persistant « Arbitre indisponible — propositions suspendues » ;
  les propositions sont mises en file, pas perdues.

- **Réponse :**

---

## C. Arbitrage et règles

### Q-C06 — Qui choisit la forme exécutable d'une règle, et qui la valide ? — **B1**

D12 fixe la hiérarchie (plan de capacités → config de modules → DSL/machine à
états → QML/JS sandboxé, forme la moins libre suffisante). Reste : **qui**
sélectionne la forme, sur quels **critères**, et **qui compile/valide** chaque
niveau (doc 06 §4).

**Proposition.**
- **La sélection est mécanique d'abord** : le validateur de la passerelle tente
  de matérialiser la proposition dans la forme la moins libre qui couvre le
  besoin (heuristique : pas de code → config de modules ; logique séquentielle
  simple → DSL ; sinon QML/JS). L'**arbitre confirme ou rétrograde** (il peut
  exiger une forme plus contrainte, jamais plus libre que la proposition).
- **Critères de sélection** : présence de code, événements écoutés, write-set
  touché, besoin d'état persistant, interaction avec d'autres règles.
- **Validation par niveau** : config de modules = validation de schéma ;
  DSL = interpréteur maison borné ; QML/JS = banc d'essai hors-process (D26)
  puis budgets runtime (D13).

- **Réponse :**

### Q-C08 (restes) — Autorité et priorité des événements déclencheurs — **B1**

La liste est tranchée (précision D12 : **tous les événements disponibles** —
collision, entrée/sortie de zone, écriture mémoire, tick, action joueur…).
Restent l'**autorité** de chaque événement et l'**ordre** en cas de
simultanéité (« le plus logique possible » à traduire en règle déterministe).

**Proposition.**
- **Autorité par source** : événements physiques (collision, zones) =
  **hôte** (la simulation Pattounx est déjà host-authoritative) ; écritures
  mémoire `state` = **hôte** (bus D15, séquencement hôte) ; écritures `config`
  = pipeline d'édition (op acceptée = événement) ; actions joueur = émises par
  le client, **validées/ordonnées par l'hôte** ; tick = hôte uniquement.
  Règle simple : **aucun événement n'est autoritatif tant qu'il n'est pas passé
  par l'hôte** — un client ne déclenche jamais une règle localement.
- **Ordre déterministe** : les événements d'un même pas de simulation sont
  traités dans la **file transactionnelle** (D12) dans l'ordre : physique →
  mémoire → actions joueur → tick, puis par séquence d'arrivée hôte. Priorité
  explicite par règle possible plus tard (champ `priority`), pas au MVP.

- **Réponse :**

---

## D. Sandbox : contenu exact (banc d'essai D26 + confinement runtime D13)

### Q-D04 — Quelle allow-list d'imports/types/fonctions au MVP ? — **B0**

**Proposition** (cohérente avec les briques existantes et le but « JS embarqué
sur briques validées », doc 04 §5) :

- **Imports autorisés** :
  - `QtQuick` (types visuels et animation de base),
  - `QtQuick.Shapes` (déjà utilisé pour les vignettes — cf. absence de
    Qt5Compat dans le kit),
  - `QtQuick.Layouts`,
  - **`Meow.GameApi`** (le module façade §Q-D05 — seul accès au jeu),
  - rien d'autre au MVP. Ni `QtQuick.Controls` (surface énorme, inutile pour
    du gameplay), ni `QtQuick.Dialogs`, ni `Qt.labs.*`, ni `QtMultimedia`,
    ni `QtQuick.LocalStorage`, ni `QtWebEngine`/`QtWebSockets`.
- **Types autorisés** (au sein des imports ci-dessus) : `Item`, `Rectangle`,
  `Text`, `Image` (source restreinte aux assets de la bibliothèque, pas
  d'URL réseau), `Shape`/`ShapePath`, `Timer` (intervalle plancher imposé),
  familles `Animation`/`Behavior`/`State`/`Transition`, `Connections`
  (uniquement vers des cibles de la façade).
- **Fonctions/objets globaux interdits** (liste noire vérifiée statiquement
  puis masquée au contexte) : `XMLHttpRequest`, `fetch`, `eval`,
  `Function(...)` (constructeur), `Qt.createQmlObject`, `Qt.createComponent`,
  `Qt.openUrlExternally`, `Qt.quit`/`Qt.exit`, `Qt.include`,
  `import "….js"` arbitraire, `gc()`, accès aux singletons du jeu
  (`Game`, `Catway`, `EditorOpBus`, `MapFileManager`, `PhysicsSession`,
  `pattounxWorld`… — masqués par le contexte restreint, jamais exposés).

- **Réponse :**

### Q-D05 — Liste exacte de la façade « API de jeu » (`Meow.GameApi`) — **B0**

Orientation tranchée : mémoire + événements + animations + capacités gameplay
sélectionnées (doc 04 §3.3). **Proposition de liste MVP** — chaque entrée est
un point de contrôle (quota, autorisation, journalisation) :

- **Mémoire (doc 05)** : `memory.get(key)`, `memory.set(key, value)` (namespace
  `state` de sa propre tuile ; quotas D15), `memory.onChanged(key, handler)` ;
  lecture seule sur la mémoire de session : `session.get(key)`.
- **Événements** : `events.on(type, handler)` (types du catalogue Q-C08),
  `events.emit(name, payload)` (événements custom, préfixés par l'uuid de
  l'artefact, débit plafonné).
- **Gameplay** : `player.position()` (lecture), `zone.playersInside()`,
  `stats.addModifier(...)` (le module stats existe déjà côté hooks),
  `dialogue.show(text, choices)` (réutilise les dialogues NPC).
- **Présentation** : `anim.play(name)`, `fx.spawn(effectId, pos)`,
  `sound.play(soundId)` (ids de la bibliothèque uniquement).
- **Pas au MVP** : téléportation/déplacement forcé du joueur, spawn/destroy
  d'autres tuiles, accès réseau, accès à d'autres tuiles en écriture
  (tout cela passe par des propositions, pas par le code embarqué).

- **Réponse :**

### Q-D06 — Quels budgets impose-t-on ? — **B1** *(valeurs de départ à affiner en test)*

**Proposition de valeurs initiales** (chacune derrière une constante/`#define`,
comme le plafond screenshots D22) :

- **Taille source/artefact** : ≤ **20 KB** (aligné sur le chunking réseau
  existant de `editor_session`).
- **CPU par événement** : ≤ **2 ms** par handler ; **tick** : ≤ 0,5 ms.
  Mesuré au banc d'essai (D26) et surveillé en partie.
- **Mémoire** : ≤ **8 Mo** par artefact instancié (heap JS + objets).
- **Nombre d'objets** : ≤ **200** items QML par artefact.
- **Débit d'événements** : ≤ **30 émissions/s** par artefact ; `Timer`
  plancher **100 ms**.
- **Banc d'essai (D26)** : chargement ≤ 5 s, sinon échec « non-chargement » ;
  simulation de N ticks sans dépassement avant verdict.

- **Réponse :**

---

## E. Canal local : événements et catalogue

### Q-E06 — Sémantique du résumé d'événements injecté et du curseur `events_poll` — **B1**

À spécifier : schéma du résumé, garanties du curseur, filtrage par rôle.

**Proposition.**
- **Curseur = séquence monotone du journal métier hôte** (D19). Chaque entrée :
  `{seq, ts, type, actor, summary, refs}` (`refs` = uuids touchés).
- **Résumé injecté par invocation** : l'app génère un bloc compact
  « depuis ton dernier tour (seq N→M) : X tuiles posées (par qui), Y verdicts
  (accepté/rejeté + raison courte), Z changements d'état pertinents », plafonné
  (ex. 30 lignes) avec mention explicite `+ K événements omis — events_poll(N)`.
- **Garanties du curseur** : relecture idempotente depuis n'importe quel `seq`
  conservé ; si le journal est tronqué en deçà du curseur demandé, réponse
  `{truncated: true, oldestSeq}` → l'agent resynchronise par `state_query`
  (état courant) au lieu de rejouer l'historique.
- **Filtrage par rôle** : le proposant voit les événements « publics » de la
  partie ; l'arbitre voit en plus les propositions en file et les
  amendements. Filtrage fait côté serveur MCP (capacités du token, D20).

- **Réponse :**

### Q-E08 — Sous-ensemble exact des tools portés au MVP — **B1**

Familles retenues (doc 02 §5). **Proposition de manifeste MVP — 10 tools** :

| Tool | Rôle | Regroupe |
|------|------|----------|
| `help(topic)` | divulgation progressive de la doc détaillée | — |
| `state_query(what, filter?, cursor?)` | lecture : `tiles`, `tile`, `enums`, `roster`, `players`, `rules`, `memory` | listTiles/getTile/enum/roster/getMemory |
| `editor_place(kind, params)` | pose : asset/case/zone/NPC/ennemi/caisse | placeAsset/placeCase/placeZone/placeNPC/placeEnemy/placeCrate |
| `editor_edit(uuid, op, params)` | édition d'existant : move/resize/delete/link/set_param/set_trigger/set_dialogue | moveTile/resizeTile/deleteTile/setZoneTrigger/setNpcDialogue |
| `memory_set(scope, uuid?, key, value)` | écriture mémoire `config` (pipeline édition) | setMemory |
| `roster_edit(op, params)` | profils joueurs + min/max | ops collab 12-16 |
| `artifact_submit(source, target?, meta)` | soumission d'un artefact QML/JS → enveloppe de proposition (D11) | qml.instantiate |
| `events_poll(cursor)` | resynchronisation en cours de tâche | — |
| `screenshot(view?)` | retour visuel (plafond D22) | — |
| `arbiter_verdict(proposalId, verdict, reasons, amendment?)` | **token arbitre uniquement** | — |

- **Post-MVP** (hors manifeste v1) : `runtime_input` (piloter joueur/NPC),
  `save_map`, tools caméra (`editor_camera`) — utiles mais non requis par le
  vertical slice.
- Le groupement exact reste à **mesurer** sur les premiers workflows
  (tokens des schémas vs ambiguïté, doc 02 §3).

- **Sous-ensemble retenu :**

---

## F. Mémoire et réseau runtime

### Q-F05 — Spécifier la stratégie delta/snapshot — **B0**

Orientation donnée : delta sur modification courante, snapshot sur ajout
d'item ; aucun snapshot de **réparation** n'existe (un delta perdu n'est
jamais rattrapé).

**Proposition.**
- **Delta** : écritures `state` coalescées par (tuile, clé) à **30 Hz** max
  (cadence alignée sur `PhysicsSession`), LWW hôte.
- **Snapshot de réparation** : snapshot **périodique** du namespace `state`
  (ex. toutes les **5 s** ou tous les 128 deltas) diffusé avec le numéro de
  séquence ; un pair qui détecte un trou de séquence applique le prochain
  snapshot au lieu de demander la retransmission.
- **Snapshot structurel** : à chaque ajout/suppression d'item (déjà décidé,
  D7) et à l'entrée d'un nouveau pair (full-sync existant étendu à la mémoire).
- **Resync à la demande** : `RequestStateSnapshot` explicite (utilisé aussi
  par Q-J03).

- **Réponse :**

### Q-F06 — Confirmer le modèle hybride reliable/supersedable — **B0**

Le chemin nommé `reliable` ne retransmet pas (R13).

**Proposition à confirmer** (cohérente D15) :
- **Intentions/commits** (propositions, verdicts, ops d'édition, écritures
  `config`) : **ACK applicatif + retry + déduplication par ID** — nouvelle
  couche V3 au-dessus de Catway.
- **État supersedable** (`state`, positions) : **séquence + snapshot de
  réparation** (Q-F05) — une valeur perdue est remplacée par la suivante,
  jamais retransmise.
- Chaque message porte son type de garantie dans l'en-tête ; aucun flux ne
  repose sur la « fiabilité » implicite de `reliable.io`.

- **Réponse :**

### Q-F07 — Cadence et plafonds du bus d'état ? — **B1** *(valeurs de départ à affiner en test)*

**Proposition de valeurs initiales** :
- **Cadence maximale** : 30 Hz par tuile (coalescence en deçà).
- **Taille max** : 1 KB par valeur, 8 KB par tuile, 256 KB par session.
- **Budget bande passante** : ~64 KB/s par pair pour le bus d'état (à comparer
  aux snapshots physiques 30 Hz existants).
- **Politique de dépassement** : l'écriture est **rejetée à la source** avec
  erreur structurée `{code: "quota_exceeded", retryable: false}` (remontée
  telle quelle à l'IA via le canal) — jamais de troncature silencieuse.

- **Réponse :**

---

## G. Artefacts : cycle de vie et migration

### Q-G06 — Cycle de vie d'un artefact attaché à plusieurs tuiles ? — **B1**

**Proposition** (s'appuie sur D16 : store séparé + références dans la map) :
- **Ownership** : l'artefact vit dans le **store par hash** ; les tuiles ne
  portent que des **références** `{hash, version}`. Pas de copie par tuile.
- **Suppression** : compteur de références ; la suppression de la dernière
  tuile référençante marque l'artefact « orphelin », purgé au **save** (GC),
  pas immédiatement (permet l'undo de la suppression).
- **Mise à jour/migration** : une nouvelle version = nouveau hash ; les tuiles
  migrent référence par référence (proposition arbitrée si le comportement
  change), l'ancienne version reste dans le store tant qu'elle est référencée.

- **Réponse :**

### Q-G07 — Que transfère-t-on lors d'un changement d'hôte ? — **B0**

L'élection/promotion éditeur (Phase 8) ne transfère ni règlement, ni
artefacts, ni état runtime, ni contexte d'arbitre (R15).

**Proposition** — le checkpoint de migration contient, dans l'ordre de
priorité :
1. **Règlement versionné** (document structuré D12) — bloquant ;
2. **Hashes des artefacts actifs** (le nouvel hôte télécharge les sources
   manquantes auprès des pairs, mécanique D16 « artefact manquant ») —
   bloquant ;
3. **Snapshot `state`** le plus récent + séquence — bloquant ;
4. **Contexte d'arbitre** : le résumé de session de l'ancien arbitre
   (journal D19 depuis le début de partie + verdicts) injecté en pré-prompt du
   nouvel arbitre — best-effort si l'ancien hôte est parti brutalement (le
   journal répliqué chez les pairs sert de source).
- **Reprise** : les propositions restent **suspendues** tant que le nouvel
  arbitre n'a pas passé le handshake D24 **et** accusé réception du checkpoint.

- **Réponse :**

---

## I. Bibliothèque : format et confiance

### Q-I04 (reste) — Champs exacts du manifeste de package — **B1**

Le principe est tranché (D29 : même format que l'`AssetManager`, étendu).

**Proposition de champs étendus** (en plus de l'existant asset_server) :
- **Identité** : `id`, `version` (semver), `contentHash` (SHA-256 par fichier
  + hash racine), `kind` (`asset3d` | `primitive` | `module` | `skin`).
- **Métadonnées** : `name`, `description`, `author`, `tags`, `preview`.
- **Contenu** : fichiers GLB/QML/JSON ; `entryPoint` pour les primitives.
- **Dépendances** : liste de `{id, versionRange}` (assets référencés).
- **Confiance** : `signature` (asymétrique, R16), `publisherKeyId`.
- **Compat** : `minGameVersion`, `channelVersion` (version du manifeste du
  canal pour les primitives exposant des capacités).

- **Réponse :**

### Q-I05 — Quel modèle de confiance ? — **B0**

Au premier jalon la bibliothèque est locale/officielle (D18), mais la chaîne
de signature n'existe pas (R16 : le SHA-256 du launcher vérifie l'intégrité,
pas l'identité de l'éditeur).

- [ ] **Officiel signé + communautaire revalidé** *(recommandation : les
      packages officiels signés sont dispensés du banc d'essai ; tout contenu
      non signé — communautaire futur — repasse par la validation complète
      D26 chez celui qui le charge)*
- [ ] Tout revalider, signature informative
- [ ] Modération serveur avant publication
- [ ] Combinaison :

- **Réponse :**

### Q-I09 — Quels budgets pour les assets ? — **B1**

**Proposition de valeurs initiales** (à confronter aux assets existants et à
la cible perf du plateau 3D) :
- **Triangles/mesh** : ≤ 50 k par asset (≤ 10 k recommandé pour les items
  posables en nombre).
- **Textures** : ≤ 2048×2048, formats compressés ; ≤ 4 textures par matériau
  (PBR base/normal/metal-rough/émission).
- **Taille disque/réseau** : ≤ 20 Mo par package.
- **Animations/materials** : animations squelettales autorisées (le pipeline
  GLB les supporte), matériaux PBR standard uniquement (pas de shader custom
  au MVP).

- **Réponse :**

---

## J. Observabilité et sortie du cadrage

### Q-J02 — Politique de stockage/effacement des données privées — **B1**

Prompts (tchat ingame), sources générées et identifiants fournisseur peuvent
contenir des données privées. Le noyau d'audit D19 est non désactivable.
*(Les captures d'écran sont réglées par D22 : rétention éphémère de quelques
tours d'IA, aucun masquage, information une fois au lancement.)*

**Proposition.**
- **Tout reste local** : aucun prompt/source/journal n'est envoyé à un serveur
  du projet (les fournisseurs LLM voient évidemment les prompts — c'est couvert
  par l'information au lancement, D22).
- **Rétention** : journal d'audit conservé **avec la sauvegarde de partie**
  (D27) tant que la partie existe ; purge à la suppression de la partie.
  Prompts du tchat hors noyau d'audit : purgés à la fin de session.
- **Identifiants fournisseur** (clés API/config CLI) : jamais copiés dans les
  logs ni le journal ; ils restent dans la config de l'agent du joueur.
- **Export** : un bouton d'export du journal (D19) pour debug/partage,
  action explicite du joueur uniquement.

- **Réponse :**

### Q-J03 — Comment diagnostiquer une divergence entre pairs ? — **B1**

**Vérification stack effectuée** (réponse au « vérifier la stack
host-authoritative existante ») : le full-sync éditeur et les snapshots
physiques **réparent** mais ne **détectent** pas — aucun hash/version d'état,
aucune demande explicite de resync n'existe en V2 (doc 10). Un choix reste
donc nécessaire.

- [ ] **Hash périodique d'état + resync** *(recommandation : hash du `state`
      calculé côté hôte et diffusé avec le snapshot de réparation Q-F05 ; un
      pair dont le hash local diverge demande `RequestStateSnapshot` — coût
      quasi nul, réutilise la mécanique F05)*
- [ ] Journal d'événements rejouable
- [ ] Snapshot autoritatif à la demande

- **Réponse :**

### Q-J04 — Quels indicateurs mesurent la qualité de l'arbitrage ? — **B2**

**Proposition de tableau de bord initial** (mesuré dès le vertical slice,
cibles à recaler ensuite) :
- **Latence** : p50 < 5 s, p95 < 15 s entre soumission et verdict (risque R8).
- **Taux** : acceptation / rejet / amendement par session (pas de « bonne »
  valeur a priori ; sert à détecter un arbitre trop laxiste ou bloquant).
- **Rollback post-acceptation** : < 5 % des propositions acceptées annulées
  ensuite (banc d'essai D26 devrait tendre vers ~0 les échecs techniques).
- **Coût** : tokens par proposition arbitrée, budget par session (config D10).

- **Réponse :**

### Q-J06 — Quels critères font abandonner ou réduire D1 ? — **B0**

**Proposition de critères de sortie** (à évaluer à la fin du prototype R1
recentré par D26) :
- **Échec d'isolation** : si, même **hors-process** (banc d'essai D26), on ne
  sait pas produire un verdict fiable (faux positifs massifs, comportements
  non reproductibles au banc) **ou** si le confinement runtime (contexte
  restreint, masquage des singletons) est contournable trivialement → repli.
- **Budget performance** : si un artefact validé ne peut être exécuté en
  partie sous les budgets Q-D06 (tick > 0,5 ms systématique) → réduire à
  la config de modules + DSL (pas de JS libre).
- **Complexité multi-joueurs** : si la réplication des effets d'artefacts
  rend le collab instable au vertical slice multi → geler le JS embarqué au
  mode solo, données seules en multi, le temps d'une itération.
- **Repli choisi** : « palette + mémoire » (D1, alternatives écartées) —
  briques + espace mémoire + règles en config/DSL, sans QML génératif.

- **Réponse :**

### Q-J07 — Quel est le prochain document à produire ? — **B1**

- [ ] Spécification du prototype sandbox R1 *(recommandé en premier : à
      réécrire autour du banc d'essai hors-process D26 — snapshot injecté,
      critères de verdict, coût de spawn d'un process Qt headless)*
- [x] Plan du vertical slice — **fait** : [`11_VERTICAL_SLICE.md`](./11_VERTICAL_SLICE.md)
- [ ] Schéma du protocole/enveloppe de proposition *(second : requis par S2)*
- [ ] ADR consolidés supplémentaires

- **Ordre retenu :**

### Q-J08 — Qui valide définitivement chaque famille de décisions ? — **B1**

À répartir entre les deux développeurs (Antoine / Valou) — proposer un
responsable par famille, l'autre relisant :
- **Produit/vision :**
- **Sécurité :**
- **Réseau :**
- **Gameplay/règles :**
- **Bibliothèque/assets :**

---

## Synthèse (état au 2026-07-12)

- **Arbitré (D9→D30)** : périmètre trois modes **livrés solo → collab →
  runtime**, arbitre obligatoire partout avec **handshake + challenge de
  disponibilité**, grain d'arbitrage **configurable par UI** (plancher
  code/règles proposé), agents `claude -p`/Codex supervisés et **invoqués
  in-app via tchat ingame**, proposition auditable avec amendement immédiat,
  règles hiérarchiques déclenchables par **tous les événements**, sandbox de
  validation = **banc d'essai hors-process sur snapshot de carte**, canal =
  serveur MCP local en **streamable HTTP intégré au jeu**, screenshots
  plafonnés/éphémères/annoncés, mémoire `config`/`state` avec **sauvegarde de
  partie distincte** et **undo qui restaure malgré tout**, artefacts sous
  autorité hôte, skill générée au build et injectée en pré-prompt,
  bibliothèque locale officielle GLB au **format asset manager étendu**,
  journal configurable à noyau d'audit obligatoire, **vertical slice solo
  S1/S2/S3 défini (doc 11)**.
- **Encore ouvert — chaque question ci-dessus porte une proposition prête à
  valider** : UX du prérequis arbitre (B04), sélection/validation des formes
  exécutables (C06), autorité/ordre des événements (C08), allow-list (D04),
  façade API (D05), budgets (D06), résumé/curseur d'événements (E06),
  manifeste des tools MVP (E08), delta/snapshot (F05), garanties réseau (F06),
  plafonds du bus (F07), cycle de vie des artefacts (G06), checkpoint de
  migration (G07), champs du package (I04), modèle de confiance (I05),
  budgets assets (I09), données privées (J02), détection de divergence (J03),
  indicateurs d'arbitrage (J04), critères de repli D1 (J06), ordre des
  prochains docs (J07), responsables par famille (J08).
