# 02 — Le canal d'interaction IA ↔ jeu (WebSocket local dédié)

> **Statut : cadrage (draft).** Décision **D2 : canal dédié**, séparé de
> l'`AutomationServer`.

## 1. Rôle & périmètre

Le canal est **l'unique point de contact** entre « l'IA du joueur » et le jeu. Il
ne sert **qu'à ça** : ce n'est pas un service exposé, pas un canal réseau P2P,
pas de la logique de gameplay. Il traduit des **commandes de haut niveau** émises
par l'IA vers les **pipelines internes existants** (`editorAutomationHooks` →
`Game.updateMap` → `EditorOpBus`), et renvoie de l'**état observable**.

## 2. Pourquoi un canal séparé de l'automation (D2)

L'`AutomationServer` (`cpp/automation/automation_server.{h,cpp}`, port 7700) fait
techniquement déjà « piloter le jeu par WebSocket JSON ». On aurait pu l'étendre.
On crée un canal distinct pour :

- **Séparer les responsabilités** : automation = test/debug bas niveau
  (introspection d'arbre QML, synthèse de clics/souris/clavier, `get`/`set` de
  propriétés arbitraires) ; canal IA = **capacités de gameplay de haut niveau**,
  contrat stable, pensé pour un agent en boucle.
- **Durcir la sécurité indépendamment.** L'automation expose délibérément une
  surface énorme (lire/écrire n'importe quelle propriété, invoquer n'importe
  quelle méthode) — acceptable en debug local, **inacceptable** comme contrat
  d'IA. Le canal IA doit exposer une **allow-list** de commandes, pas
  l'introspection totale.
- **Évoluer sans casser l'outil de dev.** Le protocole IA changera vite pendant le
  cadrage ; on ne veut pas casser le harnais d'automation existant.

> **À réutiliser quand même :** les fondations éprouvées de l'automation — bind
> **strict loopback** (`QHostAddress::LocalHost`, double garde sur l'adresse du
> pair, `automation_server.cpp:44-47` et l.117-125), format JSON corrélé par `id`,
> dispatch, tout sur le **GUI thread** (le canal manipule la scène QML). Le canal
> IA est un **frère** de l'automation, pas un fork.

## 3. Forme du protocole (proposition)

Même ossature que l'automation (familiarité, réutilisation du code de dispatch) :

```jsonc
// requête
{ "id": 42, "cmd": "editor.placeAsset", "params": { "category": "decoration",
  "type": "grass", "assetId": "0", "gridX": 12, "gridY": 8 } }

// réponse OK
{ "id": 42, "ok": true, "result": { "uuid": "{...}", "gridX": 12, "gridY": 8 } }

// réponse erreur
{ "id": 42, "ok": false, "error": "editor not open" }
```

Ajouts propres au canal IA (à spécifier au chantier) :

- **Espaces de noms de commandes** (`editor.*`, `state.*`, `qml.*`, `rules.*`
  plus tard) plutôt qu'un plat de `cmd`.
- **Événements poussés** (server→IA) en plus du req/rep : notifier l'IA d'un
  changement d'état (une tuile posée par un autre joueur, une phase de jeu qui
  change) pour alimenter sa boucle perception→action sans polling.
- **Contrat versionné** (`protocolVersion`) : la skill (doc 03) déclare la version
  qu'elle connaît ; le serveur peut négocier/refuser.

## 4. Catalogue de capacités (état des lieux V2 → cible V3)

### 4.1 Déjà exposé côté hooks (`editorAutomationHooks`, `Editor.qml`)
Réutilisable tel quel via le canal (chemin UI exact, compatible collab/undo) :

- **Pose** : `placeAsset`, `placeCase`, `placeZone`, `placeNPC`, `placeEnemy`,
  `placeCrate`.
- **Édition d'existant** : `setZoneTrigger(uuid, …)`, `setNpcDialogue(uuid, …)`.
- **Caméra** : `getCamera`, `setCamera`, `panCamera`, `zoomCamera`.
- **Catalogue** : `listAssetCategories`, `listAssets(cat,type)`.
- **Gameplay/stats** : `setStatsModuleEnabled`, `addPlayerStatModifier`,
  `getPlayerCombatStats`.
- **Système** : `saveMap`, `setUiScale`, propriété `_tileCount`.

### 4.2 Capacités manquantes pour une IA autonome (à créer)
Identifiées lors de la cartographie du socle — ce sont les vrais chantiers :

- **Introspection d'état structurée** : `state.listTiles()` → `[{uuid, tileType,
  gridX, gridY, w, h}]`, `state.getTile(uuid)` → JSON complet **incluant l'espace
  mémoire** (doc 05). Aujourd'hui l'IA doit itérer `snapableTilesList` en
  `qml_get`/`qml_invoke` bruts ; `_tileCount` ne donne qu'un compte.
- **Édition ciblée par uuid** : `deleteTile(uuid)`, `moveTile(uuid, gx, gy)`,
  `resizeTile(uuid, …)`, `selectTile(uuid)`. Absents (seuls
  `setZoneTrigger`/`setNpcDialogue` éditent un existant).
- **Espace mémoire** : `state.setMemory(uuid, blob)` / `state.getMemory(uuid)`
  (doc 05).
- **Énumération des enums** : `state.enum("CaseType")`, `enum("TriggerMode")`,
  `enum("PickMode")` — `placeCase` prend aujourd'hui un `caseType` numérique brut
  sans moyen d'en connaître les valeurs valides.
- **Roster joueurs** : créer/éditer un `PlayerProfile`/`MapInfo` (min/max, profils)
  — il existe des ops collab (`AddPlayerProfile`…12-16) mais **aucun hook**.
- **Runtime (au-delà de l'éditeur)** : piloter le joueur/NPC en jeu
  (`InputController.pushInput`), lire la position runtime des bodies
  (`World3D.bodyStates`), déclencher saut/attaque. **Totalement absent** en V2 —
  requis pour « l'usage de modules liés au NPC/joueur ».
- **QML génératif** : `qml.instantiate(artefact, attachToUuid?)` — passe par le
  **sandbox** (doc 04). Nouvelle capacité centrale du pivot.
- **Screenshot** : réutiliser `grabWindow` (déjà dans l'automation) pour donner à
  l'IA un retour visuel.

## 5. Boucle perception → action

Le canal doit rendre possible une boucle fermée côté IA :

```
observe → state.listTiles / getTile / screenshot / événements poussés
décide  → (raisonnement côté IA client)
agit    → editor.place* / state.setMemory / qml.instantiate / …
vérifie → relire l'état ; en cas d'échec, l'erreur est explicite et actionnable
```

Conséquence de cadrage : **les réponses d'erreur doivent être exploitables par une
IA** (message clair, code stable), pas juste `ok:false`.

## 6. Sécurité

- **Loopback strict**, opt-in (comme l'automation) : le canal n'existe que si
  activé ; jamais de bind `0.0.0.0`.
- **Allow-list de commandes** : pas d'introspection/`set` arbitraire façon
  automation. Le canal n'expose que le catalogue gameplay.
- **Le QML génératif ne transite pas « en clair » vers la scène** : il passe
  obligatoirement par le sandbox (doc 04). Le canal ne fait que le convoyer.
- **Authentification locale** : même en loopback, plusieurs process locaux
  peuvent tenter de se connecter. À décider (doc 08) : token de session écrit par
  le jeu dans un fichier lisible uniquement par l'utilisateur, présenté au
  handshake. L'automation actuelle n'a **aucun** token (loopback seul) — jugé
  insuffisant pour un canal qui, à terme, exécute du QML.
- **Budget / quotas** : limiter le débit de commandes et la taille des artefacts
  QML (cf. seuils réseau existants : batch 30 KB, chunking 20 KB dans
  `editor_session`).

## 7. Questions ouvertes (→ doc 08)

- Un seul canal multiplexé (éditeur + runtime + règles) ou plusieurs ?
- Événements poussés : sur quel bus interne se brancher (signaux `Game`,
  `EditorOpBus.remoteOpReceived`, `ItemSnapableEvents`) ?
- Faut-il exposer une capacité `automation.raw` (échappatoire bas niveau) pour le
  prototypage, quitte à la retirer en prod ?
- Politique multi-joueurs : les commandes IA d'un client sont-elles locales, ou
  passent-elles par le host-authoritative comme les ops d'édition humaines ?
- **Point d'insertion de l'IA arbitre** (doc 00 §4, D6) : une proposition cliente
  arrivant à l'hôte doit être soumise à l'arbitre avant rebroadcast. Le canal
  transporte-t-il un verdict d'arbitrage (accepté/amendé/rejeté) en retour, et
  sous quelle forme d'événement poussé ?
