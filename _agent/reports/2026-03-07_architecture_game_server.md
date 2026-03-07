# Rapport — Architecture Serveur de Jeu (Meownopoly)
*Date : 2026-03-07*

---

## Contexte

Catway est un **singleton C++/Qt non sous-classable** (constructeur privé). Il est impossible d'en hériter.
Il fonctionne en **P2P pur UDP** (hole punching) avec transport fiable via `reliable.io`.
Il expose des signaux : `reliableMessageReceived(senderId, data)` et `udpMessageReceived(senderId, msg)`.

---

## Options Analysées

### Option A — `GameStateManager` (composition au-dessus de Catway)

Une classe indépendante qui se connecte aux signaux de Catway pour recevoir et envoyer des messages de jeu.

```
[QML / UI]
    ↕  Q_PROPERTY / Q_INVOKABLE
[GameStateManager]  ←→  (signaux/slots)  ←→  [Catway]
    ↕                                              ↕
[GameProtocol / MessageParser]             [CatwayWorker / UDP]
```

**Fonctionnement :**
- Se connecte à `Catway::reliableMessageReceived` pour les événements de jeu
- Utilise `Catway::sendReliableMessage()` pour émettre les actions
- L'hôte (premier participant = `ORDER BY joined_at ASC` dans chatServer) est **autoritaire**
- Les autres joueurs envoient des intentions → l'hôte valide → broadcast du nouvel état

**Avantages :**
- Aucun changement à Catway requis
- Séparation nette logique réseau / logique de jeu
- Facilement testable en isolation
- Extensible (IA locale, replay, etc.)

**Inconvénients :**
- L'hôte est un SPOF (si l'hôte crash, la session meurt)
- Latence supplémentaire pour les joueurs distants (message → hôte → validation → broadcast)

---

### Option B — `GameProtocol` injecté dans Catway

Ajouter une interface `IGameProtocolHandler` à Catway, injectable via une méthode `setGameProtocolHandler()`.
Catway démultiplexe alors les paquets fiables selon un second byte de type de message.

```
[Catway]
    → magic byte 0x01 : paquets reliable.io
        → byte de type 0x10 : game protocol → IGameProtocolHandler::onGameMessage()
        → byte de type 0x20 : signaux existants
```

**Avantages :**
- Multiplexage au niveau transport (plus efficace)
- Catway reste le point central de tout le réseau

**Inconvénients :**
- Modification de Catway nécessaire
- Mélange transport et logique de jeu dans le même composant
- Plus complexe à maintenir

---

### Option C — `GameServer` autorité full-host (composition + rôle dédié)

Variante de A où la classe se divise en deux comportements selon le rôle :
- `GameServer` (hôte) : maintient le state complet, valide toutes les actions, broadcast
- `GameClient` (participants) : proxy qui envoie des intentions et reçoit des états

Les deux héritent d'une interface commune `IGameSession` pour le code QML.

```
[QML]
    ↕
[IGameSession]
    ├── [GameServer]  (hôte → autoritaire)
    └── [GameClient]  (participant → proxy)
          ↕
       [Catway]
```

**Avantages :**
- Architecture la plus propre pour un Monopoly (jeu tour par tour, pas de low-latency critique)
- Facilement évolutif vers un vrai serveur dédié plus tard (remplacer `GameServer` par une connexion TCP)
- Cohérent avec la logique "hôte = premier participant" déjà dans chatServer

**Inconvénients :**
- Plus de classes à maintenir
- Comportement conditionnel à l'initialisation (qui est hôte ?)

---

## Deux modes réseau : Jeu de plateau vs Minijeux

La présence du moteur physique **PattounX** (temps réel, déplacements à chaque frame) impose une distinction fondamentale dans le protocole :

| Mode | Usage | Transport | Pourquoi |
|---|---|---|---|
| **Fiable** (`reliable.io`) | Jeu de plateau — événements Monopoly (tour, achat, dé, etc.) | `sendReliableMessage` | Livraison garantie, ordre préservé, perte inacceptable |
| **Brut UDP** | Minijeux — positions physiques PattounX | `sendUdpDatagram` (raw) | Latence minimale, perte tolérable, un paquet obsolète vaut mieux que retransmission |

**Règle de design :** un paquet de position ne doit jamais bloquer sur retransmission. Si un paquet de position est perdu, le prochain arrivera dans 16ms — c'est acceptable. Un ACK manqué de "joueur a acheté la propriété" ne l'est pas.

---

## Recommandation

### **Option C avec fallback sur A pour commencer**

L'architecture recommandée est :

1. **Créer `GameSession` (interface QML)** — exposée en QML via singleton ou context property
2. **Créer `GameSessionHost : public GameSession`** — valide les actions, maintient le state, broadcast
3. **Créer `GameSessionClient : public GameSession`** — envoie les intentions, applique les états reçus
4. **Créer `GameProtocol`** — namespace/classe statique pour la sérialisation des messages (QDataStream sur QByteArray)
5. **Créer `GameMessageType` (enum)** — multiplexage des types de messages avec le mode de transport associé

**Protocole de message :**
```
Mode fiable  → [1 byte: GameMessageType][payload QDataStream]   (events Monopoly)
Mode brut    → [1 byte: GameMessageType][payload compact]       (positions PattounX)
```

**Exemples de types de messages et leur canal :**
```
// Canal fiable (reliable.io)
TURN_START, DICE_ROLL, BUY_PROPERTY, PAY_RENT, CARD_DRAW, JAIL_IN/OUT...

// Canal brut UDP (non-fiable)
MINIGAME_POSITION,    // {playerId, x, y, vx, vy} compact (< 20 bytes)
MINIGAME_INPUT,       // {playerId, inputFlags}
MINIGAME_SYNC,        // snapshot complet périodique (envoyé en fiable toutes les ~1s pour recorriger)
```

**Stratégie de synchronisation pour les minijeux (PattounX) :**
- Chaque joueur simule sa propre physique localement (determinisme)
- Les inputs sont broadcastés en UDP brut à chaque frame (~60Hz)
- L'hôte (`GameSessionHost`) est le serveur autoritaire — il rebroadcast les positions validées
- Un snapshot complet est envoyé en **fiable** toutes les ~1s pour corriger la dérive

### Ce qui ne nécessite PAS de toucher Catway

Catway fournit déjà tout ce qu'il faut :
- Transport fiable 60Hz (`reliableMessageReceived`) ✅
- Transport brut UDP (`udpMessageReceived`) ✅
- Gestion des joueurs (`PlayerNetwork`) ✅
- Envoi fiable et brut ✅

### Ce qui devrait être ajouté à Catway (recommandé maintenant)

Compte tenu des deux modes réseau, ces deux extensions deviennent **nécessaires** (pas juste optionnelles) :

- **`Catway::broadcastReliable(data)`** — broadcast en un appel pour les events Monopoly
- **`Catway::broadcastRaw(data)`** — broadcast brut en un appel pour les positions minijeux (60Hz × N joueurs = beaucoup d'appels)

---

## Structure de fichiers proposée

```
Meownopoly/cpp/game/
    network/
        game_session.h              (interface commune QML)
        game_session_host.h/cpp     (logique hôte — autoritaire)
        game_session_client.h/cpp   (logique client — proxy)
        game_protocol.h/cpp         (sérialisation messages)
        game_message_type.h         (enum types + canal associé)
        minigame_sync.h/cpp         (gestion sync PattounX : inputs, snapshots)
```

---

## Conclusion

- **Deux canaux réseau distincts** sont nécessaires : fiable (events plateau) et brut UDP (physique minijeux)
- **Catway supporte déjà les deux** — mais `broadcastReliable()` et `broadcastRaw()` sont à ajouter
- **`MinigameSync`** gère la synchronisation PattounX : inputs en brut 60Hz + snapshots correctifs en fiable ~1Hz
- L'architecture `GameSessionHost` / `GameSessionClient` reste valide pour les deux modes

