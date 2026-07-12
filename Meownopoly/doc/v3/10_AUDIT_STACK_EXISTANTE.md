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
