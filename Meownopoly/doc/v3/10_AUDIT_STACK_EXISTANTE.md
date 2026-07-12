# 10 — Audit de la stack V2 mobilisable par la V3

> **Statut : vérifié contre le code le 2026-07-12.** Ce document répond aux
> mentions « stack existante » du questionnaire 09. Il distingue une brique
> réellement réutilisable d'une garantie que la V2 ne fournit pas encore.

## Légende

- **Supporté** : le comportement existe et peut être réutilisé directement.
- **Partiel** : un mécanisme proche existe, mais le contrat V3 demande une couche
  ou une garantie supplémentaire.
- **Absent** : aucun mécanisme correspondant n'a été trouvé dans l'application.
- **Contredit** : la réponse proposée attribue à la stack une garantie qu'elle ne
  possède pas.

## Synthèse

| Questions | Verdict | Conclusion vérifiée |
|---|---|---|
| A08 | Partiel | Le cœur CMake/Qt n'est pas limité à Windows ; seuls `windeployqt` et `dual_test_p2p` sont sous `if(WIN32)`. Aucun packaging, CI ou test Linux n'est toutefois présent. |
| B03 | Absent | `LauncherManager` gère téléchargements/imports, mais ne contient aucun `QProcess` ni supervision d'agent. Lancer `claude -p`/Codex exige un adaptateur neuf. |
| B05, B08, G07 | Partiel | `EditorSession` sait élire/promouvoir un nouvel hôte et le nouvel hôte resynchronise la carte. Aucun transfert de contexte d'arbitre, règlement, artefacts ou état runtime générique n'existe. |
| D02, D03, D10 | Absent | Aucun chargeur de QML génératif ni sandbox V3 n'existe. Le moteur courant enregistre de nombreux singletons globaux ; aucune préemption JS ou limite CPU/mémoire n'est fournie. |
| E02 | Partiel | L'automation résout son port par `--automation-port` puis `MEOW_AUTOMATION_PORT`; `0` désactive le serveur. C'est un patron, pas une découverte sécurisée du futur canal IA. |
| E03 | Contredit | L'automation écoute strictement en loopback et revérifie l'adresse du pair, mais n'a ni token, ni handshake, ni rôle. « Stack existante » ne suffit pas à authentifier le canal IA. |
| E05 | Partiel | `Game`, `EditorOpBus` et `ItemSnapableEvents` exposent des signaux exploitables. Il n'existe ni adaptateur d'événements IA unifié ni journal métier rejouable. |
| E06, F06 | Contredit | La bibliothèque `reliable` intégrée est un système d'ACK/fragmentation. Son README demande à l'appelant de retransmettre lui-même les messages non acquittés ; Catway ne le fait pas. Elle ne garantit donc ni « au moins une fois » ni livraison ordonnée complète. |
| E07 | Partiel | `Game::beginTransaction/commitTransaction` groupe undo, sauvegarde et broadcast via `groupId`. Les mutations locales sont appliquées avant le commit et il n'existe pas de rollback transactionnel : ce n'est pas encore « tout ou rien ». |
| E08 | Partiel | Pose/caméra/catalogue/screenshot et quelques actions gameplay existent. Introspection complète, mémoire V3, QML génératif et plusieurs capacités runtime restent à créer. |
| F02 | Contredit | La persistance existante sauvegarde une **map** (`mapInfo` + `snapableTiles`) dans `autosave_tmp.json` ou `<name>_map.json`. Il n'existe pas de sauvegarde de partie/runtime distincte. |
| F04 | Absent | Il n'existe aucun bus d'état générique partagé. `EditorSession` et `PhysicsSession` sont deux protocoles spécialisés. |
| F05 | Partiel | L'éditeur utilise des `EditDelta` et un `FullSync` complet à la connexion/changement de carte ; la physique envoie des snapshots périodiques. Aucun protocole mémoire delta+réparation n'existe. |
| G01 | Partiel | `EditorSession` sait transporter/chunker des payloads JSON jusqu'à ~30 Ko par paquet, mais aucun type de message « proposition/artefact QML vers arbitre » n'existe. |
| G03 | Contredit | `ItemSnapable` possède un `QUuid` et les assets un ID texte. Cela identifie une instance ou une entrée de catalogue, pas une version immuable d'artefact. Aucun hash de contenu/manifeste d'artefact V3 n'existe. |
| G04 | Partiel | La map JSON persiste les tuiles et paramètres ; les assets/modèles vivent sous `AppDataLocation`. Il n'existe aucun store d'artefacts adressé par hash. |
| I03 | Supporté partiellement | `asset_server/` et `LauncherManager` fournissent téléchargement, reprise partielle, file, retry, manifestes et contrôle SHA-256. Ils constituent un bon socle de distribution. |
| D09, I05 | Contredit | SHA-256 vérifie l'intégrité attendue, pas l'identité de l'éditeur. Aucune signature cryptographique ni chaîne de confiance officielle n'est implémentée. |
| I06 | Supporté | Le pipeline modèle utilise déjà `.glb`, `RuntimeLoader`, `model_manifest.json` et `createModelFromGlb`. GLB est le choix naturel du premier jalon. |
| I08 | Supporté partiellement | Les assets 2D sont référencés par `(category, type, id)` ; les modèles par `modelName` résolu via `model_manifest.json`. Il manque version/hash dans la référence V3. |
| J03 | Partiel | Full-sync éditeur et snapshots physiques permettent de réparer certains états, mais aucun hash périodique, détection générique de divergence ou journal rejouable n'existe. |

## 1. Canal local : ce qui peut réellement être repris

`AutomationServer` fournit un bon patron pour :

- création opt-in seulement si un port est configuré ;
- bind sur `QHostAddress::LocalHost` ;
- seconde vérification de `peerAddress()` ;
- WebSocket JSON corrélé et exécution sur le thread GUI ;
- port fourni par CLI ou variable d'environnement.

Il ne fournit **pas** : authentification, rôle proposant/arbitre, négociation de
version, manifeste de capacités, quotas de sécurité ou journal d'événements.
Le futur canal peut reprendre son squelette, pas son niveau de confiance.

Points d'ancrage :

- `cpp/automation/automation_server.cpp` : constructeur, `resolvePort()`,
  `onNewConnection()` ;
- `cpp/main.cpp` : création opt-in après le chargement de `QmlApp`.

## 2. Réseau P2P : ne pas confondre ACK et retransmission

Catway préfixe et route les paquets via un endpoint de la bibliothèque
`cpp/reliable/`. Cette bibliothèque :

- numérote, acquitte, fragmente et réassemble les paquets ;
- calcule RTT, jitter, perte et bande passante ;
- expose les numéros acquittés à l'appelant.

Elle ne met pas automatiquement en file puis ne retransmet pas les messages non
acquittés. Le README de la bibliothèque indique explicitement que cette logique
doit être construite par l'appelant. Or Catway efface les ACK après mise à jour et
n'entretient pas de file applicative de retransmission. Les noms
`sendReliableToPlayer`/`broadcastReliable` décrivent donc le chemin historique,
pas une garantie de livraison forte.

Conséquences V3 :

- une proposition, un verdict ou un commit nécessite identifiant, ACK applicatif,
  retry et déduplication ;
- un état supersédable peut utiliser séquence + snapshot de réparation ;
- le chunking seul ne répare pas un chunk perdu ;
- les garanties E06/F06 doivent être définies au niveau du protocole V3.

Points d'ancrage :

- `cpp/reliable/README.md` ;
- `cpp/communication/catway_worker.cpp` ;
- `cpp/communication/player_network.cpp`.

## 3. Transactions éditeur : groupées, pas atomiques

La stack possède déjà :

- `Game::beginTransaction()` qui attribue un `groupId` ;
- une pile undo/redo groupée par ce même identifiant ;
- sauvegarde différée jusqu'au commit ;
- `EditorOpBus::flushGroup()` qui envoie un batch d'`ApplyState`.

Mais les mutations sont appliquées localement au fil de l'eau. Il n'existe ni
phase `prepare`, ni rollback automatique si une opération du lot échoue, ni ACK
de commit de tous les pairs. La réponse E07 « tout ou rien » est donc une cible
V3, pas une propriété réutilisable telle quelle.

Points d'ancrage :

- `cpp/game/game_loader.cpp` : `updateMap()`, `beginTransaction()`,
  `commitTransaction()` ;
- `cpp/editor/ops/editor_op_bus.cpp` : `submitFromDelta()`, `flushGroup()`.

## 4. Synchronisation et migration d'hôte

L'éditeur sait :

- envoyer la map complète en chunks lors du `Hello` ou d'un changement de map ;
- reconstruire `mapInfo` et les tuiles côté client ;
- élire lexicographiquement un hôte, promouvoir le client élu et reconnecter les
  autres pairs ;
- conserver la carte locale du client promu.

Limites : le `FullSync` n'embarque actuellement que `mapInfo` et
`snapableTiles`; il n'a pas de hash global, de journal rejouable, de retry de
chunks manquants, de règlement V3, d'état d'arbitre ou de checkpoint runtime.

Points d'ancrage :

- `qml/editor/Editor.qml` : `_sendFullSync()`, `_receiveFullSyncChunk()`,
  `_applyFullSyncSnapshot()` ;
- `cpp/editor/network/editor_session.cpp` : `HostLeaving`, `promoteToHost()`.

## 5. Persistance : carte, pas sauvegarde de partie

`Game::saveCurrentMap()` sérialise exclusivement :

- `mapInfo` ;
- `snapableTiles` via `ItemSnapable::toJSON()`.

`MapFileManager` écrit `autosave_tmp.json`, `<name>_map.json` ou l'ancien chemin
`_undo.json`. Aucun format distinct de sauvegarde runtime/checkpoint n'existe.
Si la V3 veut reprendre une partie, il faut créer un conteneur séparé ou versionné
qui référence la map et porte `memory.state`, règlement, versions d'artefacts et
état autoritatif.

Points d'ancrage :

- `cpp/game/game_loader.cpp` ;
- `cpp/game/map/mapfilemanager.cpp` ;
- `cpp/game/map/maptypes.h`.

## 6. Launcher, assets et modèles 3D

Le socle distribution est substantiel :

- téléchargements d'assets et modèles avec file et retries exponentiels ;
- support de reprise par `Range` ;
- contrôle SHA-256 ;
- manifestes de version/modèle ;
- stockage sous `QStandardPaths::AppDataLocation` ;
- import et chargement runtime de `.glb`.

Ce socle ne sait pas encore :

- lancer/superviser `claude -p` ou un équivalent Codex ;
- vérifier une signature d'éditeur ;
- résoudre une dépendance par hash de contenu ;
- gérer un store de code/QML versionné.

Références existantes :

- assets 2D : `(category, type, id)` depuis `metadata.json` ;
- modèles : `modelName` puis `model_manifest.json` ;
- rendu : `KuraModel.qml` + `RuntimeLoader` sur `.glb`.

Points d'ancrage :

- `cpp/launcher/launcher_manager.{h,cpp}` ;
- `cpp/assetManager/asset_manager.{h,cpp}` ;
- `asset_server/server.js` ;
- `qml/world3d/KuraModel.qml`, `SkinnedModel.qml`.

## 7. Portabilité Windows/Linux

Le code C++/QML inspecté ne contient pas de dépendance Windows directe hors des
blocs CMake dédiés au déploiement et au lanceur dual-instance. Cela rend une cible
Linux plausible. En revanche, le dépôt ne fournit pas de packaging Linux, de CI
Linux ni de procédure de test équivalente à `dual_test_p2p`. « Windows + Linux »
est donc une cible produit validée, avec un chantier de qualification à créer.

## 8. Décisions corrigées par cet audit

Les réponses suivantes ne peuvent pas être closes par « stack existante » :

- **E03** : authentification du canal ;
- **E06/F06** : livraison, retry, ordre et déduplication ;
- **F02** : format de sauvegarde runtime ;
- **F04** : bus d'état générique ;
- **G03** : identité/version d'artefact ;
- **G04** : store d'artefacts ;
- **J03** : détection/réparation de divergence.

Elles restent ouvertes ou deviennent des chantiers explicites dans le doc 09.

## 9. Modifications à effectuer sur les stacks existantes

Cette section traduit les décisions D9→D34 en modifications concrètes du socle
V2. Les noms de nouvelles classes sont indicatifs ; les responsabilités et
frontières sont, elles, normatives pour le cadrage.

### M1 — Créer la passerelle MCP IA *(révisé par D20 : MCP local, plus de WS custom)*

**Socle repris :** `AutomationServer` pour le bind loopback strict et le dispatch
sur le thread GUI ; `automation_mcp/` comme **patron de déclaration de tools**
(schémas). Le cycle WebSocket custom n'est plus repris tel quel : le transport
est un **serveur MCP local** (D20).

**Modifications :**

- créer une passerelle distincte, par exemple `AiGatewayServer`, exposant le
  catalogue curé comme **tools MCP**, sans réutiliser le catalogue permissif de
  l'automation ;
- forme d'intégration tranchée (**D21**, ex-Q-E11) : **endpoint MCP streamable
  HTTP loopback intégré au process du jeu** — JSON-RPC 2.0 sur HTTP POST
  (`initialize`, `tools/list`, `tools/call` au MVP, SSE optionnel). Prérequis :
  installer l'add-on **`QtHttpServer`** (absent du kit Qt 6.11.0 actuel).
  Repli documenté : pont stdio (`@modelcontextprotocol/sdk`) + IPC WS loopback ;
- tool screenshot conforme à **D22** : plafond de captures **par requête d'IA**
  via un `#define` (défaut 5), rétention éphémère (quelques tours), information
  du joueur une fois au lancement du mode IA ;
- générer un **token éphémère par session** et l'**injecter au spawn** du
  process agent (env/config), avec des configs/capacités **distinctes** pour
  les rôles `proposer` et `arbiter` (D20 — plus de fichier runtime de
  découverte) ;
- versionner le protocole globalement (`protocolVersion` dans le manifeste) ;
- regrouper les tools par familles économes en tokens (`editor_place`,
  `state_query`, `events_poll`… — doc 02 §3) sur les namespaces `editor.*`,
  `state.*`, `artifact.*`, `rules.*` et `runtime.*` ;
- ajouter quotas par session d'agent, taille maximale, rate-limit et erreurs
  structurées `{code, message, details, retryable}` ;
- conserver `AutomationServer` inchangé et test-only.

**Points d'ancrage :**

- modèle : `cpp/automation/automation_server.{h,cpp}` ;
- instanciation opt-in : `cpp/main.cpp` ;
- capacités éditeur : `editorAutomationHooks` dans `qml/editor/Editor.qml`.

**Critères d'acceptation :**

- une connexion non-loopback, sans token ou avec un rôle invalide est rejetée ;
- un proposant ne peut pas appeler une capacité réservée à l'arbitre ;
- aucune commande `tree/get/set/invoke/click/keys` de l'automation n'est exposée
  dans un build de production ;
- version incompatible et quota dépassé produisent des erreurs actionnables.

### M2 — Ajouter la supervision des processus IA

**Socle repris :** `LauncherManager` pour le cycle d'opérations longues, les
statuts, les erreurs et l'intégration QML du launcher.

**Modifications :**

- créer un `AiProcessSupervisor` basé sur `QProcess` ;
- définir des adaptateurs séparés pour `claude -p` et le mode non interactif
  retenu pour Codex, sans coder leurs arguments en dur dans l'UI ;
- gérer démarrage, arrêt gracieux, kill, timeout, crash, redémarrage et capture
  bornée de stdout/stderr ;
- injecter port/token/rôle par variables d'environnement ou fichier runtime,
  jamais dans une ligne de commande journalisée ;
- lancer deux processus ou sessions isolées chez l'hôte ;
- exposer à QML un état explicite `Stopped/Starting/Ready/Failed/Restarting` ;
- implémenter un health-check applicatif avant d'autoriser le lancement d'une
  partie IA.

**Points d'ancrage :**

- intégration launcher : `cpp/launcher/launcher_manager.{h,cpp}` ;
- UI : `qml/launcher/Launcher.qml`, `LauncherLogic.qml` ;
- nouveau composant conseillé : `cpp/ai/ai_process_supervisor.*`.

**Critères d'acceptation :**

- la fermeture du jeu ne laisse aucun processus enfant orphelin ;
- un crash arbitre bloque les nouvelles propositions et déclenche le flow de
  migration sans corrompre la partie ;
- secrets et prompts privés ne sont pas écrits dans les logs par défaut.

### M3 — Construire une vraie fiabilité applicative au-dessus de Catway

**Socle repris :** Catway, les endpoints `reliable.io`, le chunking
`EditorSession` et les métriques réseau.

**Modifications :**

- réserver une plage de messages V3 sans chevauchement avec Game/Editor/Physics ;
- créer une enveloppe commune `{messageId, sessionId, senderId, kind, seq,
  correlationId, payloadHash}` ;
- pour propositions, verdicts et commits : conserver les messages en attente,
  envoyer un ACK applicatif, retransmettre sur timeout et dédupliquer à réception ;
- pour l'état supersédable : utiliser séquence monotone, ignorer l'ancien et
  réparer par snapshot/checkpoint ;
- ajouter un identifiant de transfert aux chunks, bitmap des chunks reçus,
  demande des chunks manquants, timeout et checksum final ;
- plafonner files d'attente et nombre de retries ; exposer un échec définitif au
  protocole métier ;
- ne pas modifier le comportement historique des messages V2 avant migration
  explicite de chaque consommateur.

**Points d'ancrage :**

- transport : `cpp/communication/catway*.{h,cpp}` ;
- endpoint : `cpp/communication/player_network.*` ;
- exemple de chunking : `cpp/editor/network/editor_session.cpp` ;
- limites réelles : `cpp/reliable/README.md`.

**Critères d'acceptation :**

- tests avec perte, duplication, réordonnancement et corruption simulés ;
- une proposition/transaction n'est appliquée qu'une fois malgré les retries ;
- la perte d'un chunk est détectée et réparée ;
- une panne réseau bornée retourne un échec explicite, jamais un succès silencieux.

### M4 — Faire évoluer les transactions groupées vers un commit atomique

**Socle repris :** `Game::beginTransaction/commitTransaction`, `EditDelta`,
`groupId`, piles undo/redo et `EditorOpBus::flushGroup()`.

**Modifications :**

- séparer `prepare`, `commit` et `rollback` ;
- prévalider toutes les opérations, permissions, UUID, versions de clés et
  budgets avant la première mutation ;
- appliquer sur un état de staging ou conserver des inverses complets tant que le
  commit n'est pas confirmé ;
- envoyer le lot comme une unité versionnée et renvoyer un résultat global ;
- en cas d'échec d'une opération, restaurer l'état local et ne pas broadcaster de
  commit partiel ;
- vérifier le write-set au commit pour détecter les modifications concurrentes ;
- conserver le groupement undo/redo existant comme implémentation de l'inverse,
  après adaptation aux conflits.

**Points d'ancrage :**

- `cpp/game/game_loader.cpp` ;
- `cpp/game/map/editdelta.h`, `map.cpp` ;
- `cpp/editor/ops/editor_op_bus.{h,cpp}`.

**Critères d'acceptation :**

- injection d'une opération invalide au milieu d'un lot : aucune mutation finale ;
- undo/redo du lot en une action ;
- aucun pair ne voit un préfixe partiel du lot ;
- conflit de version retourné sans écrasement silencieux.

### M5 — Introduire un journal d'événements métier unifié

**Socle repris :** signaux `Game`, `EditorOpBus`, `ItemSnapableEvents`, événements
de `PhysicsSession` et logger existant.

**Modifications :**

- définir un `GameplayEventBus` avec événements typés, ID, auteur, source,
  timestamp logique, causalité et version ;
- adapter les signaux existants vers ce bus sans déplacer leur logique métier ;
- distinguer événements durables/auditables des événements visuels éphémères ;
- fournir abonnements filtrés à la passerelle IA et aux artefacts ;
- ajouter file transactionnelle, profondeur maximale, budget de cascade et
  détection de cycles/write-set ;
- conserver un noyau d'audit obligatoire et rendre verbosité/rétention configurables.

**Points d'ancrage :**

- `cpp/game/game.*` ;
- `cpp/editor/ops/editor_op_bus.*` ;
- `cpp/game/physics/item_snapable_events.*` ;
- `cpp/tools/logger.*`.

**Critères d'acceptation :**

- ordre causal stable pour les événements d'une transaction ;
- une boucle événement → écriture → même événement est stoppée par budget/cycle ;
- un client IA peut reprendre à partir d'un curseur ou demander un snapshot si le
  journal n'est plus disponible.

### M6 — Créer le bus d'état générique `memory.state`

**Socle repris :** modèle autoritatif de `PhysicsSession`, deltas éditeur et
`ItemSnapable::toJSON/applyJson`.

**Modifications :**

- ajouter `memory.config` et `memory.state` dans un même conteneur versionné ;
- exposer API globale et API ciblée par namespace/clé ;
- porter la mémoire sur tuiles, session et état joueur ;
- router toute intention cliente vers l'hôte, qui séquence et applique LWW ;
- publier des deltas par clé avec version, coalescés ;
- envoyer un snapshot complet périodique ou à la demande pour réparation ;
- utiliser le mécanisme M3 : intentions fiables applicativement, états
  supersédables séquencés ;
- émettre `userMemoryChanged()` et
  `memoryValueChanged(namespace,key,value,version)` ;
- imposer limites de profondeur JSON, taille par valeur/entité/session et débit.

**Points d'ancrage :**

- `cpp/game/item_snapable/ItemSnapable.{h,cpp}` ;
- `cpp/game/physics/physics_session.*` comme modèle, sans y fusionner le nouveau
  bus ;
- `cpp/game/map/editdelta.h` pour `memory.config` seulement.

**Critères d'acceptation :**

- `config` est persisté et undoable, `state` n'entre pas dans l'undo de map ;
- une écriture obsolète est ordonnée/rejetée sans divergence ;
- perte d'un delta réparée par snapshot ;
- aucun signal n'est émis si la valeur sérialisée ne change pas.

### M7 — Ajouter une sauvegarde de partie distincte de la map

**Socle repris :** sérialisation JSON, écritures atomiques `.tmp + rename` de
`MapFileManager` et snapshots de full-sync.

**Modifications :**

- créer un type `GameSave`/`SessionCheckpoint` distinct de `MapTypes` ;
- référencer la map par ID/version/hash au lieu de la recopier implicitement ;
- sérialiser règlement versionné, `memory.state`, joueurs, artefacts/hashes,
  horloges/séquences et état nécessaire à la migration ;
- ne pas écrire l'état runtime dans `<mapName>_map.json` ;
- versionner le schéma, prévoir migrations et rejet explicite des versions futures ;
- chiffrer ou exclure prompts, tokens et secrets fournisseur ;
- permettre un checkpoint autoritatif avant migration d'hôte.

**Points d'ancrage :**

- `cpp/game/game_loader.cpp` ;
- `cpp/game/map/mapfilemanager.*` comme modèle d'I/O atomique ;
- nouveau dossier conseillé : `cpp/game/save/`.

**Critères d'acceptation :**

- sauvegarder/reprendre une partie sans modifier le fichier map source ;
- reprise avec mêmes versions de règlement, artefacts et état joueur ;
- sauvegarde interrompue n'endommage pas la dernière version valide.

### M8 — Créer un registre et un store d'artefacts

**Socle repris :** `QUuid` des tuiles, `AssetManager`, manifestes modèles et
stockage `AppDataLocation`.

**Modifications :**

- conserver un UUID mutable pour l'**instance** attachée à une tuile ;
- identifier le **contenu** par SHA-256 et version de manifeste ;
- créer un manifeste avec type, version de schéma, auteur, dépendances, politique
  d'exécution, capacités requises, signature et budgets ;
- stocker une seule copie par hash sous `AppDataLocation/artifacts/` ;
- référencer les artefacts par `{instanceId, contentHash, manifestVersion}` dans
  la map/sauvegarde ;
- gérer comptage de références, garbage collection, mise à jour et migration ;
- si absent : désactiver l'élément avec diagnostic, puis tenter un téléchargement
  autorisé depuis la bibliothèque.

**Points d'ancrage :**

- identité tuile : `cpp/game/item_snapable/ItemSnapable.*` ;
- catalogue : `cpp/assetManager/asset_manager.*` ;
- manifestes : `cpp/launcher/launcher_manager.*`.

**Critères d'acceptation :**

- deux tuiles peuvent partager le même contenu sans dupliquer la source ;
- une source modifiée produit un nouveau hash sans muter l'ancienne version ;
- un hash incorrect ou une dépendance manquante empêche l'exécution.

### M9 — Implémenter le sandbox QML/JS et son repli *(structuré en deux étages par D26)*

**Socle repris :** moteur QML actuel uniquement comme environnement d'intégration ;
aucune garantie de sécurité V2 n'est réutilisable telle quelle.

**Modifications :**

- **Étage 1 — banc d'essai hors-process (D26)** : exécutable de test Qt
  headless distinct qui **réinstancie la carte depuis un snapshot** et
  instancie l'artefact candidat ; verdict sur non-chargement, boucle infinie
  (timeout → kill du process), crash, budgets. À spécifier : format du
  snapshot, critères de verdict, pool de process ;
- **Étage 2 — confinement runtime (D13)** dans le jeu, pour le code validé :
- construire un parseur/validateur d'imports, types et JS interdits ;
- fournir un module d'API de jeu minimal au lieu des singletons globaux ;
- instrumenter le JS ou définir un sous-ensemble borné pour budgets et arrêt ;
- isoler parentage, cycle de vie et quotas d'objets ;
- mesurer l'accessibilité réelle des singletons enregistrés depuis un contexte
  enfant ;
- si le confinement runtime échoue, refuser le QML libre (repli « palette +
  mémoire ») — la préemption des boucles franches est, elle, déjà couverte par
  l'étage 1 ;
- revalider au chargement avec cache indexé par hash de source + version du
  validateur (revalidation = repasser l'étage 1) ;
- appliquer la politique d'exécution du manifeste : hôte seulement ou pairs
  après revalidation.

**Points d'ancrage :**

- enregistrement actuel : `cpp/qmlapp.cpp` et `registerQml()` des singletons ;
- nouveau dossier conseillé : `cpp/ai/sandbox/` ;
- façade mémoire/événements : M5/M6.

**Critères d'acceptation bloquants R1 :**

- blocage des imports/singletons/fichier/réseau/process interdits ;
- arrêt mesuré d'une boucle infinie **au banc d'essai** sans geler le GUI du
  jeu (D26) ;
- respect des plafonds mémoire/objets ;
- destruction/rechargement sans fuite ;
- échec fermé : aucun artefact n'est instancié si un contrôle est indécidable.

### M10 — Étendre la migration d'hôte à l'autorité V3

**Socle repris :** roster, `HostLeaving`, élection lexicographique,
`promoteToHost()`, transfert du host chat et full-sync éditeur.

**Modifications :**

- inclure dans le checkpoint M7 : règlement, version d'arbitre, journal/cursor,
  `memory.state`, séquences et hashes d'artefacts ;
- suspendre propositions et commits pendant l'élection ;
- démarrer/valider le nouvel arbitre avant la reprise ;
- transférer le checkpoint au nouvel hôte et vérifier son hash ;
- resynchroniser les pairs depuis la nouvelle autorité ;
- définir le comportement si aucun pair ne peut lancer d'arbitre.

**Points d'ancrage :**

- `cpp/editor/network/editor_session.*` ;
- `qml/editor/Editor.qml` ;
- `qml/main.qml` ;
- `cpp/chat/chat_client.*`.

**Critères d'acceptation :**

- migration volontaire et sur timeout ;
- aucune proposition acceptée par deux hôtes concurrents ;
- reprise avec même règlement, état et versions d'artefacts ;
- nouvel arbitre non prêt = reprise bloquée avec diagnostic.

### M11 — Étendre la distribution d'assets en bibliothèque signée

**Socle repris :** `asset_server`, `LauncherManager`, SHA-256, queue/retry/reprise,
manifestes et pipeline GLB.

**Modifications :**

- définir un package commun pour primitives, GLB, métadonnées et artefacts ;
- signer le manifeste avec une clé éditeur asymétrique ;
- embarquer les clés publiques de confiance et prévoir rotation/révocation ;
- vérifier signature **puis** hashes de chaque fichier avant installation ;
- ajouter dépendances/version/hash aux références `(category,type,id)` et
  `modelName` ;
- installer de façon atomique dans un dossier de version, puis commuter le
  manifeste actif ;
- interdire l'import utilisateur au premier jalon D18.

**Points d'ancrage :**

- `asset_server/server.js` ;
- `cpp/launcher/launcher_manager.*` ;
- `cpp/assetManager/asset_manager.*` ;
- `qml/world3d/KuraModel.qml`, `SkinnedModel.qml`.

**Critères d'acceptation :**

- package altéré, manifeste non signé ou clé révoquée refusés ;
- interruption d'installation laisse l'ancienne version utilisable ;
- GLB chargé avec la version/hash demandés, sans résolution ambiguë.

### M12 — Générer et installer les skills Codex/Claude

**Socle repris :** déclarations de tools de `automation_mcp/` comme patron, pas
comme source de vérité.

**Modifications :**

- créer un manifeste versionné du canal IA ;
- générer au build un contrat machine et les variantes de `SKILL.md` nécessaires ;
- générer exemples, erreurs et limites depuis la même source ;
- ajouter validation de dérive en CI ;
- installer dans les emplacements spécifiques à Codex/Claude, détectés par un
  adaptateur, avec consentement utilisateur ;
- proposer mise à jour et compatibilité lors du handshake.

**Points d'ancrage :**

- patron : `automation_mcp/` ;
- nouveau générateur conseillé : `scripts/generate_ai_skill.*` ;
- packaging : `Meownopoly/CMakeLists.txt` et installeur.

**Critères d'acceptation :**

- toute commande du manifeste apparaît dans le contrat et la skill ;
- aucune commande hors allow-list n'est documentée ;
- une modification de schéma non régénérée fait échouer le build/CI.

### M13 — Qualifier officiellement Linux

**Socle repris :** cœur CMake/Qt multiplateforme.

**Modifications :**

- ajouter preset/toolchain Linux Qt 6.11+ et procédure de build reproductible ;
- créer packaging Linux et déploiement des plugins QML/Quick3D/CanvasPainter ;
- porter `dual_test_p2p` sans `cmd /c start` ;
- exécuter tests Pattounx et scénarios automation sur Windows + Linux en CI ;
- tester lancement/supervision des deux agents, permissions du fichier token,
  chemins `AppDataLocation`, GLB et sandbox sur les deux OS.

**Points d'ancrage :**

- `CMakeLists.txt` ;
- presets/scripts de build ;
- `automation_mcp/` et serveur d'automation pour les tests E2E.

**Critères d'acceptation :**

- build et package propres sur Windows et Linux ;
- mêmes scénarios réseau/éditeur/sandbox passants ;
- aucun chemin ou outil Windows requis hors bloc conditionnel.

## 10. Dépendances et ordre recommandé

| Ordre | Chantier | Dépend de | Débloque |
|---:|---|---|---|
| 1 | M9 — prototype sandbox R1 | — | D1, exécution d'artefacts |
| 2 | M3 — fiabilité applicative | Catway existant | propositions, commits, migration |
| 3 | M4 — transactions atomiques | M3 | application sûre des propositions |
| 4 | M1 — passerelle MCP | automation + automation_mcp comme patrons | connexion agents |
| 5 | M2 — supervision agents | M1 | proposant + arbitre opérationnels |
| 6 | M5 — événements métier | signaux V2 | règles, observation IA |
| 7 | M6 — bus d'état mémoire | M3, M5 | runtime custom synchronisé |
| 8 | M8 — store d'artefacts | M9 | persistance/réplication du code |
| 9 | M7 — sauvegarde runtime | M6, M8 | reprise et checkpoint |
| 10 | M10 — migration V3 | M2, M3, M7 | continuité après perte d'hôte |
| 11 | M11 — bibliothèque signée | M8 | distribution officielle |
| 12 | M12 — skills générées | M1 stabilisé | clients Codex/Claude |
| transversal | M13 — Linux | chaque chantier | support Windows/Linux réel |

Le premier vertical slice ne doit pas attendre M10/M11/M13 complets, mais il ne
doit pas contourner M9, M3 et M4 : sandbox, livraison applicative et atomicité
sont les trois fondations qui empêchent le prototype de figer de mauvaises
garanties dans le protocole public.
