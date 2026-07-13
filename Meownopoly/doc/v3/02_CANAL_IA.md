# 02 — Le canal d'interaction IA ↔ jeu (serveur MCP local)

> **Statut : cadrage (draft), transport révisé le 2026-07-12.** Décision **D2 :
> canal dédié**, séparé de l'`AutomationServer`. Décision **D20 : le transport
> est un serveur MCP local** exposé par le jeu — il **remplace** le protocole
> WebSocket maison envisagé initialement (l'invocation in-app des agents,
> D10/D17, a rendu le WS custom superflu). Fichier renommé depuis
> `02_CANAL_IA_WEBSOCKET.md`.

## 1. Rôle & périmètre

Le canal est **l'unique point de contact** entre « l'IA du joueur » et le jeu.
Concrètement : le jeu expose son catalogue curé comme **serveur MCP local**
(loopback), sous forme d'**endpoint streamable HTTP embarqué dans le process du
jeu** (D21 — pas de pont stdio externe, cf. §2 bis) ; l'application **invoque
elle-même** l'agent (`claude -p`, Codex non interactif — tchat ingame, D10) et
lui **injecte la configuration MCP + le pré-prompt skill** au lancement. L'agent agit ensuite par **tool calls MCP**
qui sont traduits vers les **pipelines internes existants**
(`editorAutomationHooks` → `Game.updateMap` → `EditorOpBus`), et reçoit en
retour de l'**état observable**.

**But du canal = créer des briques de gameplay avec logique.** L'IA cliente
n'est pas là pour *tester* le jeu : elle est là pour **produire des éléments
porteurs de logique** (fichiers QML + script, écriture de l'espace mémoire) qui
**influencent et font le gameplay**. Le catalogue du canal est pensé pour ça — pas
pour l'introspection/injection bas niveau de l'automation.

> **Frontière d'accès (non-négociable).** L'IA cliente n'a **aucun accès** au
> harnais d'**automation** (`AutomationServer` port 7700, MCP `automation_mcp/`),
> qui reste **strictement réservé au test/debug interne**. Le canal IA est une
> **surface distincte et curée** : **certaines** capacités de l'automation y sont
> **ré-exposées** (portées et durcies, cf. §5), mais l'IA ne parle **jamais** à
> l'automation directement. Deux surfaces, deux publics : automation = dev ;
> canal = IA-joueur.

## 2. Pourquoi MCP plutôt qu'un WebSocket maison (D20)

Le WS custom avait été retenu (D2/D14 initiaux) quand l'agent était un process
externe autonome qui devait *découvrir* le jeu. La précision D10/D17 —
**l'application spawne et supervise elle-même les agents** — change l'équation :

- **Support natif des deux CLIs cibles.** `claude -p` et Codex consomment des
  tools MCP nativement : plus de client WS custom à écrire et à livrer dans la
  skill (l'ex-question H02 tombe).
- **Découverte et authentification résolues par construction.** L'app contrôle
  le process agent : elle lui passe endpoint + token directement (config/env du
  process enfant). Plus de problème de « comment l'agent trouve le port et le
  secret » (ex-questions E02/E03).
- **Le manifeste devient les schémas de tools.** La source de vérité (D17) génère
  directement les déclarations MCP — même pipeline que `automation_mcp/`, qui
  reste le patron d'outillage.
- **Boucle perception→action native.** Tool call = requête/réponse corrélée,
  typée, avec erreurs structurées — ce que le protocole maison devait recréer.

Ce qui **survit** du choix initial : le canal reste **dédié et distinct de
l'automation** (D2), **local strict** (loopback), **un seul serveur** multiplexant
rôles et namespaces (esprit D14), **versionné globalement**, avec **lots
tout-ou-rien** et `automation.raw` réservé aux builds dev.

Ce qui **tombe** : le protocole WS maison (`{id, cmd, params}`), le client WS à
livrer, la découverte du secret par fichier runtime.

## 2 bis. Forme d'intégration : streamable HTTP intégré au jeu (D21)

Tranché le 2026-07-12 (ex-Q-E11) : le serveur MCP est un **endpoint streamable
HTTP loopback embarqué dans le process du jeu**, pas un pont stdio externe.

- **Compatibilité vérifiée** : les deux CLIs cibles supportent nativement le
  streamable HTTP avec bearer token (Claude Code `--transport http` /
  `--mcp-config` ; Codex `[mcp_servers.<n>] url = …` + `bearer_token_env_var`).
- **Argument décisif : la distribution.** Un pont stdio réintroduirait un
  runtime Node (ou un binaire packagé) à livrer à chaque joueur ; l'endpoint
  intégré ne demande rien de plus que le CLI d'agent lui-même. Un seul process,
  cycle de vie lié au jeu, un même endpoint pour proposante et arbitre (tokens
  distincts).
- **Coût assumé** : implémenter le sous-ensemble MCP en C++ (pas de SDK
  officiel) — JSON-RPC 2.0 sur HTTP POST : `initialize`, `tools/list`,
  `tools/call` suffisent au MVP ; SSE optionnel (réponses `application/json`).
- **Prérequis kit** : ajouter l'add-on **`QtHttpServer`** (absent du kit
  Qt 6.11.0 actuel) via le Maintenance Tool.
- **Repli documenté** : pont stdio (`@modelcontextprotocol/sdk`) + IPC WS
  loopback façon `automation_mcp/`, si un CLI exige une partie non implémentée
  de la spec.

## 3. Économie de tokens (contrainte de conception)

Chaque schéma de tool chargé coûte des tokens **à chaque invocation**. Le canal
est conçu pour minimiser ce coût — c'est le rôle conjoint de la skill et du
catalogue :

- **La skill porte la connaissance, pas les schémas.** Le pré-prompt injecté
  (doc 03) contient les workflows, recettes et conventions — compact, stable,
  donc **caché** (prompt caching) entre les invocations d'une même session. Les
  détails d'usage vivent dans la skill, pas dans des descriptions de tools
  verbeuses.
- **Catalogue réduit et groupé.** Peu de tools paramétrés plutôt que beaucoup de
  tools spécifiques : un `editor_place(kind, …)` couvrant asset/case/zone/NPC/
  ennemi/caisse plutôt que six tools ; un `state_query(what, filter)` plutôt
  qu'un tool par type de lecture.
- **Résultats compacts.** Listes paginées, ids plutôt que dumps complets,
  `state.getTile` sur demande plutôt que tout renvoyer.
- **Préfixe stable = cache efficace.** Pré-prompt skill + schémas de tools
  identiques d'une invocation à l'autre → seul le tour courant (message +
  événements injectés) est facturé plein tarif.
- **Divulgation progressive si le catalogue grossit.** Un tool `help(topic)`
  renvoyant la documentation détaillée d'une famille de commandes, plutôt que
  tout charger d'office.

## 4. Événements : injectés par tour + polling à la demande

Modèle retenu (cohérent avec « une invocation = un tour de tchat ») :

- **Injection par invocation.** L'app résume les événements survenus depuis le
  dernier tour (tuiles posées par d'autres, verdicts d'arbitrage, changements
  d'état pertinents) et les injecte dans le contexte au lancement de
  l'invocation. Pas de canal push à maintenir, pas d'agent persistant.
- **Polling à la demande.** Un tool `events_poll(cursor)` permet à l'agent de se
  resynchroniser **en cours de tâche longue** s'il pense en avoir besoin. Le
  curseur s'appuie sur le journal métier (D14/D19).

L'adaptateur unifié au-dessus des signaux internes (`Game`, `EditorOpBus`,
`ItemSnapableEvents`) reste nécessaire : il alimente le résumé d'injection **et**
le journal consulté par `events_poll`.

## 5. Catalogue de capacités (état des lieux V2 → cible V3)

Ce catalogue est le **sous-ensemble curé** que le canal expose à l'IA sous forme
de tools MCP. Il **réutilise l'implémentation** des hooks/commandes existants
(chemin UI exact, compatible collab/undo), mais **pas** la surface totale de
l'automation : les commandes bas niveau réservées au test (introspection d'arbre
QML, `get`/`set` de propriété arbitraire, synthèse souris/clavier) **n'y entrent
pas**. Les familles ci-dessous sont regroupées en tools paramétrés (§3).

### 5.1 Déjà exposé côté hooks (`editorAutomationHooks`, `Editor.qml`)
Implémentation réutilisable derrière le canal (chemin UI exact, compatible
collab/undo) — à ré-exposer via le catalogue curé, pas en accès direct :

- **Pose** : `placeAsset`, `placeCase`, `placeZone`, `placeNPC`, `placeEnemy`,
  `placeCrate` → tool groupé `editor_place`.
- **Édition d'existant** : `setZoneTrigger(uuid, …)`, `setNpcDialogue(uuid, …)`.
- **Caméra** : `getCamera`, `setCamera`, `panCamera`, `zoomCamera` → tool groupé
  `editor_camera`.
- **Catalogue** : `listAssetCategories`, `listAssets(cat,type)`.
- **Gameplay/stats** : `setStatsModuleEnabled`, `addPlayerStatModifier`,
  `getPlayerCombatStats`.
- **Système** : `saveMap`, propriété `_tileCount`.

### 5.2 Capacités manquantes pour une IA autonome (à créer)
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
- **Dry-run d'artefact** (D42, 2026-07-13) : `artifact_dryrun(source,
  targetUuid?)` — itération pré-soumission sur le **banc d'essai local**
  (verdict + métriques complets, quota par invocation ; *pass local ≠
  acceptation*). Cf. doc 12 §6 bis.
- **Événements** : `events_poll(cursor)` sur le journal métier (§4).
- **Screenshot** : réutiliser `grabWindow` (déjà dans l'automation) pour donner à
  l'IA un retour visuel — MCP supporte les résultats image nativement. Politique
  arbitrée (**D22**, 2026-07-12) : captures de l'**écran de jeu** uniquement, à
  la demande de l'IA (visualiser la map si elle le juge utile) ; plafond **par
  requête d'IA** via un `#define` compile-time pour affiner la valeur plus tard
  — **défaut : 5** ; **rétention éphémère** (gardées quelques tours d'IA puis
  purgées, pas d'accumulation) ; **aucun masquage** — le joueur est informé au
  lancement, une fois, sans redemande.

## 6. Boucle perception → action

Le canal doit rendre possible une boucle fermée côté IA :

```
contexte → événements injectés au lancement de l'invocation (§4)
observe  → state.listTiles / getTile / screenshot / events_poll
décide   → (raisonnement côté agent, guidé par la skill pré-promptée)
agit     → editor_place / state.setMemory / qml.instantiate / …
vérifie  → relire l'état ; en cas d'échec, l'erreur est explicite et actionnable
```

Conséquence de cadrage : **les erreurs de tools doivent être exploitables par une
IA** (message clair, code stable, `retryable`), pas juste un échec opaque.

## 7. Sécurité

- **Loopback strict**, opt-in : le serveur MCP n'existe que si le mode IA est
  activé ; jamais de bind `0.0.0.0`.
- **Token injecté au spawn** : l'app génère un token éphémère par session et le
  passe au process agent qu'elle lance (env/config). Il protège l'endpoint local
  contre les **autres process** de la machine (R3) — la découverte n'est plus un
  problème puisque l'app contrôle les deux bouts.
- **Deux identités locales distinctes chez l'hôte** : la cliente proposante et
  l'arbitre reçoivent des configs/tokens **différents**, portant des capacités
  différentes (l'arbitre voit les tools de verdict, pas la proposante).
- **Allow-list de tools** : pas d'introspection/`set` arbitraire façon
  automation. Le canal n'expose que le catalogue gameplay (§5).
- **Le QML génératif ne transite pas directement vers la scène** : il est placé
  dans une enveloppe de proposition (D11), soumis à l'autorité de l'hôte puis aux
  contrôles mécaniques (doc 04). En multi-joueurs, la source d'un client doit au
  minimum atteindre l'hôte pour que l'arbitre puisse la juger.
- **Budget / quotas** : rate-limit par session d'agent, taille max des artefacts
  QML (cf. seuils réseau existants : batch 30 KB, chunking 20 KB dans
  `editor_session`).
- **Garanties applicatives explicites** côté P2P (inchangé) : toute
  proposition/commit/verdict transitant entre pairs porte ID, ACK applicatif,
  retry et déduplication ; le transport Catway `reliable` ne retransmet pas
  (doc 10, R13).

## 8. Questions ouvertes (synthèse doc 08 ; questions ouvertes : doc 09)

- ~~Forme d'intégration MCP (Q-E11)~~ **tranchée D21** : streamable HTTP
  loopback intégré au jeu (§2 bis).
- Schéma exact du **résumé d'événements injecté** par tour et sémantique du
  curseur `events_poll` (recouvrement avec le journal D19).
- **Granularité du groupement de tools** (§3) : quel découpage minimise les
  tokens sans rendre les schémas ambigus ? À mesurer sur les premiers workflows.
- Politique multi-joueurs : quelles commandes restent purement locales et quelles
  propositions passent obligatoirement par l'autorité de l'hôte ? Toute mutation
  de l'état partagé doit passer par l'hôte ; la frontière exacte reste à lister.
- **Point d'insertion de l'IA arbitre** (doc 00 §4, D6) : une proposition cliente
  arrivant à l'hôte doit être soumise à l'arbitre avant rebroadcast. Sous quelle
  forme le verdict revient-il au proposant (résultat de tool, événement injecté
  au tour suivant) ?
