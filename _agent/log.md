# Agent Log

Résumés des tâches effectuées par l'agent manager.

---

## 2026-03-07

### Fix — Freeze client (suite) : render timer 1000ms + addPlayer double connexion
- **Cause principale :** `m_renderTimer.setInterval(1000)` (valeur de test non restaurée) → `playerPositionUpdated` émis à 1Hz seulement → UI paraît gelée 99% du temps
- **Fix 2 :** `addPlayer` première branche (`== currentSocketInfo()`) ne faisait pas le `disconnect` avant `takeSocket()` → connexion dupliquée possible → ajout du `disconnect` en première branche
- **Fix 3 :** HP:PING (heartbeat) était loggé à chaque battement → filtré (`data != "HP:PING"`)
- **Fichiers modifiés :** `minigame_sync.cpp` + `catway.cpp`

### Fix — Freeze UI client (3 causes)
- **Cause 1 :** `reliable_log_level(RELIABLE_LOG_LEVEL_DEBUG)` → `catway_reliable_printf` → `qDebug()` → `OutputDebugString()` à 60Hz → Qt Creator saturé → `RELIABLE_LOG_LEVEL_NONE`
- **Cause 2 :** `qDebug()` dans `sendReliablePacket` pour chaque paquet fiable → supprimé
- **Cause 3 :** Le `disconnect` dans `addPlayer` était commenté → chaque joueur ajouté empilait une connexion sur `datagramReceived` → chaque paquet reçu déclenchait `onDatagramReceived` N fois → `disconnect` restauré
- **Fichiers modifiés :** `catway_worker.cpp` + `catway.cpp`

### Fix — Freeze UI : emit log() à 60Hz dans sendUdpDatagram (root cause)
- **Problème :** `Catway::sendUdpDatagram` émettait `log(...)` pour tout paquet UDP brut envoyé (condition `data[0] != '\x01'`), incluant les paquets de position `MG:` à 60Hz → 60 mises à jour QML/sec pour les logs → thread GUI saturé
- **Résultat :** Condition changée en `data.startsWith("HP:")` — le log n'est plus émis que pour les paquets de hole-punch
- **Fichier modifié :** `Meownopoly/cpp/communication/catway.cpp` (1 ligne)

### Fix — Freeze UI MinigameSync (throttling 30Hz)
- **Problème :** La connexion directe `minigameInputReceived → playerPositionUpdated` relayait chaque paquet UDP (60/sec) vers QML synchronement → boucle JS + `ListModel::setProperty` à 60Hz → queue d'événements Qt saturée → freeze permanent
- **Résultat :** Relay remplacé par un buffer `QHash<QString, RemotePos>` + timer `m_renderTimer` à 30Hz (33ms) — les paquets UDP intermédiaires sont écrasés dans le buffer, QML ne reçoit qu'au plus 30 signaux/sec
- **Fichiers modifiés :** `Meownopoly/cpp/game/network/minigame_sync.h` + `.cpp`

### Fix — Sélection de joueurs dans l'onglet Game Network
- **Problème :** Aucun message reçu — `GameSession.startAsClient` cherche le joueur hôte via `Catway.playerById(hostPlayerId)` mais sans liste de joueurs, l'ID était inconnu
- **Résultat :** `UdpPlayersPanel` ajouté comme 1ère colonne dans `GameNetworkTestTab.qml` — sélectionner un joueur remplit automatiquement `hostPlayerId` + badge peer affiché dans la zone mini-jeu
- **Fichiers modifiés :** `Meownopoly/qml/test/CatwayTest/GameNetworkTestTab.qml`

### Onglet de test Game Network
- **Tâche :** Ajouter un onglet "Game Network" dans `CatwayTest.qml` pour tester la couche `GameSession` / `MinigameSync`
- **Résultat :** Onglet fonctionnel avec 3 colonnes
  - Colonne 1 — Session : démarrage hôte/client/stop, badge actif/inactif, rôle
  - Colonne 2 — Mini-jeu UDP brut : zone de jeu avec point draggable local (violet), points distants (orange) via `MinigameSync` 60Hz, log snapshots
  - Colonne 3 — Reliable : MapSync (envoi/réception JSON) + Board Events (ComboBox 8 types, payload JSON, log)
- **Fichiers créés/modifiés :**
  - `Meownopoly/qml/test/CatwayTest/GameNetworkTestTab.qml` (créé)
  - `Meownopoly/qml/test/CatwayTest/CatwayTest.qml` (onglet 3 ajouté)
- **Fix :** import `MinigameSync 1.0` incorrect corrigé → `import GameSession 1.0` (les deux y sont enregistrés)

---

### Init
- Création du dossier `_agent` à la racine du projet (vide-poche de l'agent)
- Architecture du projet enregistrée :
  - `Meownopoly/` — projet Qt/QML (docs archi dans `doc/architecture`)
  - `asset_server/` — serveur de mises à jour de packs d'assets
  - `chatServer/` — serveur de chat encrypté + serveur STUN
  - `image_tools/` — outils Python pour création/modification d'images

### Rapport — Architecture Serveur de Jeu
- **Tâche :** Analyser la meilleure archi pour un serveur de jeu basé sur Catway
- **Résultat :** Rapport complet dans `reports/2026-03-07_architecture_game_server.md`
- **Recommandation :** Option C — `GameSession` singleton (composition au-dessus de Catway, sans modification de Catway)
  - `GameSession` : singleton hôte/client selon rôle
  - `GameProtocol` : sérialisation (type byte + JSON) + `GameMessageType` enum
  - 2 canaux : fiable (events Monopoly) + brut UDP (inputs minijeux 60Hz)
  - `broadcastReliable()` et `broadcastRaw()` ajoutés à Catway (nécessaires)
  - `MinigameSync` : timer 60Hz inputs + 1Hz snapshots hôte

### Implémentation serveur de jeu
- **Fichiers créés** dans `cpp/game/network/` :
  - `game_message_type.h` — enum `GameMessageType::Value` (0x01–0x0D fiable, 0x10–0x11 brut)
  - `game_protocol.h/cpp` — pack/unpack paquets fiables (type + JSON) + encode/decode input minijeu (UDP brut)
  - `game_session.h/cpp` — singleton QML, gère hôte/client, envoi/réception/relay
  - `minigame_sync.h/cpp` — type QML instanciable, timers 60Hz (inputs) + 1Hz (snapshots hôte)
- **Catway modifié** : ajout de `broadcastReliable(QByteArray)` et `broadcastRaw(QString)`
- **CMakeLists.txt** : include `cpp/game/network` ajouté
- **qmlapp.cpp** : `GameSession::registerQml()` + `MinigameSync::registerQml()` ajoutés
- **Import QML** : `import GameSession 1.0` → `GameSession`, `GameMessageType`, `MinigameSync`

### Onglet de test Game Network
- **Tâche :** Créer un onglet de test QML pour `GameSession` / `MinigameSync`
- **Résultat :** Onglet fonctionnel ajouté dans le panneau CatwayTest
- **Fichiers modifiés :**
  - `Meownopoly/qml/test/CatwayTest/GameNetworkTestTab.qml` — créé (3 colonnes : session, mini-jeu UDP, events fiables)
  - `Meownopoly/qml/test/CatwayTest/CatwayTest.qml` — 3ème `TabButton` "Game Network" + `ScrollView` / `GameNetworkTestTab` ajoutés

### Fix — Freeze UI MinigameSync (throttle 60Hz → 30Hz)
- **Problème :** Connexion directe `minigameInputReceived → playerPositionUpdated` émettait 60 signaux/sec vers QML → `ListModel::setProperty` à 60Hz saturait la queue d'événements → UI gelée
- **Solution :** Buffer `QHash<QString, RemotePos>` + `m_renderTimer` à 33ms (30Hz) qui émet `playerPositionUpdated` par tick
- **Fichiers modifiés :**
  - `Meownopoly/cpp/game/network/minigame_sync.h` — `#include <QHash>`, struct `RemotePos`, membres `m_renderTimer` / `m_remotePositions`, slots `onRemotePosition` / `onRenderTick`
  - `Meownopoly/cpp/game/network/minigame_sync.cpp` — connexion redirigée vers `onRemotePosition`, `m_renderTimer` démarré/stoppé dans `start()`/`stop()`, deux nouvelles méthodes ajoutées

### Sélection de joueur dans GameNetworkTestTab
- **Tâche :** Ajouter un panneau de sélection de joueurs connectés pour que `GameSession.startAsClient()` cible le bon peer
- **Résultat :** Colonne 0 `UdpPlayersPanel` ajoutée + auto-remplissage `hostPlayerIdField` + badge peer dans la zone mini-jeu
- **Fichiers modifiés :**
  - `Meownopoly/qml/test/CatwayTest/GameNetworkTestTab.qml` — `import Catway 1.0`, `selectedPlayer`, `onSelectedPlayerChanged`, panneau joueurs, hint texte, badge peer
