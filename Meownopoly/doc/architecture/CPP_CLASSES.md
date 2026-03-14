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
| `Case` | — | ✓ | Base de toutes les cases. Enum `CaseType` (11 valeurs). Méthodes virtuelles `onLand/onLeave/onHover/toJSON`. | `CaseTile`, `TileContent`, `CaseConfigurationPanel` |
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
| `MapInfo` | — | ✓ | Métadonnées carte : nom, description, dates, version, fond, grille, musique. | `MapInfoPanel`, `MapSidePanel`, `MapInfoDrawer`, `MapNavigationBar` |
| `MapTypes` (namespace) | — | ✓ | Enum `Q_NAMESPACE` : `MapType { AUTOSAVE, CUSTOM, UNDOREDO }`. | — |
| `MapFileManager` | ✓ | ✓ | I/O fichier maps : existence, JSON read/write, renommage, listage, résolution chemins. | `MenuMapAtStart`, `EditorEscMenu`, `MapSidePanel` |
| `TemplateFileManager` | ✓ | ✓ | I/O templates. Conversion positions relatives/absolues, régénération IDs pour copier-coller. | `TP_Content` |
| `UndoRedoManager` | ✓ | ✓ | Historique snapshots `QJsonObject`. Navigation Preview/Next, flag restauration. | `Editor`, `EditorLogic`, `MapNavigationBar`, `NavArrowButton` |

---

## `game/physics/` — Moteur PattounX
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `PattounX_engine` | — | ✓ | "Feline Physics Solver". Gère `PattounX_body` et `PattounX_zone`, détection/résolution collisions, effets de zone. | `EntityEngine`, `MinigameSyncPanel` |
| `PattounX_body` | — | ✓ | Corps physique 2D : position, vélocité, masse, rayon, bounce/slide, damping. Créé par `createBody()`. | — |
| `PattounX_zone` | — | ~✓ | Zone polygonale : exclusion (mur) ou effet (vélocité/friction/vitesse). Basée sur `ItemSnapable`. | — |
| `Collision2D` | — | — | Maths collision 2D. Contient : `Polygon2D` (struct), `CollisionResult` (struct), `SegmentResult` (struct). Statiques `checkCirclePolygon`, `applyBounce`, tests AABB. | — |

---

## `game/item_snapable/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `ItemSnapable` | — | ✓ | Tuile fondamentale. Selon `TileType` : (`Case`+`DisplayParameter`) ou (`DecorationParameter`+`DisplayParameter`) ou (`ZoneParameter`+`DisplayParameter`). Graphe doublement lié next/prev pour topologie plateau. | `SnapableElement`, `SnapableDecoration`, `TileLogic`, `EditorDynamicComponent`, `Base_Board` |
| `DisplayParameter` | — | ✓ | Config visuelle : pos grille, taille, Z-layer, rotation, miroir, effets (luminosité, contraste, saturation, colorisation, flou, ombre). | `SnapableElement`, `visualEffectPanel/*` |
| `DecorationParameter` | — | ✓ | Décoration : catégorie, type, asset ID. `getAnimePath()` pour variantes animées. | `SnapableDecoration`, `ASP_Item`, `ASP_Grid` |
| `ZoneParameter` | — | ✓ | Zone physique : points polygone, couleur, nom, vélocité, friction, multiplicateurs vitesse/accél, flag exclusion. | `ZCP_GeneralSection`, `ZP_Content`, `MouseLogic_DrawPolygon` |
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

## `assetManager/`
| Classe | S | QML | Description | QML files |
|--------|---|-----|-------------|-----------|
| `AssetManager` | ✓ | ✓ | Découverte, chargement, cache et service de tous les assets graphiques. Lit `metadata.json`, construit `AssetModel` par catégorie+type. Contient : `Asset` (struct métadonnées), `AssetModel` (hérite `QAbstractListModel`). | `ASP_Grid`, `ASP_Item`, `ASP_CategoryGrid`, `AssetSelectionPanel`, `SnapableDecoration`, `SnapableElement`, `ModelSelectionPanel`, `TEST_ASSET_MANAGER` |

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
