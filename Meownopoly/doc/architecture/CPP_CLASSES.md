# Meownopoly — Classes C++
**[S]** Singleton · **[QML]** Exposé en QML · **[~QML]** Partiel

---

## Racine
| Classe | S | QML | Description |
|--------|---|-----|-------------|
| `QmlApp` | — | ✓ | Moteur QML racine. Bootstrape l'engine, instancie `Game`, `FolderCompressor`, `AssetManager`, enregistre tous les types C++. |

---

## `tools/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `EditorEnum` | ✓ | ✓ | Enum `EditorMouseMode` (Normal, Pose, SelectionLink, Template, Game, DrawPolygon). | `EditorController`, `Editor`, `MouseLogic_*` |
| `Logger` | ✓ | ✓ | Niveaux INFO/DEBUG/WARN/ERROR/SUCCESS, sortie console colorisée. | omniprésent |
| `UiStyle` | ✓ | ✓ | Constantes Z-order globales (CONFIG_PANEL, HUD, CHAT_DRAWER, WORKAREA…). | `main`, `Editor`, `ChatDrawer` |
| `AppInfo` | ✓ | ✓ | Métadonnées de l'app : nom, version name, version number. | `TitleScreen`, `main` |
| `CursorManager` | ✓ | ✓ | Déplace le curseur OS en coordonnées absolues (`setPos`, `setPosPoint`). | `Editor_WheelHandler`, `Trackers` |
| `TestManager` | ✓ | ✓ | Actions de test dev/debug (testAction1–4, UDP, STUN). | `CatwayTest`, panneaux test |
| `MouseEventFilter` | ✓ | — | Filtre global `eventFilter` pour sensibilité/inversion souris. Installé sur `QApplication`. | — |
| `MetadataGenerator` | — | — | Utilitaire pur statique. Scanne dossiers images → génère `metadata.json` pour `AssetManager`. | — |
| `FolderCompressor` | — | ✓ | Compresse/décompresse arborescences en fichier binaire. Enum `FolderCompressorDeleteOptions`. | `LauncherLogic` |
| `debug_info.h` | — | — | Header-only. Macros ANSI (`DBG_CLR_RED`, `QDBG_FUNCNAME_GREEN`…). Aucune classe. | — |

---

## `chat/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `ChatClient` | — | ✓ | Client WebSocket complet : session, E2E AES-256-GCM, images, participants, slash commands, commandes jeu. Une instance par session. Enum interne `ErrorSession`. Contient : `ChatWorker`, `ChatDatabase`, `ChatCrypto`, `ChatImageProvider`, `ChatCommandHelper`. | `ChatHeader`, `ChatDrawer`, `ChatInputBar`, `ChatParticipantsPanel`, `ChatHeaderSelection`, `ChatClientCard`, `SessionList`, `MultiplayerLobby`, `SessionCreation` |
| `ChatSessionManager` | ✓ | ✓ | Centralise toutes les sessions actives. `serverQueryClient` dédié LIST_SESSIONS, liste `ChatClient` rejoints, timer refresh 10 s, délègue session active à `Catway`. Contient : `m_serverQueryClient`, `QList<ChatClient*>`. | `ChatHeaderSelection`, `ChatHeader`, `SessionList`, `MultiplayerLobby` |
| `ChatSlashCommands` | ✓ | ✓ | Registre des slash commands (`/ping`, `/stun`, `/create`). `commandFromText()` pour matcher la saisie. | `ChatInputBar` |
| `ChatWorker` | — | — | Worker thread dédié — possède `QWebSocket`. Connexion, envoi, réception → signaux vers `ChatClient`. Interne à `ChatClient`. | — |
| `ChatDatabase` | — | — | SQLite local (historique messages chiffrés + clés de session). Une instance par `ChatClient`. | — |
| `ChatImageProvider` | — | ✓ | Image provider `image://chat_images/…`. Cache thread-safe des images reçues. Enregistré par `ChatClient::registerQml()`. | — |
| `ChatCrypto` | — | — | Statiques AES-256-GCM, PBKDF2 (`deriveLockKey`, `derivePasswordProof`), génération nonce/clé. | — |
| `ChatCommandHelper` | — | — | Statiques : formate/parse enveloppes JSON commandes (type + payload). Interne à `ChatClient`. | — |

---

## `communication/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `Catway` | ✓ | ✓ | Hub P2P singleton. STUN, hole punching, pool `UdpSocketInfo`, liste `PlayerNetwork`, UDP fiable (lib `reliable`), heartbeats, délégation `ChatClient`. Contient : `CatwayWorker`, `struct PendingCommand`. | `CatwayTest`, `StunCard`, `LocalPortsCard`, `PlayersListCard`, `UdpChatTile`, `UdpDrawTile`, `Editor`, `multiplayer/*` |
| `CatwayWorker` | — | — | Worker thread réseau — possède `StunManager`, I/O UDP brut, timers `reliable`. Interne à `Catway`. | — |
| `StunManager` | — | — | Client STUN : serveur UDP local, binding requests → IP/port externe. Émet `externalAddressReceived`. Appartient à `CatwayWorker`. | — |
| `PlayerNetwork` | — | ✓ | Endpoint distant : ID, nickname, IP/port, `UdpSocketInfo`, état P2P, `reliable_endpoint_t`. | `PlayersListCard`, `CreatePlayerForm`, `UdpPlayersPanel` |
| `UdpSocketInfo` | — | ✓ | Conteneur `QUdpSocket` + adresse/port public post-STUN. Pool géré par `Catway`. | `LocalPortsCard` |

---

## `account/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `AccountManager` | ✓ | ✓ | Compte local : UUID persisté, pseudo, paramètres STUN. Module `Meownopoly.Account 1.0`. | `AccountSetupPage`, `AccountSettingsPopup`, `main`, `TitleScreen`, `ChatDrawer`, `MultiplayerLobby`, `ChatClientCard`, `GameSessionPanel`, `GameNetworkTestTab` |

---

## `game/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `Game` | ✓ | ✓ | Contrôleur central. Plateau (`Case*`), joueurs, cartes, save/load maps & templates, `ItemSnapable`, undo/redo. Enum `GAME_CONDITION`. Dépend de : `Case`, `Player`, `Card`, `ItemSnapable`, `MapInfo`, `Map`, `UndoRedoManager`. | `Editor`, `EditorLogic`, `EditorController`, `TileLogic`, `Base_Board`, `GameBoard`, `GameScene`, `TEST_BOARD` |
| `Player` | — | ✓ | Joueur : nom, couleur, logo, kibbles, position, prison, propriétés possédées. | `PlayerTile`, `Player_Profil_Icon`, `CreatePlayerForm`, `GameBoard` |
| `Card` | — | ✓ | Stub carte chance/communauté. Corps vide — extension future. | — |
| `MeowStyle` | ✓ | ✓ | Couleurs de famille (Brown→DarkBlue), noms de types de case mappés à `CaseType`. | `CaseTile`, `CCP_RestAreaFamilyConfig`, `CCPS_TypeSection` |

---

## `game/case/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `Case` | — | ✓ | Base de toutes les cases. Enum `CaseType` (12 énumérateurs dont sentinelles `CS_Unknow`/`CS_Count` ; 10 types concrets, mais `CS_Taxe` non implémenté → fallback `CaseKibbleDispenser`, soit 9 classes `Case` dédiées). Méthodes virtuelles `onLand/onLeave/onHover/toJSON`. | `CaseTile`, `TileContent`, `CaseConfigurationPanel` |
| `CaseCatPerks` ← `Case` | — | ✓ | Intermédiaire achetable. Prix, prix vente, hypothèque, propriétaire `Player*`. Parent de RestArea, CatDoor, CatDevice. | — |
| `CaseRestArea` ← `CaseCatPerks` | — | ✓ | Rue Monopoly. `RestQuality` (1–4★ + hôtel), famille couleur, prix maisons/hôtel, loyers. | `CCPS_RestAreaSection`, `CCP_RestAreaSpecificConfig`, `CCP_RestAreaFamilyConfig`, `RestAreaContent` |
| `CaseCatDoor` ← `CaseCatPerks` | — | ✓ | Gare. `indexCatDoor` (1–4), `travelPrice`. | `CatDoorDetails`, `CatDoorContent` |
| `CaseCatDevice` ← `CaseCatPerks` | — | ✓ | Compagnie utilitaire. Taxe appliquée au joueur atterrissant. | `CCP_CatDeviceSpecificConfig`, `CatDeviceContent` |
| `CaseKibbleDispenser` ← `Case` | — | ✓ | Case départ. Récompense kibbles (défaut 200) au passage/atterrissage. | `KibbleDispenserDetails`, `KibbleDispenserContent` |
| `CaseCatNip` ← `Case` | — | ✓ | Carte Chance. Émet `cardDrawn`. | `CatNipContent` |
| `CaseCardBoardBox` ← `Case` | — | ✓ | Caisse de communauté. Émet `cardDrawn`. | `CardBoardBoxContent` |
| `CaseFreeNap` ← `Case` | — | ✓ | Parking gratuit. Cagnotte kibbles via `addToPool()`. | `FreeNapContent` |
| `CaseJail` ← `Case` | — | ✓ | Prison. Compteur tours par joueur, max 3 tours, `sendToJail/releasePlayer`. | `JailContent` |
| `CaseToJail` ← `Case` | — | ✓ | "Allez en prison". Référence `CaseJail` → envoie le joueur. | `ToJailContent` |
| `CaseFactory` | — | — | Factory statique `createCase(CaseType/QJsonObject)`. Enregistre les types QML via `registerCaseQml()`. | — |

---

## `game/map/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `Map` | — | ✓ | Carte chargée : `MapInfo` + liste `ItemSnapable`. Comptage par catégorie (case/déco/zone). Factory `loadMap()`. Contient : `MapInfo`, `ItemSnapable[]`. | `Editor`, `EditorLogic`, `EditorDynamicComponent` |
| `MapInfo` | — | ✓ | Métadonnées carte : nom, description, dates, version, fond, grille, musique + roster joueurs : `minPlayers`/`maxPlayers`, `playerConfigVersion`, liste `PlayerProfile` (add/remove/update/reorder + fallback Princess via `ensureFallbackProfile`). | `MapInfoPanel`, `MapSidePanel`, `MapInfoDrawer`, `MapNavigationBar` |
| `PlayerProfile` | — | ✓ | Profil joueur configurable : `name`, `modelName`, `colorVariant` (re-skin Color ID), `pickMode` (enum `PickMode` Unique/Shared/Mandatory), `minOccurrences` + paramètres physiques (`radius`, `mass`, `acceleration`, `maxSpeed`, `linearDamping`, `static`/`dynamicFriction`, `bounceFactor`). | `PCP_ProfileDetail`, `PCP_SkinPicker`, `AssetSelectionPanel` |
| `MapTypes` (namespace) | — | ✓ | Enum `Q_NAMESPACE` : `MapType { AUTOSAVE, CUSTOM, UNDOREDO }`. | — |
| `MapFileManager` | ✓ | ✓ | I/O fichier maps : existence, JSON read/write, renommage, listage, résolution chemins. | `MenuMapAtStart`, `EditorEscMenu`, `MapSidePanel` |
| `TemplateFileManager` | ✓ | ✓ | I/O templates. Conversion positions relatives/absolues, régénération IDs pour copier-coller. | `TP_Content` |
| `UndoRedoManager` | ✓ | ✓ | Historique snapshots `QJsonObject`. Navigation Preview/Next, flag restauration. | `Editor`, `EditorLogic`, `MapNavigationBar`, `NavArrowButton` |

---

## `game/physics/` — Moteur PattounX v2
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `pattounx::PattounX_engine` | — | — | Cœur de simulation Qt-free (`pattounx_engine_v2.{h,cpp}`) : pas de signaux/slots, API `upsertBody`/`upsertZone`/`step`/`writeSnapshot`. Types POD `BodySpec`/`ZoneSpec`/`BodySnapshot`/`WorldSnapshot` dans `pattounx_types.h`. | — |
| `PhysicsWorker` | — | — | `QThread` dédié qui fait tourner le moteur à 60 Hz. Reçoit les commandes GUI via signaux `Qt::QueuedConnection`. | — |
| `PhysicsWorld` *(contextProperty `pattounxWorld`)* | — | ✓ | Façade GUI du moteur. Triple buffer Fraser-Harris lock-free pour les snapshots, encode/décode réseau. Instance globale unique (pas singleton QML). | qml/world3d/* |
| `PhysicsSession` | ✓ | ✓ | Session physique host-authoritative sur `Catway` (calquée sur `EditorSession`). Broadcast snapshot 30 Hz fiable ; les clients relaient leurs inputs en fiable vers l'hôte qui simule pour tous. `registerQml`. | — |
| `PhysicsProtocol` | — | — | Pack/unpack des paquets physique, démultiplexage par plage de type-byte. | — |
| `PhysicsMessageType` (namespace) | — | ✓ | Enum `Q_NAMESPACE Value : quint8`, plage `0x40+` : `Snapshot`, `BodiesAnnounce`, `InputUpdate`, `Hello`. | — |
| `Collision2D` | — | — | Maths collision 2D. Contient : `Polygon2D` (struct), `CollisionResult` (struct), `SegmentResult` (struct). Statiques `checkCirclePolygon`, `applyBounce`, tests AABB. | — |

> Présentation 3D dans `qml/world3d/` : `World3D`, `PhysicsActor`, `PhysicsObjectSpawner`, `LocalPlayerSpawner`, `EditorPhysicsBridge`, `InputController`, `CameraRig`. Détails dans `doc/architecture/PHYSICS_ENGINE_V2.md`.

---

## `game/item_snapable/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `ItemSnapable` | — | ✓ | Tuile fondamentale. Selon `TileType` : (`Case`+`DisplayParameter`) ou (`DecorationParameter`+`DisplayParameter`) ou (`ZoneParameter`+`DisplayParameter`) ou (`PhysicalObjectParameter`+`DisplayParameter` pour `PhysicalObjectTile`). Graphe doublement lié next/prev pour topologie plateau. | `SnapableElement`, `SnapableDecoration`, `TileLogic`, `EditorDynamicComponent`, `Base_Board` |
| `DisplayParameter` | — | ✓ | Config visuelle : pos grille, taille, Z-layer, rotation, miroir, effets (luminosité, contraste, saturation, colorisation, flou, ombre). | `SnapableElement`, `visualEffectPanel/*` |
| `DecorationParameter` | — | ✓ | Décoration : catégorie, type, asset ID. `getAnimePath()` pour variantes animées. | `SnapableDecoration`, `ASP_Item`, `ASP_Grid` |
| `ZoneParameter` | — | ✓ | Zone physique : points polygone, couleur, nom, vélocité, friction, multiplicateurs vitesse/accél, flag exclusion. | `ZCP_GeneralSection`, `ZP_Content`, `MouseLogic_DrawPolygon` |
| `PhysicalObjectParameter` | — | ✓ | Paramètres caisse physique (`PhysicalObjectTile`) : `mass`, `bounceFactor`, `frictionStrength`, `linearDamping`. Sérialisé dans le JSON de map ; lus par Pattounx v2 à la création du Body `Dynamic`. | `SnapablePhysicalObject` |
| `ItemSnapableFactory` | ✓ | ✓ | Factory `ItemSnapable` (par type, JSON, zone). Bus signaux `createItemRequested`/`createItemsRequested` pour l'éditeur. | `EditorDynamicComponent`, `TileLogic`, `MouseLogic_Template` |

---

## `game/network/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `GameSession` | ✓ | ✓ | Session réseau Monopoly sur `Catway`. Host/client : diffusion authoritative vs intentions. UDP fiable pour plateau, UDP brut 60 Hz pour minijeux. | `GameSessionPanel`, `BoardEventsCard`, `MapSyncCard` |
| `MinigameSync` | — | ✓ | Sync temps-réel minijeux PattounX. Input à 60 Hz, snapshots ~1 Hz (host). Émet `playerPositionUpdated`. | `MinigameSyncPanel` |
| `GameProtocol` | — | — | Statique pur. Sérialise/désérialise paquets réseau (type byte + JSON) et format compact UDP `"MG:<x>;<y>;<vx>;<vy>"`. | — |
| `GameMessageType` (namespace) | — | ✓ | Enum `Q_NAMESPACE Value : quint8` : GameStart, DiceRoll, PlayerMove, BuyProperty, CardDraw, MinigameInput… | — |

---

## `editor/network/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `EditorSession` | ✓ | ✓ | Session collaborative host-authoritative sur `Catway` (calquée sur `GameSession`). Clients envoient des ops, l'hôte valide/rebroadcaste. Full-sync, présence (curseurs/sélections), migration d'hôte. | `Editor`, `EditorSessionPanel` |
| `EditorProtocol` | — | — | Pack/unpack des frames `[1 octet type][JSON UTF-8]`. `isEditorPacket` filtre par plage `>= Hello && <= <dernier type>`. | — |
| `EditorMessageType` (namespace) | — | ✓ | Enum `Q_NAMESPACE` des types de message éditeur, plage `0x20+` (coexiste avec `GameMessageType` 0x01–0x11). | — |

---

## `editor/ops/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `EditorOpBus` | ✓ | ✓ | Chokepoint QML de **toutes** les mutations de l'éditeur : `submitOp`/`submitOpWithUndo`, log, envoi via `EditorSession`, piles undo/redo par client. | `Editor`, `EditorOpsCard` |
| `EditorOpType` (namespace) | — | ✓ | Enum des types d'opération éditeur (Create/Delete/Move/Resize/Set*/Link/Unlink + ops Player Config 12-16). | — |

---

## `editor/painter/` — Rendu GPU 2D viewport-cullé *(Qt 6.11+)*
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `GridCanvasPainter` | — | ✓ | Un seul canvas pour toute la grille (croisillons, lignes), viewport culling. | `Editor` |
| `ZonesOverlayPainter` | — | ✓ | Un seul canvas pour toutes les zones polygonales (fill + contour + hachures), viewport culling. | `Editor` |
| `ZoneCanvasPainter` | — | ✓ | Legacy : 1 canvas par zone (fallback `MEOW_ZONES_RENDERER=per-tile`, sous `Loader`). | `SnapableExclusionZone` |
| `zone_hatch_compute` (namespace `zone_painter`) | — | — | Fonctions libres (pas de classe) `computeHatchSegments*` : calcul scanline factorisé des hachures (modes baseline/qtc/precompute(-async)). | — |

---

## `assetManager/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `AssetManager` | ✓ | ✓ | Découverte, chargement, cache et service de tous les assets graphiques. Lit `metadata.json`, construit `AssetModel` par catégorie+type. Contient : `Asset` (struct métadonnées), `AssetModel` (hérite `QAbstractListModel`). + sous-système modèles 3D & skins Color ID Map : `getAvailableModels`/`availablePlayerModels` (scan QRC `:/asset/models/` + `AppData/models/`), `modelDir`, `readModelManifest`, `listModelSkins`/`listSkinTextures`/`readSkinJson`/`listSkinVariants`/`loadSkinVariant`. | `ASP_Grid`, `ASP_Item`, `ASP_CategoryGrid`, `AssetSelectionPanel`, `SnapableDecoration`, `SnapableElement`, `ModelSelectionPanel`, `TEST_ASSET_MANAGER` |

---

## `launcher/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `LauncherManager` | ✓ | ✓ | Vérification/téléchargement mises à jour assets, décompression via `FolderCompressor`, gestion modèles IA. Création/upload packages dev. | `Launcher`, `LauncherLogic`, `LogsSection`, `ModelsSection` |

---

## `experiment/` *(WIP)*
| Classe | S | QML | Description |
|--------|---|-----|-------------|
| `AnimationManager` | — | ~✓ | Lecture séquences images (dossier/chemin), framerate configurable. Retourne `QImage` ou base64. |
| `AnimationProvider` | ✓ | ✓ | Séquence images → timer de frame → `frameChanged(QImage*)` pour `LiveImage`. |
| `LiveImage` | — | ✓ | `QQuickPaintedItem`. Peint les frames live d'`AnimationProvider` via `paint()`. |

---

## `reliable/`
| Élément | S | QML | Description |
|---------|---|-----|-------------|
| `reliable.h` (lib C tierce) | — | — | Livraison UDP fiable/ordonnée (ACKs, fragmentation, congestion). Mas Bandwidth LLC. Utilisée par `CatwayWorker` via `PlayerNetwork::initReliable()`. Types : `reliable_config_t`, `reliable_endpoint_t`. |
