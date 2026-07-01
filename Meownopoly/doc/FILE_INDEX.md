# Index des fichiers du projet

Ce document liste, fichier par fichier, le contenu du dépôt (C++, QML, scripts serveur/outils, config) avec une courte description de son rôle. Objectif : retrouver rapidement le(s) bon(s) fichier(s) à ouvrir pour une demande donnée, sans avoir à explorer l'arborescence à chaque fois.

Pour la documentation fonctionnelle/architecturale détaillée (pourquoi, pas juste quoi), voir [doc/INDEX.md](./INDEX.md) et les fichiers de `doc/architecture/`. Ce fichier-ci est un index mécanique par fichier source, pas un remplacement de cette doc.

Note : ce fichier a été généré (2026-07-01) par lecture automatisée de la quasi-totalité des fichiers du repo ; il peut devenir partiellement obsolète au fil des évolutions du code — en cas de doute, se fier au code plutôt qu'à cette liste.

---

## Sommaire

- [C++ (`Meownopoly/cpp/`)](#c-meownopolycpp)
- [QML (`Meownopoly/qml/`)](#qml-meownopolyqml)
- [Tests (`Meownopoly/tests/`)](#tests-meownopolytests)
- [Configuration du build (`Meownopoly/`)](#configuration-du-build-meownopoly)
- [Serveur de chat (`chatServer/`)](#serveur-de-chat-chatserver)
- [Serveur d'assets (`asset_server/`)](#serveur-dassets-asset_server)
- [Outils images (`image_tools/`)](#outils-images-image_tools)
- [Racine du dépôt](#racine-du-dépôt)

---

## C++ (`Meownopoly/cpp/`)

### cpp/ (racine)
- `cpp/main.cpp` — Point d'entrée : instancie `QGuiApplication`, gère le suffixe `--instance N` (dual-instance), détecte le backend graphique Qt Quick, construit `QmlApp` puis instancie optionnellement `AutomationServer`.
- `cpp/qmlapp.{cpp,h}` — `QmlApp` (QQmlApplicationEngine), bootstrap de l'application : enregistre tous les singletons/types QML (Game, AssetManager, Catway, EditorSession, PhysicsWorld, chat, etc.), configure les toggles de rendu GPU (grille/zones), les context properties (`pattounxWorld`), les chemins d'import QML et charge `main.qml`.

### cpp/account/
- `cpp/account/account_manager.{cpp,h}` — Singleton QML `AccountManager` : génère/persiste (QSettings) un identifiant unique de joueur, le pseudo et la config du serveur STUN (URL/port).

### cpp/assetManager/
- `cpp/assetManager/asset_manager.{cpp,h}` — Singleton QML `AssetManager` + `AssetModel` (QAbstractListModel) : indexe les assets (images, décos, modèles 3D) depuis `AppDataLocation/assets`, expose recherche par id/filename/aléatoire, génération de metadata.json, et la résolution runtime des ressources Color ID Map (manifest, skins, textures, variantes) pour le re-skinning des modèles 3D.

### cpp/automation/
- `cpp/automation/automation_server.{cpp,h}` — `AutomationServer`, serveur WebSocket JSON embarqué en local (127.0.0.1, opt-in `--automation-port`/`MEOW_AUTOMATION_PORT`) pilotant la scène QML pour les tests automatisés : introspection d'arbre (`tree`/`find`), get/set de propriétés, invocation de méthodes/fonctions JS, synthèse souris/clavier, screenshot, attente conditionnelle (`waitFor`) et `quit`.

### cpp/chat/
- `cpp/chat/chat_client.cpp` — Implémentation cœur de `ChatClient` (ctor/dtor, thread worker, `createSession`/`renameSession`/`transferHost`/`connectToSessionDirect`/`joinSession`, gestion clés de session, chargement historique local `loadHistory`, décodage image async via `m_chatPool`).
- `cpp/chat/chat_client.h` — Déclaration de la classe `ChatClient` (QObject QML-exposé, façade GUI-thread du chat) : propriétés (connected, sessionId, messages, participants, availableSessions, pingMs), API Q_INVOKABLE (créer/rejoindre session, envoyer message/image/fichier, kick, ping), signaux d'événements serveur, et tous les handlers privés de dispatch des messages WebSocket.
- `cpp/chat/chat_client_command.cpp` — Extension de `ChatClient` (pas de header propre) : chiffrement/formatage des commandes applicatives (`sendCommand`/`handleNewCommand`), auto-réponse PING/PONG, et helpers réseau P2P (`sendRequestConnectionInfo`, `sendShareConnection`) utilisés par Catway pour le hole punching.
- `cpp/chat/chat_client_handler.cpp` — Extension de `ChatClient` (pas de header propre) : dispatch central `onTextMessageReceived` (switch sur `type` JSON) et tous les handlers de messages serveur (INIT_SESSION, SESSION_CREATED, KEY_UPDATE, KICKED, SESSION_ENDED, HOST_CHANGED, SESSION_RENAMED, etc.), plus `resetSessionState()` qui vide tout l'état client.
- `cpp/chat/chat_client_message.cpp` — Extension de `ChatClient` (pas de header propre) : envoi de messages utilisateur (`sendMessage`, affichage optimiste), envoi d'images compressées en WEBP (`sendImage`) et de fichiers texte (`sendTextFile`/`saveTextToFile`), tout chiffré via `ChatCrypto` avant émission WebSocket.
- `cpp/chat/chat_command_helper.{cpp,h}` — `ChatCommandHelper` : sérialisation/désérialisation JSON compacte des commandes applicatives internes (`{type, payload}`) échangées via le canal chat chiffré (`formatCommand`/`parseCommand`).
- `cpp/chat/chat_crypto.{cpp,h}` — `ChatCrypto` : dérivation de clé de verrouillage (`deriveLockKey`) et preuve de mot de passe SHA-256 hex (`derivePasswordProof`), chiffrement authentifié maison (stream cipher SHA-256-keystream + HMAC-SHA256 encrypt-then-MAC) pour le relais aveugle end-to-end ; doit rester en miroir avec `chatServer/chat_crypto.js`.
- `cpp/chat/chat_database.{cpp,h}` — `ChatDatabase` : persistance locale SQLite (`local_history` pour les messages chiffrés, `session_keys` pour les clés de session chiffrées par le lockKey), une connexion SQLite nommée par instance pour éviter les collisions multi-ChatClient.
- `cpp/chat/chat_image_provider.{cpp,h}` — `ChatImageProvider` (QQuickImageProvider) : registre statique thread-safe (QHash + QMutex) d'images décodées, exposées à QML via l'URL `image://chat_images/<uuid>`.
- `cpp/chat/chat_session_manager.{cpp,h}` — Singleton QML `ChatSessionManager` : gère un `ChatClient` dédié à la liste des sessions (`m_serverQueryClient`, rafraîchi périodiquement), une liste de `ChatClient` par session rejointe (`joinSession`/`createAndJoinSession`/`leaveSession`), et délègue l'activation à `Catway::setChatClient`.
- `cpp/chat/chat_slash_commands.{cpp,h}` — Singleton QML `ChatSlashCommands` : registre statique des commandes slash chat (`/ping`, `/stun`, `/create`) et détection de commande dans un texte tapé par l'utilisateur.
- `cpp/chat/chat_worker.{cpp,h}` — `ChatWorker` : wrapper `QWebSocket` tournant dans son propre thread (connexion, envoi/réception de texte, ping/pong RTT toutes les 2s), relié à `ChatClient` par signaux/slots cross-thread.

### cpp/communication/
- `cpp/communication/catway.cpp` — Implémentation cœur du singleton `Catway` : construction (thread réseau dédié, ChatClient interne, connexions StunManager/CatwayWorker), `setChatClient`, listes QML `localPorts`/`players`, dispatch des datagrammes UDP reçus (`onDatagramReceived`, table de handlers hole-punch) et des commandes chat entrantes (`onChatCommandReceived`), envoi UDP/reliable/broadcast.
- `cpp/communication/catway.h` — Déclaration de `CatwayWorker` (thread réseau : STUN, reliable.io, heartbeats, snapshots joueurs) et `Catway` (singleton QML orchestrateur GUI-thread : joueurs, sockets, chat, hole punching, API reliable/broadcast), plus les structs `PlayerSnapshot` et `CatwayReliableContext` partagées entre threads.
- `cpp/communication/catway_holepunch.cpp` — Extension de `Catway` (pas de header propre) : logique du hole punching UDP (`initiateHolePunch`, handlers `HP:REPLY`/`HP:FINAL`/`HP:STRIKE`/`HP:PING`) et traitement des commandes chat liées à l'échange d'infos de connexion (`REQUEST_CONNECTION_INFO`, `REPLY_CONNECTION_INFO`, `UDP_HOLE_PUNCH_REQUEST`).
- `cpp/communication/catway_player.cpp` — Extension de `Catway` (pas de header propre) : callbacks C `reliable.io` (transmit/process packet), gestion du cycle de vie des `PlayerNetwork` (`addPlayer`/`removePlayer`/`getOrCreatePlayer`), construction et push des `PlayerSnapshot` vers le thread réseau, ré-indexation par playerId.
- `cpp/communication/catway_stun.cpp` — Extension de `Catway` (pas de header propre) : façade GUI-thread vers `StunManager` via le worker (`startStunServer`/`sendStunRequest`/`takeStunSocket`/`setupNewPort`), gestion des commandes chat mises en attente pendant une résolution STUN (`triggerStunForPendingCommand`).
- `cpp/communication/catway_worker.cpp` — Implémentation de `CatwayWorker` (thread réseau dédié) : init/boucle `reliable.io` à 60 Hz, ACK-flush et keepalives périodiques, lecture des sockets UDP (`onSocketReadyRead`, démultiplexage paquet fiable 0x01 vs raw), heartbeats `HP:PING`/`HP:STRIKE` et détection de timeout joueur (30s).
- `cpp/communication/player_network.{cpp,h}` — `PlayerNetwork` : état réseau d'un joueur/pair distant (identité, adresse de destination, socket local associé, endpoint reliable, flag P2P), gestion de l'endpoint `reliable.io` (init/destroy, fragmentation), exposition des stats réseau (RTT, perte, bande passante) via `stats()`.
- `cpp/communication/stun_manager.{cpp,h}` — `StunManager` : envoi de requêtes STUN Binding (RFC 5389, résolution DNS async), parsing de la réponse (MAPPED-ADDRESS et XOR-MAPPED-ADDRESS) pour découvrir IP/port publics, gestion du socket UDP local et de son remplacement (`takeSocket`) pour préparer un socket dédié au hole punching.
- `cpp/communication/udp_socket_info.{cpp,h}` — `UdpSocketInfo` : conteneur QObject autour d'un `QUdpSocket` (adresse/port publics STUN, port local lié), gestion propre de l'ownership/transfert de thread du socket, exposé QML (publicAddress, publicPort, localPort).

### cpp/editor/network/
- `cpp/editor/network/editor_message_type.h` — Enum `EditorMessageType` (Hello, Welcome, FullSync, Op, OpAck, OpReject, CursorUpdate, SelectionUpdate, PlayerRoster, OpChunk, HostLeaving) : identifie le type du premier octet de chaque paquet réseau éditeur, plage 0x20+ pour coexister avec `GameMessageType` sur Catway.
- `cpp/editor/network/editor_protocol.{cpp,h}` — Classe statique `EditorProtocol::pack/unpack/isEditorPacket` : sérialise/désérialise le format `[1 byte type][JSON UTF-8]` et démultiplexe les paquets appartenant à la plage `EditorMessageType` reçus par Catway.
- `cpp/editor/network/editor_session.{cpp,h}` — Singleton QML `EditorSession`, session réseau collaborative host-authoritative bâtie sur Catway (miroir de `GameSession`) : démarre en hôte/client (`startAsHost/startAsClient`), envoie/reçoit ops (avec chunking `OpChunk` au-delà de 20 Ko, rate-limit token bucket par sender), gère curseurs (UDP brut lossy), sélections distantes, roster de pairs, et la migration d'hôte (annonce volontaire `HostLeaving`, élection déterministe `electNewHost`, `promoteToHost`, purge de l'ancien hôte au timeout).

### cpp/editor/ops/
- `cpp/editor/ops/editor_op_bus.{cpp,h}` — Singleton QML `EditorOpBus`, chokepoint unique de toutes les mutations de l'éditeur : `submitOp`/`submitOpWithUndo` loggent et acheminent vers `EditorSession` (avec rate-limit local et garde anti-boucle `isApplyingRemote`/`beginApplyRemote`/`endApplyRemote`), gère les piles undo/redo par client, expose des helpers `make*Op` (Create/Delete/Move/Link/Unlink, profils joueurs) et un mécanisme de transaction groupée (`submitFromDelta`/`flushGroup`) pour batcher les `ApplyState` d'un `Game::commitTransaction`.
- `cpp/editor/ops/editor_op_type.h` — Enum `EditorOpType` (CreateItem, DeleteItem, MoveItem, ResizeItem, Set*Parameter/Data, LinkItems/UnlinkItems, ApplyState, et les ops Player Config Add/Remove/Update/Reorder Profile + SetMapPlayerLimits) : jeu d'opérations d'édition véhiculées dans le champ `"op"` de chaque payload JSON du protocole collaboratif.

### cpp/editor/painter/
- `cpp/editor/painter/grid_canvas_painter.{cpp,h}` — `GridCanvasPainter` (QCanvasPainterItem GPU) : item unique couvrant le viewport visible, expose en Q_PROPERTY les paramètres de grille (croisillons, gridSize, couleur/opacité, lineWidth, resizeMode, offsets viewport) consommés par son renderer.
- `cpp/editor/painter/grid_canvas_painter_renderer.{cpp,h}` — `GridCanvasPainterRenderer` : dessine les croisillons de la grille entière en un seul canvas avec viewport culling (calcule les indices de lignes visibles et ne trace qu'elles), instrumenté avec compteurs perf atomiques (temps paint/sync, lignes émises).
- `cpp/editor/painter/zone_canvas_painter.{cpp,h}` — `ZoneCanvasPainter` (legacy, un canvas par zone d'exclusion, fallback `MEOW_ZONES_RENDERER=per-tile`) : stocke le polygone/couleurs/hachures d'une zone, avec cache de segments de hachures pré-calculé (sync ou async via `QFutureWatcher`+`QtConcurrent`) selon le mode de parallélisation actif.
- `cpp/editor/painter/zone_canvas_painter_renderer.{cpp,h}` — `ZoneCanvasPainterRenderer` : dessine fill+stroke+hachures d'une zone unique à partir des segments (calculés à la volée ou lus depuis le cache item selon le `ParallelMode`), avec compteurs perf pour le benchmark `tst_zone_render_perf`.
- `cpp/editor/painter/zone_hatch_compute.{cpp,h}` — Fonctions pures `zone_painter::computeHatchSegments*` (scanline factorisé, sans dépendance au painter) calculant les segments de hachures d'un polygone en 3 variantes (séquentiel Baseline, `QtcEdges`, `QtcHatches` parallélisées via `QtConcurrent`) ; `currentParallelMode()` lit `MEOW_ZONE_PARALLEL_MODE` (défaut `precompute-async`) pour piloter où/comment le calcul est fait.
- `cpp/editor/painter/zones_overlay_painter.{cpp,h}` — `ZonesOverlayPainter` (QCanvasPainterItem GPU) : canvas global unique couvrant le viewport pour TOUTES les zones d'exclusion de la scène (remplace les N `ZoneCanvasPainter` par tile qui saturaient la VRAM au zoom), reçoit la liste des zones via `QVariantList zones` en coords grille.
- `cpp/editor/painter/zones_overlay_painter_renderer.{cpp,h}` — `ZonesOverlayPainterRenderer` : décode chaque zone en `ZoneDraw`, calcule sa bbox écran, applique le viewport culling (skip si hors-écran), puis dessine fill/stroke/hachures des zones visibles via `zone_hatch_compute`, avec compteurs perf (zones dessinées vs culled).

### cpp/experiment/
- `cpp/experiment/animation_manager.{cpp,h}` — `AnimationManager`, gestionnaire QML expérimental d'animations sprite-based (chargement de frames depuis fichiers/dossier, lecture par QTimer, cache base64, génération de frames de test).
- `cpp/experiment/animationprovider.{cpp,h}` — Singleton QML `AnimationProvider`, fournisseur d'images animées à 120 Hz (timer global cyclant sur une liste de `QImage*` chargée depuis un dossier), diffusé via signal `frameChanged`.
- `cpp/experiment/liveimage.{cpp,h}` — `LiveImage` (QQuickPaintedItem), item QML qui affiche l'image courante poussée par `AnimationProvider::frameChanged` et se redessine à chaque frame.

### cpp/game/ (racine)
- `cpp/game/card.{cpp,h}` — Squelette de classe `Card` (QObject vide, seul un constructeur par défaut), non implémenté ; réservé pour un futur système de cartes (Cat Nip / Cardboard Box) distinct des cases qui les gèrent.
- `cpp/game/game.h` — Déclare le singleton QML `Game`, orchestrateur central de la logique de jeu : sauvegarde/chargement de maps et de templates (JSON), gestion des deltas d'édition (`updateMap`/`applyRemoteDelta`) pour l'undo/redo et la collaboration multi-éditeurs, transactions groupées, et l'horloge logique Lamport (`tickLamport`/`syncLamport`) utilisée pour ordonner le zOrder des tuiles entre peers.
- `cpp/game/game.cpp` — Implémente le cycle de vie du singleton `Game` (instance unique, enregistrement QML de `Game`/`Player`/`CaseFactory`) et le point d'entrée `startGame()` qui émet `gameStarted`.
- `cpp/game/game_lamport.cpp` — Implémente l'horloge logique Lamport de `Game` (compteur entier + jitter par session) qui produit un `zOrder` monotone et sans collision entre peers pour le rendu des tuiles empilées, avec synchronisation à la réception (`syncLamport`) et resynchronisation depuis une `Map` chargée (`syncLamportFromMap`).
- `cpp/game/game_loader.cpp` — Implémente la persistance des maps (`saveCurrentMap`/`saveMap`/`loadMap`/`deleteMap`, sérialisation JSON des `ItemSnapable`), la création d'une map vide pour un client collaboratif (`initEmptyCollabMap`), ainsi que le pipeline undo/redo local avec broadcast des deltas vers `EditorOpBus` (`updateMap`, `updateMapMetadata`, transactions, `applyRemoteDelta`) et la politique de sauvegarde automatique (`saveOnEdit`).
- `cpp/game/game_template.cpp` — Implémente la sauvegarde/chargement/suppression de templates d'éléments (groupes d'`ItemSnapable` réutilisables) via `TemplateFileManager`, avec calcul de bounding box, conversion positions relatives/absolues et régénération des uniqueId lors du placement (`getTemplateElementsForPlacement`).
- `cpp/game/meowstyle.{h,cpp}` — Singleton QML `MeowStyle` exposant les couleurs métier des familles de terrains (`familyColors`, alignées sur `CaseRestArea::FamilyType`) et le mapping nom-lisible des types de case (`caseTypeNames`/`getCaseTypeName`), consommé par l'UI pour l'affichage sans dupliquer la logique métier côté QML.
- `cpp/game/player.h` — Déclare la classe `Player` (QObject) représentant un joueur : nom, couleur, logo, solde de kibbles, position sur le plateau, statut prison, et listes de biens possédés (`CaseRestArea`, `CaseCatDevice`, `CaseCatDoor`) avec compteurs Q_PROPERTY exposés à QML.
- `cpp/game/player.cpp` — Implémente les accesseurs/mutateurs de `Player` avec émission de signaux Qt sur changement, la logique financière (`canAfford`/`earnKibble`/`spendKibble`) et la gestion des collections de propriétés/devices/portes possédées par le joueur (ajout/retrait avec mise à jour des compteurs).

### cpp/game/case/
- `cpp/game/case/Case.{cpp,h}` — Classe de base abstraite `Case` (QObject) de toute case du plateau : enum `CaseType` (départ, terrain, caisse communauté, chance, prison, gare, parc gratuit, service, taxe...), gestion de la liste des joueurs présents sur la case, hooks virtuels `onLand`/`onLeave`/`onHover`, sérialisation JSON de base et conversion int→enum utilisée par `CaseFactory` lors du chargement de map.
- `cpp/game/case/CaseCardBoardBox.{cpp,h}` — Case "Caisse communauté", hérite directement de `Case` sans logique de tirage de carte implémentée (signal `cardDrawn` déclaré mais inutilisé), sérialisation JSON minimale.
- `cpp/game/case/CaseCatDevice.{h,cpp}` — Case "Service" (ex. compagnie d'eau/électricité), hérite de `CaseCatPerks` en ajoutant une `taxe` (multiplicateur de loyer) ; `buyCase`/`sellCase` enregistrent le joueur dans `Player::ownedCatDevices`.
- `cpp/game/case/CaseCatDoor.{h,cpp}` — Case "Gare" (cat door), hérite de `CaseCatPerks` avec un index de porte (`indexCatDoor`) et un prix de voyage (`travelPrice`) ; `buyCase`/`sellCase` gèrent l'inscription dans `Player::ownedCatDoors`.
- `cpp/game/case/CaseCatNip.{h,cpp}` — Case "Chance" (cat nip), hérite directement de `Case`, logique de tirage de carte non implémentée (code commenté), sérialisation JSON basique.
- `cpp/game/case/CaseCatPerks.{h,cpp}` — Classe intermédiaire abstraite pour toute case "achetable" (terrains, services, gares) : prix d'achat/revente/hypothèque, propriétaire courant (`owner`), logique générique `buyCase`/`sellCase` (débit/crédit via `Player::spendKibble`/`earnKibble`), et macros `CASECATPERKS_DEFAULT_PARAMETER*` factorisant les constructeurs des sous-classes.
- `cpp/game/case/CaseFactory.{h,cpp}` — Fabrique statique `CaseFactory` (hérite de `Case` par commodité) qui centralise l'enregistrement QML de toute la hiérarchie de cases (`registerCaseQml`) et la construction d'instances concrètes soit par type par défaut (`createCase(CaseType)`), soit depuis un JSON de map (`createCase(QJsonObject)`, dispatch vers le bon constructeur JSON par sous-classe).
- `cpp/game/case/CaseFreeNap.{h,cpp}` — Case "Parc gratuit" (free parking/nap), hérite de `Case`, accumule une cagnotte de kibbles (`kibbleAmount`/`addToPool`) potentiellement gagnée par le joueur qui tombe dessus (logique `onLand` non branchée).
- `cpp/game/case/CaseJail.{h,cpp}` — Case "Prison", hérite de `Case`, suit par joueur le nombre de tours passés en prison (`QMap<Player*,int>`) avec un plafond (`m_maxJailTurns`) et une amende de libération (`m_jailFine`) ; expose `sendToJail`/`releasePlayer`/`isPlayerInJail`.
- `cpp/game/case/CaseKibbleDispenser.{h,cpp}` — Case "Départ" (distributeur de croquettes), hérite de `Case`, définit une récompense (`reward`, défaut 200) versée en passant/atterrissant sur la case ; aussi réutilisée par `CaseFactory` comme substitut temporaire pour le type "Taxe" non implémenté.
- `cpp/game/case/CaseRestArea.{h,cpp}` — Case "Terrain" (propriété principale du jeu), hérite de `CaseCatPerks` : enums `RestQuality` (niveaux d'amélioration jusqu'à `RQ_HOTEL`) et `FamilyType` (couleur de la cascade/groupe, alignée sur `MeowStyle::familyColors`), prix maison/hôtel, barème de loyers par palier, `buyCase`/`sellCase` enregistrant/retirant la propriété dans `Player::ownedProperties`, sérialisation JSON complète.
- `cpp/game/case/CaseToJail.{h,cpp}` — Case "Aller en prison", hérite de `Case`, référence optionnelle vers une `CaseJail` cible (`setJailCase`) pour y envoyer le joueur.

### cpp/game/item_snapable/
- `cpp/game/item_snapable/Displayparameter.{cpp,h}` — Classe `DisplayParameter` : paramètres d'affichage communs à tout élément placé sur la grille (taille en unités, position grille, zLayer/zOrder, rotation, mirroring, effets visuels brightness/contrast/saturation/colorization/blur/shadow), sérialisation JSON manuelle et opérateur d'égalité pour la détection de changement.
- `cpp/game/item_snapable/ItemSnapable.{cpp,h}` — Classe de base `ItemSnapable` pour tout élément placable sur la grille (case, décoration, zone physique) : agrège `Case`/`DisplayParameter`/`DecorationParameter`/`ZoneParameter`, gère les listes chaînées `next`/`prev`, le `uniqueId`, la (dé)sérialisation JSON complète (`toJSON`/`applyJson`) et un "shadow copy" (`lastKnownJson`/`commitCurrentState`) utilisé pour capturer l'état avant modification (undo/redo, sync réseau).
- `cpp/game/item_snapable/ZoneParameter.{cpp,h}` — Classe `ZoneParameter` : paramètres physiques et visuels d'une zone (polygone de points, exclusion, direction/force de vélocité, friction, multiplicateurs de vitesse/accélération, couleur, nom, référence `screenEffectId`), consommée par le pont éditeur/physique (Pattounx) et le rendu des zones d'exclusion.
- `cpp/game/item_snapable/decorationparameter.{cpp,h}` — Classe `DecorationParameter` : identifie une décoration placée (catégorie/type/id) et résout via `AssetManager` le chemin du GIF animé associé (`getAnimePath`).
- `cpp/game/item_snapable/itemsnapablefactory.{cpp,h}` — Singleton QML `ItemSnapableFactory` : point de création centralisé des `ItemSnapable` (vide, par type de case, depuis JSON, zone physique) et relais de requêtes de création (`requestCreateItem(s)`) émises en signaux vers l'éditeur QML pour placement effectif.
- `cpp/game/item_snapable/physicalobjectparameter.{cpp,h}` — Classe `PhysicalObjectParameter` : coefficients physiques (mass, bounceFactor, frictionStrength, linearDamping) d'un objet dynamique/caisse pour le moteur Pattounx v2 ; feature « caisses » actuellement hors scope UI éditeur mais code conservé pour future ré-intégration.

### cpp/game/map/
- `cpp/game/map/editdelta.h` — Définit `EditDeltaType` (TileModified/Added/Deleted/MetadataChanged) et la struct `EditDelta` (uuid, groupId, JSON before/after), l'unité élémentaire d'undo/redo consommée par `Map::applyDelta`.
- `cpp/game/map/map.{cpp,h}` — Classe `Map` : conteneur des `ItemSnapable` d'une carte, gère le chargement JSON (`loadMap`), les liens next/prev entre tiles, les piles undo/redo par batch de `EditDelta` (`pushDelta`/`undo`/`redo`/`applyDelta`), les compteurs de tuiles par type et le cycle de vie (ajout/suppression/finalisation différée des tiles).
- `cpp/game/map/mapfilemanager.{cpp,h}` — Singleton QML `MapFileManager` : lecture/écriture atomique (via `.tmp`+rename et `QLockFile`) des fichiers JSON de map sous `./map/`, gestion des noms (normalisation, copie, création, suppression, distinction AUTOSAVE/CUSTOM), et propriété `currentMap` exposant la `Map` active.
- `cpp/game/map/mapinfo.{cpp,h}` — Classe `MapInfo` : métadonnées d'une carte (nom, description, dates, background/musique) + roster de joueurs (`playerProfiles`, min/maxPlayers, versioning avec fallback "Princess") + bibliothèque de `ScreenEffect` (versionnée), sérialisation JSON complète (`toJSON`).
- `cpp/game/map/maptypes.h` — Enum QML `MapTypes::MapType` (AUTOSAVE, CUSTOM, UNDOREDO) utilisé pour distinguer l'origine/destination des fichiers de map.
- `cpp/game/map/playerprofile.{cpp,h}` — Classe `PlayerProfile` : un profil de personnage sélectionnable en jeu (nom, modèle 3D, variante de couleur, `pickMode` Unique/Shared/Mandatory, `minOccurrences`) + tous les paramètres physiques (radius, mass, accélération, frictions, bounce), avec presets prédéfinis (Standard/Léger/Lourd/Glissant/Adhérent) et sérialisation JSON.
- `cpp/game/map/screeneffect.{cpp,h}` — Classe `ScreenEffect` : preset paramétrable d'effet visuel plein écran (teinte, vignette, flou, saturation, pulsation, fade in/out) déclenché à l'entrée d'une zone, stocké dans la bibliothèque `MapInfo::screenEffects` et référencé par id depuis `ZoneParameter`.
- `cpp/game/map/templatefilemanager.{cpp,h}` — Singleton QML `TemplateFileManager` : gère des templates de map réutilisables (sauvegarde/lecture de sous-ensembles d'éléments sous `./templates/`), avec conversion de positions absolues↔relatives, calcul de bounding box et régénération des UUID/liens next-prev lors du placement d'un template.

### cpp/game/network/
- `cpp/game/network/game_message_type.h` — Enum `GameMessageType::Value` (Q_NAMESPACE) définissant les types de paquets de partie (GameStart/TurnStart/DiceRoll/PlayerMove/BuyProperty/PayRent/CardDraw/Jail*/PlayerJoined/PlayerLeft/MapSync sur canal fiable 0x01–0x0D, MinigameInput/MinigameSnapshot en UDP brut 0x10–0x11).
- `cpp/game/network/game_protocol.{cpp,h}` — Classe statique `GameProtocol` : `pack`/`unpack` d'un paquet fiable `[type byte][JSON]` avec validation de plage, plus `packMinigameInput`/`unpackMinigameInput` pour encoder les positions minijeu en chaîne compacte `"MG:x;y;vx;vy"` envoyée en UDP brut.
- `cpp/game/network/game_session.{cpp,h}` — Singleton QML `GameSession`, couche de session de jeu par-dessus Catway : mode hôte (autoritaire, broadcast) ou client (envoie ses intentions à l'hôte), relay des paquets fiables/UDP reçus vers les autres joueurs quand on est hôte, émet `boardEventReceived`/`mapSyncReceived`/`minigameInputReceived`/`minigameSnapshotReceived`.
- `cpp/game/network/minigame_sync.{cpp,h}` — `MinigameSync` (QObject exposé QML), orchestre trois timers pour la synchro minijeu : envoi des inputs locaux à 60 Hz, broadcast de snapshot correctif ~1 Hz côté hôte, et un tick de rendu à 30 Hz qui réémet `playerPositionUpdated` pour les positions distantes reçues.

### cpp/game/physics/
- `cpp/game/physics/collision2d.{cpp,h}` — `Polygon2D` (points, normales pré-calculées, bounding box) et classe statique `Collision2D` : détection cercle-polygone (test statique + sweep CCD analytique cercle-segment/cercle-vertex), cercle-cercle en mouvement (`sweepCircleCircle`), point-dans-polygone (ray casting), cercle-AABB, et calcul de rebond `applyBounce`.
- `cpp/game/physics/item_snapable_events.{cpp,h}` — Singleton QML `Pattounx.ItemSnapableEvents`, agrégateur de signaux qui suit la `Map` active et s'abonne dynamiquement à chaque `ItemSnapable` (DisplayParameter/ZoneParameter) pour émettre `tileCreated`/`tileDeleted`/`tileMoved`/`zoneParameterChanged`, bridge central entre l'éditeur et la physique (consommé par `EditorPhysicsBridge`).
- `cpp/game/physics/pattounx_engine_v2.{cpp,h}` — Cœur Qt-free du moteur physique `pattounx::PattounX_engine` : gestion des bodies (Static/Kinematic/Dynamic) et zones, pipeline de step (intégration, friction/zones, CCD body-zone puis body-body, solver itératif de contacts résiduels, correction de pénétration), système de sommeil, accumulation d'événements consommés via `takeEvents`, snapshot via `writeSnapshot`.
- `cpp/game/physics/pattounx_types.h` — Types POD Qt-lite partagés du moteur : enums `BodyType`/`ShapeType`, `ShapeSpec`/`BodySpec`, `ZoneSpec`, `BodySnapshot`/`WorldSnapshot`, tous déclarés `Q_DECLARE_METATYPE` pour transiter en signaux queued.
- `cpp/game/physics/physics_message_type.h` — Enum `PhysicsMessageType::Value` (Q_NAMESPACE), plage 0x40+ : `Snapshot` (binaire compact reliable 30 Hz), `BodiesAnnounce` (table idIndex↔actorId), `InputUpdate`, `Hello`.
- `cpp/game/physics/physics_protocol.{cpp,h}` — Classe statique `PhysicsProtocol` : `packJson`/`packBinary` pour construire les paquets `[1 byte type][payload]`, `isPhysicsPacket`/`peekType`, `unpackJson`/`payloadBytes` pour décoder respectivement les payloads JSON et binaires.
- `cpp/game/physics/physics_session.{cpp,h}` — Singleton QML `Pattounx.PhysicsSession`, orchestrateur réseau host-authoritative de la physique (calqué sur EditorSession) : hôte broadcast un snapshot binaire compact + `BodiesAnnounce`, applique les `InputUpdate` clients ; client désactive sa simu locale, envoie un `Hello`, applique les snapshots reçus ; gère aussi les claims d'acteurs distants et le fallback local sur timeout de l'hôte.
- `cpp/game/physics/physics_worker.{cpp,h}` — `PhysicsWorker` (QObject vivant dans un `QThread` dédié) : boucle `runLoop` à cadence configurable (60 Hz par défaut), exécute chaque step du `PattounX_engine`, publie le `WorldSnapshot` via un pointeur atomique partagé (échange lock-free avec la GUI), relaie les commandes queued et réémet les événements moteur en signaux Qt.
- `cpp/game/physics/physics_world.{cpp,h}` — `PhysicsWorld`, façade QML instanciée en context property `pattounxWorld`, pilote le `PhysicsWorker` : triple buffer Fraser-Harris (`tryAdvanceGuiBuffer` peek+swap), API QML de création de bodies/zones et lecture d'état (`bodyState`, `allBodyIds`), et couche réseau de sérialisation binaire quantifiée du snapshot (`serializeSnapshot`/`applyRemoteSnapshot`).

### cpp/launcher/
- `cpp/launcher/launcher_manager.{cpp,h}` — Singleton QML `LauncherManager`, logique du lanceur : vérification de version, téléchargement/reprise/retry avec checksum SHA-256 des paquets d'assets et de modèles 3D (.meow), création/upload de paquets via `FolderCompressor`, gestion des modèles 3D téléchargés, et tout l'outillage du configurateur de modèles (transform QML, manifest, créateur de skins Color ID Map, bibliothèque de textures partagées).

### cpp/reliable/ (bibliothèque tierce vendorisée)
Bibliothèque "reliable.io" (Glenn Fiedler / Mas Bandwidth LLC), fiabilité UDP par ACK — code tiers, pas de logique métier Meownopoly.
- `cpp/reliable/reliable.h` — En-tête public de la lib (API C).
- `cpp/reliable/reliable.c` — Implémentation core (endpoints, fragmentation, ACK, retransmission).
- `cpp/reliable/example.c` — Exemple d'utilisation client/serveur de la lib.
- `cpp/reliable/fuzz.c` — Harness de fuzzing de la lib.
- `cpp/reliable/soak.c` — Test de charge/endurance ("soak test") de la lib.
- `cpp/reliable/stats.c` — Exemple/outil de démonstration des statistiques de la lib.
- `cpp/reliable/test.cpp` — Point d'entrée des tests unitaires internes de la lib.
- `cpp/reliable/reliable_impl.cpp` — Seul fichier écrit pour ce projet : pont qui compile `reliable.c` en C++ (désactive les tests internes, force `RELIABLE_DEBUG`) afin d'éviter d'activer `LANGUAGES C` dans CMake.

### cpp/tools/
- `cpp/tools/QtFolderCompressor/FolderCompressor.{cpp,h}` — `FolderCompressor`, sérialise/désérialise récursivement un dossier en un seul fichier compressé (qCompress par fichier) pour le packaging d'assets/modèles.
- `cpp/tools/appinfo.{cpp,h}` — Singleton QML `AppInfo`, expose le nom de l'app et les infos de version Android (`APP_VERSION_NAME`/`CODE`, no-op hors Android).
- `cpp/tools/cursor_manager.{cpp,h}` — Singleton QML `CursorManager`, permet à QML de repositionner le curseur souris global (`QCursor::setPos`).
- `cpp/tools/debug_info.h` — Macros de debug : codes couleur ANSI et helpers `qDebug()` colorés (avec/sans nom de fonction).
- `cpp/tools/editorenum.{cpp,h}` — Singleton QML `EditorEnum`, expose l'enum `EditorMouseMode` (modes de la souris dans l'éditeur : normal, pose, sélection/lien, template, jeu, dessin de polygone) à QML.
- `cpp/tools/logger.{cpp,h}` — Singleton QML `Logger`, façade de logging niveau info/debug/warn/error/success avec préfixe couleur et catégorie optionnelle, activable par macros `LOG_LEVEL_*`.
- `cpp/tools/metadata_generator.{cpp,h}` — `MetadataGenerator`, génère les fichiers `metadata.json` d'un dossier d'assets (dimensions, ratio, animation, tri naturel) pour un dossier ou récursivement pour toute l'arborescence d'assets.
- `cpp/tools/mouse_event_filter.{cpp,h}` — `MouseEventFilter`, filtre d'événements souris applicatif global appliquant sensibilité/inversion Y configurables (QSettings) en repositionnant le curseur, avec garde anti-boucle.
- `cpp/tools/test_manager.{cpp,h}` — Singleton QML `TestManager`, actions de test manuel exposées à QML (logs de démonstration, envoi de requête STUN) pour le harness de dev.
- `cpp/tools/uistyle.{cpp,h}` — Singleton C++ `UiStyle`, expose en `Q_PROPERTY` constants les z-index des calques UI (HUD, grille, workarea, chat drawer, etc.) utilisés par le QML.

---

## QML (`Meownopoly/qml/`)

### qml/ (racine)
- `qml/main.qml` — Racine `ApplicationWindow` de l'application ; pilote le `StackView` de navigation entre écrans (titre, éditeur, launcher, lobby, tests) et la state machine P2P du hole-punch client (`p2pStateMachine`), gère aussi l'annonce de départ hôte à la fermeture et la promotion en cas de migration d'hôte.

### qml/account/
- `qml/account/AccountSettingsPopup.qml` — Popup de paramètres du compte (identifiant unique copiable/régénérable, édition du pseudo, configuration du serveur STUN).
- `qml/account/AccountSetupPage.qml` — Page de première configuration du compte (choix du pseudo, serveur STUN) à la première ouverture de l'application.

### qml/chat/
- `qml/chat/ChatDrawer.qml` — Panneau tiroir racine du chat, orchestre le `ChatClient` actif (Catway ou fallback interne), les dialogs de mot de passe/fichiers, et assemble header/participants/messages/input/status.
- `qml/chat/ChatHeader.qml` — Barre d'en-tête du chat (titre, badge participants, effacement historique, indicateur connexion, redimensionnement du drawer par glisser).
- `qml/chat/ChatHeaderSelection.qml` — Sélecteur compact de session chat active dans l'en-tête, avec popup listant les sessions disponibles.
- `qml/chat/ChatInputBar.qml` — Barre de saisie du message avec gestion des commandes slash, envoi image/fichier texte, et bandeau "message privé à X".
- `qml/chat/ChatMessageDelegate.qml` — Delegate d'un message de chat (bulle stylée propriétaire/autre, affichage texte/image/fichier texte, badge privé).
- `qml/chat/ChatMessagesList.qml` — Liste des messages (ListView) avec drag&drop d'images/fichiers, auto-scroll intelligent collé au bas.
- `qml/chat/ChatParticipantsPanel.qml` — Panneau dépliable listant les participants connectés (statut, message privé, kick pour l'hôte).
- `qml/chat/ChatStatusBar.qml` — Barre de statut basse (connecté/déconnecté, nombre de messages/participants, pseudo).
- `qml/chat/ChatToastPopup.qml` — Popup de notifications toast empilées pour les nouveaux messages reçus quand le drawer est fermé.
- `qml/chat/TextFileDisplay.qml` — Affichage d'un fichier texte partagé dans le chat (en-tête coloré par extension, copier/sauvegarder, contenu scrollable).

### qml/editor/ (racine)
- `qml/editor/CameraTestPanel.qml` — Panneau flottant de debug pour piloter à la main le `CameraRig` : bascule entre modes Follow/FreeCam/FixedTopDown/OrbitDebug, sliders yaw/pitch/distance/smoothSpeed et lecture live de la position caméra.
- `qml/editor/CollabStatusPanel.qml` — Badge indiquant l'état de la session collab courante (hôte/client, id de session) avec un panneau dépliable de stats réseau reliable.io par pair (RTT, perte de paquets, débit).
- `qml/editor/Editor.qml` — Scène racine de l'éditeur de map : orchestre la grille, les panneaux HUD, le full-sync réseau (chunks host→client), l'application des ops distantes reçues de `EditorOpBus`, les curseurs/sélections distantes de la session collab, la présentation 3D (World3D/caméra/joueur physique) et les popups (menu esc, sortie de session collab, message plein écran).
- `qml/editor/EditorController.qml` — Singleton gérant les raccourcis clavier globaux de l'éditeur (suppression multi-sélection avec transaction undo, Escape contextuel, undo/redo Ctrl+Z/Y, toggle du panneau admin).
- `qml/editor/EditorDynamicComponent.qml` — Fabrique de `Component` QML instanciés dynamiquement selon le contexte : tuiles snapables (case/décoration/zone physique) et stratégies souris/scroll (sélection, pose, jeu, lien, polygone, template).
- `qml/editor/EditorEscMenu.qml` — Menu d'échappement en overlay (Retour menu principal, Charger carte, Paramètres, About) avec un sous-panneau de réglages complet (sauvegarde, échelle UI, résolution, audio, contrôles) persisté via QSettings.
- `qml/editor/EditorLogic.qml` — Composant logique central de l'éditeur (`Base_logic`) qui détient la liste des tuiles posées, l'état de sélection d'asset/case armé pour la pose, et les fonctions de sauvegarde/suppression/création de carte.
- `qml/editor/Editor_WheelHandler.qml` — Gestionnaire de molette qui délègue le scroll/zoom au `ScrollLogic` courant puis re-snap toutes les tuiles à la grille.
- `qml/editor/MenuMapAtStart.qml` — Popup de création de nouvelle carte demandant nom, description et configuration du fond d'écran (image custom ou thèmes prédéfinis, mode Stretch/Fit/Tile, snap grille).
- `qml/editor/PhysicsStatusPanel.qml` — Badge cliquable affichant l'état ON/OFF du moteur physique Pattounx (avec tickrate) et permettant de le démarrer/arrêter manuellement.
- `qml/editor/Trackers.qml` — Regroupe les `MouseArea` invisibles qui trackent la position du curseur selon le mode actif (pose d'asset, lien, placement de template) pour alimenter les prévisualisations correspondantes.

### qml/editor/logic/
- `qml/editor/logic/MouseLogic_Base.qml` — Classe de base des stratégies de souris de l'éditeur : gère le drag/snap des éléments sélectionnés via des bindings dynamiques sur `groupeSelection`, la synchronisation caméra 3D pendant zoom/pan, et les callbacks de clic/presse par défaut relayés aux side-panels.
- `qml/editor/logic/MouseLogic_DrawPolygon.qml` — Mode dessin de zones d'exclusion physiques : accumule des points de polygone au clic gauche (snap grille sur Shift), les ferme au clic droit/double-clic pour créer un `PhysicZoneTile`, avec prévisualisation live.
- `qml/editor/logic/MouseLogic_Game.qml` — Squelette de mode "jeu" (test in-editor) qui mappe la souris vers l'espace 3D pour positionner une entité, mais la logique de conversion coord 2D→3D est actuellement commentée/inactive.
- `qml/editor/logic/MouseLogic_Pose.qml` — Mode pose d'assets/cases : place l'élément armé sur la case grille cliquée via `TileLogic.placeSelectedAsset`, et déclenche le broadcast réseau `Game.updateMap(TileAdded)`.
- `qml/editor/logic/MouseLogic_Selection.qml` — Mode sélection normal : clic simple/multi (Ctrl), drag groupé avec snap, et sélection par rectangle (drag dans le vide) avec transaction undo.
- `qml/editor/logic/MouseLogic_Selection_link.qml` — Sous-mode dédié à la création de liens entre cases (prev/next) : clic sur une case cible crée le lien, avec curseur de prévisualisation indiquant si la cible survolée est valide.
- `qml/editor/logic/MouseLogic_Template.qml` — Mode gestion de templates : sous-mode "création" (toggle/rectangle de sélection d'éléments) et sous-mode "placement" qui charge un template sauvegardé et l'instancie à la position du curseur.
- `qml/editor/logic/PlanLogic.qml` — Gère l'affichage par plage de plans/calques ("étages" zLayer) du plateau : atténue (opacité, désactivé) les tuiles hors de la plage affichée, sauf un calque spécial toujours visible.
- `qml/editor/logic/ScrollLogic.qml` — Zoom de la grille à la molette (Ctrl+molette) : facteur multiplicatif ×1.1/cran, recentrage sur le curseur, ajustement de l'élément en cours de pose et synchro caméra 3D.
- `qml/editor/logic/ScrollLogic_POSE.qml` — Variante active en mode pose : détourne la molette (sans Ctrl) pour incrémenter/décrémenter largeur (Shift+molette) ou hauteur (Ctrl+molette) de l'élément en cours de placement.
- `qml/editor/logic/TileLogic.qml` — Logique métier de création/suppression/liaison des tuiles : instancie le bon composant selon `tileType`, gère la suppression avec nettoyage réseau, les connexions prev/next, et la resynchronisation après undo/redo.

### qml/editor/panel/mapInfoPanel/
- `qml/editor/panel/mapInfoPanel/MapInfoDrawer.qml` — Tiroir latéral affichant les infos de la map courante (nom, version, dates, min/max joueurs éditables), des statistiques (compteurs cases/déco/zones) et un onglet fond d'écran.
- `qml/editor/panel/mapInfoPanel/MapInfoPanel.qml` — Conteneur racine assemblant `MapInfoDrawer` et `MapNavigationBar`, masque/restaure le module de config actif à l'ouverture/fermeture du drawer.
- `qml/editor/panel/mapInfoPanel/MapNavigationBar.qml` — Barre flottante avec flèches pour naviguer entre les cartes disponibles sur disque, affiche le nom/index courant et un bouton de suppression à double confirmation.

### qml/editor/configPanel/
- `qml/editor/configPanel/BottomSidePanel.qml` — Panneau bas redimensionnable (drag vertical) hébergeant le contenu de configuration dans un ScrollView, avec poignée de resize et effet décoratif de particules.
- `qml/editor/configPanel/BottomSidePanel_Content.qml` — Layout vertical assemblant les sous-panneaux collapsables du bas (effets visuels, modèle 3D, config de case, connexions, zone) et relayant leurs signaux vers le parent.
- `qml/editor/configPanel/ModelSelectionPanel.qml` — Groupe collapsable listant les modèles 3D disponibles (primitives + modèles téléchargés) sous forme de boutons pour choisir le modèle de l'élément sélectionné.

### qml/editor/configPanel/caseConfigPanel/
- `qml/editor/configPanel/caseConfigPanel/CCPS_CardBoardBoxSection.qml` — Section informative expliquant le fonctionnement de la case Caisse de Communauté (tirage de carte à l'arrivée d'un joueur), sans champ éditable.
- `qml/editor/configPanel/caseConfigPanel/CCPS_CatDeviceSection.qml` — Section de config de la case Appareil Électronique : prix hérités via `CCP_CatPerksConfig` plus un SpinBox pour la taxe d'utilisation payée par les autres joueurs.
- `qml/editor/configPanel/caseConfigPanel/CCPS_GeneralSection.qml` — Section générique de config de case limitée au champ "Nom", synchronisée en lecture/écriture avec la case ciblée.
- `qml/editor/configPanel/caseConfigPanel/CCPS_KibbleDispenserSection.qml` — Section de config de la case Distributeur de Croquettes : un SpinBox définissant le montant de la récompense donnée au joueur qui atterrit dessus.
- `qml/editor/configPanel/caseConfigPanel/CCPS_RestAreaSection.qml` — Section regroupant tous les sous-panneaux propres aux cases Terrain : famille/couleur, prix perks hérités, prix des améliorations maison/hôtel, et prix de location.
- `qml/editor/configPanel/caseConfigPanel/CCPS_TypeSection.qml` — Sélecteur de type de case sous forme de carrousel (flèches) parcourant les types disponibles et déclenchant la conversion de la case.
- `qml/editor/configPanel/caseConfigPanel/CCP_CatPerksConfig.qml` — Bloc réutilisable "Prix et Finances" (achat/vente/hypothèque) pour les cases RestArea/CatDoor/Device, synchronisé bidirectionnellement à la case cible.
- `qml/editor/configPanel/caseConfigPanel/CCP_HouseHotelPriceConfig.qml` — Bloc réutilisable définissant les prix d'achat des améliorations (étoile/hôtel) constructibles sur une case RestArea.
- `qml/editor/configPanel/caseConfigPanel/CCP_PanelElement.qml` — GroupBox de base stylé servant de brique commune à tous les blocs `CCP_*`, exposant `targetCase`/`updatingValues` et un rendu titre/fond harmonisé.
- `qml/editor/configPanel/caseConfigPanel/CCP_RentConfig.qml` — Bloc réutilisable "Prix de Location" pour une case RestArea, avec cinq SpinBox (terrain nu, 1 à 3 étoiles, hôtel).
- `qml/editor/configPanel/caseConfigPanel/CCP_RestAreaFamilyConfig.qml` — Bloc réutilisable sélectionnant la famille/couleur d'une case RestArea via une ComboBox avec swatches colorés.
- `qml/editor/configPanel/caseConfigPanel/CaseConfigurationPanelSection.qml` — Panneau agrégateur assemblant le sélecteur de type, la config générale et les sections spécifiques par type de case, orchestrant `setTargetCase`/`updateControls`.

### qml/editor/configPanel/connectionConfigPanel/
- `qml/editor/configPanel/connectionConfigPanel/ConnectionListSection.qml` — Liste réutilisable (précédents/suivants) affichant les éléments connectés à un item avec badge d'index, survol pour highlight de la liaison, et bouton "Retirer" par entrée.
- `qml/editor/configPanel/connectionConfigPanel/ConnectionsConfigurationSection.qml` — Panneau principal de gestion des liaisons next/previous d'un élément posable : boutons d'ajout, deux `ConnectionListSection` (previous/next) supprimant des liens via `EditorOpBus`.

### qml/editor/configPanel/visualEffectPanel/
- `qml/editor/configPanel/visualEffectPanel/VEP_AdvancedEffectsSection.qml` — Sous-section regroupant les effets de flou (blur) et d'ombre portée, chacun avec case à cocher d'activation et slider d'intensité.
- `qml/editor/configPanel/visualEffectPanel/VEP_ButtonMirror.qml` — Petit bouton toggle en forme d'icône servant à activer/désactiver le miroir horizontal ou vertical d'un élément.
- `qml/editor/configPanel/visualEffectPanel/VEP_ColorEffectsSection.qml` — Sous-section colorimétrie (luminosité, contraste, saturation, colorisation) avec sélecteur de couleur inline et presets persistés via QSettings.
- `qml/editor/configPanel/visualEffectPanel/VEP_InlineColorPicker.qml` — Sélecteur de couleur compact (anneau de teinte + carré SV, ou disque HSV + slider), champ hexadécimal éditable et pipette à l'écran (actuellement désactivée — cf. [bug pipette connu]).
- `qml/editor/configPanel/visualEffectPanel/VEP_Rotation.qml` — Section de configuration de la rotation d'un élément : slider d'angle (-180° à 180°) plus deux boutons de miroir horizontal/vertical.
- `qml/editor/configPanel/visualEffectPanel/VEP_Slider.qml` — Wrapper léger autour de `MeowSlider` fournissant l'API historique du panneau d'effets visuels (label, plage -1..1, bouton reset, signal `effectChanged`).
- `qml/editor/configPanel/visualEffectPanel/VisualEffectsPanel.qml` — Panneau conteneur assemblant les trois sous-sections (couleur, effets avancés, rotation) d'un élément décoratif, avec agrégation et synchronisation depuis les paramètres d'affichage de la map.

### qml/editor/configPanel/zoneConfigPanel/
- `qml/editor/configPanel/zoneConfigPanel/ZCP_DirectionsSection.qml` — Section de configuration de la direction et de la force de vélocité appliquée par une zone physique, via un picker vectoriel circulaire et un slider de force.
- `qml/editor/configPanel/zoneConfigPanel/ZCP_FrictionSection.qml` — Section isolée exposant un unique slider de friction lié directement au paramètre de zone physique ciblée.
- `qml/editor/configPanel/zoneConfigPanel/ZCP_GeneralSection.qml` — Section générale d'une zone physique : nom, mode exclusion, multiplicateurs de vitesse/accélération, friction, et sélection d'un effet visuel à déclencher à l'entrée de zone.
- `qml/editor/configPanel/zoneConfigPanel/ZCP_VectorDirectionPicker.qml` — Widget générique de saisie d'un vecteur 2D par clic/glisser dans un cercle, avec flèche indicatrice, normalisation par pas, et bouton reset.
- `qml/editor/configPanel/zoneConfigPanel/ZoneConfigurationPanelSection.qml` — Panneau conteneur regroupant les sections générale et directions d'une zone physique Pattounx, avec agrégation et synchronisation depuis les paramètres de zone de la map.

### qml/editor/moduleManager/
- `qml/editor/moduleManager/ModuleManager.qml` — Barre horizontale de vignettes listant les modules ouverts de l'éditeur (Case, Déco, Zone, Template, Joueur, etc.), gère la sélection/toggle d'un module actif et l'ouverture du popup d'ajout.
- `qml/editor/moduleManager/ModuleManager_AddButton.qml` — Bouton "+" minimaliste servant à déclencher l'ajout d'un nouveau module au ModuleManager.
- `qml/editor/moduleManager/ModuleManager_AddPopup.qml` — Popup modal listant les modules disponibles (icônes sélectionnables) et émettant la liste des ids choisis à la validation.

### qml/editor/moduleManager/assetSelectionPanel/
- `qml/editor/moduleManager/assetSelectionPanel/ASP_CategoryGrid.qml` — Grille des catégories d'assets/décorations (générées dynamiquement depuis AssetManager) avec filtre et recherche, émet la catégorie/type sélectionnés.
- `qml/editor/moduleManager/assetSelectionPanel/ASP_ClearButton.qml` — Bouton "Clear" qui réinitialise la sélection d'asset courante.
- `qml/editor/moduleManager/assetSelectionPanel/ASP_ContentArea.qml` — Zone de contenu principale du panneau assets, bascule entre la vue catégories (ASP_CategoryGrid) et la vue assets (ASP_Grid).
- `qml/editor/moduleManager/assetSelectionPanel/ASP_Grid.qml` — Grille des assets d'une catégorie/type donnés (chargés via AssetManager), avec filtre de recherche, états loading/vide et sélection.
- `qml/editor/moduleManager/assetSelectionPanel/ASP_Item.qml` — Vignette individuelle d'un asset (image preview, id/nom, favori, tooltip détaillé) avec état sélectionné/survolé.
- `qml/editor/moduleManager/assetSelectionPanel/ASP_TitleBar.qml` — Barre de titre du panneau assets (titre "Asset Library", sous-titre de sélection, onglets de catégories, bouton clear).
- `qml/editor/moduleManager/assetSelectionPanel/DecoPanel.qml` — Conteneur autonome du module "Déco" combinant ASP_TitleBar et ASP_ContentArea pour parcourir/sélectionner un asset de décoration à poser.

### qml/editor/moduleManager/assetSelectionPanel/playerConfigPanel/
- `PCP_AddProfileCard.qml` — Carte "+ Ajouter une classe" en fin de rangée de profils joueurs, déclenche l'ajout d'un nouveau `PlayerProfile`.
- `PCP_Content.qml` — Onglet "Joueurs" racine : affiche la rangée de profils (PCP_ProfileRow) et ouvre un popup modal (PCP_ProfileDetail) pour éditer/ajouter/dupliquer/réordonner/renommer un profil, avec broadcast via EditorOpBus.
- `PCP_ModelPicker.qml` — Sélecteur de modèle 3D du joueur (ComboBox + bouton de rafraîchissement de la liste AssetManager.availablePlayerModels).
- `PCP_PhysicsExpertSection.qml` — Section "Expert" avec 8 sliders exposant tous les paramètres physiques du profil (radius, mass, acceleration, maxSpeed, dampings, frictions, bounce) avec tooltips explicatifs.
- `PCP_PhysicsSimpleSection.qml` — Section "Simple" avec 3 sliders essentiels (Taille, Poids, Vitesse) pour une édition physique simplifiée du profil.
- `PCP_PickModeSelector.qml` — Sélecteur du mode de pioche du profil (Unique/Shared/Mandatory) avec SpinBox minOccurrences visible en mode Mandatory.
- `PCP_PresetButtons.qml` — Rangée de boutons appliquant des presets physiques prédéfinis (Standard, Léger, Lourd, Glissant, Adhérent) au profil.
- `PCP_Profile3DPreview.qml` — Mini-viewport 3D (View3D + caméra ortho) affichant le modèle du profil en rotation, avec support des primitives Cube/Sphere et des skins Color ID Map.
- `PCP_ProfileCard.qml` — Vignette compacte d'un profil joueur (preview 3D, nom éditable inline, badge pickMode, actions au survol : éditer/dupliquer/supprimer/déplacer).
- `PCP_ProfileDetail.qml` — Panneau d'édition complet d'un profil (identité, preview, modèle, skin, pickMode, presets, sliders simple/expert, bouton test 3D), avec mutation locale + broadcast op réseau.
- `PCP_ProfilePreviewPane.qml` — Cadre de preview 3D agrandi et interactif (drag souris pour piloter la rotation manuellement) réutilisé dans le détail de profil.
- `PCP_ProfileRow.qml` — Liste horizontale/verticale des PCP_ProfileCard + carte d'ajout, gère sélection/édition/suppression/duplication/réordonnancement/renommage des profils.
- `PCP_SkinPicker.qml` — Sélecteur de skin et de variante Color ID Map installés pour le modèle du profil, masqué pour les primitives ou modèles sans skin.
- `PCP_StyledButton.qml` — Wrapper stylé de MeowButton pour les boutons du panneau joueurs (variante accent ou secondaire, rendu plat).
- `PCP_StyledRadioButton.qml` — RadioButton stylé cohérent avec l'éditeur (indicateur circulaire, couleurs Theme).
- `PCP_StyledSpinBox.qml` — SpinBox stylé avec boutons +/− personnalisés et fond thémé.
- `PCP_StyledTabBar.qml` — TabBar stylé harmonisé avec le reste de l'éditeur.
- `PCP_StyledTabButton.qml` — TabButton stylé avec surlignage au survol et barre inférieure pour l'onglet actif.
- `PCP_StyledTextField.qml` — TextField stylé cohérent avec les autres panneaux de configuration.
- `PCP_TestController.qml` — Singleton QML servant de bus entre PCP_ProfileDetail (demande de test d'un profil en 3D) et Editor.qml (injection des paramètres dans le joueur principal), stocke un id plutôt qu'un pointeur pour survivre aux recréations de MapInfo.

### qml/editor/moduleManager/assetSelectionPanel/screenEffectPanel/
- `SEP_Content.qml` — Éditeur de la bibliothèque d'effets d'écran plein écran (MapInfo.screenEffects) : liste maître à gauche (ajout via presets, duplication, suppression), formulaire d'édition à droite (nom, type, couleur, sliders, fondus) avec aperçu live.
- `SEP_Slider.qml` — Slider étiqueté transactionnel (begin/movedValue/commit) délégant le rendu à MeowSlider, utilisé par SEP_Content pour éditer les paramètres numériques d'un effet.

### qml/editor/moduleManager/caseSelectionPanel/
- `CSP_ClearButton.qml` — Bouton "Clear" qui réinitialise la sélection de type de case courante.
- `CSP_ContentArea.qml` — Zone de contenu du panneau cases, héberge le CSP_CaseTypeSelector et relaie les signaux de sélection/effacement de type.
- `CSP_TitleBar.qml` — Barre de titre du panneau cases ("Case Library"), avec filtres (All/Property/Event) et bouton clear.
- `CasePanel.qml` — Conteneur autonome du module "Case" hébergeant CSP_ContentArea, écrit le type de case sélectionné dans EditorLogic.

### qml/editor/moduleManager/caseSelectionPanel/caseSelectionPanelMain/
- `CSP_CaseTypeCell.qml` — Cellule individuelle représentant un type de case (icône emoji, nom, couleur, indicateur de sélection) avec interactions hover/clic.
- `CSP_CaseTypeSelector.qml` — Grille des types de cases disponibles (modèle statique Départ/Propriétés/Chance/etc.) filtrable par catégorie, avec calcul automatique du nombre de colonnes.

### qml/editor/moduleManager/config3dPanel/
- `Config3DPanel.qml` — Panneau de réglage de la caméra 3D de l'éditeur (mode Follow/FreeCam/FixedTopDown/OrbitDebug, lissage, yaw/pitch/distance d'orbite) piloté via le CameraRig.

### qml/editor/moduleManager/editorBottomPanel/
- `EBP_BackButton.qml` — Bouton "retour" générique (icône ←) du panneau bas de l'éditeur.
- `EBP_Content.qml` — Conteneur générique à deux zones (contenu principal + panneau latéral optionnel dimensionné par ratio) utilisé comme base par plusieurs panneaux (CasePanel, DecoPanel, etc.).
- `EBP_FilterButton.qml` — Rangée de boutons de filtre à bascule (checkable) émettant l'index/texte cliqué.
- `EBP_SearchBar.qml` — Champ de recherche texte avec placeholder "Search assets..." et validation par Entrée.
- `EBP_TitleBar.qml` — Barre de titre générique combinant titre/sous-titre, filtres, barre de recherche et bouton retour, réutilisée par les title bars spécialisées (ASP/CSP).
- `EditorBottomPanel.qml` — Composant racine historique du panneau bas de l'éditeur (zone titre + zone contenu extensible/rétractable), avec effet de particules décoratif (feu d'artifice).

### qml/editor/moduleManager/playerPanel/
- `PlayerPanel.qml` — Conteneur bespoke du module "Joueur" qui héberge le panneau de configuration des profils joueurs (PCP_Content) avec un chrome minimal (simple wrapper actuellement).

### qml/editor/moduleManager/templatePanel/
- `TP_Content.qml` — Panneau de gestion des templates de map : sauvegarde de la sélection courante comme template nommé, liste des templates existants, suppression, et activation du mode placement de template (bascule le MouseLogic en EM_TEMPLATE).
- `TemplatePanel.qml` — Conteneur bespoke du module "Template" hébergeant TP_Content avec un chrome minimal (fond + bordure).

### qml/editor/moduleManager/zonePanel/
- `ZP_Content.qml` — Panneau complet d'édition des zones physiques (exclusion/effet) : type de zone, nom, palette de couleurs, paramètres physiques d'effet (vélocité, friction, multiplicateurs), sélecteur de direction vectorielle, et activation du mode dessin de polygone.
- `ZonePanel.qml` — Conteneur bespoke du module "Zone" hébergeant ZP_Content avec un chrome minimal (fond + bordure).

### qml/launcher/
- `qml/launcher/ActionsSection.qml` — Section boutons d'action du launcher (vérifier/télécharger/forcer/lancer le jeu).
- `qml/launcher/InlineColorPicker.qml` — Sélecteur de couleur HSL inline à 3 sliders (teinte/saturation/luminance) pour édition live.
- `qml/launcher/Launcher.qml` — Écran principal du launcher de ressources, assemble toutes les sections et bascule vers le configurateur de modèle 3D.
- `qml/launcher/LauncherHeader.qml` — En-tête du launcher (titre + bouton retour).
- `qml/launcher/LauncherLogic.qml` — Pont logique QML/C++ exposant l'état de `LauncherManager` (versions, téléchargement, paquets, modèles) et les settings serveur.
- `qml/launcher/LogsSection.qml` — Journal d'activité du launcher (log horodaté, effacement, reset d'état).
- `qml/launcher/Model3DPreview.qml` — Viewport 3D du configurateur de modèle (sujet + comparaison, caméra "jeu" ortho ou "face" turntable).
- `qml/launcher/ModelConfigurator.qml` — Configurateur plein écran d'un modèle 3D (transform scale/rotation/position, comparaison, onglet textures/skin, sauvegarde+upload en `.meow`).
- `qml/launcher/ModelsSection.qml` — Liste des modèles 3D disponibles (téléchargement, édition, suppression locale/serveur avec confirmation).
- `qml/launcher/PackagingSection.qml` — Section de création/upload de paquets de ressources ou de modèles au format `.meow`.
- `qml/launcher/ServerConfigSection.qml` — Configuration de l'URL serveur et du token d'upload, avec test de connexion animé.
- `qml/launcher/SkinEditorPanel.qml` — Créateur/éditeur de skin "Color ID Map" (zones, teintes, textures, variantes, bibliothèque de textures partagée).
- `qml/launcher/StyledButton.qml` — Wrapper de style sombre au-dessus de `MeowButton` pour les boutons du launcher (variantes primary/danger).
- `qml/launcher/StyledCheckBox.qml` — Case à cocher stylée thème sombre du launcher.
- `qml/launcher/StyledComboBox.qml` — ComboBox stylée thème sombre du launcher (popup et delegates custom).
- `qml/launcher/TintModeSelector.qml` — Sélecteur segmenté à 3 positions (Aplat/Multiply/Overlay) pour le mode de teinte Color ID Map.
- `qml/launcher/TrashIcon.qml` — Icône poubelle dessinée en Rectangles (sans Canvas ni emoji) pour les boutons de suppression.
- `qml/launcher/VersionInfoSection.qml` — Affichage des informations de version (actuelle/dernière) et barre de progression de téléchargement.

### qml/menu/
- `qml/menu/PawMainPad.qml` — Bouton principal rond en forme de patte (toggle ouverture du menu radial, pulsation animée).
- `qml/menu/PawMenu.qml` — Menu radial complet en forme de patte, positionne jusqu'à 4 `PawSubButton` autour du `PawMainPad` avec animations d'ouverture/fermeture.
- `qml/menu/PawSubButton.qml` — Bouton d'action secondaire ("doigt" de la patte) avec icône/texte de fallback, tooltip et animations hover/pressed.

### qml/meowComponent/ (racine)
- `qml/meowComponent/AdminCommandPanel.qml` — Panneau de console admin façon chat : exécute des expressions JS arbitraires via `eval()`, affiche l'historique commande/résultat dans une `ListView`, avec bouton "Tests" ouvrant `TestCommandWindow`.
- `qml/meowComponent/Background.qml` — Image de fond du plateau/éditeur, dimensionnée sur la grille (`MapInfo.backgroundTileSize`) avec mode de remplissage (Stretch/Fit/Tile) piloté par `mapInfo.backgroundScaling`.
- `qml/meowComponent/Base_Board.qml` — Racine visuelle du plateau (grille + fond + zone de souris globale) ; synchronise imperativement `mapInfo` avec `MapFileManager.currentMap` pour éviter un binding loop QML.
- `qml/meowComponent/Base_WheelHandler.qml` — Gestionnaire de molette de souris qui délègue le scroll/zoom du plateau à `logic.scrollLogic` (haut/bas/gauche/droite).
- `qml/meowComponent/Base_WorkArea.qml` — Conteneur racine de la zone de travail, expose un sous-`Item` `groupeSelection` servant de conteneur pour les éléments multi-sélectionnés.
- `qml/meowComponent/Base_logic.qml` — Item vide agrégeant trois références (`mouseLogic`, `scrollLogic`, `grid`) formant le point d'entrée logique partagé entre plateau et éditeur.
- `qml/meowComponent/GlobalMa.qml` — `MouseArea` globale qui capte tous les clics/drag/molette du plateau et les redirige vers les callbacks de `mouseLogic` (pressed/released/clicked/drag par bouton).
- `qml/meowComponent/SelectionRect.qml` — Rectangle de sélection au lasso (fond hachuré + bordure bleue dessinés en `Canvas`), avec fonctions pour définir sa géométrie depuis des coordonnées pixel ou grille.
- `qml/meowComponent/TemplateBoundingRect.qml` — Rectangle vert pulsant avec coins décoratifs, affichant la bounding box d'un ou plusieurs éléments sélectionnés en mode "template" (via un `Repeater`).
- `qml/meowComponent/TestCommandWindow.qml` — Fenêtre de debug flottante (draggable) avec boutons de test bas niveau réseau (STUN, UDP, envoi peer-to-peer) appelant `TestManager`.

### qml/meowComponent/case/
- `qml/meowComponent/case/CaseTile.qml` — Racine visuelle d'une case du plateau : héberge `TileContent`, une `MouseArea` ouvrant `TileDetailsPopup` au clic, et l'`OwnershipIndicator` si la case a un propriétaire.
- `qml/meowComponent/case/OwnershipIndicator.qml` — Ruban triangulaire dessiné en `Canvas` en coin bas-gauche d'une case, coloré selon le propriétaire, avec effet de brillance.
- `qml/meowComponent/case/PlayerTile.qml` — Carte récapitulative d'un joueur (avatar, nom, kibbles, nombre de propriétés, statut prison) avec couleur de texte contrastée calculée automatiquement.
- `qml/meowComponent/case/StarRating.qml` — Widget d'étoiles (★/☆) disposées en courbe parabolique pour afficher un niveau de qualité (ex. maison/hôtel sur une Rest Area).
- `qml/meowComponent/case/TileContent.qml` — Dispatcher qui charge dynamiquement (via `Loader`) le composant `content/*Content2` correspondant au `Case.type` de la case (variante "2" = celles basées sur `CaseContent_Base`).
- `qml/meowComponent/case/TileDetailsPopup.qml` — Popup modale d'informations détaillées sur une case, dispatchant vers le composant `details/*Details` correspondant au type de case.

### qml/meowComponent/case/content/
Contenu visuel de chaque type de case, en 2 variantes : la version "sans suffixe" est autonome (Item + Text/Image codés en dur) ; la version "2" est réécrite comme spécialisation de `CaseContent_Base` (cercle/icône/nom communs factorisés) et c'est celle utilisée par `TileContent`.
- `CardBoardBoxContent.qml` / `CardBoardBoxContent2.qml` — Contenu "Community Chest" (icône carton + nom + label "Draw Card").
- `CaseContent_Base.qml` — Composant de base commun (V2) : cercle double bordure semi-transparent, icône centrale avec fallback emoji, texte de nom en haut.
- `CatDeviceContent.qml` / `CatDeviceContent2.qml` — Contenu "Water Fountain / Laser" (icône laser + nom).
- `CatDoorContent.qml` / `CatDoorContent2.qml` — Contenu "Train Station" (icône porte + nom + label "Train Station").
- `CatNipContent.qml` / `CatNipContent2.qml` — Contenu "Chance" (icône herbe à chat + nom + label "Chance").
- `FreeNapContent.qml` / `FreeNapContent2.qml` — Contenu "Free Nap" (icône sommeil + nom).
- `JailContent.qml` / `JailContent2.qml` — Contenu "Prison" (icône cadenas + nom ; la V2 affiche une icône conditionnelle selon `catInJail`).
- `KibbleDispenserContent.qml` / `KibbleDispenserContent2.qml` — Contenu "Case Départ/distributeur de croquettes" (icône + nom + montant de récompense).
- `RestAreaContent.qml` / `RestAreaContent2.qml` — Contenu "propriété/zone de repos" (barre de couleur de famille, nom, étoiles de qualité via `StarRating`, icône, prix).
- `ToJailContent.qml` / `ToJailContent2.qml` — Contenu "Go to Jail" (icône flèche-cadenas + nom + label "Go to Jail").

### qml/meowComponent/case/details/
Texte explicatif affiché dans `TileDetailsPopup` selon le type de case.
- `CardBoardBoxDetails.qml` — Explication "Community Chest" (tirage de carte communautaire).
- `CatDeviceDetails.qml` — Explication "Water Fountain" (utilitaire, loyer basé sur le dé et le nombre d'utilities possédées).
- `CatDoorDetails.qml` — Explication "Train Station" (loyer basé sur le nombre de gares possédées par le propriétaire).
- `CatNipDetails.qml` — Explication "Chance" (tirage de carte chance).
- `FreeNapDetails.qml` — Explication "Free Nap" (case neutre, pas de récompense/pénalité).
- `JailDetails.qml` — Règles de la case Prison (durée 3 tours, moyens de sortie : doubles, amende, carte).
- `KibbleDispenserDetails.qml` — Affiche la récompense perçue au passage sur la case (départ/distributeur de croquettes).
- `RestAreaDetails.qml` — Détail complet d'une propriété (famille, propriétaire, qualité/étoiles, prix d'achat et grille des loyers).
- `ToJailDetails.qml` — Règles de la case "Go to Jail" (déplacement direct en prison, sans passer par la case départ).

### qml/meowComponent/grid/
- `GridCanvasLayer.qml` — Wrapper QML autour de `GridCanvasPainter` (C++, Qt 6.11+) : un seul canvas GPU viewport-cullé pour dessiner toute la grille, chargé conditionnellement par `GridManager` pour éviter l'échec d'import sur Qt 6.10.
- `GridManager.qml` — Gestionnaire central de la grille configurable de l'éditeur/plateau (taille, snap, zoom multiplicatif, mode resize) ; bascule entre rendu Canvas GPU global et rendu Repeater legacy (1202 `Rectangle`) selon `MEOW_GRID_RENDERER`.

### qml/meowComponent/preview/
- `AssetPreviewCursor.qml` — Curseur de prévisualisation suivant la souris pendant la pose d'un asset (décoration ou case), instancie un `SnapableDecoration`/`SnapableCaseTile` fantôme aligné sur la grille avec application live des effets visuels du panel.
- `LinkPreviewCursor.qml` — Ligne (Shape) reliant l'élément source à la position de la souris pendant la création d'un lien entre deux tuiles, colorée selon le type d'élément survolé (case/décoration), avec animation de pulsation.
- `PolygonPreviewCursor.qml` — Prévisualisation en temps réel du polygone en cours de dessin (zone d'exclusion) : trace les segments déjà posés + ligne pointillée vers la souris, points de contrôle et compteur de points.
- `TemplatePreviewCursor.qml` — Curseur de prévisualisation d'un template multi-éléments (groupe de cases/décorations/zones) suivant la souris, recréant chaque élément du template en semi-transparent positionné relativement au centre du template.

### qml/meowComponent/snapable/
- `ConnectionOverlay.qml` — Rendu visuel (Shape) d'un lien entre deux tuiles sous forme de ruban droit avec dégradé de couleur animé et points respirants le long de la ligne.
- `ConnectionOverlay2.qml` — Variante du rendu de lien : tracé en zigzag lissé par courbes de Bézier cubiques (au lieu d'une ligne droite), avec la même logique de dégradé/sélection.
- `ResizeHandle.qml` — Poignée de redimensionnement individuelle (une des 8 directions n/s/e/w/ne/nw/se/sw) gérant le drag, le snap grille et l'écriture de `EditDelta`/`Game.updateMap` en fin de resize.
- `SnapableCaseTile.qml` — Spécialisation de `SnapableElement` pour représenter une case du plateau posable/redimensionnable sur la grille (englobe `CaseTile`).
- `SnapableDecoration.qml` — Spécialisation de `SnapableElement` pour une décoration image (asset), avec image animée + `MultiEffect` optionnel (couleur, flou, ombre, miroir, rotation) créé seulement si des effets sont actifs.
- `SnapableElement.qml` — Classe de base de tout élément posable sur la grille : position/taille dérivées de `displayParameter`, gestion drag/sélection, animations création/suppression, contrôles de plan (z-layer), poignées de resize, connexions vers éléments suivants/précédents, et surlignage des sélections distantes en mode collab.
- `SnapableElementConnections.qml` — Gestionnaire des liens (previous/next) d'un `SnapableElement` : maintient les listes bidirectionnelles, génère le modèle de segments pour l'affichage des `ConnectionOverlay`, et synchronise les cases liées côté C++.
- `SnapableElementControl.qml` — Petit panneau de contrôle flottant à droite d'un élément sélectionné, affichant le sélecteur de plan (z-layer) et poussant l'op `SetDisplayParameter` via `EditorOpBus`.
- `SnapableElementCreateAnimation.qml` — Animation d'apparition (scale 0→1) jouée à la création d'un `SnapableElement`.
- `SnapableElementDeleteAnimation.qml` — Animation de disparition (scale vers 0.1) jouée avant suppression effective d'un `SnapableElement`.
- `SnapableElementResizeHandles.qml` — Assemble les 8 `ResizeHandle` (coins + milieux de côtés) positionnés autour d'un `SnapableElement` sélectionné et redimensionnable.
- `SnapableExclusionZone.qml` — Zone physique polygonale d'exclusion/effet, éditable par points de contrôle draggables ; délègue le rendu (fill/contour/hachures) soit au `ZonesOverlayPainter` global (défaut), soit à un `ZoneCanvasPainter` local via `Loader` (fallback/preview), avec hit-testing par ray casting.

### qml/multiplayer/
- `qml/multiplayer/MultiplayerLobby.qml` — Conteneur racine du lobby multijoueur, gère le `ChatClient` mutualisé, la navigation interne (StackView) et le décodage du mode éditeur collaboratif via prefix `[EDIT:<hostId>]`.
- `qml/multiplayer/PlayerCard.qml` — Carte d'affichage d'un joueur (avatar, pseudo, badge hôte) utilisée en delegate dans une liste de joueurs.
- `qml/multiplayer/SessionCard.qml` — Carte cliquable représentant une session de jeu/éditeur dans la liste, avec bordure colorée selon disponibilité et décoration spécifique aux sessions éditeur.
- `qml/multiplayer/SessionCreation.qml` — Écran de création de session (nom, mot de passe, mode Édition/Jeu, choix de carte de départ neuve ou existante avec option copie).
- `qml/multiplayer/SessionDetails.qml` — Vue détaillée d'une session sélectionnée (infos, liste de joueurs factices, boutons rejoindre/retour).
- `qml/multiplayer/SessionList.qml` — Vue listant les sessions disponibles côté serveur chat, avec boutons de création et de connexion directe.

### qml/multiplayer/components/
- `qml/multiplayer/components/BackButton.qml` — Bouton rond réutilisable "flèche retour" utilisé dans le lobby et les détails de session.
- `qml/multiplayer/components/DirectConnexionPopup.qml` — Popup de connexion directe par IP/port STUN à un hôte (formulaire simple, non branché au state machine réel).
- `qml/multiplayer/components/StatusIndicator.qml` — Indicateur réutilisable d'état de connexion (en ligne/hors ligne) avec ping affiché.

### qml/test/CatwayTest/
Harnais de test dev pour le réseau P2P "Catway" et les systèmes qui s'appuient dessus.
- `BoardEventsCard.qml` — Carte de test envoyant/loggant des événements réseau "reliable" typés GameSession (GameStart, DiceRoll, MapSync…) via un ComboBox + champ JSON.
- `CatwayTest.qml` — Scène racine à onglets (Catway, UDP Tests, Game Network, Editor Network, Physics, Painter) assemblant tous les panneaux de test du harnais réseau Catway.
- `ChatClientCard.qml` — Carte de test du client chat WebSocket : connexion serveur, création/jointure de session, liste des participants cliquables.
- `CreatePlayerForm.qml` — Formulaire de création/édition d'un `PlayerNetwork` de test (id, nickname, socket, IP/port destination) avec envoi de demande de connexion P2P.
- `DrawGrid.qml` — Grille de dessin pixelisée (16×64) synchronisée en UDP entre deux joueurs, servant de mini-jeu de test du transport réseau.
- `EditorNetworkTestTab.qml` — Onglet assemblant panneau joueurs P2P, panneau de session éditeur et log d'ops pour tester `EditorSession` manuellement.
- `EditorOpsCard.qml` — Carte affichant en direct le log des ops `EditorOpBus` (locales soumises et distantes reçues) avec libellés lisibles par type.
- `EditorSessionPanel.qml` — Panneau de contrôle d'une `EditorSession` de test (démarrer en hôte/client, arrêter, afficher l'état actif/rôle).
- `GameNetworkTestTab.qml` — Onglet assemblant joueurs P2P, session de jeu, mini-jeu UDP brut et cartes reliable events/mapSync pour tester `GameSession`.
- `GameSessionPanel.qml` — Panneau de contrôle d'une `GameSession` de test (démarrer en hôte/client, arrêter, afficher l'état actif/rôle).
- `LocalPortsCard.qml` — Carte listant les ports UDP locaux ouverts par Catway, sélectionnables pour les tests.
- `MapSyncCard.qml` — Carte de test envoyant/affichant des synchronisations de map (JSON) via le canal reliable de `GameSession`.
- `MinigameSyncPanel.qml` — Panneau de test d'un mini-jeu de positionnement en temps réel (points colorés qui se déplacent) synchronisé via `MinigameSync` en UDP.
- `PhysicsTestTab.qml` — Panneau de test complet du moteur physique Pattounx v2 : création d'acteur/murs/zones, contrôle clavier, visualisation 2D top-down en Canvas, traçage de jitter.
- `PlayersListCard.qml` — Carte listant les joueurs Catway connus avec possibilité de sélection et de suppression.
- `StunCard.qml` — Carte minimaliste avec un bouton pour ouvrir un nouveau port via le serveur STUN.
- `UdpChatTile.qml` — Tuile de chat texte simple envoyé/reçu en UDP brut vers un joueur ciblé.
- `UdpDrawTile.qml` — Tuile combinant `DrawGrid` et une palette de couleurs pour tester le dessin synchronisé UDP/reliable.
- `UdpPlayersPanel.qml` — Panneau réutilisable listant les joueurs Catway avec détails du joueur sélectionné et actions (hole punch, etc.).
- `UdpTestTab.qml` — Onglet assemblant `UdpPlayersPanel`, `UdpChatTile` et `UdpDrawTile` pour tester les échanges UDP bruts.
- `ZoneCanvasPainterTest.qml` — Harnais isolé pour tester le rendu GPU `ZoneCanvasPainter` (polygone avec fill, contour et hachures via CanvasPainter Qt 6.11).

### qml/test/ (racine)
- `TEST_3D.qml` — Scène de test 3D avec caméra orthographique et sliders pour ajuster position/rotation de la caméra en direct.
- `TEST_ASSET_MANAGER.qml` — Écran de test du singleton `AssetManager` : scan des assets disponibles et génération de leurs fichiers metadata.json.
- `TEST_PARTICLE_BUTTON.qml` — Galerie de démonstration du composant `ParticleButton` avec plusieurs configurations de couleurs/tailles de particules.
- `TEST_PARTICLE_BUTTON_SIMPLE.qml` — Exemple minimal d'intégration de `ParticleButton` pour prise en main rapide.
- `TEST_PAW_MENU.qml` — Scène de test du composant `PawMenu` (menu radial) avec actions configurables et log d'événements.
- `TEST_RANGE_SLIDER.qml` — Test d'un `RangeSlider` stylé pour filtrer une plage de "plans" (min/max) avec simulation de visibilité d'éléments par plan.
- `TEST_VIEW_0.qml` — Dialogue de test manuel du type C++ `Player` (nom, couleur, kibble, position, prison, compteurs de propriétés).
- `TEST_VIEW_1.qml` — Dialogue de test manuel du type C++ `CaseRestArea` (nom, position, famille, qualité, propriétaire, simulation d'atterrissage).
- `Test_Comp.qml` — Scène quasi vide, vestige d'un test d'effet visuel (`MultiEffect`) sur des images animées, actuellement entièrement commenté.

### qml/theme/
- `qml/theme/Theme.qml` — Singleton QML centralisant tout le style UI (échelle globale `uiScale`, typographie, espacements, rayons, couleurs sémantiques de surface/texte/accent, helpers `hover`/`pressed`/`px`).

### qml/titleScreen/
- `qml/titleScreen/TitleScreen.qml` — Écran titre de l'application, menu principal (lobby multijoueur, éditeur, launcher, tests) et barre compte (pseudo + accès aux paramètres).

### qml/ui_item/
Kit de composants UI génériques réutilisables (préfixe `Meow`).
- `BtSideMenu.qml` — Bouton HUD circulaire réutilisable (icône emoji + fond coloré) utilisé dans les menus latéraux du jeu/éditeur.
- `CollapsableGroupBox.qml` — `GroupBox` repliable au clic sur son titre, masquant son contenu (`ColumnLayout`) quand replié.
- `InteractiveUiElement.qml` — Item de base permettant de déplacer et redimensionner son contenu via appui long puis drag, avec overlay visuel de mode édition et poignées de resize.
- `LayerVisualizer.qml` — Badge compact draggable verticalement affichant/sélectionnant un numéro de calque (zLayer) avec code couleur et jauge de position dans la pile.
- `MeowButton.qml` — Bouton générique stylé de l'application (variantes primary/secondary/danger/…, icône, loading, effet de brillance et de scale) servant de base à `ParticleButton`.
- `MeowCheckBox.qml` — Case à cocher stylée canonique des panneaux de l'éditeur (indicateur carré avec coche, couleur d'accent surchargeable).
- `MeowComboBox.qml` — Liste déroulante stylée canonique des panneaux de l'éditeur (fond, popup et delegate uniformisés).
- `MeowInfoBox.qml` — Encadré d'information ou note textuelle discrète, avec variantes colorées (info/warning/tip) ou mode simple texte italique.
- `MeowPropertyRow.qml` — Ligne "label + contrôle" alignée pour les panneaux en `ColumnLayout` plats.
- `MeowSlider.qml` — Slider étiqueté canonique avec affichage de valeur en encadré/texte, mode live ou transactionnel (undo), bouton reset optionnel.
- `MeowSpinBox.qml` — Spin box numérique entière avec boutons ± auto-répétitifs, champ éditable, formatage des milliers et suffixe d'unité.
- `MeowSwatchButton.qml` — Petit bouton-pastille coloré carré utilisé dans les pickers/presets de couleur.
- `MeowSwitch.qml` — Interrupteur (switch) stylé canonique avec piste et pastille animée.
- `MeowTextField.qml` — Champ texte stylé canonique sans label, réutilisable dans n'importe quel layout des panneaux de l'éditeur.
- `ParticleButton.qml` — Extension de `MeowButton` ajoutant un jet de particules (émetteur `ParticleSystem`) en arc au clic.
- `Player_Profil_Icon.qml` — Icône de profil joueur circulaire avec cadre blanc et effet d'estompage (fade) sur les bords, alimentée par un `DecorationParameter`.
- `SizeSelector.qml` — Champ composite label "W:" + `SpinBox` pour sélectionner une taille/largeur numérique dans un cadre stylé.

### qml/world3d/
- `qml/world3d/CameraRig.qml` — Rig de caméra 3D instanciable à 4 modes (Follow avec lerp et sync grille 2D, FreeCam, FixedTopDown, OrbitDebug) piloté par `setMode`/`moveManual`/`orbitDelta`.
- `qml/world3d/EditorPhysicsBridge.qml` — Pont réactif entre les événements de tuiles de l'éditeur (`ItemSnapableEvents`) et le moteur physique Pattounx, qui upsert/retire les zones de collision avec debounce ~30 Hz.
- `qml/world3d/InputController.qml` — Traduit les événements clavier (keymap configurable ZQSD/flèches) en vecteur d'input normalisé poussé vers le `PhysicsWorld` (direct ou via `PhysicsSession` en réseau).
- `qml/world3d/KuraMaterial.qml` — `CustomMaterial` QtQuick3D partagé implémentant le shader de re-teinte/texturage par zone du système Color ID Map (20 zones, 8 slots de texture).
- `qml/world3d/KuraModel.qml` — Présentateur 3D chargeant un `.glb` via `RuntimeLoader` et appliquant le `KuraMaterial` avec la config de skin/variante et teinte d'équipe à tous les sous-modèles.
- `qml/world3d/LocalPlayerSpawner.qml` — Crée/retire le body physique Kinematic du joueur local dans le `PhysicsWorld` dès que le moteur démarre.
- `qml/world3d/PhysicsActor.qml` — Présentateur 3D générique qui lit `bodyState(bodyId)` à chaque frame et applique position/orientation lissées au node 3D, avec helpers cosmétiques `jump()`/`wave()` et un mode de trace de debug du jitter.
- `qml/world3d/ScreenEffectController.qml` — Logique non visuelle qui écoute l'entrée/sortie de zones physiques et résout/anime (fondu) l'effet d'écran actif via une pile LIFO de zones chevauchantes.
- `qml/world3d/ScreenEffectOverlay.qml` — Calque 2D plein écran (teinte, vignette radiale, pulsation) qui rend l'effet actif fourni par `ScreenEffectController`.
- `qml/world3d/SkinnedModel.qml` — Résout un `modelName`+`colorVariant` de `PlayerProfile` (skin, variante, zones d'équipe) et alimente un `KuraModel`, avec fallback sur les primitives Cube/Sphere.
- `qml/world3d/World3D.qml` — Scène 3D racine (View3D + caméra ortho + lumière) exposant les conversions grille↔monde, le registry des `PhysicsActor` et leur tick d'interpolation par frame.

---

## Tests (`Meownopoly/tests/`)
- `Meownopoly/tests/CMakeLists.txt` — Build des tests C++ (Qt6::Test) : moteur physique, cycle de vie map, benchmarks de rendu grille/zones ; cibles `EXCLUDE_FROM_ALL` à builder à la demande.
- `Meownopoly/tests/combined_render_scene.qml` — Scène QML de test combinant grille + zones d'exclusion, pilotée par `tst_combined_render_perf` pour mesurer le coût combiné réaliste.
- `Meownopoly/tests/grid_render_scene.qml` — Scène QML isolée comparant Repeater legacy vs GridCanvasPainter, pilotée par `tst_grid_render_perf`.
- `Meownopoly/tests/map_lifecycle/CMakeLists.txt` — Build du test `tst_mapinfo` (utilisable en standalone ou intégré au projet parent).
- `Meownopoly/tests/map_lifecycle/tst_mapinfo.cpp` — Tests unitaires Qt Test de `MapInfo`/`PlayerProfile` (constructeurs, JSON round-trip, setters, versioning du roster joueurs).
- `Meownopoly/tests/test_map.json` — Fixture JSON d'une map réelle (~22 zones) utilisée par les benchmarks de rendu combiné.
- `Meownopoly/tests/tst_collision2d.cpp` — Tests unitaires des primitives de collision 2D (polygones, sweep cercle/cercle).
- `Meownopoly/tests/tst_combined_render_perf.cpp` — Benchmark mesurant le coût combiné grille + zones d'exclusion sur une map JSON réelle (manuel, non-CI).
- `Meownopoly/tests/tst_grid_render_perf.cpp` — Benchmark comparant Repeater vs GridCanvasPainter sur plusieurs scénarios (idle, zoom, pan, resize).
- `Meownopoly/tests/tst_pattounx_engine.cpp` — Tests unitaires du moteur physique Pattounx v2 (smoke tests, collisions corps-corps, sleep system).
- `Meownopoly/tests/tst_physics_worker.cpp` — Tests du thread physique dédié (`PhysicsWorker`/`PhysicsWorld`) : cycle de vie start/stop, buffer.
- `Meownopoly/tests/tst_snapshot_codec.cpp` — Tests round-trip de l'encodage/décodage des snapshots physiques réseau (host/client via 2 instances `PhysicsWorld`).
- `Meownopoly/tests/zone_render_scene.qml` — Scène QML isolée instanciant N `ZoneCanvasPainter`, pilotée par `tst_zone_render_perf` pour mesurer leur coût de rendu.

---

## Configuration du build (`Meownopoly/`)
- `Meownopoly/CMakeLists.txt` — Build principal CMake de l'application (Qt6 Ninja Multi-Config), collecte des sources, composants Qt requis, tests optionnels.
- `Meownopoly/Meownopoly.pro` — Fichier de projet qmake legacy (vestige, remplacé par CMake) listant sources/headers/ressources historiques.
- `Meownopoly/asset.qrc` — Ressources Qt regroupant les assets par défaut (ex. image placeholder `nopic.webp`).
- `Meownopoly/base_comp.qrc` — Ressources Qt des composants QML de base du plateau (contenus de cases : CardBoardBox, CatDevice, CatDoor, etc.).
- `Meownopoly/chat.qrc` — Ressources Qt du système de chat QML (drawer, header, messages, participants, fichiers texte).
- `Meownopoly/launcher.qrc` — Ressources Qt du launcher (config serveur, packaging, modèles 3D, éditeur de skins).
- `Meownopoly/other.qrc` — Ressources Qt diverses/test (scènes de test, menu PawMenu, harness CatwayTest).
- `Meownopoly/qml.qrc` — Ressources Qt principales de l'UI (theme, main.qml, écran titre, compte, éditeur et sa logique).

---

## Serveur de chat (`chatServer/`)
- `chatServer/.deployEnv` — Credentials/config de déploiement SSH (host, user, mot de passe, nom du service systemd) pour `deploy.sh`, gitignoré en théorie.
- `chatServer/.env` — Variables d'environnement runtime du serveur (port, STUN port, tailles max payload/DB, TTL, debug, dashboard activé).
- `chatServer/CLAUDE.md` — Doc d'architecture détaillée du chatServer (protocole WS, schéma SQLite, sécurité, invariants, gotchas) pour Claude Code.
- `chatServer/DASHBOARD_V3_CRYPTO.md` — Note de version décrivant l'ajout du chiffrement E2EE (mot de passe, dérivation de clé, chiffrement/déchiffrement) dans le dashboard web.
- `chatServer/IMAGE_SUPPORT.md` — Note de version décrivant la détection et l'affichage des images (data URI base64) dans le dashboard de chat.
- `chatServer/README.md` — Documentation principale du serveur de chat : architecture blind-relay, protocole WebSocket, installation, variables d'env.
- `chatServer/TEXT_FILES_FEATURE.md` — Note de version décrivant le format d'envoi de fichiers texte (`📄FILE:ext:nom`) dans le chat, côté C++/QML/dashboard.
- `chatServer/chat_crypto.js` — Miroir JS du système crypto E2EE du client C++ (dérivation de clé, nonces, chiffrement/déchiffrement), utilisé par le dashboard/labo, jamais côté serveur.
- `chatServer/cleanup.js` — Tâche périodique de purge des données anciennes (TTL configurable) appelant `database.cleanupOldData`.
- `chatServer/dashboard.css` — Feuille de style du dashboard web de monitoring/admin (thème sombre).
- `chatServer/dashboard.html` — Page HTML du dashboard admin (stats, liste des sessions, actions de modération).
- `chatServer/dashboard.js` — Logique client du dashboard : polling REST `/api/*`, gestion du token admin, rendu des sessions/logs.
- `chatServer/database.js` — Couche d'accès SQLite (better-sqlite3) : schéma, migrations additives, requêtes sessions/messages/participants.
- `chatServer/deploy.sh` — Script de déploiement SSH/SCP du chat server (copie fichiers, npm install, restart systemd) basé sur `.deployEnv`.
- `chatServer/labo.html` — Playground crypto + mini client de chat E2EE (React/Tailwind en CDN) pour tester le protocole.
- `chatServer/server.js` — Point d'entrée du serveur : HTTP + WebSocket + routage des commandes du protocole chat, validations et sécurité.
- `chatServer/setup-domain.sh` — Script bootstrap nginx + Let's Encrypt + systemd pour exposer le chat server sur un domaine.
- `chatServer/simple_stun.js` — Mini serveur STUN (RFC 5389) UDP répondant MAPPED-ADDRESS/XOR-MAPPED-ADDRESS pour le hole-punching Catway.
- `chatServer/test_clear.js` — Script de test manuel vérifiant le flux `CLEAR_HISTORY` (envoi message, clear, vérification historique vide).
- `chatServer/test_client.js` — Script de test manuel du flux complet JOIN/PUBLISH_KEY/SEND_MSG avec un gros payload.
- `chatServer/test_dashboard.sh` — Script curl testant rapidement l'endpoint `/api/stats` du dashboard.
- `chatServer/test_get_session_list.js` — Script de test manuel vérifiant la commande `GET_SESSION_LIST` contre le serveur distant.
- `chatServer/test_participants.js` — Script de test manuel vérifiant `GET_PARTICIPANTS` et la détection correcte de l'hôte.

---

## Serveur d'assets (`asset_server/`)
- `asset_server/.deployEnv` — Credentials/config de déploiement SSH (host, user, service) pour `deploy.sh` de l'asset server.
- `asset_server/.env.example` — Modèle de configuration (token d'upload, mode NODE_ENV) à copier en `.env`.
- `asset_server/README.md` — Documentation d'installation/usage du serveur de distribution d'assets (endpoints API, dossiers).
- `asset_server/deploy.sh` — Script de déploiement SSH/SCP de l'asset server (copie fichiers, npm install, restart systemd).
- `asset_server/server.js` — Serveur Express HTTP de distribution d'assets `.meow` : upload (multer), versioning, CORS, rate-limit.
- `asset_server/setup-domain.sh` — Script bootstrap nginx + Let's Encrypt pour exposer l'asset server sur un domaine.
- `asset_server/start_server.bat` — Script Windows lançant le serveur (vérifie Node.js, installe les dépendances si besoin, `npm start`).
- `asset_server/start_server.sh` — Équivalent Linux/bash de `start_server.bat` pour lancer le serveur d'assets.

---

## Outils images (`image_tools/`)
- `image_tools/CHANGELOG_BiRefNet.md` — Changelog décrivant l'intégration de BiRefNet/BiRefNet_lite (modèles IA de suppression de fond) avec comparatif perf/qualité.
- `image_tools/README_suppression_fond.md` — Documentation d'usage du script `supprimer_fond.py` (suppression de fond IA sur séquences PNG).
- `image_tools/convertir_en_webp.py` — Script CLI convertissant une image en WebP avec qualité configurable.
- `image_tools/creer_animation_webp.py` — Script générant des animations WebP à partir de séquences d'images WebP (fps, qualité, boucle).
- `image_tools/extraire_frames.py` — Script extrayant les frames de fichiers MP4 en séquences d'images PNG (multi-threadé).
- `image_tools/installer_dependances.py` — Script installant les dépendances Python (`requirements.txt`) nécessaires à `supprimer_fond.py`.
- `image_tools/installer_pytorch_cuda.py` — Script désinstallant PyTorch CPU et réinstallant la variante CUDA pour accélérer l'IA sur GPU.
- `image_tools/pipeline_mp4_vers_animation.py` — Script d'orchestration enchaînant extraction de frames → suppression de fond → conversion WebP → animation.
- `image_tools/renommer_images.py` — Script renommant en série les PNG du dossier courant selon un format `nom-numéro.png`.
- `image_tools/requirements.txt` — Liste des dépendances Python (PyTorch CUDA, OpenCV, transformers, etc.) pour les outils IA de traitement d'image.
- `image_tools/supprimer_fond.py` — Script principal de suppression de fond par IA (BiRefNet) sur séquences d'images, avec fallback OpenCV.
- `image_tools/tagger_images.py` — Script générant tags de style/descriptifs + description pour des images via l'appel au CLI Claude (modèle Sonnet).
- `image_tools/tags_images.json` — Données générées : tags et descriptions par image (résultat de `tagger_images.py`), pas du code.
- `image_tools/test_birefnet.py` — Script de test standalone vérifiant le fonctionnement de BiRefNet sur une image unique.
- `image_tools/test_birefnet_lite.py` — Script comparant les performances BiRefNet vs BiRefNet_lite.
- `image_tools/video_background_remover.py` — Variante/ancienne version du retrait de fond vidéo (RMBG-2.0/BiRefNet) avec chemins hardcodés spécifiques à un poste dev.

---

## Racine du dépôt
- `.mcp.json` — Configuration des serveurs MCP du repo : `meownopoly-automation` (pilotage automation stdio local) et `meowtrack` (suivi de tâches via HTTP distant).
- `CLAUDE.md` — Instructions globales du projet pour Claude Code (architecture, build, conventions QML, gotchas).
- `changelog.md` — Changelog "fun" du projet résumant l'historique Git (commits, branches, contributeurs) mois par mois.
- `.deployEnv` — Credentials/config de déploiement générique à la racine (mêmes infos que `chatServer/.deployEnv`, probablement dupliqué/legacy).
- `.gitattributes` — Force les scripts shell (`*.sh`) en fins de ligne LF pour éviter qu'un checkout CRLF sous Windows ne les casse.
- `.gitignore` — Exclusions Git globales (dossiers build, caches Python, assets générés par image_tools, node_modules, fichiers `.autosave`/`.user`).
- `test_dual.bat` — Script Windows lançant deux instances de Meownopoly.exe (profils QSettings/DB séparés via `--instance 2`) pour tester le P2P en local.
